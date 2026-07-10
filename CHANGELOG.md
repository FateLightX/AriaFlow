# Changelog

All notable changes to AriaFlow are documented in this file.

## 0.1.0 - 2026-07-11

### Added

- Native SwiftUI macOS download manager with URL, magnet, ED2K, and torrent tasks.
- Bundled universal `aria2-next 2.4.9` engine sidecars for Apple Silicon and Intel Macs.
- Queue controls, task actions, history, menu bar status, Dock progress, and configurable download settings.
- Release packaging, checksum generation, local smoke tests, and GitHub release automation.

### Known Limitations

- Requires macOS 26 or later.
- `v0.1.0` archives use ad-hoc signing and are not notarized; Gatekeeper may require an explicit user confirmation.
- AriaFlow is local-only and does not manage remote aria2 instances, accounts, cloud sync, or browser extensions.
