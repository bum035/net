#!/usr/bin/env python3
"""End-to-end olympiad-day orchestrator with multiple operation modes.

MODES (--mode):
  full       (default) Login -> detect lab -> inventory -> backup -> topology -> archive
  setup     Interactive prompt only (then exits without connecting)
  diagnose  EVE pre-flight checks: TCP, login, lab list, per-node telnet probe
  backup    Inventory + backup only (skip topology + archive)
  push      Push a single .cfg file to its device
              Requires --push-cfg <path> (device name auto-detected from filename
              or pass --push-name <name>)
  push-all  Push every .cfg in a backup folder back to corresponding devices
              Default: latest backup folder. Override with --push-dir
  scrt      Generate SecureCRT session .ini files (one per device)
              Output to lab folder + optionally --deploy to live SecureCRT
  topology  Render Graphviz topology only (no backup)
  archive   Create tar.gz of the lab folder (no backup)
  list-labs Show all labs at the EVE-NG root folder

Usage examples:
  # First time: interactive setup, then full workflow
  python scripts/olymp-run.py

  # Daily: skip prompts, just backup
  python scripts/olymp-run.py --mode backup

  # Generate SecureCRT sessions and copy to live config
  python scripts/olymp-run.py --mode scrt --deploy

  # Push entire latest backup back to devices (after a config rollback)
  python scripts/olymp-run.py --mode push-all --yes

  # Push single .cfg
  python scripts/olymp-run.py --mode push --push-cfg backup-2026-05-09_10-00/R1_*.cfg

  # Diagnose only (no folder creation)
  python scripts/olymp-run.py --mode diagnose

  # Re-prompt for credentials
  python scripts/olymp-run.py --reconfigure

Config file format (~/net/olymp.conf):
  eve:
    host: 10.2.0.163
    port: 80
    https: false
    user: admin
    password: Buma_8084
    tenant: ""
  node_defaults:
    username: ""
    password: ""
    secret: ""
  node_overrides:
    R1: {username: cisco, password: cisco, secret: cisco}
    SW2: {username: admin, password: Cisco123}
  output_root: ~/net/olymp-day
  generate_topology: true
  create_archive: true
"""

import argparse
import getpass
import http.cookiejar
import json
import os
import re
import shutil
import socket
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# Force UTF-8 stdout/stderr (Windows cp1252 chokes on non-ASCII)
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

try:
    import yaml
except ImportError:
    yaml = None


CONFIG_DEFAULT = os.path.expanduser("~/net/olymp.conf")
SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))


# ---------------------------------------------------------------------------
# pretty output (ASCII-only)
# ---------------------------------------------------------------------------
def _color(s, code):
    if not sys.stderr.isatty():
        return s
    return f"\033[{code}m{s}\033[0m"

def OK(m):    print(_color("[ OK ]", "32"), m, file=sys.stderr)
def FAIL(m):  print(_color("[FAIL]", "31"), m, file=sys.stderr)
def WARN(m):  print(_color("[WARN]", "33"), m, file=sys.stderr)
def INFO(m):  print(_color("[INFO]", "36"), m, file=sys.stderr)
def STEP(m):  print(_color(">>> " + m,  "36"), file=sys.stderr)


# ---------------------------------------------------------------------------
# config IO
# ---------------------------------------------------------------------------
def _yaml_dump(data, fp):
    if yaml:
        yaml.safe_dump(data, fp, sort_keys=False, allow_unicode=False, default_flow_style=False)
    else:
        json.dump(data, fp, indent=2)

def _yaml_load(fp):
    if yaml:
        return yaml.safe_load(fp)
    return json.load(fp)

def load_config(path):
    if not os.path.exists(path):
        return None
    with open(path, "r", encoding="utf-8") as f:
        return _yaml_load(f)

def save_config(cfg, path):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        _yaml_dump(cfg, f)
    OK(f"config saved -> {path}")


