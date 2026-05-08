#!/usr/bin/env python3
"""Pre-flight diagnostics for olympiad EVE-NG access.

Walks through every layer that can fail BEFORE you start config grabbing:
  1. EVE host reachable (TCP 80/443 or custom port)
  2. EVE-NG REST API auth (with explicit credentials or auto-fallback)
  3. Lab list, currently active lab (or specific --lab)
  4. Per-node telnet port reachable
  5. Per-node banner / hostname / privileged-mode reachability with cred fallback

Usage:
    # Olympiad-day usage with custom IP, port, user, pass, locked lab:
    ./diagnose-eve.py --host 10.50.40.30 --port 8080 \\
                      --user student1 --password Lab2026 \\
                      --lab "/students/student1/locked-lab.unl" \\
                      --check-nodes --emit-inventory

    # Per-node telnet probe with custom device creds:
    ./diagnose-eve.py --host 10.50.40.30 --port 8080 \\
                      --user student1 --password Lab2026 \\
                      --node-user cisco --node-password cisco \\
                      --check-nodes

    # URL with embedded port (alternative):
    ./diagnose-eve.py --host http://10.50.40.30:8080 --user x --password y

    # Default-cred discovery (no explicit creds -> tries admin/eve, admin/admin, etc.):
    ./diagnose-eve.py --host 10.50.40.30

Exit code:
    0 - all checks pass
    1 - EVE unreachable / auth failed
    2 - some nodes have problems
"""

import argparse
import json
import socket
import sys
import time
import urllib.request
import urllib.error
import urllib.parse
import http.cookiejar
import ssl

# Windows console (cp1252) chokes on Unicode. Force UTF-8 if possible.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass


COMMON_CREDS = [
    {"username": "", "password": "", "secret": ""},
    {"username": "cisco", "password": "cisco", "secret": "cisco"},
    {"username": "admin", "password": "admin", "secret": "admin"},
    {"username": "admin", "password": "Admin@123", "secret": "Admin@123"},
    {"username": "cisco", "password": "Cisco123", "secret": "Cisco123"},
]


def col(s, c="reset"):
    codes = {"red": 31, "green": 32, "yellow": 33, "cyan": 36, "reset": 0}
    if not sys.stdout.isatty():
        return s
    return f"\033[{codes[c]}m{s}\033[0m"


def OK(m):    print(col("[ OK ]", "green"),  m)
def FAIL(m):  print(col("[FAIL]", "red"),    m)
def WARN(m):  print(col("[WARN]", "yellow"), m)
def INFO(m):  print(col("[INFO]", "cyan"),   m)


def tcp_open(host, port, timeout=4):
    try:
        with socket.create_connection((host, int(port)), timeout=timeout):
            return True
    except Exception:
        return False


def http_request(method, url, cj, data=None):
    req = urllib.request.Request(url, method=method)
    req.add_header("Accept", "application/json")
    if data is not None:
        body = json.dumps(data).encode("utf-8")
        req.add_header("Content-Type", "application/json")
        req.data = body
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    opener = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(cj),
        urllib.request.HTTPSHandler(context=ctx),
    )
    try:
        with opener.open(req, timeout=10) as r:
            return r.status, r.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8")
    except Exception as e:
        return 0, str(e)


