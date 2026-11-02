# Backlog

Decisions and rationale: [`docs/PLAN.md`](docs/PLAN.md).

## M0 — Bootstrap
- [ ] `fvm use 3.47.9`, `flutter create --org io.nuc134r --project-name nux --platforms android,linux,windows`
- [ ] Pub workspace root; `packages/nux_backend`, `packages/tab_switcher`
- [ ] Lints (garage2's `analysis_options.yaml`), gen-l10n en + ru, Material 3 theme + dark mode, JetBrains Mono
- [ ] Drift DB skeleton + migration test harness; secure-storage wrapper; logger with redaction
- [ ] `.gitignore` for keystores/keys; gitleaks in CI
- [ ] CI: `tests.yml`, `release.yml`, `release-notes.yml` ported from garage2; `tool/version.sh`, `tool/changelog.sh`
- [ ] `docs/RELEASING.md` (no personal paths), CHANGELOG.md
- [ ] In-app updates (port `features/updates`), beta channel toggle
- [ ] App icon pipeline (`icons/*.svg` → `tool/generate_icons.py`, as in garage2)
- [ ] `CLAUDE.md` with commands and conventions

## M1 — Tabs + SSH terminal
- [ ] tab_switcher 2.0: merge lamp_studio's local copy, null safety, M3, predictive back, landscape
- [ ] Live/parked tab lifecycle, serialisable `TabState`, session restore after restart
- [ ] Tab menu (duplicate, pin, close others), groups, undo close, unsaved-changes guard
- [ ] Connections: host, port, user, auth (key / password / agent-less), jump host, group, colour tag
- [ ] Identities: generate ed25519, import OpenSSH/PEM (with passphrase), copy public key, biometric unlock
- [ ] Known hosts: TOFU dialog with fingerprint, changed-key warning, manage list
- [ ] Spike: flterm vs xterm2 on a mid-range phone (htop, vim, tmux, emoji, CJK, 10 MB `cat`)
- [ ] Terminal tab: `TerminalSurface`, extra-keys bar, sticky modifiers, font zoom, copy mode, links
- [ ] Connection pool (sessions outlive widgets), reconnect banner, keep-alive
- [ ] Smoke test that renders every tab kind at phone and tablet widths

## M2 — SFTP + viewer
- [ ] `FileSystem` port + SFTP implementation
- [ ] File browser tab: breadcrumbs, sort, hidden files, multi-select, rename/move/delete/chmod, bookmarks
- [ ] Transfers: upload/download queue with progress, resume, share to/from other apps (SAF)
- [ ] Read-only code viewer (re_editor), large-file lazy loading, image / markdown / hex views

## M3 — SSH port forwarding
- [ ] Rules: local (-L), remote (-R), dynamic SOCKS5 (-D), per connection, auto-start
- [ ] Android foreground service (flutter_foreground_task 11) in its own isolate; typed messages
- [ ] Notification with active rules and byte counters; quick toggles in the home screen
- [ ] Guard against duplicate/conflicting local ports; clear error when a port is taken

## M4 — ZeroTier (`zerotier_sockets` 2.0, own repo)
- [ ] Spike: `hook/build.dart` + `native_toolchain_cmake` building libzt 1.8.10 for android-arm64 and linux-x64
- [ ] Convert to a plain Dart package with native assets; drop the `.aar` and `loader.dart`
- [ ] ffigen 23 `@Native` bindings
- [ ] Prebuilt provider: GitHub-release binaries with pinned sha256; `LIBZT_SRC` / toolchain → build from source
- [ ] CI matrix (android arm64/armv7/x86_64, linux, macos, windows) + check 16 KB `LOAD` alignment
- [ ] I/O isolate with `zts_bsd_poll`; node events via `NativeCallable.listener`
- [ ] `ZeroTierServerSocket` (bind/listen/accept)
- [ ] `ZeroTierDatagramSocket` (UDP sendto/recvfrom)
- [ ] `dart test` suite on Linux (two nodes in one network, or a local planet)
- [ ] nux: ZeroTier settings (identity, networks, status), SSH-over-ZT sockets (`SSHSocket` adapter)
- [ ] nux forwarding modes: ZT TCP, **ZT UDP**, ZT→SSH, inbound ZT→local

## M5 — Editor + workspaces
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
- [ ] VS Code: `code-server`/`openvscode-server` through a forward in a WebView tab
- [ ] Tablet / desktop layouts, hardware keyboard shortcuts
- [ ] tree-sitter highlighting and outline
- [ ] Encrypted backup/restore of connections (secrets only with a passphrase)

## Owner actions (outside this repo)
- [ ] Revoke the SSH key that `lamp_studio` commit `8fa47a2` hardcoded; rewrite or keep that repo private
- [ ] Remove the personal path from garage2 `docs/RELEASING.md`
- [ ] Create the nux release keystore and the four `ANDROID_*` secrets