# ---------------------------------------------------------------------------
# interactive prompt
# ---------------------------------------------------------------------------
def _ask(label, default=None, secret=False, cast=str):
    suffix = ""
    if default not in (None, ""):
        suffix = f" [{default}]" if not secret else " [<saved>]"
    msg = f"  {label}{suffix}: "
    while True:
        if secret:
            val = getpass.getpass(msg)
        else:
            try:
                val = input(msg).strip()
            except EOFError:
                val = ""
        if not val and default is not None:
            return default
        if not val:
            if secret:
                return ""
            print("    (required)", file=sys.stderr)
            continue
        try:
            return cast(val)
        except Exception as e:
            print(f"    invalid: {e}", file=sys.stderr)

def _ask_yn(label, default=True):
    d = "Y/n" if default else "y/N"
    while True:
        val = input(f"  {label} [{d}]: ").strip().lower()
        if not val:
            return default
        if val in ("y", "yes"):
            return True
        if val in ("n", "no"):
            return False

def interactive_setup(saved_path):
    print(file=sys.stderr)
    print("=" * 64, file=sys.stderr)
    print(" Olympiad-day initial setup", file=sys.stderr)
    print(f" (will save to: {saved_path})", file=sys.stderr)
    print("=" * 64, file=sys.stderr)

    print(file=sys.stderr)
    STEP("EVE-NG endpoint")
    cfg = {
        "eve": {
            "host":     _ask("EVE-NG IP / hostname", default="10.2.0.163"),
            "port":     _ask("EVE-NG port", default=80, cast=int),
            "https":    _ask_yn("Use HTTPS?", default=False),
            "user":     _ask("EVE-NG username", default="admin"),
            "password": _ask("EVE-NG password", secret=True),
            "tenant":   _ask("EVE-NG tenant (Pro only, blank if community)", default=""),
        },
        "node_defaults": {},
        "node_overrides": {},
        "output_root": "~/net/olymp-day",
        "generate_topology": True,
        "create_archive": True,
    }

    print(file=sys.stderr)
    STEP("Default device telnet credentials")
    INFO("vIOS console usually has NO password. Press Enter to keep blank.")
    cfg["node_defaults"] = {
        "username": _ask("Default node username", default=""),
        "password": _ask("Default node password", default="", secret=True),
        "secret":   _ask("Default enable secret (blank = same as password)", default="", secret=True),
    }

    print(file=sys.stderr)
    STEP("Per-node credential overrides (optional)")
    INFO("If only some nodes have AAA configured, list them here.")
    INFO("Enter a blank node name to finish.")
    while True:
        name = input("    Node name (blank=done): ").strip()
        if not name:
            break
        cfg["node_overrides"][name] = {
            "username": _ask(f"      {name} username", default=""),
            "password": _ask(f"      {name} password", default="", secret=True),
            "secret":   _ask(f"      {name} secret",   default="", secret=True),
        }

    print(file=sys.stderr)
    STEP("Output preferences")
    cfg["output_root"]        = _ask("Output folder root", default="~/net/olymp-day")
    cfg["generate_topology"]  = _ask_yn("Generate Graphviz topology diagram?", default=True)
    cfg["create_archive"]     = _ask_yn("Create tar.gz snapshot?", default=True)

    return cfg


