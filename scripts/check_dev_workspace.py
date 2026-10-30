#!/usr/bin/env python3
"""Verify every interactive azu dev mode opens the workspace (no old UI route).
Usage: python3 scripts/check_dev_workspace.py /path/to/azu
Uses a disposable project and a failing build stub; no application is started.
"""
import errno
import fcntl
import os
from pathlib import Path
import pty
import select
import signal
import struct
import sys
import tempfile
import termios
import time

binary = os.path.abspath(sys.argv[1])
with tempfile.TemporaryDirectory(prefix="azu-workspace-route-") as directory:
    root = Path(directory)
    (root / "src").mkdir()
    (root / "tools").mkdir()
    (root / "shard.yml").write_text("name: workspace_lab\nversion: 0.1.0\ntargets:\n  workspace_lab:\n    main: src/server.cr\n")
    shards = root / "tools/shards"
    shards.write_text("#!/bin/sh\necho 'Error: intentional test build failure'\nexit 1\n")
    shards.chmod(0o700)
    for flags in ([], ["--ui", "rich"], ["--ui", "mission"]):
        pid, master = pty.fork()
        if pid == 0:
            os.chdir(directory)
            env = dict(os.environ, PATH=str(root / "tools") + os.pathsep + os.environ["PATH"], TERM="xterm-256color", COLORTERM="truecolor", LANG="en_US.UTF-8")
            for key in ("CI", "AZU_UI", "NO_COLOR"):
                env.pop(key, None)
            os.execve(binary, [binary, "dev", *flags], env)
        output = bytearray()

        def collect(seconds):
            end = time.monotonic() + seconds
            while time.monotonic() < end:
                if select.select([master], [], [], 0.05)[0]:
                    try:
                        data = os.read(master, 65536)
                    except OSError as ex:
                        if ex.errno == errno.EIO:
                            return
                        raise
                    if not data:
                        return
                    output.extend(data)

        try:
            fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 136, 0, 0))
            collect(1.0)
            assert b"Workspace" in output and b"Ctrl-P" in output, f"mode {flags} did not open workspace"
            os.write(master, b"d")
            collect(0.3)
            assert b"intentional test build failure" in output, "build errors were not accessible"
            os.write(master, b"q")
            collect(0.3)
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                done, status = os.waitpid(pid, os.WNOHANG)
                if done:
                    assert os.waitstatus_to_exitcode(status) == 0
                    break
                collect(0.05)
            else:
                raise AssertionError("dev did not quit")
            assert b"\x1b[?1049l" in output
        finally:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            os.close(master)
print("Workspace passed: default, rich and mission use one UI; build diagnostics and cleanup work")
