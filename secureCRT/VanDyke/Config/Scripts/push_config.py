# $language = "Python"
# $interface = "1.0"

# ============================================================
#  SecureCRT Script: Push edited config (Olympiad — Linux)
#  ----------------------------------------------------------
#  File picker-ээр .cfg файл сонгож, идэвхтэй tab руу мөр-мөрөөр push хийнэ.
#
#  Анхаар: зөвхөн ИДЭВХТЭЙ tab-руу push. Бүх tab-руу push хийх бол
#  "Send Commands to All Sessions" toggle-ыг идэвхжүүлээд config-аа paste.
# ============================================================

import os

LINE_DELAY_MS = 50


def main():
    default_dir = os.environ.get("OLYMP_BACKUP_DIR") or os.path.expanduser("~/OlympBackup")

    file_path = crt.Dialog.FileOpenDialog(
        "Push hiih config faili songono uu",
        "Open",
        default_dir,
        "Config Files (*.cfg)|*.cfg|All Files (*.*)|*.*||",
    )

    if not file_path:
        return

    if not crt.Session.Connected:
        crt.Dialog.MessageBox("Idevhtei session holbogdoogui baina!")
        return

    answer = crt.Dialog.MessageBox(
        "PUSH hiih file: {0}\n\nZALGAH UU?".format(file_path),
        "Tatlal batalgaa",
        4 + 32,
    )
    if answer != 6:
        return

    with open(file_path, "r") as f:
        content = f.read()

    crt.Screen.Synchronous = True
    crt.Screen.Send("configure terminal\r")
    crt.Screen.WaitForString("(config)#", 5)

    lines = content.splitlines()
    sent = 0
    for line in lines:
        s = line.strip()
        if not s or s.startswith("!"):
            continue
        crt.Screen.Send(s + "\r")
        crt.Sleep(LINE_DELAY_MS)
        sent += 1

    crt.Screen.Send("end\r")
    crt.Screen.WaitForString("#", 5)
    crt.Screen.Synchronous = False

    crt.Dialog.MessageBox(
        "Push duusav!\n\n"
        "Niit mor:    {0}\n"
        "Ilgeesen:    {1}\n\n"
        "TIP: 'wr mem' damjuulj hadgalahaa marthgui!".format(len(lines), sent)
    )


main()