# ---------------------------------------------------------------------------
# EVE-NG client (urllib only — no extra deps)
# ---------------------------------------------------------------------------
class Eve:
    def __init__(self, host, port, https, user, password, tenant=""):
        scheme = "https" if https else "http"
        self.url = f"{scheme}://{host}:{port}"
        self.host = host
        self.user = user
        self.cj = http.cookiejar.CookieJar()
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.cj),
            urllib.request.HTTPSHandler(context=ctx),
        )
        self._login(user, password, tenant)

    def _request(self, method, path, body=None):
        req = urllib.request.Request(f"{self.url}{path}", method=method)
        req.add_header("Accept", "application/json")
        if body is not None:
            req.add_header("Content-Type", "application/json")
            req.data = json.dumps(body).encode("utf-8")
        try:
            with self.opener.open(req, timeout=20) as r:
                return r.status, r.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode("utf-8", errors="replace")

    def _login(self, user, password, tenant):
        # Quick TCP probe so we fail fast with a useful message
        parsed = urllib.parse.urlparse(self.url)
        try:
            with socket.create_connection((parsed.hostname, parsed.port or (443 if parsed.scheme == "https" else 80)), timeout=5):
                pass
        except Exception as e:
            raise RuntimeError(f"EVE-NG TCP unreachable: {e}")

        body = {"username": user, "password": password, "html5": "-1"}
        if tenant:
            body["tenant"] = tenant
        code, text = self._request("POST", "/api/auth/login", body)
        try:
            j = json.loads(text)
        except Exception:
            j = {}
        if code != 200 or j.get("status") != "success":
            msg = j.get("message") if j else None
            if not msg and "Slim Application Error" in text:
                msg = "EVE server error (Slim app exception) - check tenant / EVE version"
            if not msg:
                msg = f"HTTP {code} - {text[:200]}"
            raise RuntimeError(f"EVE login failed: {msg}")

    def get_json(self, path):
        code, text = self._request("GET", path)
        if code != 200:
            raise RuntimeError(f"GET {path} HTTP {code}: {text[:200]}")
        return json.loads(text).get("data")

    def whoami(self):
        return self.get_json("/api/auth")

    def list_labs(self, folder="/"):
        # path: "/" -> root; folder names percent-encoded
        return self.get_json("/api/folders" + ("" if folder == "/" else folder))

    def lab_nodes(self, lab_path):
        return self.get_json(f"/api/labs{lab_path}/nodes")

    def lab_topology(self, lab_path):
        return self.get_json(f"/api/labs{lab_path}/topology")


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def sanitize_lab_name(lab_path):
    name = lab_path.lstrip("/").rstrip("/")
    if name.endswith(".unl"):
        name = name[:-4]
    name = name.replace("/", "_")
    name = re.sub(r"[^A-Za-z0-9._-]", "_", name)
    return name or "lab-unknown"


def normalize_lab_path(lab_path):
    if not lab_path.startswith("/"):
        lab_path = "/" + lab_path
    if not lab_path.endswith(".unl"):
        lab_path += ".unl"
    return lab_path


def pick_lab(eve, requested):
    """Determine target lab. Use requested, or active, or list+ask."""
    if requested:
        return normalize_lab_path(requested)
    me = eve.whoami() or {}
    active = (me.get("lab") or "").rstrip("/")
    if active and active != "/":
        OK(f"using active lab: {active}")
        return normalize_lab_path(active)
    INFO("No active lab. Available labs at root:")
    folders = eve.list_labs("/") or {}
    labs = folders.get("labs", []) or []
    for i, L in enumerate(labs, 1):
        print(f"    [{i}] {L['path']}    (mtime: {L.get('mtime','?')})", file=sys.stderr)
    if not labs:
        raise RuntimeError("No labs found at root. Use --lab to specify a path.")
    while True:
        choice = input("  Select lab number (or full path): ").strip()
        if choice.isdigit() and 1 <= int(choice) <= len(labs):
            return normalize_lab_path(labs[int(choice) - 1]["path"])
        if choice.startswith("/"):
            return normalize_lab_path(choice)
        print("  invalid choice", file=sys.stderr)


def write_inventory(path, cfg, lab_host, nodes, backup_dir):
    overrides = cfg.get("node_overrides") or {}
    nd = cfg.get("node_defaults") or {}

    # Default credential rotation: user-supplied first, then common fallbacks
    creds = []
    if any(nd.get(k) for k in ("username", "password", "secret")):
        creds.append({
            "username": nd.get("username", ""),
            "password": nd.get("password", ""),
            "secret":   nd.get("secret") or nd.get("password", ""),
        })
    for fallback in [
        {"username": "", "password": "", "secret": ""},
        {"username": "cisco", "password": "cisco", "secret": "cisco"},
        {"username": "admin", "password": "admin", "secret": "admin"},
    ]:
        if fallback not in creds:
            creds.append(fallback)

    devices = []
    skipped = []
    for nid in sorted(nodes.keys(), key=lambda x: int(x)):
        n = nodes[nid]
        url = n.get("url", "")
        if not url.startswith("telnet://"):
            skipped.append((n.get("name"), url))
            continue
        port = int(url.split(":")[-1])
        d = {
            "name": n.get("name"),
            "host": lab_host,
            "port": port,
            "device_type": "cisco_ios_telnet",
        }
        ov = overrides.get(n.get("name")) or overrides.get(str(nid))
        if ov:
            d.update({k: v for k, v in ov.items() if v != ""})
        devices.append(d)

    inv = {
        "backup_dir": backup_dir,
        "default_credentials": creds,
        "devices": devices,
    }
    with open(path, "w", encoding="utf-8") as f:
        _yaml_dump(inv, f)
    OK(f"inventory: {path}  ({len(devices)} telnet device(s))")
    for name, url in skipped:
        INFO(f"  skipped non-telnet node: {name} ({url})")
    return inv