def check_eve(host, user, password, port=None, tenant=None, try_alternates=True):
    eve = host.rstrip("/")
    if not eve.startswith(("http://", "https://")):
        eve = "http://" + eve

    parsed = urllib.parse.urlparse(eve)

    # If --port was given explicitly, override URL port
    if port:
        eve_host_only = parsed.hostname
        eve = f"{parsed.scheme}://{eve_host_only}:{port}"
        parsed = urllib.parse.urlparse(eve)

    eve_host = parsed.hostname
    eve_port = parsed.port or (443 if parsed.scheme == "https" else 80)

    INFO(f"EVE-NG endpoint: {eve}  (host={eve_host}, port={eve_port})")

    # Layer 1: TCP reachability
    if not tcp_open(eve_host, eve_port):
        FAIL(f"EVE-NG TCP {eve_host}:{eve_port} closed/unreachable")
        for alt in (80, 443, 8080, 8443):
            if alt != eve_port and tcp_open(eve_host, alt):
                scheme_alt = "https" if alt in (443, 8443) else "http"
                WARN(f"  ALTERNATE TCP {eve_host}:{alt} open -> try --host {scheme_alt}://{eve_host}:{alt}")
        return None
    OK(f"EVE-NG TCP {eve_host}:{eve_port} open")

    cj = http.cookiejar.CookieJar()

    # Layer 2: API status (no auth needed)
    code, body = http_request("GET", f"{eve}/api/status", cj)
    if code == 0:
        FAIL(f"GET /api/status network error: {body}")
        return None
    INFO(f"GET /api/status -> HTTP {code}")

    # Layer 3: login
    payload = {"username": user, "password": password, "html5": "-1"}
    if tenant:
        payload["tenant"] = tenant
    code, body = http_request("POST", f"{eve}/api/auth/login", cj, data=payload)
    try:
        j = json.loads(body)
    except Exception:
        j = {}

    if code == 200 and j.get("status") == "success":
        OK(f"login succeeded (user={user}{', tenant='+tenant if tenant else ''})")
    else:
        # Show clean error
        msg = j.get("message") if j else None
        if msg:
            FAIL(f"login failed (user={user}): HTTP {code} - {msg}")
        elif "Slim Application Error" in body:
            FAIL(f"login failed (user={user}): HTTP {code} - EVE server error (Slim app exception)")
            INFO("  Possible: wrong tenant, account locked, EVE-NG version mismatch")
            INFO("  Check via browser:  " + eve)
        else:
            FAIL(f"login failed (user={user}): HTTP {code}  body={body[:200]}")

        if not try_alternates:
            return None

        # Only try alternates when caller did not pass explicit creds
        for alt in [("admin", "eve"), ("admin", "admin"), ("admin", "unl"), ("admin", "Admin@123"), ("root", "eve")]:
            if alt == (user, password):
                continue
            INFO(f"  trying alternate creds {alt[0]}/{alt[1]} ...")
            payload_alt = {"username": alt[0], "password": alt[1], "html5": "-1"}
            if tenant:
                payload_alt["tenant"] = tenant
            code2, body2 = http_request("POST", f"{eve}/api/auth/login", cj, data=payload_alt)
            try:
                j2 = json.loads(body2)
            except Exception:
                j2 = {}
            if code2 == 200 and j2.get("status") == "success":
                OK(f"  alt creds WORK: {alt[0]}/{alt[1]} - use these instead")
                user, password = alt
                break
        else:
            FAIL("All credentials failed.")
            INFO("  Tomorrow olympiad: ask the proctor for IP/port/user/pass/lab path explicitly.")
            INFO("  Then re-run:  --host <ip> --port <port> --user <user> --password <pass> --lab <path>")
            return None
    OK(f"login succeeded (user={user})")

    # Layer 4: whoami
    code, body = http_request("GET", f"{eve}/api/auth", cj)
    try:
        whoami = json.loads(body).get("data", {})
    except Exception:
        whoami = {}
    INFO(f"whoami: name={whoami.get('name','?')}  active_lab={whoami.get('lab','none')}  role={whoami.get('role','?')}")

    # Layer 5: list labs
    code, body = http_request("GET", f"{eve}/api/folders/", cj)
    try:
        labs = json.loads(body).get("data", {}).get("labs", [])
    except Exception:
        labs = []
    if not labs:
        WARN("No labs found at root folder")
    else:
        INFO(f"{len(labs)} lab(s) at root:")
        for L in labs:
            print(f"        {L['path']}    (mtime: {L.get('mtime','?')})")
    return {"eve": eve, "cj": cj, "labs": labs, "active_lab": whoami.get("lab", "")}


