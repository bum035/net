#!/usr/bin/env python3
"""Generate SecureCRT session .ini files from EVE-NG nodes (or inventory.yml).

Each EVE-NG node becomes a SecureCRT session pre-configured with:
  - Protocol = Telnet
  - Hostname = EVE-NG host (e.g. 10.50.40.30)
  - [Telnet] Port = node telnet port (e.g. 32769)

Sessions are written to:
  - The lab workspace under olymp-day/<lab>/secureCRT/<device>.ini
  - Optionally deployed live to:
      Linux:   ~/.vandyke/SecureCRT/Config/Sessions/<lab>/
      Windows: %APPDATA%\\VanDyke\\Config\\Sessions\\<lab>\\

Usage:
  # From an inventory.yml (uses host/port from each device entry)
  python scripts/olymp-scrt.py --inventory olymp-day/lab-XX/inventory.yml \\
                               --output    olymp-day/lab-XX/secureCRT \\
                               --deploy

  # From EVE-NG REST API (live)
  python scripts/olymp-scrt.py --eve-host 10.X.Y.Z --eve-port 80 \\
                               --eve-user admin --eve-password Pass \\
                               --lab "/path/to.unl" \\
                               --output  olymp-day/lab-XX/secureCRT \\
                               --deploy

The --deploy flag also copies the generated .ini files into the live
SecureCRT Sessions folder so they show up in the Connection Manager
without restarting SecureCRT (note: SecureCRT may need re-scan or restart).
"""

import argparse
import json
import os
import re
import shutil
import socket
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
import http.cookiejar

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

try:
    import yaml
except ImportError:
    yaml = None


def OK(m):    print(f"[ OK ] {m}", file=sys.stderr)
def FAIL(m):  print(f"[FAIL] {m}", file=sys.stderr)
def WARN(m):  print(f"[WARN] {m}", file=sys.stderr)
def INFO(m):  print(f"[INFO] {m}", file=sys.stderr)


SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT   = os.path.dirname(SCRIPTS_DIR)
TEMPLATE_INI = os.path.join(REPO_ROOT, "secureCRT", "VanDyke", "Config", "Sessions",
                            "pod-template", "R1.ini")


# ---------------------------------------------------------------------------
# SecureCRT .ini patching
# ---------------------------------------------------------------------------
def hex_port(p):
    """Encode port as 8-char hex (SecureCRT uses lowercase hex, big-endian wide)."""
    return f"{int(p):08x}"


def patch_session(template_text, hostname, telnet_port, description=""):
    """Patch a SecureCRT session .ini text with new hostname/port/description.

    SecureCRT field formats found in pod-template/R1.ini:
      S:"Hostname"=<ip>
      S:"Protocol Name"=Telnet
      D:"[Telnet] Port"=<8-hex>      (added if missing)
      Z:"Description"=00000001
       <text>
    """
    text = template_text

    # 1) Hostname
    text = re.sub(r'^S:"Hostname"=.*$',
                  f'S:"Hostname"={hostname}',
                  text, flags=re.MULTILINE)

    # 2) Protocol = Telnet (force)
    text = re.sub(r'^S:"Protocol Name"=.*$',
                  'S:"Protocol Name"=Telnet',
                  text, flags=re.MULTILINE)

    # 3) [Telnet] Port — set if exists, otherwise add
    port_hex = hex_port(telnet_port)
    if re.search(r'^D:"\[Telnet\] Port"=', text, flags=re.MULTILINE):
        text = re.sub(r'^D:"\[Telnet\] Port"=.*$',
                      f'D:"[Telnet] Port"={port_hex}',
                      text, flags=re.MULTILINE)
    else:
        # Insert near the SSH2 Port line so it lives in a sensible place
        text = re.sub(r'^(D:"\[SSH2\] Port"=.*)$',
                      f'\\1\nD:"[Telnet] Port"={port_hex}',
                      text, flags=re.MULTILINE)

    # 4) Description (if requested)
    if description:
        # Z:"Description"=00000001\n <text>
        # Replace existing description block if present
        new_desc = f'Z:"Description"=00000001\n {description}'
        if re.search(r'^Z:"Description"=', text, flags=re.MULTILINE):
            text = re.sub(r'^Z:"Description"=\d+\n(?: .*\n)*',
                          new_desc + "\n", text, count=1, flags=re.MULTILINE)
        else:
            text += "\n" + new_desc + "\n"

    return text


# ---------------------------------------------------------------------------
# inventory / EVE-NG sources
# ---------------------------------------------------------------------------
def devices_from_inventory(path):
    if yaml is None:
        sys.exit("PyYAML required: pip install pyyaml")
    with open(path, "r", encoding="utf-8") as f:
        inv = yaml.safe_load(f)
    out = []
    for d in inv.get("devices", []):
        out.append({
            "name": d["name"],
            "host": d["host"],
            "port": int(d["port"]),
            "device_type": d.get("device_type", "cisco_ios_telnet"),
        })
    return out


