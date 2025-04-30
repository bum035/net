
          SecureCRT(R) 9.6.2 (Official) -- February 20, 2025

            Copyright (C) 1995-2025 VanDyke Software, Inc.
                        All rights reserved.


Product Overview
----------------

The SecureCRT client for Windows, Mac, and Linux provides rock-solid 
terminal emulation for computing professionals, raising productivity 
with advanced session management and a host of ways to save time and 
streamline repetitive tasks. 

SecureCRT provides secure remote access, file transfer, and data 
tunneling for everyone in your organization.

SecureCRT includes a 30-day try-before-you-buy evaluation license for
the fully functional application and access to VanDyke Software(R)
technical support.

The list of changes made for this release of SecureCRT can be found
on the History tab in the About box.


Contents
--------

 1. Key Benefits
 2. New in SecureCRT 9.6
 3. System Requirements
 4. Export Control
 5. Upgrades
 6. SecureCRT Features
 7. Mailing Lists
 8. Videos
 9. Enhancement Requests and Questions
10. Reporting Bugs
11. Contact Information


1. Key Benefits
---------------

Securely access business applications:

  Securely access applications on UNIX, Linux, or VMS from machines 
  running Windows, Linux, and Mac — employ the rich emulation support 
  for VT100/102/220, TN3270, ANSI, SCO ANSI, Wyse 50/60, Xterm, and 
  Linux console.

Stay organized:

  Whether you have one or thousands of sessions, you can configure, 
  manage, and organize all your sessions with full control over 
  scrollback, key mappings, colors, fonts, and more. 

Access your full array of network devices from one client:

  Use SSH (SSH2, SSH1), Telnet, Telnet/TLS, serial, RDP (Windows 
  only), and other protocols.

Leverage the high-productivity GUI:

  Time-saving capabilities include multi-session launch, tabbed 
  sessions, tab groups, tiled sessions, cloned sessions, a button 
  bar and Command Manager for repeated commands, and mapped keys.

Stay secure:

  Depend on the open standard Secure Shell (SSH) protocol for 
  encrypted logon and session data, flexible authentication options, 
  and optional FIPS 140-2 -approved ciphers.

Automate repetitive tasks:

  Automate repetitive tasks in SecureCRT by running scripts using 
  VBScript, JScript, PerlScript, or Python. The script recorder 
  builds your keystrokes into a VBScript or Python script.

Implement smart cards:

  Implement for highly secure, two-factor authentication. SecureCRT 
  supports X.509 smart cards (PIV/CAC) with the ability to select a 
  specific certificate to be used for public-key authentication.

Transfer files between network devices:

  Transfer files with SFTP, Xmodem, Ymodem, Zmodem, or Kermit. A 
  built-in TFTP server provides additional file transfer flexibility.


2. New in SecureCRT 9.6
-----------------------

Easily export and share specific sessions or folders with more
control over what settings are included in the export file.

Change the hostname or IP address for multiple sessions at the same 
time.

Map a key, command, or button on the button bar to send a string to 
the Command window, allowing it to be modified before sending it to
the session.


Here are some of the new features in SecureCRT 9.6:

More control over XML export settings

  Easily export and share only the session settings you want.  Select 
  specific folders and sessions and choose whether or not to include 
  sensitive data like usernames and passwords in the export XML file.  
  Update selected sessions across workstations without completely
  overriding the existing setup.

New ways to save time

  Change hostname for multiple sessions: Change the hostname or IP 
  address for a group of sessions, saving time, especially when a
  jump host’s IP address changes.

  Command window enhancement: Map a key, command, or button on the 
  button bar to send a string to the Command window, allowing it to 
  be modified before sending it to the session.

Improved Linux support

  Dark mode: The system appearance Light or Dark setting is honored 
  by the SecureCRT application window. (Already supported on Windows
  and macOS.)

  Zoom session view: Quickly zoom a session (increase or decrease the
  font size) using the keyboard and the scroll wheel.

New platform support

  SecureCRT now supports macOS 15 (Sequoia) and Ubuntu 24.04 LTS
  64-bit.

Other enhancements

  Python support: Python 3.12 scripting engine is now supported. 
  Python 3.13 is supported on Windows and macOS.

  Local proxy command (macOS and Linux): A new firewall type, "Proxy 
  command", allows a local proxy command to be run when connecting to 
  a remote server. (Already supported on Windows.)

  OpenSSH trusted certificates: OpenSSH trusted certificates can be 
  accepted as host keys.

