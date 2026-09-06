# Changelog

## 0.4.10 - 2026-09-06

- Updated bundled `aria2-next` sidecars to 2.7.0 (arm64 and x86_64).

## 0.4.9 - 2026-08-30

- Updated bundled `aria2-next` sidecars to 2.6.8 (arm64 and x86_64).

## 0.4.8 - 2026-08-28

- Updated bundled `aria2-next` sidecars to 2.6.7 (arm64 and x86_64).

## 0.4.7 - 2026-08-27

- Updated bundled `aria2-next` sidecars to 2.6.5 (arm64 and x86_64).

## 0.4.6 - 2026-08-26

- Updated bundled `aria2-next` sidecars to 2.6.2 (arm64 and x86_64).

## 0.4.5 - 2026-08-25

- Updated bundled `aria2-next` sidecars to 2.6.0 (arm64 and x86_64).

## 0.4.4 - 2026-08-24

- 修复 aria2-next 引擎写入用户主目录 `~/.aria2-next` 的问题，DHT/状态数据迁移到 App Support 下。

## 0.4.3 - 2026-08-24

- Updated bundled `aria2-next` sidecars to 2.5.7 (arm64 and x86_64).

## 0.4.2 - 2026-08-22

- Updated bundled `aria2-next` sidecars to 2.5.6 (arm64 and x86_64).

## 0.4.1 - 2026-08-12

- 修复 RPC 地址构造、连接恢复与设置重置生命周期问题。
- 收紧 RPC Secret 文件权限，并避免无精确文件列表时删除下载目录。
- 修正公证 stapled ticket 流程与发布门禁校验。

All notable changes to AriaFlow are documented in this file.

## 0.4.0 - 2026-08-11

### Changed

- Updated bundled `aria2-next` sidecars from 2.5.2 to 2.5.5.
- Automatic engine recovery now restarts the local managed engine when RPC is
  unresponsive, so downloads resume without a manual restart.
- Added AI continuation guidance in `docs/AI_DEVELOPMENT.md`.

### Added

- Added automatic Simplified Chinese and English UI localization. Chinese
  system languages use Chinese; all other languages fall back to English.

## 0.3.5 - 2026-07-30

### Changed

- Replaced manual login-item setup with an in-app toggle backed by the macOS
  Service Management API, with a System Settings link when approval is needed.
- Architecture-specific ZIPs now extract to `AriaFlow.app` instead of adding the
  CPU architecture to the app bundle name.

## 0.3.4 - 2026-07-29

### Added

- Added automatic software updates when network access becomes available, with
  SHA256, code-signature, bundle-ID, version, and CPU-architecture validation.
- Added updater status and a manual check action to the About page.
- Added a fastly.jsdelivr.net update-manifest fallback when the official GitHub
  Releases API cannot be reached.

### Changed

- Updated bundled `aria2-next` sidecars from 2.5.1 to 2.5.2.
- Added separate Apple Silicon and Intel release packages while preserving the
  Universal package for compatibility.

## 0.3.3 - 2026-07-20

### Fixed

- HTTPS downloads failed with “unable to get local issuer certificate” after enabling TLS verification. The managed engine now loads the macOS CA bundle (`/etc/ssl/cert.pem`) via `ca-certificate`.

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
