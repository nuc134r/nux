# nux — plan

`io.nuc134r.nux`. A rewrite of the older `lamp_studio` prototype as a phone-first:

1. **SSH / SFTP client**
2. **Port forwarder** over SSH and ZeroTier (TCP and UDP)
3. **Mobile IDE** with git, on interchangeable backends: SSH, Termux (SSH to localhost), local (fewer features), with LSP support
4. **Code viewer / editor**

Everything open lives in **Chrome-style tabs** (terminal, file browser, editor, git, forwardings…) that keep their state.

The work breakdown lives in [`../TODO.md`](../TODO.md). This file records the decisions behind it.

---

## 1. Principles

- **Same spirit as garage2**: feature-first folders, plain-Dart domain logic with unit tests, Riverpod 3,
  Drift, go_router, gen-l10n (en + ru), strict lints, CHANGELOG-driven GitHub releases, in-app updates.
- **Fresh history.** Nothing is copied from `lamp_studio`'s git history. Code is re-written or ported
  file by file after review (see §10, privacy).
- **Friendly by default.** Every destructive or surprising action explains itself: host key changes, force
  pushes, discarding changes, closing a tab with unsaved edits. Defaults are safe; power is one tap away.
- **Backends behind interfaces.** UI never knows if a file came over SFTP, from Termux or local storage.
- **Native code via Dart build hooks**, not hand-carried `.aar`/`.so` files.

## 2. Versions (checked 2026-11-02)

| What | Version | Note |
|---|---|---|
| Flutter | **3.47.9** stable (Dart 3.13.7) | pinned with FVM (`.fvmrc`); garage2 is on 3.47.7 |
| flutter_riverpod | 3.4.3 | hand-written providers, like garage2 |
| go_router | 18.1.x | only for non-tab screens (see §5) |
| drift / drift_flutter | 2.35.x / 0.3.1 | |
| dartssh2 | 4.1.0 | SSH, SFTP, exec, local/remote forwarding |
| flterm / libghostty | 0.0.6 / 0.0.13 | terminal on Ghostty's VT engine (§6) |
| re_editor | 0.10.0 | code editor widget (§7) |
| git2dart | 0.5.6 | libgit2 FFI, Android supported (§8) |
| flutter_secure_storage | 11.2.0 | private keys, passwords, tokens |
| flutter_foreground_task | 11.0.3 | forwarding keeps running in background |
| hooks / code_assets / native_toolchain_cmake | 2.2 / 2.1 / 0.3.2 | build hooks for libzt (§4) |
| ota_update, package_info_plus | 7.1.0, 10.2.2 | in-app updates (same as garage2) |
| ffigen | 23.0.0 | `@Native` bindings |

Re-check with `fvm flutter pub outdated` at the start of each milestone.

## 3. Architecture

Pub **workspace** (monorepo) so the app and its own packages build and test together:

```
nux/
  pubspec.yaml               # workspace root + the app
  lib/
    app/                     # app root, router, theme, tab host
    core/                    # db, secure store, logging, shared widgets, result types
    features/
      connections/           # hosts, identities (keys), known hosts, jump hosts
      terminal/              # terminal tab, extra-keys bar, sessions
      files/                 # file browser tab (any backend), transfers
      forwarding/            # forwarding rules, foreground service, stats
      zerotier/              # node, networks, identity
      editor/                # editor tab, buffers, search, LSP client glue
      workspace/             # project = backend + root dir; file tree, quick open
      git/                   # status, diff, stage, commit, branches, log, remotes
      backends/              # ssh, termux, local implementations of the ports below
      lsp/                   # JSON-RPC client, server registry
      updates/               # GitHub releases + OTA (port of garage2's feature)
      settings/
  packages/
    tab_switcher/            # 2.0 of the extracted library (see §5)
    nux_backend/             # pure-Dart interfaces (FileSystem, ProcessRunner, PtyHost, GitRepo)
  test/
```

