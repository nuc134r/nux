# nux

A phone-first SSH/SFTP client, port forwarder (SSH and ZeroTier, TCP and UDP) and mobile IDE with git,
a code editor and LSP support, built with Flutter. Everything opens in Chrome-style tabs.

**Status:** early. SSH terminals in tabs, saved hosts, SSH key management and host key checking work.
SFTP, port forwarding, ZeroTier, the editor and git come next: see [`TODO.md`](TODO.md) and the plan in
[`docs/PLAN.md`](docs/PLAN.md).

<p>
  <img src="docs/screenshots/terminal.png" width="240" alt="Terminal">
  <img src="docs/screenshots/tabs.png" width="240" alt="Tabs">
  <img src="docs/screenshots/key.png" width="240" alt="SSH key">
</p>

## Install

Download the APK for your phone from [Releases](https://github.com/nuc134r/nux/releases)
(`arm64-v8a` for most phones). The app updates itself from there.

## Build

```bash
fvm install            # Flutter version from .fvmrc
fvm flutter pub get
fvm flutter run
```

See [`CLAUDE.md`](CLAUDE.md) for the conventions and commands, and [`docs/RELEASING.md`](docs/RELEASING.md)
for publishing.

## License

[MIT](LICENSE). JetBrains Mono is under the [SIL Open Font License](assets/fonts/OFL.txt).
