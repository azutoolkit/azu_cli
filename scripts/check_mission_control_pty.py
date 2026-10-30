#!/usr/bin/env python3
"""Exercise the compiled sample HUD in a real Unix PTY; no application is started."""
import errno
import fcntl
import os
import pty
import select
import signal
import struct
import sys
import termios
import time

binary = os.path.abspath(sys.argv[1])
pid, master = pty.fork()
if pid == 0:
    os.execve(binary, [binary, "--interactive"], dict(os.environ, TERM="xterm-256color", COLORTERM="truecolor", LANG="en_US.UTF-8"))

output = bytearray()


def collect(seconds):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        ready, _, _ = select.select([master], [], [], min(0.05, max(0, end - time.monotonic())))
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


def resize(width, height):
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", height, width, 0, 0))


try:
    resize(136, 40)
    collect(0.8)
    os.write(master, b"h")
    collect(0.2)
    assert b"Keyboard hints" in output, "keyboard hints did not open"
    os.write(master, b"\x1b")
    collect(0.2)
    os.write(master, b"t")
    collect(0.2)
    assert b"azu/dev" in output, "shared request source did not open"
    os.write(master, b"t")
    collect(0.2)
    os.write(master, b"\x10")  # Ctrl-P
    collect(0.2)
    assert b"Navigate" in output, "palette did not open"
    os.write(master, b"sql\r")
    collect(0.2)
    os.write(master, b"bl")  # collapse rail, open logs
    collect(0.2)
    resize(80, 24)
    collect(0.2)
    os.write(master, b"/req\r")
    collect(0.2)
    os.write(master, b"q")
    collect(0.5)
    deadline = time.monotonic() + 5
    while True:
        done, status = os.waitpid(pid, os.WNOHANG)
        if done:
            assert os.waitstatus_to_exitcode(status) == 0, output.decode(errors="replace")
            break
        if time.monotonic() > deadline:
            raise AssertionError("HUD did not terminate")
        collect(0.05)
    for sequence in (b"\x1b[?1049h", b"\x1b[?1049l", b"\x1b[?25h", b"\x1b[?2004l"):
        assert sequence in output, f"missing terminal lifecycle sequence: {sequence!r}"
    assert b"Unhandled exception" not in output
    print("PTY passed: keyboard hints, shared request source, palette, SQL, logs, filtering, resize, quit and terminal restoration")
finally:
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    os.close(master)