def write_topology_dot(path, lab_name, nodes, links):
    name_map = {f"node{nid}": n.get("name", f"node{nid}") for nid, n in nodes.items()}
    with open(path, "w", encoding="utf-8") as f:
        f.write(f'digraph "{lab_name}" {{\n')
        f.write('  rankdir=LR;\n')
        f.write('  graph [bgcolor="#1c2433", fontcolor=white, fontname="Helvetica"];\n')
        f.write('  node  [style=filled, fontname="Helvetica", fontcolor=white];\n')
        f.write('  edge  [color="#7fb3d5", fontcolor=white];\n')
        for nid, n in sorted(nodes.items(), key=lambda x: int(x[0])):
            tmpl = (n.get("template") or "").lower()
            is_switch = "switch" in tmpl or "viosl2" in tmpl or "iosvl2" in tmpl or "nxos" in tmpl
            is_host   = "linux" in tmpl or "win" in tmpl or "host" in tmpl
            if is_switch:
                shape, color = "box3d", "#34495e"
            elif is_host:
                shape, color = "note", "#7d6608"
            else:
                shape, color = "ellipse", "#1f618d"
            f.write(f'  "node{nid}" [shape={shape}, fillcolor="{color}", label="{n.get("name","?")}"];\n')
        for L in links or []:
            s = L.get("source"); d = L.get("destination")
            sl = L.get("source_label", "")
            dl = L.get("destination_label", "")
            f.write(f'  "{s}" -> "{d}" [taillabel="{sl}", headlabel="{dl}", arrowhead=none];\n')
        f.write('}\n')


def render_topology(dot_path, out_dir):
    if not shutil.which("dot"):
        WARN("graphviz 'dot' not in PATH - topology image not rendered")
        return False
    base = os.path.splitext(os.path.basename(dot_path))[0]
    for fmt in ("svg", "png"):
        out = os.path.join(out_dir, f"{base}.{fmt}")
        rc = subprocess.call(["dot", f"-T{fmt}", dot_path, "-o", out])
        if rc == 0:
            OK(f"topology: {out}")
        else:
            WARN(f"dot {fmt} failed (rc={rc})")
    return True


def make_archive(lab_dir, output_root, lab_name):
    if not shutil.which("tar"):
        WARN("tar not found - archive skipped")
        return None
    archive = os.path.join(output_root, f"{lab_name}-{time.strftime('%Y-%m-%d_%H-%M')}.tar.gz")
    rc = subprocess.call(["tar", "-czf", archive, "-C", output_root, lab_name])
    if rc == 0:
        OK(f"archive: {archive}")
        return archive
    WARN(f"tar failed (rc={rc})")
    return None


def find_python_with_netmiko():
    """Find a Python that has netmiko installed.
    Order: current sys.executable, PyOlymp bundled, py launcher (-3.12).
    """
    candidates = [sys.executable]
    pyolymp = os.path.expandvars(r"%USERPROFILE%\PyOlymp\Python312\python.exe")
    if os.path.exists(pyolymp):
        candidates.append(pyolymp)
    # Linux equivalents
    for p in ("/usr/bin/python3", "/usr/local/bin/python3"):
        if os.path.exists(p):
            candidates.append(p)

    for py in candidates:
        try:
            rc = subprocess.call([py, "-c", "import netmiko"],
                                 stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL)
            if rc == 0:
                return py
        except Exception:
            continue
    return None


