#!/usr/bin/env python3
"""Batch backup running-config from a list of EVE-NG nodes via netmiko.

Usage:
    ./netmiko_backup.py inventory.yml
    ./netmiko_backup.py --host 127.0.0.1 --port 32769 --type cisco_ios_telnet

inventory.yml format:
    backup_dir: ~/OlympBackup
    devices:
      - name: R1
        host: 127.0.0.1
        port: 32769
        device_type: cisco_ios_telnet
        username: cisco
        password: cisco
      - name: SW1
        host: 127.0.0.1
        port: 32770
        device_type: cisco_ios_telnet
"""

import argparse
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

try:
    from netmiko import ConnectHandler
except ImportError:
    sys.exit("netmiko not installed. Run: pip3 install netmiko")

try:
    import yaml
except ImportError:
    yaml = None


def backup_one(dev, backup_dir, stamp):
    name = dev.get("name") or dev["host"]
    try:
        conn = ConnectHandler(
            device_type=dev.get("device_type", "cisco_ios_telnet"),
            host=dev["host"],
            port=int(dev.get("port", 23)),
            username=dev.get("username", ""),
            password=dev.get("password", ""),
            secret=dev.get("secret", dev.get("password", "")),
            timeout=20,
            session_timeout=60,
            fast_cli=False,
        )
        try:
            conn.enable()
        except Exception:
            pass
        output = conn.send_command("show running-config", read_timeout=60)
        conn.disconnect()

        fname = os.path.join(backup_dir, "{0}_{1}.cfg".format(name, stamp))
        with open(fname, "w") as f:
            f.write("! Hostname: {0}\n! Backup:   {1}\n\n".format(name, time.ctime()))
            f.write(output)
        return (name, "OK", fname)
    except Exception as e:
        return (name, "FAIL", str(e))


def load_inventory(path):
    if yaml is None:
        sys.exit("PyYAML required. Run: pip3 install pyyaml")
    with open(path) as f:
        return yaml.safe_load(f)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("inventory", nargs="?", help="YAML inventory file")
    p.add_argument("--host")
    p.add_argument("--port", type=int)
    p.add_argument("--type", default="cisco_ios_telnet")
    p.add_argument("--user", default="")
    p.add_argument("--password", default="")
    p.add_argument("--name", default="device")
    p.add_argument("--out", default=os.environ.get("OLYMP_BACKUP_DIR") or os.path.expanduser("~/OlympBackup"))
    p.add_argument("--workers", type=int, default=6)
    args = p.parse_args()

    os.makedirs(args.out, exist_ok=True)
    stamp = time.strftime("%Y-%m-%d_%H-%M")

    if args.inventory:
        inv = load_inventory(args.inventory)
        backup_dir = os.path.expanduser(inv.get("backup_dir", args.out))
        os.makedirs(backup_dir, exist_ok=True)
        devices = inv["devices"]
    elif args.host and args.port:
        backup_dir = args.out
        devices = [{
            "name": args.name, "host": args.host, "port": args.port,
            "device_type": args.type, "username": args.user, "password": args.password,
        }]
    else:
        p.error("provide inventory file OR --host/--port")

    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futures = [ex.submit(backup_one, d, backup_dir, stamp) for d in devices]
        for fu in as_completed(futures):
            name, status, info = fu.result()
            print("[{0}] {1}: {2}".format(status, name, info))


if __name__ == "__main__":
    main()
