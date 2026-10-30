#!/usr/bin/env python3
"""Generate an Azu v1 app and exercise jobs commands against an owned Redis.
Usage: python3 scripts/check_jobs_commands.py /absolute/path/to/azu
Requires Crystal, shards, redis-server and redis-cli. Never uses an external Redis.
"""
import json
import os
import re
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time

binary = str(Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="azu-jobs-commands-") as temporary:
    root = Path(temporary)
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    env = dict(os.environ, REDIS_URL=f"redis://127.0.0.1:{port}/0", REDIS_HOST="127.0.0.1", REDIS_PORT=str(port),
               JOOBQ_ENV="development", CRYSTAL_ENV="development", AZU_UI="plain", AZU_QUIET="true")
    env.pop("REDIS_PASS", None)
    redis_log = open(root / "redis.log", "w+")
    redis = subprocess.Popen(["redis-server", "--bind", "127.0.0.1", "--port", str(port), "--dir", temporary,
                              "--save", "", "--appendonly", "no"], stdout=redis_log, stderr=subprocess.STDOUT)
    worker = None
    app = root

    def run(argv, **kwargs):
        result = subprocess.run(argv, cwd=app, env=env, text=True, capture_output=True, timeout=240, **kwargs)
        if result.returncode:
            raise AssertionError(f"{argv} exited {result.returncode}\n{result.stdout}\n{result.stderr}")
        return result.stdout

    def cli(*args):
        return json.loads(run([binary, *args, "--json"]))

    def redis_command(*args):
        return run(["redis-cli", "-p", str(port), "--raw", *args]).strip()

    try:
        for _ in range(100):
            ping = subprocess.run(["redis-cli", "-p", str(port), "ping"], capture_output=True)
            if ping.stdout.strip() == b"PONG":
                break
            time.sleep(0.05)
        else:
            raise AssertionError("owned Redis did not start")
        run([binary, "new", "jobs_probe", "--yes", "--author", "Test", "--email", "test@example.com",
             "--type", "api", "--db", "sqlite", "--no-git", "--no-docker", "--ci", "None"])
        app = root / "jobs_probe"
        # This exercises the CLI parser as well as the generator's actual output.
        run([binary, "generate", "joobq", "--force", "--queue", "probe", "--workers", "2"])
        assert 'job_class: "ExampleJob"' in (app / "config/joobq.development.yml").read_text()
        lock = (app / "shard.lock").read_text()
        for shard, prefix in [('azu', '1.'), ('cql', '1.'), ('joobq', '0.5.')]:
            version = re.search(r'  ' + shard + r':\n    git: [^\n]+\n    version: ([^\n]+)', lock)
            assert version and version[1].startswith(prefix), lock
            print(f'{shard}: {version[1]}', flush=True)
        run(["crystal", "build", "src/worker.cr", "--no-codegen"])
        run([binary, "db:setup"])
        print("Generated Azu v1 app, JoobQ worker and SQLite migration passed", flush=True)
        (app / "seed_jobs.cr").write_text('''require "./src/initializers/joobq"
3.times { ExampleJob.enqueue(message: "integration") }
redis = JoobQ.store.redis
redis.lpush("joobq:processing:probe", "held-by-another-worker")
2.times do
  job = ExampleJob.new(message: "retry integration")
  JoobQ::DeadLetterQueue.add(redis, Time.utc.to_unix_ms, [job.to_json])
end
''')
        run(["crystal", "run", "seed_jobs.cr"])
        before = cli("jobs:status")["queues"][0]
        assert (before['pending'], before['processing'], before['dlq']) == (3, 1, 2), before
        preview = cli("jobs:clear", "--queue=probe", "--dry-run")
        assert preview['jobs'] == 3 and preview['dry_run'], preview
        assert redis_command("LLEN", "probe") == "3"
        cli("jobs:clear", "--queue=probe", "--force")
        assert redis_command("LLEN", "probe") == "0"
        assert redis_command("LLEN", "joobq:processing:probe") == "1"
        assert len(cli("jobs:dlq", "--queue=probe", "--limit=1")["entries"]) == 1
        preview = cli("jobs:retry", "--queue=probe", "--all", "--dry-run")
        assert len(preview["entries"]) == 2
        assert redis_command("ZCARD", "joobq:dead_letter") == "2"
        assert cli("jobs:retry", "--queue=probe", "--all", "--force")["succeeded"] == 2
        assert cli("jobs:retry", "--queue=probe", "--all", "--force")["succeeded"] == 0
        assert redis_command("LLEN", "probe") == "2"
        assert redis_command("ZCARD", "joobq:dead_letter") == "0"
        cli("jobs:pause", "--queue=probe", "--force")
        assert redis_command("GET", "joobq:queue:probe:paused") == "1"
        cli("jobs:resume", "--queue=probe", "--force")
        assert redis_command("EXISTS", "joobq:queue:probe:paused") == "0"
        print("Status, DLQ paging, dry runs, atomic retries, queue clearing and pause/resume passed", flush=True)
        redis_command("DEL", "joobq:processing:probe") # remove only our artificial active-job fixture
        with open(root / "worker.log", "w+") as worker_log:
            worker = subprocess.Popen([binary, "jobs:worker", "--queues=probe", "--workers=3", "--shutdown-timeout=5"],
                                      cwd=app, env=env, stdout=worker_log, stderr=subprocess.STDOUT, start_new_session=True)
            deadline = time.monotonic() + 180
            while time.monotonic() < deadline:
                if redis_command("HGET", "joobq:stats:completed", "probe") == "2":
                    break
                if worker.poll() is not None:
                    break
                time.sleep(0.1)
            worker_log.seek(0)
            output = worker_log.read()
            assert redis_command("HGET", "joobq:stats:completed", "probe") == "2", output
            assert "Starting queues: probe (3 workers)" in output, output
            worker.send_signal(signal.SIGTERM)
            assert worker.wait(timeout=15) == 0
        print("Worker selection, concurrency override, actual completions and SIGTERM drain passed", flush=True)
        # A child compiler failure must propagate; no false success or leftover scratch file.
        tools = root / "tools"
        tools.mkdir()
        compiler = tools / "crystal"
        compiler.write_text("#!/bin/sh\nexit 7\n")
        compiler.chmod(0o700)
        failed = subprocess.run([binary, "jobs:status"], cwd=app,
                                env=dict(env, PATH=str(tools) + os.pathsep + env['PATH']), capture_output=True)
        assert failed.returncode != 0
        assert not list(app.glob('.azu_jobs_*'))
        print("Compiler failure propagation and scratch cleanup passed", flush=True)
    finally:
        if worker is not None and worker.poll() is None:
            os.killpg(worker.pid, signal.SIGTERM)
            try:
                worker.wait(timeout=15)
            except subprocess.TimeoutExpired:
                os.killpg(worker.pid, signal.SIGKILL)
                worker.wait()
        redis.terminate()
        redis.wait(timeout=10)
        redis_log.close()
