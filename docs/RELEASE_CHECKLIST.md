# Release Checklist

## Automated

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  scripts/verify_release.sh
```

Required results:

- Universal `x86_64 arm64` app
- executable arm64 and x86_64 sidecars
- valid `Info.plist` and code signature
- valid ZIP SHA-256
- bundled third-party notices and GPL text
- passing peer-blocklist, sidecar download and packaged-app download smoke tests

Artifacts:

```text
dist/AriaFlow.app
dist/AriaFlow-<version>.zip
dist/AriaFlow-<version>.zip.sha256
```

Architecture-specific builds:

```bash
ARCH=arm64 scripts/package_app.sh
ARCH=x86_64 scripts/package_app.sh
```

These produce `AriaFlow-<version>-arm64.zip` and
`AriaFlow-<version>-x86_64.zip` with only the matching sidecar. Both archives
extract to `AriaFlow.app`; the architecture suffix belongs only to the ZIP name.

## Version and Publish

Before tagging, keep the release version aligned in:

- `CHANGELOG.md` and `update.json`
- `APP_VERSION` / `BUILD_NUMBER` in `scripts/package_app.sh`
- `APP_VERSION` in `scripts/verify_release.sh`
- updater and About fallbacks in `SoftwareUpdater.swift` / `SettingsViews.swift`
- the branch-build fallback in `.github/workflows/ci.yml`

Push `main`, then push `v<version>`. The tag workflow validates `update.json`,
runs the release gate, builds Universal / arm64 / x86_64 ZIPs, and creates or
updates the GitHub Release with checksums and notices. Use `gh run watch` and
verify the published asset list before announcing the release.

## Manual

- Launch the packaged app on macOS 14 or 15.
- Verify main-window and menu-bar launch modes.
- Add, pause, resume and delete an HTTP task.
- Verify torrent/magnet file selection.
- Verify settings persistence and peer-blocklist URL add/reload/clear.
- Verify history, Dock badge and menu-bar actions.
- On Apple Silicon, confirm the arm64 sidecar is selected.

## Distribution

- Upload the ZIP and matching checksum together.
- Preserve `THIRD_PARTY_NOTICES.md` and `third_party/aria2-next/COPYING`.
- State whether the build is ad-hoc signed or notarized.
- For notarization, set `SIGN_IDENTITY` and `NOTARY_PROFILE` when running `scripts/package_app.sh`.