def run_backup(inv_path, extra_args=None):
    """Invoke netmiko_backup.py in a Python that has netmiko."""
    backup_script = os.path.join(SCRIPTS_DIR, "netmiko_backup.py")
    if not os.path.exists(backup_script):
        FAIL(f"netmiko_backup.py missing at {backup_script}")
        return 2

    py = find_python_with_netmiko()
    if not py:
        FAIL("No Python with netmiko found.")
        INFO("Install via:")
        INFO("  cd usb-offline && .\\setup-windows-offline.ps1")
        INFO("Or check current Python is the right one:")
        INFO(f"  current: {sys.executable}")
        return 3

    if py != sys.executable:
        INFO(f"netmiko found in: {py}  (orchestrator runs in {sys.executable})")

    cmd = [py, backup_script, inv_path]
    if extra_args:
        cmd.extend(extra_args)
    INFO("running: " + " ".join(cmd))
    return subprocess.call(cmd)


# ---------------------------------------------------------------------------
# push helpers
# ---------------------------------------------------------------------------
def latest_backup_dir(lab_dir):
    """Find the most recent backup-* subfolder."""
    if not os.path.isdir(lab_dir):
        return None
    candidates = [d for d in os.listdir(lab_dir)
                  if d.startswith("backup-") and os.path.isdir(os.path.join(lab_dir, d))]
    if not candidates:
        return None
    candidates.sort(reverse=True)
    return os.path.join(lab_dir, candidates[0])


def device_from_filename(cfg_path):
    """Extract device name from a .cfg filename like 'R1_2026-05-09_10-00.cfg'."""
    base = os.path.basename(cfg_path)
    base = re.sub(r"\.cfg$", "", base)
    # strip trailing timestamp pattern _YYYY-MM-DD_HH-MM
    base = re.sub(r"_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}$", "", base)
    return base


def run_push_one(cfg_file, device, py=None, slow=False, yes=False):
    """Push a single .cfg file using netmiko_push.py."""
    push_script = os.path.join(SCRIPTS_DIR, "netmiko_push.py")
    if not os.path.exists(push_script):
        FAIL(f"netmiko_push.py missing at {push_script}")
        return 2
    py = py or find_python_with_netmiko()
    if not py:
        FAIL("No Python with netmiko found.")
        return 3
    cmd = [py, push_script, cfg_file,
           "--host", str(device["host"]),
           "--port", str(device["port"]),
           "--type", device.get("device_type", "cisco_ios_telnet")]
    if device.get("username") is not None:
        cmd += ["--user", str(device["username"])]
    if device.get("password") is not None:
        cmd += ["--password", str(device["password"])]
    if device.get("secret") is not None:
        cmd += ["--secret", str(device["secret"])]
    if slow:
        cmd.append("--slow")
    INFO(f"  push: {os.path.basename(cfg_file)} -> {device['name']} ({device['host']}:{device['port']})")
    if not yes:
        try:
            ans = input("    Proceed? [y/N]: ").strip().lower()
        except KeyboardInterrupt:
            return 130
        if ans not in ("y", "yes"):
            INFO("    skipped")
            return 0
    return subprocess.call(cmd)


def load_inventory_devices(inv_path):
    if yaml is None:
        sys.exit("PyYAML required: pip install pyyaml")
    with open(inv_path, "r", encoding="utf-8") as f:
        inv = yaml.safe_load(f) or {}
    return {d["name"]: d for d in inv.get("devices", [])}


