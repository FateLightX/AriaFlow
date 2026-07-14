# Contributing

## Requirements

- macOS 14+
- Xcode 26 or Swift 6.2-compatible toolchain

Read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) before changing module ownership or engine lifecycle.

## Checks

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/verify_release.sh
```

Run full release verification for changes to engine behavior, resources, persistence, downloads or packaging.

## Pull Requests

- Keep changes focused.
- Add tests or smoke assertions for non-trivial behavior.
- Do not commit `dist/`, `.build/`, user data, secrets, certificates or notarization credentials.
- Sidecar changes must update `THIRD_PARTY_NOTICES.md`, both SHA-256 values and the upstream source record.
