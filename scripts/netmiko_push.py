#!/usr/bin/env python3
"""Push a .cfg file to a single device via netmiko (telnet/SSH).

Usage:
    ./netmiko_push.py R1.cfg --host 127.0.0.1 --port 32769
    ./netmiko_push.py R1.cfg --host 192.168.1.1 --type cisco_ios --user admin

Comments (lines starting with !) and blank lines are skipped.
'wr mem' is sent at the end unless --no-save.
"""

import argparse
import sys

try:
    from netmiko import ConnectHandler
except ImportError:
    sys.exit("netmiko not installed. Run: pip3 install netmiko")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("cfg")
    p.add_argument("--host", required=True)
    p.add_argument("--port", type=int, default=23)
    p.add_argument("--type", default="cisco_ios_telnet")
    p.add_argument("--user", default="")
    p.add_argument("--password", default="")
    p.add_argument("--secret", default=None)
    p.add_argument("--no-save", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    with open(args.cfg) as f:
        lines = [
            l.rstrip() for l in f
            if l.strip() and not l.lstrip().startswith("!")
        ]

    print("Push: {0} ({1} lines) -> {2}:{3}".format(args.cfg, len(lines), args.host, args.port))
    if args.dry_run:
        for l in lines:
            print("  " + l)
        return

    conn = ConnectHandler(
        device_type=args.type,
        host=args.host,
        port=args.port,
        username=args.user,
        password=args.password,
        secret=args.secret or args.password,
        timeout=20,
    )
    try:
        conn.enable()
    except Exception:
        pass
    out = conn.send_config_set(lines, read_timeout=60)
    print(out)
    if not args.no_save:
        print(conn.save_config())
    conn.disconnect()


if __name__ == "__main__":
    main()
