# Changelog

Each `## <version>` section becomes the GitHub release notes for that tag (tool/changelog.sh) and is
shown in the app under Settings → App version. Write for people using the app, not for developers.

## 0.9.6

- **Git in the workspace drawer** (Version control): a commit box (with Amend), **Staged** and **Changes** with a + / − on each file to stage or unstage, Stage all / Unstage all, and a tap on a file shows its diff. Long-press a change to discard it (asks first).
- **Branches**: tap the branch on the workspace card to switch or create one.
- **Pull, Push and Fetch** in the workspace card's ⋮. When the branches have diverged, nux explains and asks: rebase or merge. A new branch is offered to be published. git never waits for a password it cannot get.
- **Fixed: tabs sometimes could not be switched** from the overview (taking the preview of an unpainted tab failed and stopped the switch).
- Fixed an error when the workspace card's menu stayed open while the drawer closed.

## 0.9.5

- **Find and replace** in the editor (⋮ → Replace while editing, or the ⇄ button in the find bar), with match case and regex.
- **Go to line** (⋮ → Go to line).
- **An editor key bar** while editing: Tab and outdent, arrows, Home/End, undo/redo, and the symbols code needs ({} () [] <> ; : = " ' ` / \ | & …).
- **Changed on the server?** Saving a file someone else changed now offers Show changes: a line diff of the server's copy against yours, then Overwrite or Discard mine.

## 0.9.4

- **Home tab**: the hosts tab is now Home, with Hosts and Workspaces pages (swipe or tap the bar). On Workspaces, tap one to open, rename or delete it; ⋮ has Add host and New workspace.
- **Workspace tree**: long-press any file or folder for its details (size, date, owner, permissions) and Open, Open in file browser, Open terminal here, Copy path.
- The tab's icon in the header opens the workspace drawer.
- The tab overview opens scrolled to the tab you were on.
- File paths under a tab's name keep their end visible (`…/lib/src`) when they do not fit.
- Pictures and hex views no longer offer a text size, and menus no longer show empty sections.

## 0.9.3

- **The log is kept across launches** (up to about 2 MB) and **crashes are written to it** the moment they happen, so they are still there after nux restarts. Settings → Share log sends it as a text file, with hosts and addresses hidden.

## 0.9.2

- **Quick open is fast in big projects**: the file list is remembered between openings (refreshed in the background), and matching runs off the main thread while you type.
- **The workspace drawer looks like the rest of nux**: folder and file icons, rounded rows, change letters in small badges, and Explorer / Version control as a segmented switch.
- The project tree **opens at the file you are on** (or the last one you opened from it), with that file marked.
- **Open terminal** in the workspace card's ⋮ starts a terminal in the workspace folder.
- **Encoding and line endings in the editor**: the file's encoding (UTF-8, UTF-8 BOM, UTF-16, ISO 8859-1, Windows-1251) and line endings (LF, CRLF, CR) are detected and kept when saving. ⋮ → Encoding reads it again in another one, Save with encoding converts it, Line endings changes them.
- With no tabs open, the Hosts button sits in the middle of the screen.
- Quick connect is gone: add a host instead.

## 0.9.1

- **Port forwarding under a host, tidied**: a plain chevron at the end of the host opens them in a subtle panel attached below it; TCP/UDP badges on every forwarding; regular font; a full-width "Add port forwarding" button.
- While they are hidden, the strip under the host reads like "2 ports, 3 connections" with the traffic.
- More one-tap ports in the editor: SSH, HTTP, HTTPS, RDP, VNC, SMB, PostgreSQL, MySQL, Redis, MongoDB, dev server, Minecraft.

## 0.9.0

- **Workspaces**: a folder on a host with its own tabs. Open one from a file browser (⋮ → Open as workspace) or from ☰ on the tab overview. Switching workspaces swaps all tabs; the others keep running in the background and come back as you left them, also after a restart.
- **The workspace drawer** (☰ on the tab overview): the workspace, its branch, the project tree with changed files marked, and Version control with the list of changes. Tap a file to open it; long-press a folder to open it in a file browser or a terminal.
- **Quick open and Search in files** in a workspace (⋮ of any tab, or the workspace card): find a file by a few letters of its name, or find text in all files (ripgrep or grep on the host, case-insensitive unless you type a capital) and open it at that line.
- **Stopping a forwarding really stops it**: connections that were already open (a game, a database session) used to keep going through a stopped forwarding, over ZeroTier and SSH alike. They are now closed too.
- Forwarding options read "Connections from LAN" and "Auto start".

## 0.8.0

- **Forwardings live under their host.** The ⇄ button at the end of a host tile slides its forwardings out: each shows its ports, a switch and, while on, connections and traffic. When they are hidden and some run, a strip under the host shows how many and how much traffic. The separate Port forwarding screen is gone.
- **A simpler forwarding editor**: the host is the one you opened it from; Here → there / There → here / SOCKS; one-tap destination ports (PostgreSQL, MySQL, Redis, HTTP, SSH); the port here is suggested for you; one line shows where traffic goes; options are two chips.
- **TCP and UDP in one forwarding** for hosts on a ZeroTier network. Your existing ZeroTier forwardings move under the host with that address (a host is added when there is none).

## 0.7.6

- **Smoother forms**: typing in the port-forwarding editor (or any screen over your tabs) no longer stutters while the keyboard opens; the open terminal behind it was being resized on every frame.
- **Faster file browser**: large folders open and sort much faster, and folders with many links load in one go.
- **Big text files** open the first 512 KB right away (Load all for the rest), decode in the background and skip syntax colouring above 1 MB, so opening them no longer freezes the app.
- **Scrollbars** you can drag in the file browser and in text, Markdown and hex views.
- **Copy and paste**: selecting text in the terminal shows Copy, Paste and Select all; the text editor gets Cut, Copy, Paste and Select all on its selection.
- Leaving a **ZeroTier** network asks first.
- **Add buttons** at the bottom of Keys, Port forwarding and ZeroTier, instead of in the ⋮ menu.
- Host pings refresh every 10 seconds again; a host that does not answer shows just an empty dot.
- The unused "predictive back" setting is gone.

## 0.7.5

- **Connections survive closing nux**, like Termux: closing nux from the recent apps no longer ends your terminals, file browsers or port forwards while the background notification is there. Opening nux again brings back every tab exactly as you left it. "Disconnect all" in the notification ends everything.

## 0.7.4

- **More reliable background connections**: when Android refuses to start the background service (it does that while nux is in the background), nux notices, keeps trying, and starts it as soon as you come back, so the notification and your forwards no longer disappear for good.
- **Settings → Background connections** shows whether notifications are allowed and whether nux is exempt from battery optimisation, with a button to fix each. nux asks once for the battery exemption, like Termux.
- **Settings → Share log**: what nux did since it started (hosts and addresses hidden), to attach to a bug report.
- Host pings refresh every 5 seconds. Connected hosts are measured over their SSH session, so hosts behind a jump host show a ping too while connected.

## 0.7.3

- The host editor has one big **Save** button (no "Save and connect").
- Hosts reached through **ZeroTier** show their ping too, while ZeroTier is on and the network is up.
- The tab overview no longer splits tabs into sections by host group.

## 0.7.2

- **ZeroTier**: networks show their names instead of only their ids, and turning ZeroTier on with several networks no longer crashes nux.
- Opening a tab from the tab overview no longer plays a sliding animation in its header (it happened after closing tabs there).
- The background notification's **Disconnect all** always works, and the notification goes away when you close nux from the recent apps (closing nux ends its connections; the notification used to stay behind with a button that did nothing).
- **Open terminal here** in the file browser's ⋮ menu: a shell on the same host, in the folder you are looking at.

## 0.7.1

- **No more floating buttons**: Add host, Upload, Add key, Join network and Add forward are in the ⋮ menu of their tab or screen (Stop all too), so nothing covers the content.
- **New hosts list**: hosts are small tiles with a reachability dot and the round-trip time to their SSH port (refreshed every 20 seconds), the name and just the address. Tap a host for its menu: **SSH** and **SFTP** side by side, then port forwarding, edit, duplicate and delete. The search bar and the letter avatars are gone.
- Tab previews in the overview are sharp (rendered for the screen's density).
- The hosts tab's ⋮ menu no longer shows a stray divider.
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
