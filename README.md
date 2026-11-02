# nux

A phone-first SSH/SFTP client, port forwarder (SSH and ZeroTier, TCP and UDP) and mobile IDE with git,
a code editor and LSP support, built with Flutter. Everything opens in Chrome-style tabs.

**Status:** early. The first build sets up settings and in-app updates. Features arrive milestone by milestone:
see [`TODO.md`](TODO.md) and the plan in [`docs/PLAN.md`](docs/PLAN.md).

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
