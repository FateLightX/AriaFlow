# AI Development Guide

This is the shortest entrypoint for a new AI working in this repository. Read
`AGENTS.md` first, then this guide, then the source file and every caller of
the symbol being changed.

## Repository Facts

- SwiftPM macOS app, SwiftUI + narrow AppKit hooks.
- Deployment macOS 14+; Xcode 26 / Swift 6.2.
- Universal arm64 + x86_64 executable and release bundle.
- Bundled `aria2-next` sidecars in `Sources/AriaFlow/Resources/`; system
  `aria2c` / `aria2-next` are fallback only.
- Local-only app: no accounts, cloud sync, or remote aria2 management.
- UI strings use Simplified Chinese as the source key, with English and
  zh-Hant translation tables in `Sources/AriaFlow/Resources/*.lproj`.

## Handoff Commands

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
git status -sb
swift test --disable-sandbox
scripts/verify_localizations.py
scripts/verify_release.sh
```

`scripts/verify_release.sh` runs unit tests, localization checks, universal
release build, packaging, code signing, zip checksum, sidecar RPC/download
smoke tests, and packaged-app download smoke tests. Do not claim a release
without a passing gate and a real artifact.

## Task Entrypoints

| Task | Start here |
| --- | --- |
| UI layout / labels / sheets | `Sources/AriaFlow/MainWindowViews.swift`, `SettingsViews.swift`, `AddTaskSheet.swift`, `TaskListViews.swift` |
| Task persistence / history | `Sources/AriaFlow/Persistence.swift`, `TaskModels.swift`, `AppStore.swift` |
| Engine lifecycle / auto recovery | `Sources/AriaFlow/EngineManager.swift`, `AppStore.swift` |
| JSON-RPC client | `Sources/AriaFlow/Aria2Client.swift` |
| Localization | `Sources/AriaFlow/Localization.swift`, `Sources/AriaFlow/Resources/*.lproj/Localizable.strings`, `scripts/verify_localizations.py` |
| Sidecar / GPL notices | `docs/SIDECAR.md`, `THIRD_PARTY_NOTICES.md`, `scripts/install_sidecar.sh` |
| Release preparation | `docs/RELEASE_CHECKLIST.md`, `update.json`, `.github/workflows/ci.yml` |

## Engine and RPC Boundaries

- `EngineManager` owns process discovery/launch. It writes
  `engine-runtime.conf` mode `0600` and passes it with `--conf-path`; never put
  the RPC secret on argv.
- `AppStore` owns connection state and polling. It tolerates transient poll
  failures, then enters recovery: local managed engine restarts on repeated
  RPC failure; remote RPC is never force-shutdown.
- `Aria2Client` is the only JSON-RPC layer. Keep RPC details out of views.
- Peer blocklists are URL-sourced, cached locally, validated, and reloaded
  through `aria2.changeGlobalOption`; failed reloads keep prior rules.

## Sidecar Upgrade

Download both macOS assets and the checksum file from the same upstream
[aria2-next](https://github.com/AnInsomniacy/aria2-next) release, verify
SHA-256, replace both files under `Sources/AriaFlow/Resources/`, then update
the About-window engine version, `docs/SIDECAR.md`, `THIRD_PARTY_NOTICES.md`,
and `CHANGELOG.md`. Never replace a sidecar without checksum and GPL source
records.

## Release Gate

Keep these aligned before tagging:

- `update.json`
- `APP_VERSION` / `BUILD_NUMBER` in `scripts/package_app.sh`
- `APP_VERSION` in `scripts/verify_release.sh`
- updater/About fallbacks in `Sources/AriaFlow/SoftwareUpdater.swift` and
  `Sources/AriaFlow/SettingsViews.swift`
- branch-build fallback in `.github/workflows/ci.yml`

Push `main`, then push `v<version>`. The tag workflow validates the release
manifest, runs the full gate, builds Universal / arm64 / x86_64 archives, and
publishes GitHub assets. Verify the published assets after the run.
