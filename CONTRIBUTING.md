# Contributing to AriaFlow

## Development

- Require macOS 26 and Xcode 26 or a compatible Swift 6.2 toolchain.
- Run `swift build --disable-sandbox` before opening a pull request.
- Run `scripts/verify_release.sh` for changes that affect packaging, resources, or download behavior.
- Keep UI copy consistent with the existing Simplified Chinese interface and document user-facing behavior in English.

## Pull Requests

- Keep each pull request focused and include the behavior being changed.
- Do not commit `dist/`, `.build/`, user settings, session data, RPC secrets, signing certificates, or notarization credentials.
- Update tests and release documentation when changing packaging, bundled sidecars, or supported platforms.

## Bundled Engine

Changes to either bundled `aria2-next` sidecar must update `THIRD_PARTY_NOTICES.md`, the corresponding source record, and both SHA-256 values. Do not replace a sidecar without verifying its upstream release checksum.
