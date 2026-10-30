#!/usr/bin/env python3
"""Exercise generated session auth and its real telemetry publisher in Chromium.

Usage: python3 scripts/check_auth_telemetry.py DISPOSABLE_SQLITE_APP APP_BINARY
Generate auth, migrate and build the disposable app first. Requires Playwright,
Chromium and redis-server. Only ephemeral local services are started.
"""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
import uuid
from urllib.request import urlopen

from playwright.sync_api import expect, sync_playwright


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def stop(process):
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


app, binary = (Path(value).resolve() for value in sys.argv[1:3])
databases = list((app / "db").glob("*_development.db"))
assert len(databases) == 1, "Migrate the disposable SQLite app first"
snapshots = []
lock = threading.Lock()
done = threading.Event()


def drain(client):
    with client, client.makefile() as stream:
        for line in stream:
            data = json.loads(line)
            if data.get("stream") == "auth":
                with lock:
                    snapshots.append(data)


with tempfile.TemporaryDirectory(prefix="azu-auth-check-") as directory:
    path = str(Path(directory) / "telemetry.sock")
    listener = socket.socket(socket.AF_UNIX)
    listener.bind(path)
    os.chmod(path, 0o600)
    listener.listen(4)
    listener.settimeout(0.2)

    def accept():
        while not done.is_set():
            try:
                client, _ = listener.accept()
            except socket.timeout:
                continue
            threading.Thread(target=drain, args=(client,), daemon=True).start()

    thread = threading.Thread(target=accept, daemon=True)
    thread.start()
    port, redis_port = free_port(), free_port()
    env = dict(os.environ, HOST="127.0.0.1", PORT=str(port), PORT_REUSE="false",
               CRYSTAL_ENV="development", PERFORMANCE_MONITORING="true",
               AZU_TELEMETRY_SOCKET=path, DATABASE_URL=f"sqlite3://{databases[0]}",
               REDIS_HOST="127.0.0.1", REDIS_PORT=str(redis_port))
    for key in ("CSRF_SECRET", "SESSION_SECRET", "REDIS_URL", "REDIS_PASS"):
        env.pop(key, None)
    email = f"auth-{uuid.uuid4().hex}@example.test"
    password = "Disposable auth test password 42!"
    base = f"http://localhost:{port}"
    server = redis = None
    try:
        redis = subprocess.Popen(["redis-server", "--bind", "127.0.0.1", "--port", str(redis_port),
                                  "--save", "", "--appendonly", "no"], stdout=subprocess.DEVNULL)
        with tempfile.TemporaryFile(mode="w+") as log:
            server = subprocess.Popen([str(binary)], cwd=app, env=env, stdout=log, stderr=subprocess.STDOUT)
            for _ in range(100):
                if server.poll() is not None:
                    log.seek(0)
                    raise RuntimeError("App exited: " + log.read()[-4000:])
                try:
                    urlopen(base + "/", timeout=1).close()
                    break
                except OSError:
                    time.sleep(0.1)
            else:
                raise TimeoutError("App did not start")

            with sync_playwright() as playwright:
                browser = playwright.chromium.launch(
                    executable_path=os.environ.get("CHROMIUM_PATH") or shutil.which("chromium"),
                    headless=True, args=["--no-sandbox"])
                page = browser.new_page()
                page.goto(base + "/register")
                page.get_by_label("Email", exact=True).fill(email)
                page.get_by_label("Password", exact=True).fill(password)
                page.get_by_role("button", name="Create account", exact=True).click()
                expect(page).to_have_url(base + "/login")
                page.get_by_label("Email", exact=True).fill(email)
                page.get_by_label("Password", exact=True).fill("Wrong password")
                page.get_by_role("button", name="Sign in", exact=True).click()
                expect(page.get_by_text("Invalid email or password", exact=True)).to_be_visible()
                page.get_by_label("Email", exact=True).fill(email)
                page.get_by_label("Password", exact=True).fill(password)
                page.get_by_role("button", name="Sign in", exact=True).click()
                expect(page).to_have_url(base + "/account")
                page.get_by_role("button", name="Sign out", exact=True).click()
                expect(page).to_have_url(base + "/login")
                browser.close()

            expected = [("sign-up", "accepted"), ("sign-in", "rejected"),
                        ("sign-in", "accepted"), ("sign-out", "accepted")]
            for _ in range(50):
                with lock:
                    data = snapshots[-1] if snapshots else {}
                rows = data.get("auth", {}).get("recent", [])
                if [(row["event"], row["outcome"]) for row in reversed(rows)] == expected:
                    break
                time.sleep(0.1)
            else:
                raise AssertionError(f"Missing auth outcomes: {data}")
            assert all(set(row) == {"id", "at", "event", "outcome"} for row in rows)
            assert email not in json.dumps(data) and password not in json.dumps(data)
            print("PASS: generated registration, rejected/accepted login, logout and private socket events; no credentials exported")
    finally:
        stop(server)
        stop(redis)
        done.set()
        thread.join(timeout=2)
        listener.close()
