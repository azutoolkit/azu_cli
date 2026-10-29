#!/usr/bin/env python3
"""Verify CQL JSON APIs and the narrower generated instance-save limitation.
Default: private SQLite database. --postgres also owns a disposable PostgreSQL container.
A future CQL release that fixes instance saving must fail this check so the CLI gate is revisited.
"""
import argparse
import os
from pathlib import Path
import secrets
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / 'spec/fixtures/cql_json'


def run(args, **kwargs):
    return subprocess.run(list(map(str, args)), cwd=ROOT, check=True, timeout=240, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--postgres', action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='azu-cql-json-') as directory:
        work = Path(directory)
        binary = work / 'json-probe'
        run(['crystal', 'build', FIXTURES/'query_builder.cr', '-o', binary, '--error-trace'])
        env = dict(os.environ, CQL_JSON_ADAPTER='SQLite', CQL_JSON_DATABASE_URL=f'sqlite3://{work}/probe.db')
        run([binary], env=env)
        failure = subprocess.run(['crystal', 'build', str(FIXTURES/'generated_save.cr'), '--no-codegen', '--error-trace'],
                                 cwd=ROOT, env=env, capture_output=True, text=True, timeout=240)
        output = failure.stdout + failure.stderr
        if failure.returncode == 0:
            raise AssertionError('Instance save! now compiles: validate persistence and remove the CLI JSON generation gate.')
        if not all(part in output for part in ('active_record/attributes.cr', 'Hash(Symbol,', 'not JSON::Any')):
            raise AssertionError('Unexpected compiler failure:\n' + output)
        print('PASS: generated instance save! reproduces the specific JSON::Any-to-DB::Any attributes error', flush=True)
        if not args.postgres:
            return
        with socket.socket() as connection:
            connection.bind(('127.0.0.1', 0))
            port = connection.getsockname()[1]
        container, password = 'azu-json-' + secrets.token_hex(5), secrets.token_hex(16)
        try:
            run(['docker', 'run', '-d', '--rm', '--name', container, '-e', 'POSTGRES_PASSWORD='+password,
                 '-p', f'127.0.0.1:{port}:5432', 'postgres:18'], stdout=subprocess.DEVNULL)
            for _ in range(120):
                ready = subprocess.run(['docker', 'exec', container, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres'],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
                if ready.returncode == 0:
                    break
                time.sleep(.25)
            else:
                raise TimeoutError('Disposable PostgreSQL did not become ready')
            env.update(CQL_JSON_ADAPTER='Postgres', CQL_JSON_DATABASE_URL=f'postgres://postgres:{password}@127.0.0.1:{port}/postgres')
            run([binary], env=env)
        finally:
            subprocess.run(['docker', 'rm', '-f', container], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)


if __name__ == '__main__':
    main()
