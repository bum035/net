# $language = "VBScript"
# $interface = "1.0"

' ============================================================
'  SecureCRT Script: Auto-backup running-config (Olympiad Edition)
'  ----------------------------------------------------------
'  - Бүх нээлттэй идэвхтэй tab-уудаас `show running-config`-ийг
'    автоматаар татаж тус тусд нь файлд хадгална.
'  - Файлын нэр: <hostname>_<timestamp>.cfg
'
'  Хэрэглэх заавар:
'    Script → Run... эсвэл Button Bar товчлуурт оноо
' ============================================================

' BACKUP_DIR — олимпиадын машин дээр C:\ permission байхгүй ч ажиллана.
' Дарж бичих бол OLYMP_BACKUP_DIR орчны хувьсагч тавиад дахин ажиллуулна.
Dim BACKUP_DIR
BACKUP_DIR = CreateObject("WScript.Shell").ExpandEnvironmentStrings("%OLYMP_BACKUP_DIR%")
If BACKUP_DIR = "" Or BACKUP_DIR = "%OLYMP_BACKUP_DIR%" Then
    BACKUP_DIR = CreateObject("WScript.Shell").ExpandEnvironmentStrings("%USERPROFILE%\OlympBackup\")
End If
Const READ_TIMEOUT = 60                ' show run хүлээх макс секунд

Sub Main
    Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")

    If Not fso.FolderExists(BACKUP_DIR) Then
        fso.CreateFolder(BACKUP_DIR)
    End If

    Dim totalTabs : totalTabs = crt.GetTabCount()
    Dim done : done = 0
    Dim skipped : skipped = 0
    Dim failed : failed = 0
    Dim report : report = ""
    Dim stamp : stamp = TimeStamp()

    Dim i, tab, hostname, output, fname, file

    For i = 1 To totalTabs
        Set tab = crt.GetTab(i)

        If Not tab.Session.Connected Then
            skipped = skipped + 1
            report = report & "[SKIP] Tab " & i & ": holbogdoogui" & vbCrLf
        Else
            tab.Activate
            tab.Screen.Synchronous = True
            On Error Resume Next

            hostname = GetHostname(tab)
            If hostname = "" Then hostname = "device" & i

            ' terminal length 0 — More-prompt гарахаас сэргийлнэ
            tab.Screen.Send "terminal length 0" & vbCr
            tab.Screen.WaitForString hostname & "#", 10

            ' show running-config
            tab.Screen.Send "show running-config" & vbCr
            tab.Screen.WaitForString "show running-config" & vbCr, 10

            ' Гаралтыг дараагийн prompt хүртэл унших
            output = tab.Screen.ReadString(hostname & "#", READ_TIMEOUT)

            If Err.Number <> 0 Or Len(output) < 50 Then
                failed = failed + 1
                report = report & "[FAIL] " & hostname & ": gar-d ali esvel timeout" & vbCrLf
                Err.Clear
            Else
                fname = BACKUP_DIR & Sanitize(hostname) & "_" & stamp & ".cfg"
                Set file = fso.CreateTextFile(fname, True, False)
                file.WriteLine "! ============================================"
                file.WriteLine "! Hostname:    " & hostname
                file.WriteLine "! Backup time: " & Now()
                file.WriteLine "! Source tab:  " & i
                file.WriteLine "! ============================================"
                file.WriteLine ""
                file.Write output
                file.Close

                done = done + 1
                report = report & "[OK]   " & hostname & " -> " & fname & vbCrLf
            End If

            On Error Goto 0
            tab.Screen.Synchronous = False
        End If
    Next

    crt.Dialog.MessageBox _
        "Config backup duusav!" & vbCrLf & vbCrLf & _
        "Amjilttai:  " & done & vbCrLf & _
        "Orhisson:   " & skipped & vbCrLf & _
        "Aldaatai:   " & failed & vbCrLf & vbCrLf & _
        "Zam: " & BACKUP_DIR & vbCrLf & vbCrLf & _
        report
End Sub

' --- Туслах функцууд ---

Function GetHostname(tab)
    Dim row, line, pos, hostname, parenPos

    ' Шинэ prompt гаргах
    tab.Screen.Send vbCr
    crt.Sleep 300

    row = tab.Screen.CurrentRow
    line = tab.Screen.Get(row, 1, row, tab.Screen.Columns)
    line = Trim(line)

    ' "(config)", "(config-if)" г.м. ymijg хасах
    parenPos = InStr(line, "(")
    If parenPos > 0 Then
        line = Trim(Left(line, parenPos - 1))
    End If

    ' "#" эсвэл ">" хүртлэх хэсгийг авах
    pos = InStr(line, "#")
    If pos = 0 Then pos = InStr(line, ">")

    If pos > 0 Then
        hostname = Trim(Left(line, pos - 1))
    End If

    GetHostname = hostname
End Function

Function Sanitize(s)
    Dim r : r = s
    r = Replace(r, "\", "_")
    r = Replace(r, "/", "_")
    r = Replace(r, ":", "_")
    r = Replace(r, "*", "_")
    r = Replace(r, "?", "_")
    r = Replace(r, """", "_")
    r = Replace(r, "<", "_")
    r = Replace(r, ">", "_")
    r = Replace(r, "|", "_")
    r = Replace(r, " ", "_")
    Sanitize = r
End Function

Function TimeStamp()
    Dim n : n = Now()
    TimeStamp = Year(n) & _
        "-" & Right("0" & Month(n), 2) & _
        "-" & Right("0" & Day(n), 2) & _
        "_" & Right("0" & Hour(n), 2) & _
        "-" & Right("0" & Minute(n), 2)
End Function