def run_push_all(lab_dir, push_dir, slow=False, yes=False):
    """Push every .cfg in push_dir (or latest backup) to its device."""
    if not push_dir:
        push_dir = latest_backup_dir(lab_dir)
    if not push_dir or not os.path.isdir(push_dir):
        FAIL(f"no backup dir found in {lab_dir}")
        return 1

    inv_path = os.path.join(lab_dir, "inventory.yml")
    if not os.path.exists(inv_path):
        FAIL(f"inventory.yml missing at {inv_path}")
        return 2
    devices = load_inventory_devices(inv_path)

    cfgs = sorted([f for f in os.listdir(push_dir) if f.endswith(".cfg")])
    if not cfgs:
        FAIL(f"no .cfg files in {push_dir}")
        return 1

    INFO(f"push-all: {len(cfgs)} .cfg(s) from {push_dir}")
    py = find_python_with_netmiko()
    if not py:
        FAIL("No Python with netmiko found.")
        return 3

    if not yes:
        print(f"  About to push {len(cfgs)} configs back to live devices.", file=sys.stderr)
        ans = input("  Confirm push-all? [y/N]: ").strip().lower()
        if ans not in ("y", "yes"):
            INFO("aborted")
            return 0

    ok = fail = 0
    for f in cfgs:
        path = os.path.join(push_dir, f)
        name = device_from_filename(path)
        d = devices.get(name)
        if not d:
            WARN(f"  no device named {name} in inventory - skipping {f}")
            fail += 1
            continue
        rc = run_push_one(path, d, py=py, slow=slow, yes=True)  # already confirmed above
        if rc == 0:
            ok += 1
        else:
            WARN(f"  push failed for {name} (rc={rc})")
            fail += 1
    INFO(f"push-all summary: {ok} OK, {fail} FAIL")
    return 0 if fail == 0 else 2


def run_scrt(lab_dir, lab_name, deploy=False):
    """Generate SecureCRT sessions via olymp-scrt.py."""
    scrt_script = os.path.join(SCRIPTS_DIR, "olymp-scrt.py")
    inv_path    = os.path.join(lab_dir, "inventory.yml")
    out_dir     = os.path.join(lab_dir, "secureCRT")
    if not os.path.exists(scrt_script):
        FAIL(f"olymp-scrt.py missing at {scrt_script}")
        return 2
    if not os.path.exists(inv_path):
        FAIL(f"inventory.yml missing at {inv_path} - run 'olymp-run.py --mode backup' first")
        return 2
    cmd = [sys.executable, scrt_script,
           "--inventory", inv_path,
           "--output", out_dir,
           "--lab-name", lab_name]
    if deploy:
        cmd.append("--deploy")
    INFO("running: " + " ".join(cmd))
    return subprocess.call(cmd)


