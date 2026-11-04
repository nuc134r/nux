# Backlog

Decisions and rationale: [`docs/PLAN.md`](docs/PLAN.md).

## M0 — Bootstrap
- [x] `fvm use 3.47.9`, `flutter create --org io.nuc134r --project-name nux --platforms android,linux,windows`, minSdk 26
- [x] Pub workspace root; `packages/nux_backend` (`packages/tab_switcher` is created with the 2.0 port in M1)
- [x] Lints (garage2's `analysis_options.yaml`), gen-l10n en + ru, Material 3 theme + dark mode, JetBrains Mono
- [x] Drift DB skeleton + migration test harness; secure-storage wrapper; logger with redaction
- [x] `.gitignore` for keystores/keys; gitleaks in CI (`secrets.yml`, every push and PR, gates releases)
- [x] CI: `tests.yml`, `release.yml`, `release-notes.yml` ported from garage2; `tool/version.sh`, `tool/changelog.sh`
- [x] `docs/RELEASING.md` (no personal paths), CHANGELOG.md
- [x] In-app updates (port `features/updates`), beta channel toggle, `NUX_UPDATER` dart-define to disable
- [x] App icon pipeline (`icons/*.svg` → `tool/generate_icons.py`, as in garage2)
- [x] `CLAUDE.md` with commands and conventions
- [ ] Create the release keystore + `ANDROID_*` secrets, tag `v0.1.0` (owner)

## M1 — Tabs + SSH terminal
- [x] Create `packages/tab_switcher` in the workspace (rewritten as 2.0; ideas from 1.0.1 and lamp_studio's copy)
- [x] tab_switcher 2.0: Dart 3, M3, back closes the grid, wide-screen tab strip, header swipe with the body following
- [x] Live/parked tab lifecycle (`keepAlive`, `onParked`/`onResumed`, previews), session restore after restart
- [x] Tab menu (pin, close others, "another terminal on this host"), grid sections by group, undo close, unsaved-changes guard
- [x] Connections: host, port, user, keys in order, saved password, jump host (ProxyJump), group, colour tag, keep-alive
- [x] Quick connect (`user@host:port`)
- [x] Identities screen (PLAN §14): generate Ed25519/ECDSA/RSA with passphrase and comment
- [x] Import OpenSSH / PEM / PKCS#8 (plain and PBES2) / PuTTY `.ppk` v2+v3 from file or clipboard
- [ ] Import from a share intent (another app's "Share" → nux)
- [x] Public key export: copy, share, QR, SHA256/MD5 fingerprints, randomart; guarded encrypted private export
- [x] "Install on server" (ssh-copy-id equivalent) and switch the connection to the key
- [x] Keys in secure storage, optional device unlock per key, "used by" list and delete warning, change passphrase
- [x] Key tests against ssh-keygen / openssl / puttygen (throwaway keys made at test time)
- [x] Known hosts: TOFU dialog with fingerprint, changed-key and new-key-type warnings, manage list
- [ ] Spike on a real mid-range phone: flterm vs xterm2 (htop, vim, tmux, emoji, CJK, 10 MB `cat`)
- [x] Terminal tab: flterm view, extra-keys bar with sticky Ctrl/Alt, font size setting, paste/copy all, URL links
- [x] Terminal: pinch to zoom, text size and line spacing from the menu and settings, tap shows the keyboard
- [ ] Terminal: volume keys as modifiers, copy mode with handles, open file paths in an editor tab (M5)
- [ ] Move a tab to another group from its menu
- [x] Connection pool (shared per host, idle grace period), reconnect banner and "Enter to reconnect", keep-alive
- [x] SSH integration tests against a throwaway local sshd (TOFU, exec, pty, changed key, jump host)
- [x] Smoke test renders every route at phone and desktop widths; screenshot test (`tool/screenshots.sh`)

## M2 — SFTP + viewer
- [x] `FileSystem` port + SFTP and local (`dart:io`) implementations, one contract test for both
- [x] File browser tab: breadcrumbs, sort (folders first, natural order), hidden files, multi-select,
      rename/move/delete/chmod/new folder, bookmarks per host, back goes up, "Terminal here"
- [x] Transfers: upload/download queue with progress, cancel, resume after a drop; save as / share downloads
- [ ] Downloading and uploading whole folders
- [ ] Receive files shared from other apps (share intent → upload)
- [x] Read-only code viewer (re_editor): ~45 highlighted languages, line numbers, folding, find, wrap
- [x] Large files load the first 512 KB with "Load all"; image, Markdown (rendered/source) and hex views

## M3 — SSH port forwarding
- [x] Rules: local (-L), remote (-R), dynamic SOCKS5 (-D), per connection, auto-start (schema v4)
- [x] Forwards run on the shared SSH pool in the main isolate (prompts keep working); reconnect with backoff
- [x] Android foreground service (`specialUse`) keeps the process alive; notification with count, traffic and "Stop all"
- [x] Forwardings under their host in the hosts tab (slide out, peek while running); compact editor with
  port suggestions; TCP+UDP in one forwarding (ZeroTier hosts)
- [x] Duplicate/conflicting ports refused when saving; clear errors for a taken port, a refused remote bind, ports < 1024
- [x] One foreground service for SSH sessions (terminals, SFTP) and forwards (`KeepAliveHub`), "Disconnect all"
- [x] Ask once to ignore battery optimisation (Termux-style); Settings → Background connections shows both permissions
- [ ] Setting to not keep sessions alive in the background
- [x] Keep sessions and forwards after nux is swiped out of recents, like Termux: one cached FlutterEngine
      (`NuxEngine.kt`) that the activity borrows and does not destroy; the service no longer stops with the task
- [ ] Device-test the cached engine: swipe away, reopen, notification tap, Disconnect all, low memory, updates
- [ ] Byte counters for SOCKS connections (dartssh2's SOCKS server only reports connections)

## M4 — ZeroTier (`zerotier_sockets` 2.0, own repo)
- [x] `hook/build.dart` + `native_toolchain_cmake` build libzt 1.8.10 from a pinned commit (android-arm64 and
      linux-x64 verified; Android output 16 KB aligned); local checkout via `hooks.user_defines.libzt_src`
- [x] Plain Dart package with native assets; `.aar`, plugin and `loader.dart` gone
- [x] ffigen 23 `@Native` bindings
- [ ] Optional prebuilt provider (release binaries with pinned sha256) to speed up builds
- [ ] CI matrix for the package (android ABIs, macOS, Windows); it runs `dart test` on Linux now
- [x] One shared adaptive poller for all sockets (an I/O isolate stays possible later)
- [ ] Node events from libzt's callback (its message is freed when the C callback returns, so the
      async `NativeCallable.listener` cannot read it; status is polled instead)
- [x] `ZeroTierServerSocket` (bind/listen/accept)
- [x] `ZeroTierDatagramSocket` (UDP sendto/recvfrom)
- [x] `dart test` on Linux (offline: identity, binding, errors); real traffic opt-in via `test/network_test.dart`
- [x] nux: ZeroTier screen (node on/off, node id, networks with status and addresses, start with nux)
- [x] nux: hosts reachable through a ZeroTier network (SSH over a ZeroTier TCP socket), schema v5
- [x] nux forwarding: ZeroTier TCP and **ZeroTier UDP** (local port ↔ ZeroTier address, no SSH)
- [ ] Inbound forwarding (ZeroTier peers reach a port on this device) and ZeroTier → SSH chains
- [ ] Publish zerotier_sockets 2.0 to pub.dev (nux pins a git commit until then)

## M5 — Editor + workspaces
- [x] Editing: edit mode in the viewer, save with remote-change detection (overwrite / discard mine), undo/redo, "•" in the tab title, close guard for unsaved changes
- [ ] Workspace = backend + root; recent workspaces; project tree tab
- [ ] Edit mode: undo/redo, auto-indent, brackets, find/replace, go to line, save, save-as-root (`sudo tee`)
- [ ] Remote change detection (mtime/hash) with a reload/overwrite/diff choice
- [ ] Quick open (fuzzy), search in files (`rg`/`grep` over exec; Dart fallback locally)
- [ ] Cursor ergonomics: keybar swipe, symbol palette, big handles

## M6 — Git
- [ ] `GitRepo` port; CLI implementation (porcelain v2) for SSH/Termux
- [ ] Status screen, stage/unstage files, hunks and lines
- [ ] Diff viewer (unified / side-by-side), commit sheet (amend, sign-off)
- [ ] Branches: switch (with stash/carry choice), create, delete, rename; tags; stash list
- [ ] Fetch/pull with an explained divergence choice; push preview; force-with-lease confirmation
- [ ] Log graph, commit details, blame gutter
- [ ] Conflict resolver
- [ ] "Equivalent git command" expander on every action

## M7 — Backends
- [ ] Termux guided setup (install openssh, authorise nux key, start sshd, test)
- [ ] Local backend: app storage + SAF folders, local PTY (ptyx/pty2), git2dart (clone over HTTPS with token)
- [ ] Capability flags per backend so the UI hides what is unsupported

## M8 — LSP
- [ ] JSON-RPC client over an exec channel's stdio; server registry with `command -v` detection
- [ ] Diagnostics, hover, completion, definition, references, rename, format, code actions

## M9 — Polish / research
- [ ] Web browser tab (PLAN §5): address bar, back/forward/reload, restore URL, downloads to transfers
- [ ] "Open in browser tab" on local forwards; SOCKS (-D) forward as the WebView proxy (Android `ProxyController`)
- [ ] VS Code: `code-server`/`openvscode-server` through a forward in a WebView tab
- [ ] Tablet / desktop layouts, hardware keyboard shortcuts
- [ ] tree-sitter highlighting and outline
- [ ] Encrypted backup/restore of connections (secrets only with a passphrase)
- [ ] In-app SSH agent + agent forwarding; FIDO2 `sk-` keys; SSH certificates
- [ ] F-Droid: `NUX_UPDATER=false` flavour, build-from-source paths for all native libs, fastlane metadata

## Owner actions (outside this repo)
- [ ] Revoke the SSH key that `lamp_studio` commit `8fa47a2` hardcoded; rewrite or keep that repo private
- [ ] Remove the personal path from garage2 `docs/RELEASING.md`
- [ ] Create the nux release keystore and the four `ANDROID_*` secrets