def check_lab(eve, cj, lab_path):
    lab_path = lab_path if lab_path.startswith("/") else "/" + lab_path
    lab_url = f"{eve}/api/labs{lab_path}"
    INFO(f"--- inspecting lab {lab_path} ---")

    code, body = http_request("GET", f"{lab_url}/nodes", cj)
    if code != 200:
        FAIL(f"GET .../nodes HTTP {code}: {body[:200]}")
        return None
    try:
        data = json.loads(body).get("data", {})
    except Exception:
        FAIL(f"nodes JSON parse error: {body[:200]}")
        return None

    if not data:
        WARN("Lab has zero nodes")
        return {"nodes": {}, "links": []}

    INFO(f"{len(data)} node(s):")
    for nid, n in data.items():
        url = n.get("url", "")
        proto = "telnet" if url.startswith("telnet://") else ("vnc" if url.startswith("vnc://") else "?")
        port = url.split(":")[-1] if ":" in url else "?"
        status = {0: "stopped", 1: "starting", 2: "running"}.get(n.get("status"), "?")
        print(f"        node{nid:>3}  {n.get('name','?'):<10}  {proto:<6} :{port:<6}  status={status:<8} image={n.get('image','?')[:40]}")

    code, body = http_request("GET", f"{lab_url}/topology", cj)
    try:
        links = json.loads(body).get("data", [])
    except Exception:
        links = []
    INFO(f"{len(links)} link(s)")
    for L in links:
        print(f"        {L.get('source','?')}.{L.get('source_label','?')} <-> {L.get('destination','?')}.{L.get('destination_label','?')}")

    return {"nodes": data, "links": links}


def check_node(host, port, name=""):
    """Verify node is reachable + can grab hostname with credential fallback."""
    if not tcp_open(host, port):
        return ("FAIL", f"TCP {host}:{port} closed")

    try:
        from netmiko import ConnectHandler
        from netmiko.exceptions import NetmikoAuthenticationException, NetmikoTimeoutException
    except ImportError:
        return ("WARN", "netmiko not installed; TCP-only check passed")

    base = dict(device_type="cisco_ios_telnet", host=host, port=int(port),
                timeout=15, session_timeout=30, banner_timeout=15, auth_timeout=15,
                fast_cli=False)
    last = None
    for c in COMMON_CREDS:
        try:
            conn = ConnectHandler(**base, **c)
            try: conn.enable()
            except Exception: pass
            h = conn.send_command("show running-config | inc hostname", read_timeout=15).strip()
            conn.disconnect()
            return ("OK", f"hostname={h or '(empty)'}  cred=user='{c['username']}' password={'<set>' if c['password'] else '<empty>'}")
        except NetmikoAuthenticationException as e:
            last = f"auth fail: {e}"
        except NetmikoTimeoutException as e:
            last = f"timeout: {e}"
        except Exception as e:
            last = f"{type(e).__name__}: {e}"
    return ("FAIL", f"login failed with all common creds. last: {last}")


