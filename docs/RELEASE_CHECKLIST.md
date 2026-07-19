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