def devices_from_eve(host, port, https, user, password, tenant, lab_path):
    scheme = "https" if https else "http"
    url = f"{scheme}://{host}:{port}"
    cj = http.cookiejar.CookieJar()
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    opener = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(cj),
        urllib.request.HTTPSHandler(context=ctx),
    )

    body = {"username": user, "password": password, "html5": "-1"}
    if tenant:
        body["tenant"] = tenant
    req = urllib.request.Request(f"{url}/api/auth/login", method="POST")
    req.add_header("Content-Type", "application/json")
    req.data = json.dumps(body).encode()
    with opener.open(req, timeout=15) as r:
        if r.status != 200:
            raise RuntimeError(f"login HTTP {r.status}")

    if not lab_path.startswith("/"):
        lab_path = "/" + lab_path
    if not lab_path.endswith(".unl"):
        lab_path += ".unl"

    with opener.open(f"{url}/api/labs{lab_path}/nodes", timeout=15) as r:
        nodes = json.loads(r.read().decode()).get("data", {})

    out = []
    for nid in sorted(nodes.keys(), key=lambda x: int(x)):
        n = nodes[nid]
        url_n = n.get("url", "")
        if not url_n.startswith("telnet://"):
            continue
        out.append({
            "name": n.get("name"),
            "host": host,
            "port": int(url_n.split(":")[-1]),
            "device_type": "cisco_ios_telnet",
            "image": n.get("image", ""),
            "template": n.get("template", ""),
        })
    return out


# ---------------------------------------------------------------------------
# deploy paths
# ---------------------------------------------------------------------------
def live_securecrt_sessions_dir():
    """Detect live SecureCRT Sessions folder per platform."""
    if sys.platform.startswith("win"):
        appdata = os.environ.get("APPDATA")
        if appdata:
            return os.path.join(appdata, "VanDyke", "Config", "Sessions")
    else:
        return os.path.expanduser("~/.vandyke/SecureCRT/Config/Sessions")
    return None


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--inventory", help="path to inventory.yml")
    src.add_argument("--eve-host", help="EVE-NG host (live)")

    ap.add_argument("--eve-port",     type=int, default=80)
    ap.add_argument("--eve-https",    action="store_true")
    ap.add_argument("--eve-user",     default="admin")
    ap.add_argument("--eve-password", default="eve")
    ap.add_argument("--eve-tenant",   default="")
    ap.add_argument("--lab",          help="lab path for --eve-host source")

    ap.add_argument("--output", required=True,
                    help="output folder for generated .ini files")
    ap.add_argument("--lab-name",
                    help="folder name to use under live SecureCRT Sessions/ "
                         "(default: derived from --output basename)")
    ap.add_argument("--template", default=TEMPLATE_INI,
                    help=f"template .ini (default: {TEMPLATE_INI})")
    ap.add_argument("--deploy",  action="store_true",
                    help="also copy to live SecureCRT Sessions folder")
    ap.add_argument("--description-prefix", default="auto-generated",
                    help="text prefix for the session description")
    args = ap.parse_args()

    if args.eve_host and not args.lab:
        ap.error("--lab is required when using --eve-host")

    # 1) Load template
    if not os.path.exists(args.template):
        FAIL(f"template not found: {args.template}")
        sys.exit(1)
    with open(args.template, "r", encoding="utf-8") as f:
        template_text = f.read()
    OK(f"template: {args.template}")

    # 2) Source devices
    if args.inventory:
        devices = devices_from_inventory(args.inventory)
        OK(f"inventory: {args.inventory}  ({len(devices)} device(s))")
    else:
        devices = devices_from_eve(
            host=args.eve_host, port=args.eve_port, https=args.eve_https,
            user=args.eve_user, password=args.eve_password, tenant=args.eve_tenant,
            lab_path=args.lab,
        )
        OK(f"EVE-NG: {args.eve_host}:{args.eve_port} {args.lab}  ({len(devices)} telnet node(s))")

    if not devices:
        FAIL("no devices to generate")
        sys.exit(2)

    # 3) Output folder
    os.makedirs(args.output, exist_ok=True)

    # 4) Generate per-device .ini
    written = []
    for d in devices:
        desc = (f"{args.description_prefix} for {d['name']} "
                f"-> {d['host']}:{d['port']} ({d.get('device_type','telnet')})")
        text = patch_session(template_text, d["host"], d["port"], description=desc)
        out_path = os.path.join(args.output, f"{d['name']}.ini")
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(text)
        written.append(out_path)
        OK(f"  wrote: {out_path}  -> {d['host']}:{d['port']}")

    # 5) Deploy to live SecureCRT folder
    if args.deploy:
        live = live_securecrt_sessions_dir()
        if not live:
            WARN("could not detect live SecureCRT Sessions dir for this platform")
        else:
            lab_name = args.lab_name or os.path.basename(args.output.rstrip("/\\")) or "olymp"
            target = os.path.join(live, lab_name)
            os.makedirs(target, exist_ok=True)
            for p in written:
                dst = os.path.join(target, os.path.basename(p))
                shutil.copy2(p, dst)
            OK(f"deployed {len(written)} session(s) to {target}")
            INFO("In SecureCRT: refresh Connection Manager (F4) "
                 "or restart SecureCRT to see the new sessions.")

    print(file=sys.stderr)
    INFO(f"DONE. {len(written)} session file(s) generated.")


if __name__ == "__main__":
    main()
