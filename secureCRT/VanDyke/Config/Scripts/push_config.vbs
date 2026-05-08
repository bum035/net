# $language = "VBScript"
# $interface = "1.0"

' ============================================================
'  SecureCRT Script: Push edited config file to active session
'  ----------------------------------------------------------
'  - Notepad-аар засварласан config файлыг идэвхтэй device рүү
'    push хийнэ.
'  - File picker дилог гарч ирэх ёстой.
'
'  Анхаар: Скрипт зөвхөн ИДЭВХТЭЙ tab руу push хийнэ.
'          Бүх tab-руу push хийх бол `Send Commands to All
'          Sessions` ашиглаад config-аа хуулсан нь дээр.
' ============================================================

Const LINE_DELAY_MS = 50  ' Мөр хооронд хүлээх delay (ms)

Sub Main
    Dim shell : Set shell = CreateObject("WScript.Shell")
    Dim defaultDir : defaultDir = shell.ExpandEnvironmentStrings("%OLYMP_BACKUP_DIR%")
    If defaultDir = "" Or defaultDir = "%OLYMP_BACKUP_DIR%" Then
        defaultDir = shell.ExpandEnvironmentStrings("%USERPROFILE%\OlympBackup\")
    End If

    Dim filePath
    filePath = crt.Dialog.FileOpenDialog( _
        "Push hiih config faili songono uu", _
        "Open", _
        defaultDir, _
        "Config Files (*.cfg)|*.cfg|All Files (*.*)|*.*||")

    If filePath = "" Then
        Exit Sub
    End If

    If Not crt.Session.Connected Then
        crt.Dialog.MessageBox "Idevhtei session holbogdoogui baina!"
        Exit Sub
    End If

    Dim answer
    answer = crt.Dialog.MessageBox( _
        "PUSH hiih file: " & filePath & vbCrLf & vbCrLf & _
        "ZALGAH UU?", _
        "Tatlal batalgaa", _
        4 + 32)  ' Yes/No, Question icon

    If answer <> 6 Then Exit Sub  ' 6 = Yes

    ' Файлыг унших
    Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")
    Dim ts : Set ts = fso.OpenTextFile(filePath, 1)
    Dim content : content = ts.ReadAll
    ts.Close

    ' Config mode-руу орох
    crt.Screen.Synchronous = True
    crt.Screen.Send "configure terminal" & vbCr
    crt.Screen.WaitForString "(config)#", 5

    ' Мөр болгоныг илгээх
    Dim lines, line, sent, total
    lines = Split(content, vbCrLf)
    total = UBound(lines) + 1
    sent = 0

    Dim i
    For i = 0 To UBound(lines)
        line = Trim(lines(i))

        ' Хоосон болон comment мөрийг алгасах
        If line <> "" And Left(line, 1) <> "!" Then
            crt.Screen.Send line & vbCr
            crt.Sleep LINE_DELAY_MS
            sent = sent + 1
        End If
    Next

    ' Config mode-аас гарах
    crt.Screen.Send "end" & vbCr
    crt.Screen.WaitForString "#", 5

    crt.Screen.Synchronous = False

    crt.Dialog.MessageBox _
        "Push duusav!" & vbCrLf & vbCrLf & _
        "Niit mor:    " & total & vbCrLf & _
        "Ilgeesen:    " & sent & vbCrLf & vbCrLf & _
        "TIP: 'wr mem' damjuulj hadgalahaa marthgui!"
End Sub