Please see the History tab in the SecureCRT About Box for information
on changes and bug fixes.


3. System Requirements
----------------------

Windows
  - Windows 11
  - Windows Server 2022  
  - Windows Server 2019
  - Windows Server 2016
  - Windows 10

macOS 
  - macOS 15 (Sequoia)
  - macOS 14 (Sonoma)
 
Linux 
  - Ubuntu 24.04 LTS 64-bit
  - Ubuntu 22.04 LTS 64-bit


4. Export Control
-----------------

This Software is subject to export control.  The Software may be
transmitted, exported, or re-exported only under applicable export
laws and restrictions and regulations of the United States Bureau of
Industry and Security or foreign agencies or authorities.  By
downloading or using the Software, you are agreeing to comply with
export controls.

For more information see:

  https://www.vandyke.com/download/export.html


5. Upgrades
-----------

Users who purchased SecureCRT within a year prior to the official 
release are eligible for a free upgrade to SecureCRT 9.6.  All users 
can evaluate SecureCRT 9.6 for 30 days free of charge.  For more 
information, please visit:

  https://www.vandyke.com/pricing/index.html?pid=upgrades


6. SecureCRT Features 
---------------------

Support for SSH1 and SSH2 Secure Shell protocols
  - SSH2 Protocol support:
    - ChaCha20/Poly1305, AES-GCM, AES-128, AES-192, AES-256, 
      AES-128-CTR, AES-192-CTR, AES-256-CTR, Twofish, and 3DES 
      ciphers.
    - RSA, Ed25519, ECDSA (RFC 5656), DSA, and X.509 (Windows) host 
      key support.
    - Multiple ordered authentication methods, ciphers, and MACs.
    - Public Key Assistant makes it easier to upload public keys.
    - Support for GSSAPI secure key exchange.
    - Local port forwarding, X11 forwarding, remote forwarding, and
      dynamic forwarding.
    - OpenSSH Agent forwarding.
    - SHA2, SHA1, UMAC, and MD5 MACs.
    - Public key with support for RSA (up to 16,384 bits), Ed25519, 
      ECDSA (RFC 5656), DSA, PuTTY PPK, OpenSSH certificates, and
      X.509 certificate including SmartCards, PKCS #11, PKCS #12 
      (Windows only), and Kerberos v5 via GSSAPI.  Password and 
      keyboard-interactive authentication methods are also supported.
    - SFTP tab creates an SFTP session to an existing SSH session.
    - Passphrase and password caching options.
  - Built-in SSH agent allows keys to be explicitly added or removed.
  - SSH1 Protocol support:
    - DES and 3DES ciphers.
    - RSA, TIS, and password authentication.
    - Local port forwarding, X11 forwarding.

Session Management
  - Dockable session manager.
  - Named sessions store different preferences for different hosts.
  - Tabbed sessions allow multiple sessions in the same window.
  - Tab groups make it easier to group related sessions.
  - Launch multiple selected sessions in tabs with a single click.
  - Tiling allows multiple sessions to be viewed at once.
  - A session can be logged to a file, including options for logging
    custom data and a option for creating a new log file at midnight.

Configuration & Customization
  - Easy configuration of basic SSH, port forwarding, remote
    forwarding, and other settings in Session Options dialog.
  - Named firewalls.
  - A built-in Credentials Manager allows multiple sessions to share 
    authentication credentials.
  - Personal data folder for separate storage of logon credentials.
  - Dependent session option (jump host).
  - User-defined number of savelines (scrollback) up to 128,000.
  - User-configurable number of rows and columns.
  - User-defined foreground, background, and bold colors.
  - User-defined keymaps.
  - User-defined button bar.
  - User-defined word delimiter characters for double-click.
  - Emacs mode maps ALT+<key> to send ESC+<key>.
  - Real-time keyword highlighting.