def emit_inventory(host, lab_data, lab_path):
    eve_host = urllib.parse.urlparse(host if host.startswith(("http://","https://")) else "http://"+host).hostname
    print()
    print("# ===== auto-generated inventory.yml =====")
    print(f"# lab: {lab_path}")
    print(f"# host: {eve_host}")
    print()
    print("backup_dir: ~/net/olymp-day/lab-XX/backup-" + time.strftime("%Y-%m-%d_%H-%M"))
    print()
    print("default_credentials:")
    print("  - {username: '', password: '', secret: ''}")
    print("  - {username: 'cisco', password: 'cisco', secret: 'cisco'}")
    print("  - {username: 'admin', password: 'admin', secret: 'admin'}")
    print()
    print("devices:")
    for nid, n in sorted(lab_data["nodes"].items(), key=lambda x: int(x[0])):
        url = n.get("url", "")
        if not url.startswith("telnet://"):
            print(f"  # node{nid} ({n.get('name')}): NON-TELNET ({url}) - skipped, use VNC/console manually")
            continue
        port = url.split(":")[-1]
        print(f"  - name: {n.get('name')}")
        print(f"    host: {eve_host}")
        print(f"    port: {port}")
        print("    device_type: cisco_ios_telnet")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--host", required=True, help="EVE-NG host (with or without http://, optional :port)")
    p.add_argument("--port", type=int, default=None, help="override port (defaults to URL port or 80/443)")
    p.add_argument("--user", default=None, help="EVE-NG login username (default: admin)")
    p.add_argument("--password", default=None, help="EVE-NG login password (default: eve)")
    p.add_argument("--tenant", default=None, help="EVE-NG Pro tenant ID (only if Pro multi-tenant)")
    p.add_argument("--lab", default=None, help="lab path (defaults to your active lab)")
    p.add_argument("--no-fallback-creds", action="store_true",
                   help="disable trying common alternate creds when login fails (when given explicit creds)")
    p.add_argument("--check-nodes", action="store_true",
                   help="probe each node's telnet + login (slower, ~5s/node)")
    p.add_argument("--node-user", default=None, help="username for per-node telnet probe")
    p.add_argument("--node-password", default=None, help="password for per-node telnet probe")
    p.add_argument("--emit-inventory", action="store_true",
                   help="print inventory.yml for the lab")
    args = p.parse_args()

    # Detect whether caller explicitly gave creds
    explicit_creds = (args.user is not None) or (args.password is not None)
    user = args.user if args.user is not None else "admin"
    password = args.password if args.password is not None else "eve"

    # If --node-user/--node-password given, override the per-node probe creds
    if args.node_user is not None or args.node_password is not None:
        global COMMON_CREDS
        COMMON_CREDS = [{
            "username": args.node_user or "",
            "password": args.node_password or "",
            "secret":   args.node_password or "",
        }] + COMMON_CREDS

    print(col("=" * 70, "cyan"))
    print(col(" EVE-NG diagnostics", "cyan"))
    print(col("=" * 70, "cyan"))

    # When explicit creds given, do NOT try common alternates unless asked
    try_alts = not (explicit_creds or args.no_fallback_creds)
    eve_state = check_eve(args.host, user, password,
                          port=args.port, tenant=args.tenant,
                          try_alternates=try_alts)
    if not eve_state:
        sys.exit(1)

    lab = args.lab or eve_state.get("active_lab")
    if not lab or lab == "/":
        WARN("No active lab; pick one from above and re-run with --lab <path>")
        if eve_state["labs"]:
            lab = eve_state["labs"][0]["path"]
            INFO(f"  defaulting to first lab: {lab}")
        else:
            sys.exit(2)

    lab_data = check_lab(eve_state["eve"], eve_state["cj"], lab)
    if not lab_data:
        sys.exit(1)

    if args.check_nodes and lab_data["nodes"]:
        print()
        INFO("--- per-node probe (telnet + login) ---")
        eve_host = urllib.parse.urlparse(eve_state["eve"]).hostname
        any_fail = False
        for nid, n in sorted(lab_data["nodes"].items(), key=lambda x: int(x[0])):
            url = n.get("url", "")
            if not url.startswith("telnet://"):
                INFO(f"node{nid} {n.get('name')}: skip ({url})")
                continue
            port = url.split(":")[-1]
            status, info = check_node(eve_host, port, n.get("name"))
            line = f"node{nid:>3} {n.get('name','?'):<10} :{port:<6} {info}"
            if status == "OK":
                OK(line)
            elif status == "WARN":
                WARN(line)
            else:
                FAIL(line)
                any_fail = True
        if any_fail:
            print()
            WARN("Some nodes failed login. Add username/password to inventory.yml:")
            print("  devices:")
            print("    - {name: R1, host: 10.x.y.z, port: 32769, username: cisco, password: cisco}")

    if args.emit_inventory:
        emit_inventory(args.host, lab_data, lab)


if __name__ == "__main__":
    main()
