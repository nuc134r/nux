# nux

Flutter app (Android first; Linux/Windows later): SSH/SFTP client, SSH/ZeroTier port forwarder and mobile IDE.
Plan and decisions: `docs/PLAN.md`. Backlog: `TODO.md` (tick items when done).
Flutter is pinned with FVM (`.fvmrc`, 3.47.9): run `fvm flutter …` / `fvm dart …`.

## Stack
- **Pub workspace**: the app at the root, own packages in `packages/` (`nux_backend`: pure-Dart backend interfaces).
  One `pubspec.lock` for everything. `build_runner` is held at 2.16.x because `flutter_test` pins `analyzer` below 14.
- **Riverpod 3** with hand-written providers (`Override` is imported from `package:flutter_riverpod/misc.dart`)
- **Drift** (SQLite) — schema in `lib/core/db/tables.dart`
- **go_router** only for screens that are not tabs; paths in `Routes` (`lib/app/router.dart`)
- **gen-l10n** — `lib/l10n/app_en.arb` (template) and `app_ru.arb`; use `context.l10n`

## Layout
- `lib/core/` — db, `SecretStore`, `Log` + `redact`, shared widgets, `app_info.dart` (repo, version, `NUX_UPDATER`)
- `lib/features/<feature>/{data,domain,presentation}` — home, settings, updates (more per TODO.md)
- Domain logic is plain Dart and unit-tested (e.g. `release.dart`, `redact.dart`, `packages/nux_backend`).

## Rules
- **No personal data in the repo**: no real hosts, IPs, usernames, ZeroTier network ids or keys in code, tests,
  docs or screenshots. Use `example.com`, `192.0.2.0/24`, `2001:db8::/32`. Never generate test keys into
  committed files: create them at test time. `secrets.yml` runs gitleaks on every push.
- Secrets (private keys, passwords, passphrases, tokens) only go through `SecretStore`; the database keeps the id.
- Everything logged goes through `Log`, which redacts; shared logs also mask hosts.
- User-data tables use `SyncedTable` (UUID `id`, `createdAt`, `updatedAt`; set `updatedAt` on every write).
- No hardcoded UI strings: add keys to both ARB files (`test/l10n_test.dart` checks), then `fvm flutter gen-l10n`.
- After changing tables: `fvm dart run build_runner build`, bump `schemaVersion`, add a migration step, then
  `fvm dart run drift_dev schema dump lib/core/db/database.dart drift_schemas/app/drift_schema_vN.json` and
  `fvm dart run drift_dev schema generate drift_schemas/app test/generated_migrations`.
- `test/app_smoke_test.dart` renders every route in `Routes.all` at phone and desktop widths — add new routes there.
- User-visible changes get a line in `CHANGELOG.md` under the next version (it is the release notes).

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
