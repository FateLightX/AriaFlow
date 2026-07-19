# Changelog

All notable changes to AriaFlow are documented in this file.

## 0.3.2 - 2026-07-20

### Changed

- Debounce settings and history disk writes (400ms) and flush on app termination.
- Compress README assets (`AppIcon.png` 1024→256, screenshot palette/optimized PNG).
- Split oversized `Models.swift` / `Views.swift` into focused source files (persistence, task models, settings, store, window/list/sheets/settings views).
- Poll slower when idle; tolerate brief RPC failures before disconnecting.
- Paginate waiting/stopped task lists (up to 2000) and show a status-bar truncation hint.
- Keep selection stable when a task disappears instead of jumping to the first row.
- Infer HTTP/Magnet/ED2K/FTP/BT protocol labels; surface real error/source detail.
- Notify only on complete/fail (no “任务开始” spam).
- Default TLS certificate verification on; tighten RPC origin; keep RPC secret in a 0600 runtime conf (not process argv).
- Align packaging resource layout handling and CI default version.

### Fixed

- Removed dead mock `updateSelectedStatus` helper.

## 0.3.1 - 2026-07-19

### Changed

- When “隐藏 Dock 图标” is on, the Dock stays hidden even while main/settings windows are open.
- Settings toggle label simplified to “隐藏 Dock 图标”.

## 0.3.0 - 2026-07-19

### Changed

- Settings window height now fits each tab's content (no scrollbar / fixed 360 height).
- BT Peer Blocklist is link-only (http/https): download, validate, cache locally, then apply to the engine. Local file import is removed.

## 0.2.0 - 2026-07-15

### Added

- Added local BitTorrent peer blocklist selection, validation, runtime reload, and clearing.

### Changed

- Updated bundled `aria2-next` sidecars from 2.4.9 to 2.5.1.
- Updated the engine log level to the 2.5.x-compatible `info` value.
- Consolidated developer documentation around architecture, sidecar, release, and agent recovery context.

### Fixed

- Activated the Settings window correctly on macOS 15.
- Prevented the main window from flashing when launching in menu-bar mode.
- Restored native Command-drag repositioning for the menu-bar item.

## 0.1.1 - 2026-07-11

### Changed

- Lowered the deployment target to macOS 14.
- Kept Liquid Glass controls on macOS 26 and added standard material/button fallbacks for macOS 14 and 15.

### Fixed

- Preserved menu-bar launch behavior without relying on macOS 15-only scene APIs.
- Disabled main-window state restoration through the cross-version AppKit window path.

### Known Limitations

- Archives use ad-hoc signing and are not notarized; Gatekeeper may require explicit user confirmation.

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
