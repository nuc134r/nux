# Changelog

Each `## <version>` section becomes the GitHub release notes for that tag (tool/changelog.sh) and is
shown in the app under Settings → App version. Write for people using the app, not for developers.

## 0.7.1

- **Cleaner tab bar**: only the tab count and ⋮ are left; every action (new folder, transfers, edit, save, find, show source…) is in the ⋮ menu. The file browser's menu is shorter, with **Sort** and **View** submenus; a dot on ⋮ means transfers are running.
- **Denser file lists** with the owner of each file and relative dates ("5 min ago", "yesterday"). The exact date, size in bytes, permissions, owner and group are in the file's ⋮ sheet.
- The tab overview's top bar is now part of the background, without the "nux" title.
- **Sessions stay alive in the background**, like in Termux: while a terminal or file browser is connected, nux keeps running with a notification ("2 SSH connections"), so switching apps no longer drops your sessions. The notification's "Disconnect all" closes everything; port forwards share the same notification.
- Tapping the terminal really brings the keyboard back after Back has hidden it (the 0.7.0 fix did not work on phones).
- Installing a key on a server shows its progress on the "Install on a server" row; the result comes as a message with a "Use key" button (no more dialog).
- Messages at the bottom sit just above the edge again, not far up the screen.
- The file browser tells you when the connection is lost: right away when it closes, or after 20 seconds when the server stops answering (a dropped network). The folder you were in stays visible under a "Reconnect" bar, and an error while opening a folder is now shown even when a folder is already on screen.

## 0.7.0

- **Text size everywhere**: terminal and files have separate sizes. Change them from a tab's ⋮ menu, by pinching the text with two fingers, or in Settings → Text.
- **Denser terminal** by default, with adjustable line spacing in Settings → Text.
- A **new ⋮ menu** that opens instantly: in a tab it shows that tab's actions and Settings; in the tab overview it leads to hosts, quick connect, port forwarding, keys, ZeroTier and settings.
- The tab header now stands apart from the tab's content, and swiping between tabs is quicker.
- Tapping the terminal brings the keyboard back after Back has hidden it.
- Web links in the terminal are underlined, and nux asks before opening one (or copies it).
- Leaving edit mode is easy: a ✓ button, Back, or switching a Markdown file to its rendered view; unsaved changes can be saved or discarded.
- Back in a file opened from the file browser closes the file and returns to the browser (it used to move the browser up a folder instead).
- Checkboxes in Markdown files are visible in dark mode.
- Messages at the bottom sit higher and can be swiped away sideways.
- A wrong password now says so (instead of "Cancelled") and nux asks for it again.
- Turning ZeroTier off really stops it. Connections and forwards no longer start it again until you turn it back on.
- Host key fingerprints now look like OpenSSH's (`ssh-keygen -l`), so you can compare them with the server's. Hosts you already trusted stay trusted.

## 0.6.0

- **Edit files**: open a file, tap the pencil, change it and save. If someone changed the file on the server meanwhile, nux asks whether to overwrite it or take their version. Undo and redo are in the menu; tabs with unsaved changes show a dot and ask before closing.

## 0.5.0

- **ZeroTier built in**: nux runs its own ZeroTier node (no VPN permission, no separate app). Join networks by id, see their status and your addresses, and copy the node id to authorize it.
- Hosts can be reached **through a ZeroTier network**: turn it on in the host's settings, and SSH, files and forwarding go over ZeroTier.
- **ZeroTier port forwarding** without SSH, for **TCP and UDP**: a port on your phone reaches a device in your ZeroTier network.

## 0.4.0

- **Port forwarding**: local (`ssh -L`), remote (`ssh -R`) and SOCKS proxy (`ssh -D`) rules per host, with a sentence that explains what each rule does. Turn them on and off from the hosts list, see open connections and traffic, start rules together with nux.
- Forwarding keeps running in the background with a notification that shows the traffic and can stop everything. A dropped connection reconnects by itself.
- A port that is already taken, or a rule that clashes with another one, is explained instead of failing silently.

## 0.3.0

- **Files**: browse a host's files over SFTP in a tab. Sort, show hidden files, select several, rename, move, delete, change permissions, create folders, bookmark folders, open a terminal in a folder.
- **Transfers**: upload from your phone and download to it, with progress. An interrupted transfer continues where it stopped. Save downloads anywhere or share them.
- **Viewer**: open text files with syntax highlighting, line numbers, search and line wrapping. Markdown is shown formatted, images as images, and binary files as hex. Very large files open quickly and load the rest on request.

## 0.2.0

- **SSH terminal** in tabs: open a host and get a shell. Tabs work like Chrome's: swipe the header to switch, swipe down (or tap the counter) for all tabs, swipe a card away to close it, with Undo. Your tabs come back after a restart.
- **Hosts**: save servers with keys, an optional saved password, a jump host, a group and a colour. Or type `user@host` into Quick connect.
- **SSH keys**: generate Ed25519, ECDSA or RSA keys, or import OpenSSH, PEM, PKCS#8 and PuTTY keys. Share the public key as text or a QR code, install it on a server in one tap, protect keys with a passphrase or the device lock.
- **Server keys are checked**: nux asks before trusting a new server and warns loudly if a server's key changes.
- Extra keys above the keyboard: Esc, Tab, Ctrl, Alt, arrows and the symbols phone keyboards hide.

## 0.1.0

- First build: settings (theme, language), in-app updates from GitHub releases with an optional beta channel, and this changelog.
- SSH, SFTP, port forwarding and the editor come next.
