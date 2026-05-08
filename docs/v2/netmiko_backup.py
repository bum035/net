#!/usr/bin/env python3
"""Robust batch backup of running-config from EVE-NG nodes via netmiko.

Multi-credential attempt, retry, SSH fallback, console-prompt rescue.

Usage:
    ./netmiko_backup.py inventory.yml
    ./netmiko_backup.py --host 10.2.0.163 --port 32769
    ./netmiko_backup.py --host 10.2.0.163 --port 32769 --user cisco --password cisco
    ./netmiko_backup.py inv.yml --ssh                  # cisco_ios over SSH
    ./netmiko_backup.py inv.yml --slow                 # bigger timeouts
    ./netmiko_backup.py inv.yml --raw-on-fail          # save raw transcript on failure

inventory.yml format:
    backup_dir: ~/OlympBackup
    default_credentials:                # optional — applied per-device unless overridden
      - {username: "", password: ""}
      - {username: "cisco", password: "cisco", secret: "cisco"}
      - {username: "admin", password: "admin"}
    devices:
      - name: R1
        host: 10.2.0.163
        port: 32769
        device_type: cisco_ios_telnet   # default
        # username/password optional — omit to try default_credentials list
"""

import argparse
import os
import socket
import sys
import time
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed

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
        msg += "\nThe olympiad bundle installed netmiko in PyOlymp's Python 3.12.\n"
        msg += "Run with the bundled Python instead:\n"
        msg += "    %s %s %s\n" % (_olymp_py, sys.argv[0], " ".join(sys.argv[1:]))
        msg += "  or use the wrapper:  usb-offline\\py-olymp.cmd %s %s\n" % (sys.argv[0], " ".join(sys.argv[1:]))
        msg += "  or open a NEW PowerShell so PATH refreshes.\n"
    else:
        msg += "\nInstall offline wheels (run from usb-offline/ folder):\n"
        msg += "    python -m pip install --no-index --find-links wheels netmiko pyyaml\n"
    sys.exit(msg)

try:
    import yaml
except ImportError:
    yaml = None


DEFAULT_CREDS = [
    # Most labs run with no auth on console
    {"username": "", "password": "", "secret": ""},
    # Common olympiad / EVE-NG auto-config defaults
    {"username": "cisco", "password": "cisco", "secret": "cisco"},
    {"username": "admin", "password": "admin", "secret": "admin"},
    {"username": "admin", "password": "Admin@123", "secret": "Admin@123"},
    {"username": "cisco", "password": "Cisco123", "secret": "Cisco123"},
    {"username": "root",  "password": "Cisco",    "secret": "Cisco"},
]

# Common command we run after connect to wake up/clear pager
PRECMDS = ["terminal length 0", "terminal width 511"]


def is_port_open(host, port, timeout=5):
    try:
        with socket.create_connection((host, int(port)), timeout=timeout):
            return True
    except Exception:
        return False


