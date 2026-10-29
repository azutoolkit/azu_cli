#!/usr/bin/env python3
"""Real Chromium acceptance checks for the fixture from e2e_browser_app.sh.

Requires Python Playwright and Chromium. Only uses disposable local app/database
resources; never point this runner at a deployed application.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import sqlite3
import subprocess
import time
import traceback
from urllib.request import urlopen

from playwright.sync_api import expect, sync_playwright


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--cli", type=Path, required=True)
    args = parser.parse_args()
    app, evidence, cli = args.app.resolve(), args.evidence.resolve(), args.cli.resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    db = app / "db/browser_shop_development.db"
    assert db.exists(), "Generate and migrate the disposable browser_shop app first"
    with sqlite3.connect(db) as conn:
        assert conn.execute("select count(*) from products").fetchone()[0] == 0, "Use a fresh fixture"
        assert conn.execute("select count(*) from users").fetchone()[0] == 0, "Use a fresh fixture"

    port, redis_port = free_port(), free_port()
    base = f"http://localhost:{port}"
    env = os.environ.copy()
    for key in ("DATABASE_URL", "CSRF_SECRET", "SESSION_SECRET", "REDIS_URL", "REDIS_PASS"):
        env.pop(key, None)
    env.update(HOST="127.0.0.1", PORT=str(port), PORT_REUSE="false",
               REDIS_HOST="127.0.0.1", REDIS_PORT=str(redis_port),
               CRYSTAL_ENV="development", PERFORMANCE_MONITORING="false")
    checks, failures, console_errors = [], [], []
    server = redis = None
    handles = []
    started = time.monotonic()

    def passed(name):
        checks.append(name)
        print(f"PASS: {name}", flush=True)

    def command(name, *argv):
        with (evidence / f"{name}.log").open("w") as log:
            subprocess.run(argv, cwd=app, env=env, stdout=log, stderr=subprocess.STDOUT,
                           timeout=300, check=True)

    def rows(sql):
        with sqlite3.connect(db) as conn:
            return conn.execute(sql).fetchall()

    def start_server():
        log = (evidence / "server.log").open("a")
        handles.append(log)
        process = subprocess.Popen([str(app / "bin/browser_shop")], cwd=app, env=env,
                                   stdout=log, stderr=subprocess.STDOUT)
        for _ in range(100):
            if process.poll() is not None:
                raise RuntimeError("Application exited; inspect server.log")
            try:
                with urlopen(base + "/", timeout=1) as response:
                    if response.status == 200:
                        return process
            except OSError:
                time.sleep(0.1)
        process.terminate()
        process.wait(timeout=10)
        raise TimeoutError("Application did not become ready")

    def stop(process):
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)

    try:
        redis = subprocess.Popen(["redis-server", "--bind", "127.0.0.1", "--port", str(redis_port),
                                  "--save", "", "--appendonly", "no"],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
        server = start_server()
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                executable_path=os.environ.get("CHROMIUM_PATH") or shutil.which("chromium"),
                headless=True, args=["--no-sandbox"])
            context = browser.new_context(viewport={"width": 1440, "height": 1000},
                                          color_scheme="dark")
            context.tracing.start(screenshots=True, snapshots=True, sources=True)
            page = context.new_page()
            page.on("pageerror", lambda error: failures.append(str(error)))
            page.on("console", lambda message: console_errors.append(message.text) if message.type == "error" else None)
            page.on("response", lambda response: failures.append(f"{response.status} {response.url}") if response.status >= 500 else None)
            page.set_default_timeout(10000)

            def shot(name):
                page.screenshot(path=str(evidence / f"{name}.png"), full_page=True)

            def no_overflow():
                assert page.evaluate("document.documentElement.scrollWidth <= innerWidth"), "Horizontal overflow"

            def create_product(name):
                page.get_by_role("link", name="New product", exact=True).click()
                page.get_by_label("Name", exact=True).fill(name)
                page.get_by_label("Price cents", exact=True).fill("1299")
                page.get_by_label("Active", exact=True).check()
                page.get_by_role("button", name="Save", exact=True).click()
                expect(page.locator("dd").nth(0)).to_have_text(name)
                expect(page.locator("dd").nth(2)).to_have_text("true")
                return page.url

            try:
                page.goto(base)
                expect(page.get_by_role("heading", level=1)).to_be_visible()
                shot("00-home-dark")
                page.get_by_role("link", name="Build your first page").click()
                expect(page).to_have_url(base + "/#next-steps")
                page.locator("[data-theme-toggle]").click()
                assert page.evaluate("localStorage.getItem('azu-theme')") is not None
                shot("01-home")
                passed("Home, internal navigation and theme control")

                # Generators register the section in the shared desktop/mobile partial.
                page.get_by_role("navigation", name="Main", exact=True).get_by_role("link", name="Products", exact=True).click()
                expect(page.get_by_role("navigation", name="Main", exact=True).get_by_role("link", name="Products", exact=True)).to_have_attribute("aria-current", "page")
                expect(page.get_by_text("No products yet", exact=True)).to_be_visible()
                shot("01-products-empty")
                passed("Generated section is reachable from the sidebar with an active state and empty-state action")
                page.get_by_role("link", name="New product").click()
                page.get_by_role("button", name="Save").click()
                expect(page).to_have_url(base + "/products/new")
                assert page.get_by_label("Name", exact=True).evaluate("e => e.validity.valueMissing")
                page.get_by_label("Price cents").fill("1299")
                # Explicitly bypass only HTML required validation to exercise server validation.
                page.locator("form[action='/products']").evaluate("form => form.noValidate = true")
                with page.expect_navigation() as invalid:
                    page.get_by_role("button", name="Save").click()
                assert invalid.value.status == 422
                assert not rows("select id from products")
                passed("Browser required validation and server 422 reject an empty product")

                page.goto(base + "/products")
                product_url = create_product("Browser <em>product</em>")
                assert page.locator("dd em").count() == 0
                shot("02-product-created")
                page.get_by_role("link", name="Edit", exact=True).click()
                page.get_by_label("Name", exact=True).fill("Updated browser product")
                page.get_by_label("Price cents").fill("2599")
                page.get_by_label("Active", exact=True).uncheck()
                page.get_by_role("button", name="Save").click()
                expect(page.locator("dd")).to_have_text(["Updated browser product", "2599", "false"])
                page.get_by_role("link", name="Back", exact=True).click()
                page.get_by_role("link", name="Updated browser product", exact=True).click()
                page.get_by_role("button", name="Delete", exact=True).click()
                expect(page.get_by_role("dialog")).to_be_visible()
                page.get_by_role("dialog").get_by_role("button", name="Cancel", exact=True).click()
                assert len(rows("select id from products")) == 1
                page.get_by_role("button", name="Delete", exact=True).click()
                page.get_by_role("dialog").get_by_role("button", name="Delete record", exact=True).click()
                expect(page).to_have_url(base + "/products")
                assert not rows("select id from products")
                assert context.request.get(product_url).status == 404
                passed("Clicked product create, list, show, edit, checkbox update and delete; escaped HTML")

                page.set_viewport_size({"width": 390, "height": 844})
                page.get_by_label("Open navigation", exact=True).click()
                expect(page.get_by_role("navigation", name="Mobile", exact=True)).to_be_visible()
                shot("02-mobile-navigation")
                page.get_by_role("navigation", name="Mobile", exact=True).get_by_role("link", name="Products", exact=True).click()
                persisted_url = create_product("Survives server restart")
                assert page.get_by_role("link", name="Edit", exact=True).evaluate("e => getComputedStyle(e).backgroundColor") != "rgba(0, 0, 0, 0)"
                no_overflow()
                page.get_by_role("link", name="Edit", exact=True).click()
                no_overflow()
                shot("03-mobile-product-form")
                page.get_by_role("link", name="Cancel", exact=True).click()
                no_overflow()
                shot("04-mobile-products")
                passed("Mobile 390px product forms/list work without horizontal overflow")

                page.get_by_label("Open navigation", exact=True).click()
                page.get_by_role("navigation", name="Mobile", exact=True).get_by_role("link", name="Account", exact=True).click()
                expect(page).to_have_url(base + "/login")
                page.get_by_role("link", name="Sign up", exact=True).click()
                page.get_by_label("Email", exact=True).fill("browser-e2e@example.test")
                page.get_by_label("Password", exact=True).fill("Browser test password 42!")
                page.get_by_role("button", name="Create account", exact=True).click()
                expect(page).to_have_url(base + "/login")
                assert rows("select password_digest from users")[0][0].startswith("$2")
                page.get_by_label("Email", exact=True).fill("browser-e2e@example.test")
                page.get_by_label("Password", exact=True).fill("Wrong password")
                page.get_by_role("button", name="Sign in", exact=True).click()
                expect(page.get_by_text("Invalid email or password", exact=True)).to_be_visible()
                page.get_by_label("Email", exact=True).fill("browser-e2e@example.test")
                page.get_by_label("Password", exact=True).fill("Browser test password 42!")
                page.get_by_role("button", name="Sign in", exact=True).click()
                expect(page).to_have_url(base + "/account")
                expect(page.get_by_text("browser-e2e@example.test", exact=True)).to_be_visible()
                no_overflow()
                shot("05-mobile-account")
                expect(page.locator(".avatar-placeholder")).to_be_visible()
                assert page.locator(".avatar-placeholder > div").evaluate("e => getComputedStyle(e).display") == "flex"
                cookie = next(c for c in context.cookies() if c["name"] == "browser_shop_session")
                assert cookie["secure"] and cookie["httpOnly"] and cookie["sameSite"] == "Strict"
                page.get_by_role("button", name="Sign out").click()
                page.goto(base + "/account")
                expect(page).to_have_url(base + "/login")
                page.get_by_label("Email", exact=True).fill("browser-e2e@example.test")
                page.get_by_label("Password", exact=True).fill("Browser test password 42!")
                page.get_by_role("button", name="Sign in", exact=True).click()
                expect(page).to_have_url(base + "/account")
                passed("Clicked registration, invalid/valid login, protected account and logout; bcrypt and cookie flags")

                assert context.request.post(base + "/products", form={"name": "CSRF", "price_cents": "1"}).status == 403
                passed("A state-changing request without a CSRF token is refused")
                result = page.evaluate("""async () => {
                  const a = new WebSocket(`ws://${location.host}/chat`);
                  const b = new WebSocket(`ws://${location.host}/chat`);
                  let timer;
                  try {
                    return await Promise.race([
                      (async () => {
                        await Promise.all([a,b].map(s => new Promise((resolve,reject) => {
                          s.onopen = resolve; s.onerror = reject;
                        })));
                        const received = Promise.all([a,b].map(s => new Promise(resolve => {
                          s.onmessage = e => resolve(e.data);
                        })));
                        a.send('browser broadcast'); return await received;
                      })(),
                      new Promise((_,reject) => {timer = setTimeout(() => reject(new Error('WebSocket timeout')),5000);})
                    ]);
                  } finally {clearTimeout(timer); a.close(); b.close();}
                }""")
                assert result == ["browser broadcast", "browser broadcast"]
                passed("Two real browser WebSocket clients receive the generated chat broadcast")

                with browser.new_context(java_script_enabled=False, viewport={"width": 390, "height": 844}, color_scheme="dark") as plain:
                    plain_page = plain.new_page()
                    plain_page.goto(base)
                    plain_page.get_by_label("Open navigation", exact=True).click()
                    plain_page.get_by_role("navigation", name="Mobile", exact=True).get_by_role("link", name="Products", exact=True).click()
                    plain_page.get_by_role("link", name="New product", exact=True).click()
                    plain_page.get_by_role("button", name="Save", exact=True).click()
                    expect(plain_page).to_have_url(base + "/products/new")
                    assert plain_page.get_by_label("Name", exact=True).evaluate("e => e.validity.valueMissing")
                    plain_page.screenshot(path=str(evidence / "05-mobile-no-javascript.png"), full_page=True)
                passed("Mobile navigation and required forms work with application JavaScript disabled")

                stop(server)
                before = rows("select version from cql_schema_migrations order by version")
                command("incremental-generate", str(cli), "generate", "model", "Audit", "code:string")
                command("incremental-migrate", str(cli), "db:migrate")
                assert rows("select name from sqlite_master where name='audits'")
                assert len(rows("select version from cql_schema_migrations")) == len(before) + 1
                command("rollback", str(cli), "db:rollback", "--steps", "1", "--force")
                assert not rows("select name from sqlite_master where name='audits'")
                assert rows("select version from cql_schema_migrations order by version") == before
                command("reapply", str(cli), "db:migrate")
                reapplied = rows("select version from cql_schema_migrations order by version")
                command("idempotence", str(cli), "db:migrate")
                assert rows("select version from cql_schema_migrations order by version") == reapplied
                assert len(reapplied) == len(before) + 1
                assert rows("select name from products") == [("Survives server restart",)]
                assert len(rows("select id from users")) == 1
                passed("Incremental migration, rollback, reapply and idempotence preserve existing app data")

                command("rebuild", "crystal", "build", "src/server.cr", "-o", "bin/browser_shop", "--error-trace")
                server = start_server()
                page.reload()
                expect(page).to_have_url(base + "/account")
                expect(page.get_by_text("browser-e2e@example.test", exact=True)).to_be_visible()
                page.set_viewport_size({"width": 1440, "height": 1000})
                page.goto(persisted_url)
                expect(page.locator("dd").nth(0)).to_have_text("Survives server restart")
                shot("06-after-restart")
                passed("Authenticated browser session and product survive rebuild and server restart")
                command("generated-specs", "crystal", "spec", "--error-trace")
                passed("Generated application Crystal specs")
                assert not failures, failures
                passed("No browser JavaScript exceptions or HTTP 5xx responses")
            except Exception:
                shot("failure")
                raise
            finally:
                context.tracing.stop(path=str(evidence / "browser-trace.zip"))
                # Trace includes synthetic session/CSRF cookies; keep it local/private.
                (evidence / "browser-trace.zip").chmod(0o600)
                browser.close()
    except Exception:
        failures.append(traceback.format_exc())
        raise
    finally:
        stop(server)
        stop(redis)
        for handle in handles:
            handle.close()
        shutil.copyfile(app / "shard.lock", evidence / "shard.lock")
        report = {"passed": checks, "failures": failures, "console_errors": console_errors,
                  "duration_seconds": round(time.monotonic() - started, 1), "app": str(app),
                  "dependency_versions": "shard.lock",
                  "scope": "Local Chromium, generated web scaffold, SQLite, isolated Redis; not hosted infrastructure certification"}
        (evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        (evidence / "report.md").write_text(
            "# Generated application browser acceptance\n\n"
            + ("PASS" if not failures else "FAIL") + f" — {len(checks)} checks passed.\n\n"
            + "\n".join(f"- {check}" for check in checks)
            + "\n\n" + report["scope"] + ".\n"
            + "\nExact resolved dependency versions are recorded in shard.lock.\n"
            + "\nScreenshots are from the running app. browser-trace.zip contains synthetic session cookies; keep it private.\n"
            + ("\n```\n" + "\n".join(failures) + "\n```\n" if failures else ""))


if __name__ == "__main__":
    main()
