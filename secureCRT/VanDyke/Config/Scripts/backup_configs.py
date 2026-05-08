# $language = "Python"
# $interface = "1.0"

# ============================================================
#  SecureCRT Script: Auto-backup running-config (Olympiad — Linux)
#  ----------------------------------------------------------
#  Бүх нээлттэй tab-аас `show running-config` татаж файлд хадгална.
#  Файлын нэр: <hostname>_<timestamp>.cfg
#
#  Linux SecureCRT-д VBS COM объект ажиллахгүй (WScript.Shell, FSO),
#  тиймээс энэ Python хувилбар байгаа.
#
#  BACKUP_DIR-ыг $OLYMP_BACKUP_DIR орчны хувьсагчаар дарж бичнэ,
#  default нь ~/OlympBackup/.
# ============================================================

import os
import re
import time

BACKUP_DIR = os.environ.get("OLYMP_BACKUP_DIR") or os.path.expanduser("~/OlympBackup")
READ_TIMEOUT = 60


def sanitize(name):
    return re.sub(r"[\\/:*?\"<>| ]", "_", name)


def timestamp():
    return time.strftime("%Y-%m-%d_%H-%M")


def get_hostname(tab):
    tab.Screen.Send("\r")
    crt.Sleep(300)
    row = tab.Screen.CurrentRow
    line = tab.Screen.Get(row, 1, row, tab.Screen.Columns).strip()
    paren = line.find("(")
    if paren > 0:
        line = line[:paren].strip()
    pos = line.find("#")
    if pos < 0:
        pos = line.find(">")
    if pos > 0:
        return line[:pos].strip()
    return ""


def main():
    if not os.path.isdir(BACKUP_DIR):
        os.makedirs(BACKUP_DIR)

    total = crt.GetTabCount()
    done = skipped = failed = 0
    report = []
    stamp = timestamp()

    for i in range(1, total + 1):
        tab = crt.GetTab(i)
        if not tab.Session.Connected:
            skipped += 1
            report.append("[SKIP] Tab {0}: holbogdoogui".format(i))
            continue

        tab.Activate()
        tab.Screen.Synchronous = True
        try:
            hostname = get_hostname(tab) or "device{0}".format(i)
            tab.Screen.Send("terminal length 0\r")
            tab.Screen.WaitForString(hostname + "#", 10)
            tab.Screen.Send("show running-config\r")
            tab.Screen.WaitForString("show running-config\r", 10)
            output = tab.Screen.ReadString(hostname + "#", READ_TIMEOUT)

            if not output or len(output) < 50:
                failed += 1
                report.append("[FAIL] {0}: timeout".format(hostname))
            else:
                fname = os.path.join(
                    BACKUP_DIR, "{0}_{1}.cfg".format(sanitize(hostname), stamp)
                )
                with open(fname, "w") as f:
                    f.write("! ============================================\n")
                    f.write("! Hostname:    {0}\n".format(hostname))
                    f.write("! Backup time: {0}\n".format(time.strftime("%Y-%m-%d %H:%M:%S")))
                    f.write("! Source tab:  {0}\n".format(i))
                    f.write("! ============================================\n\n")
                    f.write(output)
                done += 1
                report.append("[OK]   {0} -> {1}".format(hostname, fname))
        except Exception as e:
            failed += 1
            report.append("[FAIL] tab {0}: {1}".format(i, e))
        finally:
            tab.Screen.Synchronous = False

    crt.Dialog.MessageBox(
        "Config backup duusav!\n\n"
        "Amjilttai:  {0}\n"
        "Orhisson:   {1}\n"
        "Aldaatai:   {2}\n\n"
        "Zam: {3}\n\n{4}".format(done, skipped, failed, BACKUP_DIR, "\n".join(report))
    )


main()