def run_diagnose(eve_cfg, lab_path=None, host_for_check=None):
    """Run diagnose-eve.py with current config values."""
    diag_script = os.path.join(SCRIPTS_DIR, "diagnose-eve.py")
    if not os.path.exists(diag_script):
        FAIL(f"diagnose-eve.py missing at {diag_script}")
        return 2
    cmd = [sys.executable, diag_script,
           "--host", eve_cfg["host"],
           "--port", str(eve_cfg["port"]),
           "--user", eve_cfg["user"],
           "--password", eve_cfg["password"],
           "--check-nodes"]
    if eve_cfg.get("tenant"):
        cmd += ["--tenant", eve_cfg["tenant"]]
    if lab_path:
        cmd += ["--lab", lab_path]
    INFO("running: " + " ".join(cmd[:8]) + " ...")  # don't echo password
    return subprocess.call(cmd)


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", default=CONFIG_DEFAULT,
                    help=f"config file path (default: {CONFIG_DEFAULT})")
    ap.add_argument("--reconfigure", action="store_true",
                    help="ignore existing config and re-prompt for everything")
    ap.add_argument("--lab", default=None,
                    help="lab path to use (e.g. /lab-04-gre-ipsec-vpn.unl); "
                         "default: detect active lab or prompt")
    ap.add_argument("--dry-run", action="store_true",
                    help="build inventory.yml but skip backup/topology/archive")
    ap.add_argument("--no-confirm", action="store_true",
                    help="skip the 'press Enter to continue' confirmation")
    ap.add_argument("--raw-on-fail", action="store_true",
                    help="pass --raw-on-fail to netmiko_backup.py (write transcript on failure)")
    ap.add_argument("--slow", action="store_true",
                    help="pass --slow to netmiko_backup.py (bigger timeouts)")

    ap.add_argument("--mode",
                    choices=["full", "setup", "diagnose", "backup",
                             "push", "push-all", "scrt", "topology",
                             "archive", "list-labs"],
                    default="full",
                    help="operation mode (default: full)")
    ap.add_argument("--push-cfg",
                    help="(--mode push) .cfg file to push")
    ap.add_argument("--push-name",
                    help="(--mode push) device name (overrides filename auto-detect)")
    ap.add_argument("--push-dir",
                    help="(--mode push-all) backup directory (default: latest)")
    ap.add_argument("--yes", "-y", action="store_true",
                    help="(push modes) answer YES to per-device confirmation")
    ap.add_argument("--deploy", action="store_true",
                    help="(--mode scrt) copy generated .ini files to live SecureCRT folder")
    args = ap.parse_args()

    cfg_path = os.path.expanduser(args.config)

    # ---- 1) load/create config -------------------------------------------
    if args.reconfigure or not os.path.exists(cfg_path):
        cfg = interactive_setup(cfg_path)
        save_config(cfg, cfg_path)
        if args.mode == "setup":
            OK("setup complete")
            return
    else:
        cfg = load_config(cfg_path)
        OK(f"loaded config: {cfg_path}")

    if not cfg or not cfg.get("eve"):
        FAIL("config malformed; rerun with --reconfigure")
        sys.exit(2)

    if args.mode == "setup":
        INFO("config exists; nothing to do (use --reconfigure to re-prompt)")
        return

    eve_cfg = cfg["eve"]
    output_root = os.path.expanduser(cfg.get("output_root", "~/net/olymp-day"))

    # ---- 2) DIAGNOSE mode (no full login required) -----------------------
    if args.mode == "diagnose":
        rc = run_diagnose(eve_cfg, lab_path=args.lab)
        sys.exit(rc)

    # ---- 3) Login (all other modes need it) ------------------------------
    print(file=sys.stderr)
    STEP(f"Connecting to EVE-NG  {eve_cfg['host']}:{eve_cfg['port']}  user={eve_cfg['user']}")
    try:
        eve = Eve(
            host=eve_cfg["host"],
            port=int(eve_cfg["port"]),
            https=bool(eve_cfg.get("https")),
            user=eve_cfg["user"],
            password=eve_cfg["password"],
            tenant=eve_cfg.get("tenant", ""),
        )
    except Exception as e:
        FAIL(str(e))
        INFO("Edit config: " + cfg_path)
        INFO("Or rerun with --reconfigure to re-enter credentials.")
        sys.exit(1)
    OK("EVE-NG login")

    # ---- 4) list-labs mode ----------------------------------------------
    if args.mode == "list-labs":
        folders = eve.list_labs("/") or {}
        labs = folders.get("labs", []) or []
        if not labs:
            INFO("(no labs at root)")
        for L in labs:
            print(f"  {L['path']}    (mtime: {L.get('mtime','?')})")
        return

    # ---- 5) determine target lab ----------------------------------------
    lab_path   = pick_lab(eve, args.lab)
    lab_name   = sanitize_lab_name(lab_path)
    lab_dir    = os.path.join(output_root, lab_name)
    OK(f"target lab: {lab_path}")
    OK(f"workspace: {lab_dir}")

    # ---- 6) PUSH single ---------------------------------------------------
    if args.mode == "push":
        if not args.push_cfg:
            FAIL("--mode push requires --push-cfg <file>")
            sys.exit(2)
        if not os.path.exists(args.push_cfg):
            FAIL(f"file not found: {args.push_cfg}")
            sys.exit(2)
        inv_path = os.path.join(lab_dir, "inventory.yml")
        if not os.path.exists(inv_path):
            FAIL(f"inventory.yml missing at {inv_path}; run --mode backup first")
            sys.exit(2)
        devices = load_inventory_devices(inv_path)
        name = args.push_name or device_from_filename(args.push_cfg)
        d = devices.get(name)
        if not d:
            FAIL(f"device '{name}' not in inventory; available: {sorted(devices.keys())}")
            sys.exit(2)
        rc = run_push_one(args.push_cfg, d, slow=args.slow, yes=args.yes)
        sys.exit(rc)

    # ---- 7) PUSH-ALL ------------------------------------------------------
    if args.mode == "push-all":
        rc = run_push_all(lab_dir, args.push_dir, slow=args.slow, yes=args.yes)
        sys.exit(rc)

    # ---- 8) Pull nodes/topology (needed by backup/topology/scrt/full) ----
    nodes = eve.lab_nodes(lab_path) or {}
    links = eve.lab_topology(lab_path) or []
    if not nodes:
        FAIL("Lab has zero nodes (or wrong lab path)")
        sys.exit(2)

    INFO(f"{len(nodes)} node(s), {len(links)} link(s)")
    for nid in sorted(nodes.keys(), key=lambda x: int(x)):
        n = nodes[nid]
        print(f"      node{nid:>3}  {n.get('name','?'):<14}  "
              f"{n.get('url','?')}  status={n.get('status','?')}",
              file=sys.stderr)

    # ---- 9) inventory (always written for backup/full/scrt) --------------
    backup_dir = os.path.join(lab_dir, time.strftime("backup-%Y-%m-%d_%H-%M"))
    if args.mode in ("backup", "full"):
        os.makedirs(backup_dir, exist_ok=True)
    else:
        os.makedirs(lab_dir, exist_ok=True)
    inv_path = os.path.join(lab_dir, "inventory.yml")
    inv = write_inventory(inv_path, cfg, eve_cfg["host"], nodes, backup_dir)

    # ---- 10) SCRT mode ----------------------------------------------------
    if args.mode == "scrt":
        rc = run_scrt(lab_dir, lab_name, deploy=args.deploy)
        sys.exit(rc)

    # ---- 11) TOPOLOGY mode ------------------------------------------------
    if args.mode == "topology":
        STEP("Topology")
        dot = os.path.join(lab_dir, "topology.dot")
        write_topology_dot(dot, lab_name, nodes, links)
        OK(f"dot: {dot}")
        render_topology(dot, lab_dir)
        return

    # ---- 12) ARCHIVE mode -------------------------------------------------
    if args.mode == "archive":
        STEP("Archive")
        make_archive(lab_dir, output_root, lab_name)
        return

    # ---- 13) BACKUP / FULL ------------------------------------------------
    if not args.no_confirm and not args.dry_run:
        print(file=sys.stderr)
        try:
            input(_color("  Press Enter to start backup, Ctrl-C to abort: ", "33"))
        except KeyboardInterrupt:
            print(file=sys.stderr)
            INFO("aborted by user")
            sys.exit(0)

    if not args.dry_run:
        print(file=sys.stderr)
        STEP("Running netmiko_backup.py")
        extra = []
        if args.raw_on_fail:
            extra.append("--raw-on-fail")
        if args.slow:
            extra.append("--slow")
        rc = run_backup(inv_path, extra_args=extra)
        if rc == 0:
            OK("backup complete")
        else:
            WARN(f"backup exit code {rc} - some devices may have failed")
            INFO("Re-run with --raw-on-fail to capture transcripts:")
            INFO(f"  python {sys.argv[0]} --raw-on-fail")

    if args.mode == "backup":
        # backup-only -> stop here (no topology/archive)
        print(file=sys.stderr)
        STEP("DONE")
        OK(f"backup: {backup_dir}")
        return

    # ---- 14) FULL (continues) -- topology + archive ---------------------
    if cfg.get("generate_topology", True):
        print(file=sys.stderr)
        STEP("Topology")
        dot = os.path.join(lab_dir, "topology.dot")
        write_topology_dot(dot, lab_name, nodes, links)
        OK(f"dot: {dot}")
        if not args.dry_run:
            render_topology(dot, lab_dir)

    if cfg.get("create_archive", True) and not args.dry_run:
        print(file=sys.stderr)
        STEP("Archive")
        make_archive(lab_dir, output_root, lab_name)

    print(file=sys.stderr)
    STEP("DONE")
    OK(f"workspace: {lab_dir}")
    OK(f"backup: {backup_dir}")
    OK(f"inventory: {inv_path}")
    if not args.dry_run and os.path.isdir(backup_dir):
        cnt = len([f for f in os.listdir(backup_dir) if f.endswith(".cfg")])
        INFO(f"  {cnt} .cfg file(s) in backup dir")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(file=sys.stderr)
        FAIL("interrupted")
        sys.exit(130)
