#!/usr/bin/env python3
"""Generate and exercise a disposable web/API app with PostgreSQL or MySQL 8.4.
Owns its database container and Redis process; never accepts a deployment URL.
Keeps logs and resolved dependency locks under /tmp/azu-db-e2e-*.
"""
import argparse
from http.cookiejar import CookieJar
import json
import os
from pathlib import Path
import re
import secrets
import signal
import shutil
import socket
import subprocess
import tempfile
import threading
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, build_opener, HTTPCookieProcessor, HTTPRedirectHandler

ROOT = Path(__file__).resolve().parent.parent


def port():
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


def stop(process):
    if process and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adapter', choices=['postgresql', 'mysql'], required=True)
    parser.add_argument('--type', choices=['web', 'api'], required=True)
    args = parser.parse_args()
    work = Path(tempfile.mkdtemp(prefix='azu-db-e2e-'))
    app, evidence = work / 'compat_app', work / 'evidence'
    evidence.mkdir()
    print(f'Evidence: {evidence}', flush=True)
    cli = str(Path(os.environ.get('AZU_BIN', ROOT / 'bin/azu')).resolve())
    container = 'azu-compat-' + secrets.token_hex(5)
    database = 'azu_compat_' + secrets.token_hex(5)
    password = secrets.token_hex(16)
    db_port, redis_port, http_port = port(), port(), port()
    server = redis = None
    handles, snapshots, checks = [], [], []
    base_env = dict(os.environ, CRYSTAL_ENV='development', AZU_ENV='development',
                    REDIS_HOST='127.0.0.1', REDIS_PORT=str(redis_port),
                    REDIS_URL=f'redis://127.0.0.1:{redis_port}', HOST='127.0.0.1',
                    PORT=str(http_port), PORT_REUSE='false', PERFORMANCE_MONITORING='true')
    base_env.pop('DATABASE_URL', None)
    base_env['CRYSTAL_CACHE_DIR'] = str(work / 'compiler-cache')
    sequence = 0

    def run(command, cwd=None, env=None, ok=True, label='command'):
        nonlocal sequence
        sequence += 1
        path = evidence / f'{sequence:02d}-{label}.log'
        with path.open('w') as log:
            result = subprocess.Popen(list(map(str, command)), cwd=cwd or work, env=env or base_env,
                                      stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                result.wait(timeout=360)
            except subprocess.TimeoutExpired:
                # CLI commands spawn compilers; stop the entire owned process group.
                os.killpg(result.pid, signal.SIGKILL)
                result.wait()
                raise
        if (result.returncode == 0) != ok:
            raise AssertionError(f'{label}: unexpected exit {result.returncode}; see {path}')
        return path

    def passed(name):
        checks.append(name)
        print('PASS:', name, flush=True)

    def command(*argv, **kwargs):
        return run([cli, *argv], cwd=app, label=argv[0].replace(':', '-'), **kwargs)

    socket_path = str(work / 'telemetry.sock')
    listener = socket.socket(socket.AF_UNIX)
    listener.bind(socket_path)
    os.chmod(socket_path, 0o600)
    listener.listen()
    listener.settimeout(.25)
    done = threading.Event()

    def collect():
        while not done.is_set():
            try:
                connection, _ = listener.accept()
            except socket.timeout:
                continue
            except OSError:
                return
            with connection:
                connection.settimeout(.5)
                buffer = b''
                while not done.is_set():
                    try:
                        data = connection.recv(65536)
                        if not data:
                            break
                        buffer += data
                        assert len(buffer) <= 1_048_576, 'telemetry exceeds 1 MiB'
                        while b'\n' in buffer:
                            line, buffer = buffer.split(b'\n', 1)
                            snapshots.append(json.loads(line))
                    except socket.timeout:
                        continue
                    except (ValueError, AssertionError) as ex:
                        snapshots.append({'collector_error': str(ex)})
                        return
    collector = threading.Thread(target=collect, daemon=True)
    collector.start()
    try:
        log = (evidence / 'redis.log').open('w'); handles.append(log)
        redis = subprocess.Popen(['redis-server', '--bind', '127.0.0.1', '--port', str(redis_port),
                                  '--save', '', '--appendonly', 'no'], stdout=log, stderr=log)
        if args.adapter == 'postgresql':
            run(['docker', 'run', '-d', '--rm', '--name', container,
                 '-e', 'POSTGRES_PASSWORD=' + password, '-p', f'127.0.0.1:{db_port}:5432',
                 os.environ.get('E2E_POSTGRES_IMAGE', 'postgres:18')], label='postgres-start')
            url = f'postgres://postgres:{password}@127.0.0.1:{db_port}/{database}?connect_timeout=5'
            ready = ['docker', 'exec', container, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres']
        else:
            tls = work / 'tls'; tls.mkdir(); tls.chmod(0o755)
            run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2',
                 '-subj', '/CN=Azu Compatibility CA', '-keyout', tls/'ca-key.pem', '-out', tls/'ca.pem'], label='ca')
            run(['openssl', 'req', '-newkey', 'rsa:2048', '-nodes', '-subj', '/CN=localhost',
                 '-keyout', tls/'server-key.pem', '-out', tls/'server.csr'], label='csr')
            (tls/'extensions').write_text('subjectAltName=DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth\n')
            run(['openssl', 'x509', '-req', '-in', tls/'server.csr', '-CA', tls/'ca.pem',
                 '-CAkey', tls/'ca-key.pem', '-CAcreateserial', '-days', '2', '-extfile', tls/'extensions',
                 '-out', tls/'server-cert.pem'], label='certificate')
            # Disposable test key must be readable by the mysql UID in the container.
            for name in ('server-key.pem', 'server-cert.pem', 'ca.pem'):
                (tls/name).chmod(0o644)
            run(['docker', 'run', '-d', '--rm', '--name', container, '-e', 'MYSQL_ROOT_PASSWORD='+password,
                 '-e', 'MYSQL_ROOT_HOST=%', '-p', f'127.0.0.1:{db_port}:3306',
                 '-v', f'{tls}:/tls:ro', 'mysql:8.4', '--ssl-ca=/tls/ca.pem',
                 '--ssl-cert=/tls/server-cert.pem', '--ssl-key=/tls/server-key.pem',
                 '--require-secure-transport=ON'], label='mysql-start')
            url = f'mysql://root:{password}@127.0.0.1:{db_port}/{database}?' + urlencode(
                {'ssl-mode': 'verify_identity', 'ssl-ca': str(tls/'ca.pem'), 'connect_timeout': '5'})
            ready = ['docker', 'exec', '-e', 'MYSQL_PWD='+password, container, 'mysqladmin', '--protocol=TCP', '-h127.0.0.1', 'ping', '-uroot']
        for _ in range(120):
            if subprocess.run(ready, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                break
            time.sleep(.5)
        else:
            raise TimeoutError('database did not become ready')
        run([cli, 'new', 'compat_app', '--yes', '--author', 'Compatibility', '--email', 'test@example.test',
             '--type', args.type, '--db', args.adapter, '--no-git', '--no-docker', '--ci', 'None'], label='generate')
        run(['crystal', 'run', ROOT/'scripts/select_framework_versions.cr', '--', 'shard.yml'], cwd=app, label='versions')
        run(['shards', 'install'], cwd=app, label='install')
        (evidence/'shard.lock').write_text((app/'shard.lock').read_text())
        base_env['DATABASE_URL'] = url
        command('generate', 'scaffold', 'Post', 'title:string', 'published:bool')
        command('db:setup')
        command('db:migrate')
        command('db:status')
        command('db:rollback', '--force')
        command('db:migrate')
        passed('create, migrate twice, status, rollback and reapply')
        command('generate', 'seed', 'Posts')
        seed = next((app/'src/db/seeds/development').glob('*_posts.cr'))
        seed.write_text('Post.new(title: "seed-record", published: false).save!\n')
        command('db:seed'); command('db:seed')
        check = app/'check_seed.cr'
        check.write_text('require "./src/compat_app"\nraise "seed was duplicated" unless Post.all.count { |row| row.title == "seed-record" } == 1\n')
        run(['crystal', 'run', check], cwd=app, label='seed-count')
        failure = seed.parent/'99999999999999_failure.cr'; failure.write_text('raise "intentional seed failure"\n')
        failure_log = command('db:setup', '--seed', ok=False)
        assert 'intentional seed failure' in failure_log.read_text()
        failure.unlink()
        command('db:reset', '--force', '--seed')
        run(['crystal', 'run', check], cwd=app, label='reset-seed-count')
        passed('seed configuration, repeat-run tracking, failure exit and reset')
        if args.adapter == 'mysql':
            bad = dict(base_env, DATABASE_URL=url.replace('127.0.0.1', 'localhost'))
            # The CA is required; a system trust store must reject our private test CA.
            bad['DATABASE_URL'] = re.sub(r'&ssl-ca=[^&]+', '', url)
            rejected = command('db:create', env=bad, ok=False)
            assert re.search('certificate|SSL|TLS', rejected.read_text(), re.I), rejected.read_text()
            passed('MySQL 8.4 verified TLS, caching_sha2 authentication and untrusted CA rejection')
        (app/'src/endpoints/compat_failure.cr').write_text('''module CompatApp
  struct CompatFailureRequest
    include Azu::Request
  end
  struct CompatFailure
    include Azu::Endpoint(CompatFailureRequest, Azu::Response::Empty)
    get "/compat-failure"
    def call : Azu::Response::Empty
      raise "compatibility exception"
    end
  end
end
''')
        (app/'bin').mkdir(exist_ok=True)
        run(['crystal', 'build', 'src/server.cr' if args.type == 'web' else 'src/api.cr', '-o', 'bin/compat_app'], cwd=app, label='build')
        log = (evidence/'server.log').open('w'); handles.append(log)
        server_env = dict(base_env, AZU_TELEMETRY_SOCKET=socket_path)
        server = subprocess.Popen([str(app/'bin/compat_app')], cwd=app, env=server_env, stdout=log, stderr=log)
        base = f'http://127.0.0.1:{http_port}'
        client = build_opener(HTTPCookieProcessor(CookieJar()), NoRedirect())
        def http(path, method='GET', fields=None, expected=200):
            headers = {}; body = None
            if fields is not None:
                if args.type == 'api':
                    headers['Content-Type'] = 'application/json'; body = json.dumps(fields).encode()
                else:
                    headers['Content-Type'] = 'application/x-www-form-urlencoded'; body = urlencode(fields).encode()
            try:
                response = client.open(Request(base+path, data=body, method=method, headers=headers), timeout=10)
            except HTTPError as ex:
                response = ex
            text = response.read().decode()
            assert response.status == expected, f'{method} {path}: {response.status}, wanted {expected}: {text[:300]}'
            return text, response.headers
        for _ in range(100):
            assert server.poll() is None, 'server exited; see server.log'
            try:
                http('/health'); break
            except OSError:
                time.sleep(.1)
        else:
            raise TimeoutError('application readiness')
        if args.type == 'api':
            created, _ = http('/posts', 'POST', {'title':'live-record','published':True}, 201)
            identity = json.loads(created)['id']
            http(f'/posts/{identity}', 'PATCH', {'title':'updated-record'}, 200)
            assert 'updated-record' in http(f'/posts/{identity}')[0]
            http(f'/posts/{identity}', 'DELETE', expected=204)
        else:
            def token(path):
                return re.search(r'name="_csrf" value="([^"]+)"', http(path)[0]).group(1)
            _, headers = http('/posts', 'POST', {'title':'live-record','published':'true','_csrf':token('/posts/new')}, 303)
            location = headers['Location']
            http(location, 'POST', {'title':'updated-record','_method':'patch','_csrf':token(location+'/edit')}, 303)
            assert 'updated-record' in http(location)[0]
            http(location, 'POST', {'_method':'delete','_csrf':token(location)}, 303)
            identity = location.rsplit('/',1)[1]
        http(f'/posts/{identity}', expected=404)
        http('/posts')
        http('/compat-failure?password=do-not-export-this', expected=500)
        for _ in range(50):
            if any(s.get('sql', {}).get('recent') and s.get('errors') for s in snapshots):
                break
            time.sleep(.2)
        assert snapshots and not any('collector_error' in s for s in snapshots)
        latest = next((s for s in reversed(snapshots) if s.get('errors') and s.get('sql', {}).get('recent')), None)
        assert latest, 'no live SQL/error telemetry'
        assert latest['sql']['pool'] is not None, 'missing pool telemetry'
        assert all('ms' in query and 'params' not in query for query in latest['sql']['recent'])
        assert 'do-not-export-this' not in json.dumps(latest), 'request parameter leaked'
        assert any(e['problem']['status'] == 500 for e in latest['errors'])
        (evidence/'telemetry.json').write_text(json.dumps(latest, indent=2))
        passed('HTTP create/read/update/delete and real SQL/error/pool telemetry with redaction')
        (evidence/'report.json').write_text(json.dumps({'adapter':args.adapter,'type':args.type,'checks':checks}, indent=2))
    finally:
        stop(server); stop(redis)
        done.set(); listener.close(); collector.join(timeout=2)
        for handle in handles: handle.close()
        with (evidence/'database.log').open('w') as log:
            subprocess.run(['docker','logs',container], stdout=log, stderr=log)
        subprocess.run(['docker','rm','-f',container], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        shutil.rmtree(work/'compiler-cache', ignore_errors=True)
        print(f'Evidence retained: {evidence}', flush=True)


if __name__ == '__main__':
    main()