`zerotier_sockets` stays in its own repository (it is published on pub.dev); during development nux uses a
`dependency_overrides` git/path entry.

**Backend ports** (in `packages/nux_backend`, pure Dart so they can be tested without Flutter):

| Port | SSH | Termux | Local |
|---|---|---|---|
| `FileSystem` | SFTP | SFTP to `localhost:8022` | `dart:io` in app storage / SAF-picked folders |
| `ProcessRunner` | exec channel | exec channel | — (no general exec on Android) |
| `PtyHost` | shell channel | shell channel | `ptyx` / `pty2` with the app's own toybox shell (limited) |
| `GitRepo` | `git` CLI over exec, `--porcelain=v2` | same | git2dart (libgit2) |
| `LspTransport` | stdio of an exec channel | same | — |

Termux is "SSH to localhost" plus a guided setup (install `openssh`, generate a key in nux, copy the
`authorized_keys` line, `sshd`). It reuses the SSH backend completely.

**State**: Drift for connections, forwardings, workspaces, recent files, tab session. Secrets never go
into Drift. They go into `flutter_secure_storage` and Drift keeps only a reference id.
Rows have UUID `id`, `createdAt`, `updatedAt` (as in garage2) so backup/merge works later.

## 4. ZeroTier: `zerotier_sockets` 2.0

What exists today (1.1.0): a Flutter plugin that ships a prebuilt `libzt.aar` (libzt, 4 ABIs) and opens it
with `DynamicLibrary.open('libzt.so')`. Only TCP clients exist. Sockets are non-blocking and polled
from the UI isolate. Problems:

- **The `.so` files are 4 KB page-aligned** (`readelf` shows `LOAD` align `0x1000`). Android 15+ devices
  with 16 KB pages refuse to load them, and Google Play rejects them.
