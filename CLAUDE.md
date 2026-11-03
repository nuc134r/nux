# nux

Flutter app (Android first; Linux/Windows later): SSH/SFTP client, SSH/ZeroTier port forwarder and mobile IDE.
Plan and decisions: `docs/PLAN.md`. Backlog: `TODO.md` (tick items when done).
Flutter is pinned with FVM (`.fvmrc`, 3.47.9): run `fvm flutter …` / `fvm dart …`.

## Stack
- **Pub workspace**: the app at the root, own packages in `packages/` (`nux_backend`: pure-Dart backend interfaces;
  `tab_switcher`: Chrome-style tabs, Flutter — test it with `flutter test`; `flterm`: vendored terminal widget
  with line-height and tap-to-show-keyboard patches, see its README — keep the diff small).
  One `pubspec.lock` for everything. `build_runner` is held at 2.16.x because `flutter_test` pins `analyzer` below 14.
- **Riverpod 3** with hand-written providers (`Override` is imported from `package:flutter_riverpod/misc.dart`)
- **Drift** (SQLite) — schema in `lib/core/db/tables.dart`
- **go_router** only for screens that are not tabs; paths in `Routes` (`lib/app/router.dart`)
- **gen-l10n** — `lib/l10n/app_en.arb` (template) and `app_ru.arb`; use `context.l10n`

## Layout
- `lib/core/` — db, `SecretStore`, `Log` + `redact`, shared widgets, `app_info.dart` (repo, version, `NUX_UPDATER`)
- `lib/features/<feature>/{data,domain,presentation}`: workspace (tabs, session restore), connections (hosts,
  known hosts), identities (SSH keys), ssh (connector, pool, backend, SFTP, prompts), terminal, files (browser,
  transfers, bookmarks), viewer, forwarding (rules, engine, manager, foreground service), zerotier (node
  service, SSH socket adapter, TCP/UDP forwards), settings, updates
- ZeroTier comes from `zerotier_sockets` (git dependency): its build hook clones libzt and compiles it with
  CMake, so builds and `flutter test` need git, CMake and a C++ compiler (the NDK for Android). Never call
  libzt from widget tests: `@Native` functions load the library on first call; the node is started on demand.
- File features work on `nux_backend`'s `FileSystem` through an `FsOpener`; tests and screenshots pass a
  `LocalFileSystem` (`TabFactory.openOverride`). New `FileSystem` implementations must pass
  `packages/nux_backend/test/file_system_contract.dart`.
- Tabs are `NuxTab`s (`features/workspace/domain/nux_tab.dart`) created by `TabFactory`; give a new kind a `kindName`,
  `args` and a case in `TabFactory.restore`. Heavy state (sessions) lives in the tab object, not its widget.
- SSH goes through `SshPool` (one connection per host, shared) → `SshConnector` (jump hosts, keys, password,
  TOFU). UI questions go through `SshPrompter` (dialogs in the app, fakes in tests).
- Domain logic is plain Dart and unit-tested (e.g. `release.dart`, `redact.dart`, `packages/nux_backend`).

## Rules
- **No personal data in the repo**: no real hosts, IPs, usernames, ZeroTier network ids or keys in code, tests,
  docs or screenshots. Use `example.com`, `192.0.2.0/24`, `2001:db8::/32`. Never generate test keys into
  committed files: create them at test time. `secrets.yml` runs gitleaks on every push.
- Secrets (private keys, passwords, passphrases, tokens) only go through `SecretStore`; the database keeps the id.
- Everything logged goes through `Log`, which redacts; shared logs also mask hosts.
- User-data tables use `SyncedTable` (UUID `id`, `createdAt`, `updatedAt`; set `updatedAt` on every write).
- No hardcoded UI strings: add keys to both ARB files (`test/l10n_test.dart` checks), then `fvm flutter gen-l10n`.
  `python tool/add_strings.py strings.py` adds many at once (see its docstring); use ICU plurals for counts.
- After changing tables: `fvm dart run build_runner build`, bump `schemaVersion`, add a migration step, then
  `fvm dart run drift_dev schema dump lib/core/db/database.dart drift_schemas/app/drift_schema_vN.json` and
  `fvm dart run drift_dev schema generate drift_schemas/app test/generated_migrations`.
- `test/app_smoke_test.dart` renders every route in `Routes.all` at phone and desktop widths — add new routes there
  (ids are `sample`, created by `insertSamples` in `test/helpers.dart`).
- Key and SSH tests need `ssh-keygen`, `openssl`, `puttygen` and `/usr/sbin/sshd`
  (`apt install openssh-client openssh-server openssl putty-tools`); without them those tests skip.
- Look at the UI, not just the tests: `bash tool/screenshots.sh` renders `docs/screenshots/*.png`.
- User-visible changes get a line in `CHANGELOG.md` under the next version (it is the release notes).
- **UI: no FABs and no extra header buttons.** Tab headers have only the tab count and ⋮; actions go in
  `NuxTab.menuEntries` (submenus for option groups), screens put them in an app-bar `NuxMenuButton`
  (list screens: Add is a bottom `AddBar`).
  Progress shows where the action started, results in snackbars. See `docs/PLAN.md` "UI conventions".

## Icons
Never edit generated icon files (`android/.../res/{drawable,mipmap-*}/ic_*`, `assets/app_icon.png`);
change `icons/*.svg` and run `python tool/generate_icons.py` (needs a Chromium-based browser; `BROWSER=` to pick one).

## Commands
```bash
fvm flutter analyze
fvm flutter test
(cd packages/nux_backend && fvm dart test)
fvm dart run build_runner build
fvm flutter gen-l10n
```
Releasing: `docs/RELEASING.md`.
