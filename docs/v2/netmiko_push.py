#!/usr/bin/env python3
"""Push a .cfg file to a single device via netmiko (telnet/SSH) with auth fallback.

Usage:
    ./netmiko_push.py R1.cfg --host 127.0.0.1 --port 32769
    ./netmiko_push.py R1.cfg --host 192.168.1.1 --type cisco_ios --user admin --password admin
    ./netmiko_push.py R1.cfg --host 10.x --port 32769 --slow --no-save
    ./netmiko_push.py R1.cfg --host 10.x --port 32769 --dry-run

Comments (lines starting with !) and blank lines are skipped.
'wr mem' is sent at the end unless --no-save.
"""

import argparse
import socket
import sys
import time

try:
    from netmiko import ConnectHandler
    from netmiko.exceptions import (
        NetmikoAuthenticationException,
        NetmikoTimeoutException,
    )
except ImportError:
    import os as _os
    _olymp_py = _os.path.expandvars(r"%USERPROFILE%\PyOlymp\Python312\python.exe")
    msg = "netmiko not installed for this Python (%s).\n" % sys.executable
    if _os.path.exists(_olymp_py):
        msg += "Run with bundled Python: %s %s %s\n" % (_olymp_py, sys.argv[0], " ".join(sys.argv[1:]))
        msg += "Or use wrapper:  usb-offline\\py-olymp.cmd %s %s\n" % (sys.argv[0], " ".join(sys.argv[1:]))
    else:
        msg += "Install: python -m pip install --no-index --find-links wheels netmiko\n"
    sys.exit(msg)


DEFAULT_CREDS = [
    {"username": "", "password": "", "secret": ""},
    {"username": "cisco", "password": "cisco", "secret": "cisco"},
    {"username": "admin", "password": "admin", "secret": "admin"},
    {"username": "admin", "password": "Admin@123", "secret": "Admin@123"},
    {"username": "cisco", "password": "Cisco123", "secret": "Cisco123"},
]


def is_port_open(host, port, timeout=5):
    try:
        with socket.create_connection((host, int(port)), timeout=timeout):
            return True
    except Exception:
        return False


def try_connect(host, port, devtype, username, password, secret, slow):
    base = dict(
        device_type=devtype,
        host=host,
        port=int(port),
        timeout=30 if slow else 20,
        session_timeout=120 if slow else 60,
        banner_timeout=30 if slow else 15,
        auth_timeout=30 if slow else 15,
        fast_cli=False,
        global_delay_factor=2 if slow else 1,
    )

    # explicit creds -> try only those
    if username is not None or password is not None:
        creds = [{
            "username": username or "",
            "password": password or "",
            "secret":   secret if secret is not None else (password or ""),
        }]
    else:
        creds = list(DEFAULT_CREDS)

    last_err = None
    for cred in creds:
        try:
            conn = ConnectHandler(**base, **cred)
            return conn, cred
        except NetmikoAuthenticationException as e:
            last_err = e
            continue
        except NetmikoTimeoutException as e:
            last_err = e
            continue
        except Exception as e:
            last_err = e
            continue
    raise RuntimeError(f"All credentials failed; last: {last_err}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("cfg")
    p.add_argument("--host", required=True)
    p.add_argument("--port", type=int, default=23)
    p.add_argument("--type", default="cisco_ios_telnet")
    p.add_argument("--user", default=None)
    p.add_argument("--password", default=None)
    p.add_argument("--secret", default=None)
    p.add_argument("--no-save", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--slow", action="store_true")
    p.add_argument("--ssh", action="store_true", help="force cisco_ios over SSH")
    p.add_argument("--delay-per-line", type=float, default=0,
                   help="seconds to sleep between lines (default 0; use 0.5 for unstable consoles)")
    args = p.parse_args()

    if args.ssh:
        args.type = "cisco_ios"

    with open(args.cfg) as f:
        lines = [
            l.rstrip() for l in f
            if l.strip() and not l.lstrip().startswith("!")
        ]

    print(f"Push: {args.cfg} ({len(lines)} lines) -> {args.host}:{args.port} (type={args.type})")
    if args.dry_run:
        for l in lines:
            print("  " + l)
        return

    if not is_port_open(args.host, args.port, timeout=5):
        sys.exit(f"FAIL: port {args.port} on {args.host} not reachable")

    try:
        conn, used = try_connect(args.host, args.port, args.type, args.user, args.password, args.secret, args.slow)
    except Exception as e:
        sys.exit(f"FAIL: connect: {e}")

    print(f"Connected (user='{used.get('username','')}', secret={'<set>' if used.get('secret') else '<empty>'})")

    try:
        try:
            conn.enable()
        except Exception:
            pass

        if args.delay_per_line > 0:
            # send manually so we can sleep
            conn.config_mode()
            for l in lines:
                conn.send_command_timing(l, read_timeout=20)
                time.sleep(args.delay_per_line)
            conn.exit_config_mode()
            out = "(slow mode — see device console for output)"
        else:
            out = conn.send_config_set(lines, read_timeout=120 if args.slow else 60)
        print(out)

        if not args.no_save:
            print(conn.save_config())
    finally:
        conn.disconnect()


if __name__ == "__main__":
    main()
