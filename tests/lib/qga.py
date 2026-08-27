#!/usr/bin/env python3
"""Run a command inside a QEMU guest and print its real output.

The test scripts previously drove the VM by injecting keystrokes and reading
results off screenshots. That works, barely, and it is why a whole class of
defect went unnoticed: an installed system tracking Debian stable instead of
testing passed every automated check and was found by a person running
`cat /etc/apt/sources.list` by hand.

This talks to qemu-guest-agent over the virtio-serial channel, so a check can
assert on text instead of a picture. The guest needs qemu-guest-agent installed,
which only test images have — see tests/packages/test-tools.list.chroot.

Usage:
    python3 tests/lib/qga.py <socket> <shell command>

Exits with the guest command's exit status, so it composes with `set -e`.
"""

import base64
import json
import os
import socket
import sys
import time


class GuestAgent:
    def __init__(self, path, timeout=60.0):
        self.path = path
        self._connect(timeout)

    def _connect(self, timeout=60.0):
        """(Re)open the channel.

        Reconnecting matters more than it looks. QEMU accepts a client on the
        chardev socket immediately, long before the guest agent exists — the
        agent only starts once udev sees the virtio port, roughly two minutes
        into a boot. A connection opened at t=0 is therefore attached to nothing,
        and holding onto it means waiting forever on a channel that will never
        answer. Each retry gets a fresh socket instead.
        """
        deadline = time.time() + timeout
        while True:
            try:
                sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                sock.connect(self.path)
                break
            except OSError:
                if time.time() > deadline:
                    raise SystemExit(f"qga: could not connect to {self.path}")
                time.sleep(0.5)
        self.sock = sock
        self.sock.settimeout(30.0)
        self.f = self.sock.makefile("rw", encoding="utf-8", newline="\n")

    def _call(self, name, **args):
        payload = {"execute": name}
        if args:
            payload["arguments"] = args
        self.f.write(json.dumps(payload) + "\n")
        self.f.flush()
        while True:
            line = self.f.readline()
            if not line:
                raise SystemExit("qga: connection closed")
            msg = json.loads(line)
            if "error" in msg:
                raise SystemExit(f"qga: {msg['error']}")
            if "return" in msg:
                return msg["return"]

    def wait_ready(self, timeout=180.0):
        """Block until the agent answers.

        The agent starts as a systemd service, so it is not available the
        instant QEMU is up — it appears somewhere during boot, typically after a
        minute or so.

        Every failure mode has to be caught here, not just SystemExit. Before the
        agent is running nothing writes to the channel at all, so readline blocks
        until the socket timeout and raises socket.timeout — which is an OSError,
        not a SystemExit. Letting that escape made an early version give up after
        30 seconds while reporting that the agent "never answered".
        """
        deadline = time.time() + timeout
        # Short per-attempt timeout: a ping that goes unanswered should cost a
        # couple of seconds, not the full read timeout.
        while time.time() < deadline:
            try:
                self.sock.settimeout(3.0)
                # No 0xFF sync byte. It is a documented QGA convention, but this
                # agent answers it with {"error": ... "JSON parse error, stray
                # '\uFFFD'"}, and _call treats any error reply as a failure — so
                # sending it made every ping fail while the channel was perfectly
                # healthy. Reconnecting is enough on its own.
                self._call("guest-ping")
                self.sock.settimeout(30.0)
                return True
            except (SystemExit, OSError, ValueError):
                time.sleep(2.0)
                try:
                    self.f.close()
                    self.sock.close()
                except OSError:
                    pass
                try:
                    self._connect(timeout=5.0)
                except SystemExit:
                    pass
        return False

    def run(self, command, timeout=120.0):
        """Run a shell command, returning (exit_code, stdout, stderr)."""
        res = self._call(
            "guest-exec",
            path="/bin/sh",
            arg=["-c", command],
            **{"capture-output": True},
        )
        pid = res["pid"]
        deadline = time.time() + timeout
        while time.time() < deadline:
            status = self._call("guest-exec-status", pid=pid)
            if status.get("exited"):
                def decode(key):
                    raw = status.get(key)
                    return base64.b64decode(raw).decode("utf-8", "replace") if raw else ""
                return status.get("exitcode", 0), decode("out-data"), decode("err-data")
            time.sleep(0.4)
        raise SystemExit(f"qga: command timed out after {timeout}s: {command}")


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    sock_path = sys.argv[1]
    command = " ".join(sys.argv[2:])

    agent = GuestAgent(sock_path)
    if not agent.wait_ready():
        raise SystemExit("qga: guest agent never became ready — is qemu-guest-agent "
                         "installed? Test images need STRATA_TEST_TOOLS=1.")
    code, out, err = agent.run(command)
    if out:
        sys.stdout.write(out if out.endswith("\n") else out + "\n")
    if err:
        sys.stderr.write(err if err.endswith("\n") else err + "\n")
    sys.exit(code)


if __name__ == "__main__":
    main()