Advanced Terminal Emulation
  - Quality VT100, VT102, VT220, VT320, Linux console, SCO ANSI, 
    TN3270, TVI910, TVI925, Wyse 50/60, and ANSI emulations.
  - VT line drawing.
  - Support for bold, underline, and reverse attributes.
  - Double-width and double-height fonts.
  - 80/132 column switching.
  - VT100 and VT220 keyboard emulation.
  - Optional ANSI color.
  - 256-color Xterm.
  - 24-bit color (True Color) Xterm.
  - Xterm extensions for mouse support and changing title bar.
  - Multi-byte character set support for Japanese, Korean, and
    Chinese.
  - Unicode support includes the ability to display character sets
    from multiple languages, support for multi-byte character sets,
    right-to-left reading order languages, and an extensive
    character encoding list.
 
Other Features
  - FIPS 140-2 validated cryptographic library support (Windows 
    only).
  - Variable compression increases performance on slow connections.
  - Simple interface for automating logins.
  - Support for Telnet, Telnet/TLS (Windows only), and RLogin 
    (Windows only) protocols:
    - Telnet supports Negotiate About Window Size (NAWS).
    - Telnet supports Local Flow Control (LFLOW).
  - Local shell support.
  - RDP support (Windows).
  - Serial (COM) device support.
  - Hex view.
  - Integration with SecureFX.
  - Scripting language support for VBScript, JScript, and Perlscript
    (Windows only).
  - Support for Python scripting.
  - Script recorder.
  - Zmodem, Xmodem, Ymodem, and Kermit file transfer (upload and 
    download).
  - Built-in TFTP server.
  - Drag-and-drop file transfer (upload).
  - Auto print, selection, screen, and pass-through printing.
  - Modem dialer support: configure and save modem, country code,
    phone, and redial settings for TAPI sessions (Windows only).
  - SOCKS firewall support with password authentication.
  - Unauthenticated and basic HTTP proxy support.
  - Generic and local proxy firewall support.
  - Copy and paste, including an "auto copy" option and a "paste on
    middle or right mouse click" option.
  - Command window option provides an editable type-ahead buffer with
    history support and the ability to send text to the active 
    session, all sessions, specified tab groups, and visible sessions. 
    Use "Send characters immediately" mode to stop commands, edit 
    files using vi, send escape sequences, and do tab completion.
  - Support for use from the command line or web browsers (Windows 
    only).
  - Support for standard insertion caret so that it can be tracked
    by screen access technology for the blind.
  - Import/export tool makes it easy to copy settings between 
    systems.
  - Standalone command-line utilities enable automation of routine 
    file transfer, shell, and public-key administration tasks.


7. Mailing Lists
----------------

Every VanDyke Software license includes a full year of upgrades and
technical support.  To receive e-mail notification when new releases
of SecureCRT are available, sign up for our SecureCRT mailing list at:

  https://www.vandyke.com/cgi-bin/subscribe.php?RMF=3


8. Videos
---------

Get online video how-tos on the VanDyke Software YouTube Channel:

  http://youtube.com/vandykesoftware


9. Enhancement Requests and Questions
-------------------------------------

We want to hear from you.  Let us know what features you would like to
see in future releases of SecureCRT by visiting our website at:

  https://www.vandyke.com/cgi-bin/customer_form.php?cft=feature

If you have any questions, please visit our website at:

  https://www.vandyke.com/cgi-bin/customer_form.php?cft=support


10. Reporting Bugs
------------------

If you experience something you believe is a bug, please fill out
our online form at: 

   https://www.vandyke.com/cgi-bin/customer_form.php?cft=bug

Please do not assume someone else will report it.  We will try to
resolve reported bugs as quickly as possible; however, we can't 
resolve bugs that are not reported.

Please describe the problem in as much detail as possible.  Please 
include the following information:

   - Version of SecureCRT (as shown in the About dialog)
   - TCP/IP package and version
   - Operating system and version (including service pack level)


11. Contact Information
-----------------------

For information on ordering licenses, please visit the VanDyke 
Software website at the following address:

   https://www.vandyke.com


All other inquiries should be directed to:

   VanDyke Software, Inc.
   4848 Tramway Ridge Dr. NE
   Suite 101
   Albuquerque, NM  87111
   USA

   Inquiry form:  https://www.vandyke.com/feedback.php


VanDyke Software, SecureCRT, and SecureFX are trademarks or registered
trademarks of VanDyke Software, Inc. in the United States  and/or other
countries.

All other products and services mentioned are trademarks or registered
trademarks of their respective companies.
