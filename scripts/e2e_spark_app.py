#!/usr/bin/env python3
"""Browser acceptance for e2e_spark_app.sh's disposable SQLite fixture."""
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
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def stop(process):
    if process and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--evidence', type=Path, required=True)
    args = parser.parse_args()
    app, evidence = args.app.resolve(), args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    db = app / 'db/spark_lab_development.db'
    assert db.exists(), 'Generate and migrate the disposable spark_lab app first'
    def rows(sql, params=()):
        with sqlite3.connect(db) as conn:
            return conn.execute(sql, params).fetchall()
    assert not rows('select id from products'), 'Use a fresh fixture'
    port, redis_port = free_port(), free_port()
    base = f'http://localhost:{port}'
    env = os.environ.copy()
    for key in ('DATABASE_URL', 'SPARK_SECRET', 'CSRF_SECRET', 'SESSION_SECRET', 'REDIS_URL', 'REDIS_PASS'):
        env.pop(key, None)
    env.update(HOST='127.0.0.1', PORT=str(port), PORT_REUSE='false', REDIS_HOST='127.0.0.1',
               REDIS_PORT=str(redis_port), CRYSTAL_ENV='development', PERFORMANCE_MONITORING='false')
    handles, checks, failures = [], [], []
    server = redis = None
    def passed(name):
        checks.append(name)
        print(f'PASS: {name}', flush=True)
    def start_server():
        log = (evidence / 'server.log').open('a')
        handles.append(log)
        process = subprocess.Popen([str(app / 'bin/spark_lab')], cwd=app, env=env,
                                   stdout=log, stderr=subprocess.STDOUT)
        try:
            for _ in range(100):
                if process.poll() is not None:
                    raise RuntimeError('Application exited; inspect server.log')
                try:
                    with urlopen(base + '/', timeout=1) as response:
                        if response.status == 200:
                            return process
                except OSError:
                    time.sleep(0.1)
            raise TimeoutError('Application did not become ready')
        except BaseException:
            stop(process)
            raise
    try:
        redis = subprocess.Popen(['redis-server', '--bind', '127.0.0.1', '--port', str(redis_port),
                                  '--save', '', '--appendonly', 'no'], stdout=subprocess.DEVNULL,
                                 stderr=subprocess.STDOUT)
        server = start_server()
        with sync_playwright() as pw:
            browser = pw.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH') or shutil.which('chromium'),
                                         headless=True, args=['--no-sandbox'])
            context = browser.new_context(viewport={'width': 1440, 'height': 1100}, color_scheme='dark')
            context.on('response', lambda response: failures.append(f'{response.status} {response.url}') if response.status >= 500 else None)
            context.tracing.start(screenshots=True, snapshots=True, sources=True)
            page = context.new_page()
            page.on('pageerror', lambda error: failures.append(str(error)))
            page.set_default_timeout(10000)
            def live(target):
                expect(target.locator('html')).to_have_attribute('data-spark-status', 'connected')
                expect(target.get_by_role('button', name='Save', exact=True)).to_be_enabled()
            def fill(target, name, price='1299', active=True):
                target.get_by_label('Name', exact=True).fill(name)
                target.get_by_label('Price cents', exact=True).fill(price)
                target.get_by_label('Active', exact=True).set_checked(active)
            def save(target):
                target.get_by_role('button', name='Save', exact=True).click()
            def record(target, name):
                return target.locator('tbody tr').filter(has=target.get_by_role('link', name=name, exact=True))
            def edit(target, name):
                form = target.locator('form[spark-submit]')
                previous_form = form.get_attribute('id')
                row = record(target, name)
                record_id = row.get_by_role('link', name=name, exact=True).get_attribute('href').rsplit('/', 1)[1]
                row.get_by_role('button', name='Edit', exact=True).click()
                # Edit is a WebSocket round trip that replaces the editor. Waiting
                # for click actionability alone can type into the outgoing form.
                expect(form).not_to_have_attribute('id', previous_form)
                expect(target.get_by_role('heading', name=f'Edit product #{record_id}', exact=True)).to_be_visible()
                expect(target.get_by_label('Name', exact=True)).to_have_value(name)
            try:
                page.goto(base + '/counters/live')
                expect(page.get_by_role('button', name='Increase count')).to_be_enabled()
                page.get_by_role('button', name='Increase count').click()
                expect(page.locator('output').nth(0)).to_have_text('1')
                page.get_by_label('Title', exact=True).fill('Hello <em>Spark</em>')
                page.get_by_label('Title', exact=True).blur()
                expect(page.locator('output').nth(1)).to_have_text('Hello <em>Spark</em>')
                assert page.locator('output em').count() == 0
                page.get_by_label('Enabled', exact=True).check()
                expect(page.locator('output').nth(2)).to_have_text('true')
                page.screenshot(path=str(evidence / 'spark-counter.png'), full_page=True)
                page.get_by_role('button', name='Reset', exact=True).click()
                expect(page.locator('output').nth(0)).to_have_text('0')
                passed('Standalone component: typed events, escaped text and reset')

                page.get_by_role('navigation', name='Main', exact=True).get_by_role('link', name='Products', exact=True).click()
                live(page)
                peer = context.new_page()
                peer.on('pageerror', lambda error: failures.append(str(error)))
                peer.goto(base + '/products')
                live(peer)
                fill(page, 'Live <em>product</em>')
                save(page)
                expect(record(page, 'Live <em>product</em>')).to_be_visible()
                expect(record(peer, 'Live <em>product</em>')).to_be_visible()
                assert page.locator('tbody em').count() == 0
                assert rows('select name, price_cents, active from products') == [('Live <em>product</em>', 1299, 1)]
                expect(page.get_by_label('Name', exact=True)).to_have_value('')
                expect(page.get_by_label('Active', exact=True)).not_to_be_checked()
                passed('Live create commits to SQLite, resets its form and updates another tab')

                edit(page, 'Live <em>product</em>')
                page.get_by_label('Name', exact=True).fill('')
                page.locator('form[spark-submit]').evaluate('form => form.noValidate = true')
                save(page)
                expect(page.get_by_role('alert')).to_contain_text('name')
                assert rows('select name from products') == [('Live <em>product</em>',)]
                fill(page, 'Updated live product', '2599', False)
                save(page)
                expect(record(peer, 'Updated live product')).to_contain_text('false')
                assert rows('select price_cents, active from products') == [(2599, 0)]
                passed('Inline server validation rejects invalid data; edit persists unchecked booleans')

                peer.get_by_label('Name', exact=True).fill('Unsaved draft')
                edit(page, 'Updated live product')
                fill(page, 'Final live product', '3099', True)
                save(page)
                expect(record(peer, 'Final live product')).to_be_visible()
                expect(peer.get_by_label('Name', exact=True)).to_have_value('Unsaved draft')
                peer.get_by_role('button', name='Cancel', exact=True).click()
                expect(peer.get_by_label('Name', exact=True)).to_have_value('')
                passed('Peer broadcasts preserve a draft; explicit cancel clears it')

                fallback = context.new_page()
                fallback.goto(base + '/products/new')
                fill(fallback, 'HTTP fallback product')
                save(fallback)
                expect(fallback.locator('dd').nth(0)).to_have_text('HTTP fallback product')
                expect(record(page, 'HTTP fallback product')).to_be_visible()
                expect(record(peer, 'HTTP fallback product')).to_be_visible()
                fallback.get_by_role('link', name='Edit', exact=True).click()
                fill(fallback, 'HTTP updated product')
                save(fallback)
                expect(record(page, 'HTTP updated product')).to_be_visible()
                page.screenshot(path=str(evidence / 'spark-products.png'), full_page=True)
                passed('HTTP create/update services also invalidate live lists')

                record(page, 'Final live product').get_by_role('button', name='Delete', exact=True).click()
                page.get_by_role('button', name='Keep record').click()
                assert len(rows('select id from products')) == 2
                edit(peer, 'Final live product')
                record(page, 'Final live product').get_by_role('button', name='Delete', exact=True).click()
                page.get_by_role('button', name='Delete record', exact=True).click()
                expect(record(peer, 'Final live product')).to_have_count(0)
                assert rows('select name from products') == [('HTTP updated product',)]
                save(peer)
                expect(peer.get_by_role('alert')).to_contain_text('no longer exists')
                assert rows('select name from products') == [('HTTP updated product',)]
                peer.get_by_role('button', name='Cancel', exact=True).click()
                passed('Confirmed delete refreshes peers; saving a concurrently deleted record fails safely')

                stop(server)
                expect(page.locator('html')).not_to_have_attribute('data-spark-status', 'connected')
                server = start_server()
                live(page)
                live(peer)
                expect(record(page, 'HTTP updated product')).to_be_visible()
                assert len(rows('select id from products')) == 1
                passed('Restart/reconnect retains persisted data without duplicate writes')

                with sqlite3.connect(db) as conn:
                    conn.executemany('insert into products (name, price_cents, active, created_at, updated_at) values (?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)',
                                     [(f'Catalog product {i:02}', 1000 + i, 1) for i in range(26)])
                page.get_by_role('button', name='Refresh', exact=True).click()
                expect(page.locator('tbody tr')).to_have_count(25)
                page.get_by_role('button', name='Next', exact=True).click()
                expect(page.locator('tbody tr')).to_have_count(2)
                expect(page.get_by_role('button', name='Next', exact=True)).to_be_disabled()
                page.get_by_role('button', name='Previous', exact=True).click()
                expect(page.locator('tbody tr')).to_have_count(25)
                passed('Bounded 25-row paging, refresh, next and previous')
                page.screenshot(path=str(evidence / 'spark-products-paging.png'), full_page=True)
                page.set_viewport_size({'width': 390, 'height': 844})
                assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), 'Mobile horizontal overflow'
                page.screenshot(path=str(evidence / 'spark-products-mobile.png'), full_page=True)
                passed('Responsive live UI has no document overflow on mobile')

                offline_context = browser.new_context(java_script_enabled=False)
                offline = offline_context.new_page()
                offline.goto(base + '/products')
                expect(offline.get_by_role('button', name='Save', exact=True)).to_be_disabled()
                offline.get_by_role('link', name='standard form').click()
                fill(offline, 'No JavaScript product')
                save(offline)
                expect(offline.locator('dd').nth(0)).to_have_text('No JavaScript product')
                offline_context.close()
                passed('Without JavaScript, disabled live controls and usable HTTP form fallback')
                assert not failures, failures
            except Exception:
                failures.append(traceback.format_exc())
                page.screenshot(path=str(evidence / 'failure.png'), full_page=True)
                raise
            finally:
                context.tracing.stop(path=str(evidence / 'trace.zip'))
                os.chmod(evidence / 'trace.zip', 0o600)
                browser.close()
    except Exception:
        if not failures:
            failures.append(traceback.format_exc())
        raise
    finally:
        stop(server)
        stop(redis)
        for handle in handles:
            handle.close()
        (evidence / 'report.json').write_text(json.dumps({'checks': checks, 'failures': failures}, indent=2) + '\n')


if __name__ == '__main__':
    main()
