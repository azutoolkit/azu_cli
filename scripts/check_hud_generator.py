#!/usr/bin/env python3
"""Generate a real Spark scaffold through the HUD composer in a disposable project.
Usage: python3 scripts/check_hud_generator.py PREVIEW_BINARY AZU_BINARY
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

preview, cli = map(os.path.abspath, sys.argv[1:3])
with tempfile.TemporaryDirectory(prefix="azu-hud-generator-") as directory:
    root = Path(directory)
    (root / "src").mkdir()
    (root / "shard.yml").write_text("name: hud_lab\nversion: 0.1.0\ntargets:\n  hud_lab:\n    main: src/server.cr\n")
    pid, master = pty.fork()
    if pid == 0:
        os.chdir(directory)
        os.execve(preview, [preview, "--interactive"], dict(os.environ, AZU_PREVIEW_COMMAND_BINARY=cli, TERM="xterm-256color", COLORTERM="truecolor", LANG="en_US.UTF-8"))
    output = bytearray()

    def collect(seconds):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            ready, _, _ = select.select([master], [], [], 0.05)
            if ready:
                try:
                    data = os.read(master, 65536)
                except OSError as error:
                    if error.errno == errno.EIO:
                        return
                    raise
                if not data:
                    return
                output.extend(data)

    try:
        fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 136, 0, 0))
        collect(0.5)
        os.write(master, b"g")
        collect(0.2)
        os.write(master, b"scaffold Product name:string price_cents:int32 active:bool --spark\r")
        collect(0.3)
        assert not list(root.glob("src/models/*.cr")), "generator ran before confirmation"
        assert b"Run this command?" in output, "review was not displayed"
        os.write(master, b"y")
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline and not list(root.glob("src/components/**/*.cr")):
            collect(0.1)
        collect(0.5)
        assert (root / "src/models/product.cr").exists(), "model was not generated"
        components = list(root.glob("src/components/**/*.cr"))
        assert components, "live component was not generated"
        assert any("Spark" in path.read_text() for path in components), "missing Spark component implementation"
        assert (root / "src/initializers/spark.cr").exists(), "Spark was not wired"
        assert list(root.glob("src/db/migrations/*.cr")), "migration missing"
        os.write(master, b"\x1b")
        collect(0.2)
        os.write(master, b"q")
        collect(0.3)
        done, status = os.waitpid(pid, 0)
        assert os.waitstatus_to_exitcode(status) == 0
        assert b"\x1b[?1049l" in output
        print("HUD passed: review before write, confirmed real generator, Spark component/model/migration/wiring, clean exit")
    except Exception:
        # Keep terminal control sequences out of diagnostic output.
        import re
        print(re.sub(rb"\x1b\[[0-9;?]*[A-Za-z]", b"", bytes(output[-8000:])).decode(errors="replace"), file=sys.stderr)
        raise
    finally:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        os.close(master)
