#!/usr/bin/env python3
"""Run the compiled check_remote_monitor.cr against a private loopback sshd.
Usage: python3 scripts/check_remote_monitor.py /tmp/azu-monitor-check
Requires OpenSSH client/server. Does not modify ~/.ssh or system sshd config.
"""
import getpass
import datetime
import fcntl
import json
import os
from pathlib import Path
import shlex
import socket
import pty
import select
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time

binary = os.path.abspath(sys.argv[1])
with tempfile.TemporaryDirectory(prefix="azu-ssh-check-") as directory:
    root = Path(directory)
    for name in ("host_key", "client_key"):
        subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(root / name)], check=True)
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    snapshot = root / "snapshot.json"
    # The key can only read this file, even if a modified client asks for a shell.
    (root / "authorized_keys").write_text(
        f'restrict,command="/bin/cat -- {snapshot}" ' + (root / "client_key.pub").read_text()
    )
    (root / "authorized_keys").chmod(0o600)
    (root / "sshd_config").write_text(f"""Port {port}
ListenAddress 127.0.0.1
HostKey {root}/host_key
PidFile {root}/sshd.pid
AuthorizedKeysFile {root}/authorized_keys
StrictModes no
UsePAM no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowUsers {getpass.getuser()}
AllowTcpForwarding no
AllowAgentForwarding no
PermitTTY no
""")
    public = (root / "host_key.pub").read_text().split()
    (root / "known_hosts").write_text(f"[127.0.0.1]:{port} {public[0]} {public[1]}\n")
    (root / "ssh_config").write_text(f"""Host fixture
  HostName 127.0.0.1
  Port {port}
  User {getpass.getuser()}
  IdentityFile {root}/client_key
  IdentitiesOnly yes
  UserKnownHostsFile {root}/known_hosts
  GlobalKnownHostsFile /dev/null
""")
    wrapper = root / "ssh-test"
    wrapper.write_text(f'#!/bin/sh\nexec /usr/bin/ssh -F {shlex.quote(str(root / "ssh_config"))} "$@"\n')
    wrapper.chmod(0o700)
    slow = root / "slow-test"
    slow.write_text("#!/bin/sh\nsleep 20 &\nwait\n")
    slow.chmod(0o700)
    with (root / "sshd.log").open("w+") as log:
        server = subprocess.Popen(["/usr/sbin/sshd", "-D", "-e", "-f", str(root / "sshd_config")], stdout=log, stderr=log)
        try:
            for _ in range(100):
                if server.poll() is not None:
                    log.seek(0)
                    raise RuntimeError(log.read())
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                        break
                except OSError:
                    time.sleep(0.05)
            subprocess.run([binary, str(root)], check=True, timeout=30)
            # Even an arbitrary command requested using the test key returns only
            # the forced snapshot, never a shell. No commands modify the server.
            snapshot.write_text("forced-snapshot")
            result = subprocess.run([str(wrapper), "-o", "StrictHostKeyChecking=yes", "fixture", "printf forbidden-shell"], capture_output=True, text=True, check=True, timeout=5)
            assert result.stdout == "forced-snapshot", "restricted key allowed an arbitrary command"
            print("SSH passed: server-side forced command rejects arbitrary remote commands")
            if len(sys.argv) > 2:
                # Run the actual connect router/reader/render loop, not only the reader.
                cli = os.path.abspath(sys.argv[2])
                (root / "ssh").symlink_to(wrapper)
                snapshot.write_text(json.dumps({"v": 1, "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "requests": {"rps": 42}}))
                pid, terminal = pty.fork()
                if pid == 0:
                    os.chdir(directory)
                    os.execve(cli, [cli, "connect", "--ssh", "fixture", "--snapshot", str(snapshot)],
                              dict(os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"], TERM="xterm-256color", COLORTERM="truecolor", LANG="en_US.UTF-8"))
                output = bytearray()
                try:
                    fcntl.ioctl(terminal, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 136, 0, 0))
                    deadline = time.monotonic() + 10
                    while time.monotonic() < deadline and b"SSH verified" not in output:
                        if select.select([terminal], [], [], 0.1)[0]:
                            output.extend(os.read(terminal, 65536))
                    assert b"SSH verified" in output and b"READ ONLY" in output, "production HUD did not connect"
                    os.write(terminal, b"q")
                    deadline = time.monotonic() + 5
                    while time.monotonic() < deadline:
                        done, status = os.waitpid(pid, os.WNOHANG)
                        if done:
                            assert os.waitstatus_to_exitcode(status) == 0
                            break
                        time.sleep(0.05)
                    else:
                        raise AssertionError("connect did not quit")
                    print("Connect passed: real CLI route, SSH metrics, read-only HUD and disconnect")
                finally:
                    try:
                        os.kill(pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                    os.close(terminal)
        except Exception:
            log.seek(0)
            print(log.read()[-3000:], file=sys.stderr)
            raise
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