def try_connect(dev, slow=False, raw=False):
    """Try connect with credentials in order of preference. Returns (conn, used_cred) or raises."""
    base = dict(
        device_type=dev.get("device_type", "cisco_ios_telnet"),
        host=dev["host"],
        port=int(dev.get("port", 23)),
        timeout=30 if slow else 20,
        session_timeout=120 if slow else 60,
        banner_timeout=30 if slow else 15,
        auth_timeout=30 if slow else 15,
        fast_cli=False,
        global_delay_factor=2 if slow else 1,
    )

    # If device explicitly sets credentials, try ONLY those
    if "username" in dev or "password" in dev:
        creds = [{
            "username": dev.get("username", ""),
            "password": dev.get("password", ""),
            "secret":   dev.get("secret",   dev.get("password", "")),
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
            # On timeout, often it's the prompt waiting at "Username:" with no creds set.
            # Try once more with explicit Enter trick (handled by netmiko's banner).
            continue
        except Exception as e:
            last_err = e
            continue
    raise RuntimeError(f"All credentials failed; last error: {last_err}")


def backup_one(dev, backup_dir, stamp, slow=False, raw=False):
    name = dev.get("name") or dev["host"]
    host, port = dev["host"], int(dev.get("port", 23))

    # Pre-flight: TCP reachability
    if not is_port_open(host, port, timeout=5):
        return (name, "FAIL", f"port {port} on {host} not reachable")

    transcript = []
    try:
        conn, used_cred = try_connect(dev, slow=slow, raw=raw)
    except Exception as e:
        return (name, "FAIL", f"connect: {e}")

    try:
        # enter privileged mode (silent if already there)
        try:
            conn.enable()
        except Exception:
            pass

        # tame the pager + width
        for cmd in PRECMDS:
            try:
                out = conn.send_command_timing(cmd, read_timeout=15)
                transcript.append(f"# {cmd}\n{out}")
            except Exception:
                pass

        # primary capture
        output = conn.send_command(
            "show running-config",
            read_timeout=120 if slow else 60,
            strip_prompt=False,
            strip_command=False,
        )
        transcript.append(f"# show running-config\n{output}")

        # detect "no config" or empty (e.g., new device asking initial dialog)
        if "Building configuration" not in output and "hostname" not in output:
            # try send_command_timing as last-resort
            output2 = conn.send_command_timing("show running-config", read_timeout=120, last_read=10)
            transcript.append(f"# (timing) show running-config\n{output2}")
            if "hostname" in output2:
                output = output2

        conn.disconnect()
    except Exception as e:
        try:
            conn.disconnect()
        except Exception:
            pass
        if raw:
            tpath = os.path.join(backup_dir, f"{name}_{stamp}.transcript.txt")
            with open(tpath, "w") as f:
                f.write("\n\n".join(transcript))
                f.write(f"\n\n# EXCEPTION\n{traceback.format_exc()}")
            return (name, "FAIL", f"capture: {e} (transcript: {tpath})")
        return (name, "FAIL", f"capture: {e}")

    fname = os.path.join(backup_dir, f"{name}_{stamp}.cfg")
    with open(fname, "w") as f:
        f.write(f"! Hostname: {name}\n")
        f.write(f"! Backup:   {time.ctime()}\n")
        f.write(f"! Source:   {host}:{port}  device_type={dev.get('device_type','cisco_ios_telnet')}\n")
        f.write(f"! Auth used: user='{used_cred.get('username','')}' password={'<set>' if used_cred.get('password') else '<empty>'}\n\n")
        f.write(output)
    return (name, "OK", fname)


def load_inventory(path):
    if yaml is None:
        sys.exit("PyYAML required. Run: pip install pyyaml")
    with open(path) as f:
        return yaml.safe_load(f)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("inventory", nargs="?", help="YAML inventory file")
    p.add_argument("--host")
    p.add_argument("--port", type=int)
    p.add_argument("--type", default="cisco_ios_telnet",
                   help="netmiko device_type (cisco_ios_telnet, cisco_ios, cisco_xe, cisco_nxos, etc.)")
    p.add_argument("--user", default=None)
    p.add_argument("--password", default=None)
    p.add_argument("--secret", default=None)
    p.add_argument("--name", default="device")
    p.add_argument("--out", default=os.environ.get("OLYMP_BACKUP_DIR") or os.path.expanduser("~/OlympBackup"))
    p.add_argument("--workers", type=int, default=6)
    p.add_argument("--ssh", action="store_true",
                   help="force device_type to cisco_ios (SSH) for ALL devices in inventory")
    p.add_argument("--slow", action="store_true",
                   help="larger timeouts and slower interaction (use for sluggish/loaded EVE)")
    p.add_argument("--raw-on-fail", action="store_true",
                   help="write transcript file on failure (helps debugging)")
    args = p.parse_args()

    os.makedirs(args.out, exist_ok=True)
    stamp = time.strftime("%Y-%m-%d_%H-%M")

    if args.inventory:
        inv = load_inventory(args.inventory)
        backup_dir = os.path.expanduser(inv.get("backup_dir", args.out))
        os.makedirs(backup_dir, exist_ok=True)
        devices = inv["devices"]
        # apply default_credentials list if present
        if inv.get("default_credentials"):
            global DEFAULT_CREDS
            DEFAULT_CREDS = inv["default_credentials"] + DEFAULT_CREDS
    elif args.host and args.port:
        backup_dir = args.out
        devices = [{
            "name": args.name, "host": args.host, "port": args.port,
            "device_type": args.type,
        }]
        if args.user is not None or args.password is not None:
            devices[0]["username"] = args.user or ""
            devices[0]["password"] = args.password or ""
            if args.secret is not None:
                devices[0]["secret"] = args.secret
    else:
        p.error("provide inventory file OR --host/--port")

    if args.ssh:
        for d in devices:
            d["device_type"] = "cisco_ios"

    print(f"Backup → {backup_dir}  (stamp={stamp}, workers={args.workers})")

    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futures = [ex.submit(backup_one, d, backup_dir, stamp, slow=args.slow, raw=args.raw_on_fail) for d in devices]
        ok = fail = 0
        for fu in as_completed(futures):
            name, status, info = fu.result()
            print(f"[{status}] {name}: {info}")
            if status == "OK":
                ok += 1
            else:
                fail += 1
        print(f"\nSummary: {ok} OK, {fail} FAIL")
        sys.exit(0 if fail == 0 else 2)


if __name__ == "__main__":
    main()