- Opaque binary of unknown provenance, Android only, so it can't be unit-tested on the desktop / CI.
- No UDP, no server sockets, no event callbacks (issue #1), polling costs CPU on the UI isolate.

**The modern way: Dart build hooks (native assets).** Stable since Dart 3.10, used by e.g. `libghostty`:

- The package becomes a **plain Dart package** (no Android/iOS plugin folders) with `hook/build.dart`.
  The hook emits a `CodeAsset(linkMode: DynamicLoadingBundled())` for the target OS and architecture.
  Flutter bundles it into the APK, desktop app or `dart test` run automatically.
- Bindings are generated by ffigen as **`@Native` external functions** bound to the asset id, so there is no
  `DynamicLibrary.open` or loader code.
- **Binary provider** (the libghostty pattern):
  1. Default: download a **prebuilt** `libzt` for the target triple from this package's GitHub release.
     Its **sha256 is pinned** in the package (`asset_hashes.dart`), so builds are reproducible and offline-cached.
  2. `LIBZT_SRC=/path/to/libzt`, or a C/C++ toolchain available: **compile from source** with
     `native_toolchain_cmake` (Android NDK cross-compile, `-Wl,-z,max-page-size=16384`).
- A **CI workflow in the zerotier repo** builds libzt (pinned submodule, tag 1.8.10) for
  android arm64/armv7/x86_64 and linux/macos/windows x64, verifies the 16 KB alignment and uploads the
  binaries plus their hashes to a release.
- **Threading**: one long-lived I/O isolate owns all fds and runs `zts_bsd_poll`. It talks to the main
  isolate over `SendPort`s, so the UI isolate never polls. Node events come through `zts_init_set_event_handler`
  with a `NativeCallable.listener`.
- **API** (mirrors `dart:io` so it fits next to normal sockets):
  - `ZeroTierSocket` (TCP client, as now)
  - `ZeroTierServerSocket` (bind / listen / accept, for inbound forwarding)
  - `ZeroTierDatagramSocket` (**UDP**: `zts_bsd_sendto` / `recvfrom`, like `RawDatagramSocket`)
  - `ZeroTierNode` with a `Stream<NodeEvent>` instead of `waitFor*` polling
- Upstream risk: libzt's last commit is Nov 2024. It is pinned, small and C, so a fork is possible if needed.

Spike first (M4.0): one hook building libzt for `android-arm64` + `linux-x64`, a `dart test` that starts a node.

## 5. Tabs (Chrome-style)

Start from `tab_switcher` 1.0.1 (the extracted library). `lamp_studio` still carries a slightly newer local
copy (it has `tab_switcher_tab_list_item.dart`). Merge both into **tab_switcher 2.0** in `packages/`:

- Null-safe, Dart 3, Material 3 theming, predictive back, landscape and tablet layouts (grid or strip).
- **State preservation**:
  - **Live**: the current tab and the N most recent ones (default 3) stay mounted in an `IndexedStack` with
    `TickerMode` off. Scroll position, terminal and editor state survive switching.
  - **Parked**: older tabs are disposed after taking a preview image. Each tab's model has a serialisable
    `TabState` (kind + args + cursor/scroll), so a parked tab and the whole session after an app restart come back as they were.
  - Connections (SSH sessions) belong to a connection pool, not to widgets. Parking a terminal tab keeps its
    session alive, and the terminal buffer is kept in the controller.
- Swipe header to switch, swipe down for the grid, swipe a card to close, long-press for a menu
  (duplicate, pin, close others, move to group), **tab groups** per workspace/host.
- Unsaved-changes guard on close. Undo "closed tab" snackbar.
- go_router handles only things that are not tabs (settings, editing a connection, onboarding). Opening a file
  is a **command**, not a route.

## 6. Terminal

**Choice: `flterm`** (Flutter widget over Ghostty's `libghostty-vt`, active, all platforms, native assets),
behind a small `TerminalSurface` interface in nux.

| Candidate | State |
|---|---|
| `xterm` 4.0.0 | most used, but no release since Feb 2024. lamp_studio even needed a git fork |
| `xterm2` / `xterm3` / `kterm` | community forks of xterm.dart, 2026 releases, small user base |
| `flterm` + `libghostty` | Ghostty's VT engine (a real terminal's parser and state): wide-char / emoji / grapheme correctness, OSC 8 links, truecolor, touch + soft keyboard support built in |
| `ghostty_vte_flutter` | another libghostty wrapper, less active |

Risk: 0.0.x versions. Mitigation: a spike in M1, and the `TerminalSurface` abstraction keeps `xterm2` as a
drop-in fallback. Same author's `ptyx` (or `pty2`) covers local PTYs.

Mobile extras (ported from lamp_studio's virtual keyboard): an extra-keys bar (Esc, Tab, Ctrl, Alt, arrows,
`|~/-`), sticky modifiers, volume-key modifiers, pinch-to-zoom font, copy mode, URL / path tapping
(opens the file in an editor tab on the same host).

## 7. Code viewer / editor

**`re_editor`** (active, built for large files, code folding, find/replace, multi-cursor-ish selection
handling, custom toolbars) with `re_highlight` grammars. `highlight`/`flutter_highlight` (used by
lamp_studio) has been dead since 2021.

- Viewer mode first: open huge files (lazy load over SFTP, size warning), go to line, search, wrap toggle.
- Edit mode: undo/redo per buffer, auto-indent, bracket pairs, an extra-keys bar shared with the terminal,
  "save as root" through `sudo tee` on SSH backends, conflict detection (remote mtime changed since open).
- Phone ergonomics: a big cursor handle, a swipe-on-keybar to move the cursor, quick symbol palette, readable
  defaults (JetBrains Mono, 14 sp).
- Markdown preview, image viewer, hex view for binary files.
- Later: tree-sitter for precise highlighting / outline (via a native-assets package).

## 8. Git client

- **Remote backends** (SSH/Termux): run the real `git` CLI over exec. Parse `status --porcelain=v2 -z`,
  `log --format=…`, `diff --no-color`. Server-side credentials and hooks then just work.
- **Local backend**: `git2dart` (libgit2). Clone over HTTPS with a token stored in secure storage.
- One `GitRepo` interface. The UI does not care which backend is behind it.

Friendly UX:
- Status screen grouped as *Changes / Staged / Conflicts / Untracked*, swipe to stage/unstage, tap for diff.
- Diff viewer: side-by-side in landscape, unified in portrait, **stage individual hunks/lines**.
- Commit sheet with a summary-length hint, amend toggle, sign-off toggle, author from the workspace's identity.
- Branch switcher with "you have uncommitted changes — stash, carry over, or cancel?".
- Pull = fetch + explained choice (fast-forward / rebase / merge) when diverged. Push shows what will go out.
  Force push is `--force-with-lease` and asks with the list of commits that would be lost.
- Log as a graph, commit details, blame in the editor gutter, stash list, tags.
- Conflict resolver: ours / theirs / both per hunk, then "mark resolved".
- Every operation shows the equivalent git command in a "what did this do?" expander, which also teaches.

## 9. LSP (and VS Code)

- Client: JSON-RPC 2.0 over **stdio of an SSH exec channel** (or Termux). A small registry maps language →
  server command (`dart language-server`, `pyright-langserver --stdio`, `rust-analyzer`, `clangd`,
  `typescript-language-server --stdio`, `gopls`), editable by the user and detected with `command -v`.
- Features in order: diagnostics, hover, completion, go to definition, references, rename, format, code actions.
- Files are opened with `file://` URIs of the **remote** path, so the server sees the real project.
- **VS Code remote**: research only. The VS Code Server protocol is not public or stable. Realistic options:
  (a) open an `openvscode-server` / `code-server` instance through an SSH port forward in a WebView tab,
  (b) reuse LSP only (above). Option (a) is cheap once forwarding and a WebView tab exist.

## 10. Privacy: nothing personal leaks

Found while reading the source repos (**the owner should act on these**):

- `lamp_studio` commit `8fa47a2` ("hardcoding ssh key") puts an **OpenSSH private key** into
  `lib/ssh/shell_connection.dart`. It is still in that repo's history. **Treat that key as compromised:
  remove it from every `authorized_keys`.** Then rewrite or archive that repo before ever making it public.
- `lamp_studio` commits carry a personal e-mail address as author on 3 commits.
- garage2's `docs/RELEASING.md` contains a local Windows user path (`C:\Users\<name>\keys\…`).
- `lamp_studio` accepts **every** SSH host key without checking (`onVerifyHostKey` returns true).

Rules for nux:
- New repository history. Code is ported by hand, never cherry-picked from lamp_studio.
- No hosts, IPs, usernames, network ids or keys in code, tests or screenshots. Use `example.com`,
  `192.0.2.0/24` (TEST-NET-1), `8056c2e21c000001`-style dummy network ids.
- CI runs **gitleaks** on every push and PR. `.gitignore` covers `*.jks`, `key.properties`, `*.pem`, `id_*`.
- Commits use the GitHub noreply address.
- Secrets live only in `flutter_secure_storage` (Android Keystore). Optional biometric unlock (`local_auth`).
  Backups exclude secrets unless explicitly encrypted with a passphrase.
- Host keys: **TOFU** with a fingerprint dialog, `known_hosts` table, loud warning on a changed key.
- Logs redact passwords, keys and tokens. Shared debug logs mask hosts by default.

## 11. Releases and in-app updates

Port garage2's pipeline almost verbatim:
- `tests.yml` (analyze + test + gitleaks), `release.yml` (tag `v*` → signed APKs, universal + split per ABI →
  GitHub release with the CHANGELOG section), `release-notes.yml`.
- `tool/version.sh`, `tool/changelog.sh`, `docs/RELEASING.md` (keystore setup, without personal paths).
- `features/updates`: GitHub `releases/latest` check on start (setting to disable, "skip this version"),
  ABI-matched APK download through `ota_update`, changelog screen. Pre-releases are opt-in ("beta channel").
- Android: `REQUEST_INSTALL_PACKAGES`. Same keystore forever (documented).
- Platforms: Android first. Linux/Windows desktop builds later (everything is native-assets friendly).
  No web build (no raw sockets).

## 12. Milestones

See [`TODO.md`](../TODO.md) for the checklist. Order:

| # | Milestone | Outcome |
|---|---|---|
| M0 | Bootstrap | workspace, CI, release + updates working from build #1 |
| M1 | Tabs + SSH terminal | connections, keys, known hosts, flterm spike, tab_switcher 2.0 |
| M2 | SFTP + viewer | file browser tab, transfers, read-only code viewer |
| M3 | SSH forwarding | -L/-R/-D rules, foreground service, notification with stats |
| M4 | ZeroTier 2.0 | build hooks, UDP, server sockets, ZT and ZT+SSH forwarding |
| M5 | Editor + workspaces | re_editor, project tree, quick open, search in files |
| M6 | Git | status/diff/stage/commit/branch/push/pull/log/conflicts |
| M7 | Backends | Termux guided setup, local mode with git2dart |
| M8 | LSP | diagnostics → completion → navigation |
| M9 | Polish / research | VS Code via WebView, tablets/desktop, tree-sitter |

M4 can run in parallel with M2–M3 because it lives in its own repo.

## 13. Decisions (answered 2026-11-02)

1. `tab_switcher` 2.0 is developed inside the nux workspace (`packages/tab_switcher`) and published from
   there once it is stable.
2. Distribution: **GitHub releases** for now. Keep **F-Droid** possible later:
   - no proprietary dependencies (no Firebase / Play Services);
   - every native binary can be built from source (the libzt hook's `LIBZT_SRC` / toolchain path, and the
     same for libghostty and libgit2), because F-Droid does not accept prebuilt binaries;
   - the in-app updater checks only GitHub, and an F-Droid build turns it off with a build flag
     (`--dart-define=NUX_UPDATER=false`);
   - reproducible builds: pinned Flutter (FVM), committed `pubspec.lock`, `fastlane/metadata` added when needed.
3. **Start clean**: no importer for lamp_studio data. **SSH key management** is a first-class feature (§14).
4. Minimum Android version: **API 26** (Android 8).

## 14. SSH key management

Keys ("identities") are their own screen, not a field hidden inside a connection.

- **Generate**: Ed25519 (default), ECDSA P-256/384/521, RSA 3072/4096. Optional passphrase, and a comment
  (default `nux@<device model>`).
- **Import**: OpenSSH private key (`-----BEGIN OPENSSH PRIVATE KEY-----`), PEM/PKCS#1/PKCS#8, PuTTY `.ppk`
  (v2/v3). Import from a file picker, the clipboard or a share intent. Encrypted keys ask for the passphrase.
  The original file is not kept.
- **Export**: copy or share the **public** key (`authorized_keys` line), show it as a QR code, show
  SHA256 and MD5 fingerprints and the randomart. Exporting the private key needs explicit confirmation plus
  biometric/device credential, and it always leaves encrypted with a passphrase.
- **Install on server** (`ssh-copy-id` equivalent): over an already authenticated (password) session,
  append the public key to `~/.ssh/authorized_keys` with the right permissions, skip it if it is already there,
  then offer to switch the connection to key auth.
- **Storage**: private keys live in `flutter_secure_storage` (Android Keystore-backed). Optional "require
  biometric unlock" per key. Passphrase-protected keys can remember the passphrase for the session only or not at all.
- **Usage**: each key lists the connections that use it; deleting a used key warns and lists them.
  A connection can try several keys in order.
- **Later**: an SSH agent inside nux with agent forwarding (per connection, off by default), FIDO2/security keys
  (`sk-ssh-ed25519`), certificates (`*-cert.pub`).
- **Tests**: round-trip generate → serialise → parse for every key type, golden fixtures generated with
  `ssh-keygen` on throwaway keys (fixtures are created in the test, never committed private keys).
