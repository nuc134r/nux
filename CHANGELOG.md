# Changelog

Each `## <version>` section becomes the GitHub release notes for that tag (tool/changelog.sh) and is
shown in the app under Settings → App version. Write for people using the app, not for developers.

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
