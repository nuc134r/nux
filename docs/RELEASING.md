# Releasing

| Workflow | Trigger | Output |
|---|---|---|
| `tests.yml` | push to `main`, pull requests | analyze + tests (app and `packages/*`) |
| `secrets.yml` | every push and pull request | gitleaks scan of the whole history |
| `release.yml` | pushing a `v*` tag, or "Run workflow" with a version | signed APKs on a GitHub release |
| `release-notes.yml` | manual | re-syncs release notes from CHANGELOG.md |

## Versions

- The version comes from the git tag (`tool/version.sh`): `v1.2.0` → `1.2.0`. Builds between tags are
  `1.2.0-5-g1a2b3c4` and sort after `1.2.0`. `pubspec.yaml`'s version is only for local builds.
- A tag with a suffix (`v1.3.0-beta.1`) is published as a **pre-release**. Only people who turned on
  Settings → App version → Beta versions are offered it.
- Before tagging, add a `## 1.2.0` section to `CHANGELOG.md`. It becomes the release notes and is shown in the app.

## One-time setup

### 1. Create an upload keystore

Android only installs an update if it is signed with the **same key** as the installed app, so create one
key and keep it forever. Back up the `.jks` file and its passwords (password manager). If they are lost,
everyone has to uninstall to get new versions.

Run this **outside the repository** (keystores are git-ignored and gitleaks would flag them, but don't risk it):

```bash
keytool -genkeypair -v -keystore ~/keys/nux-upload.jks -keyalg RSA -keysize 4096 -validity 10000 -alias nux
```

`keytool` comes with any JDK. It asks for a keystore password, a name (anything) and a key password
(Enter reuses the keystore password).

### 2. Add repository secrets

Repo **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the `.jks` file, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | `nux` (the `-alias` above) |
| `ANDROID_KEY_PASSWORD` | key password |

With the GitHub CLI:

```bash
gh secret set ANDROID_KEYSTORE_BASE64 --body "$(base64 -w0 ~/keys/nux-upload.jks)"
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_ALIAS --body nux
gh secret set ANDROID_KEY_PASSWORD
```

PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\keys\nux-upload.jks")) | Set-Clipboard`.

Without these secrets the workflow still runs but signs with a throwaway debug key and warns. That is
fine for testing, not for releases: debug-signed APKs cannot update each other.

### 3. Local release builds (optional)

Create `android/key.properties` (git-ignored):

```properties
storeFile=/absolute/path/to/nux-upload.jks
storePassword=…
keyAlias=nux
keyPassword=…
```

## Publishing

```bash
git tag v0.1.0 && git push origin v0.1.0
```

or Actions → **Release APK** → Run workflow → version `0.1.0`. The workflow runs the tests and the secret scan,
builds a universal APK plus one per ABI (`arm64-v8a`, `armeabi-v7a`, `x86_64`) and publishes them.
The app picks the APK for its ABI.

**Don't push changes to `.github/workflows/` while a release runs.** The publish step creates the tag
with the workflow's `GITHUB_TOKEN`, and GitHub refuses (`HTTP 403: Resource not accessible by
integration`) a token without the `workflows` permission when the tagged commit's workflow files differ
from `main`. App changes are fine: the release tags the commit it built. If it happened, run the
release again from `main` (its workflows match), or push the tag yourself.

## F-Droid (later)

Build with `--dart-define=NUX_UPDATER=false`: the GitHub update check, the beta switch and the changelog
download disappear (the bundled changelog is still shown). See docs/PLAN.md §13.
