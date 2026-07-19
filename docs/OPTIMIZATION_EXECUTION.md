# Optimization Execution Log

Date: 2026-07-20  
Scope: AriaFlow 0.3.1 → **0.3.2**  
Source plan: dual-app review (reliability / security / engineering)

## Goals completed

| Item | Status | Notes |
| --- | --- | --- |
| Remove dead mock selection helper | Done | Deleted `updateSelectedStatus` (`8.4 MB/s` fake speeds) |
| Task list pagination | Done | Waiting/stopped fetched in pages of 100, max 20 pages (~2000) |
| Truncation UX | Done | Status bar shows “列表过长已截断” when capped |
| Soft poll failures | Done | 3 consecutive poll failures required to mark disconnected |
| Adaptive poll interval | Done | 2s with active downloads, 5s when idle |
| Stable selection | Done | Missing gid clears selection; no jump to first row |
| Protocol / detail mapping | Done | HTTP/Magnet/ED2K/FTP/BT + error/source detail |
| Quieter notifications | Done | Complete/fail only |
| Certificate verification default | Done | `check-certificate=true` (conf + launch args) |
| RPC origin tighten | Done | `rpc-allow-origin-all=false` |
| RPC secret off argv | Done | Written into `engine-runtime.conf` mode `0600` |
| Packaging alignment | Done | `DEVELOPER_DIR` default + nested Resources flatten |
| CI default version | Done | Non-tag default `0.3.2` |
| Tests | Done | `TaskMappingTests` for protocol/detail/status |
| Execution document | Done | This file |

## Deferred (documented, not in this drop)

- Shared Swift package / monorepo for AriaFlow + AriaLite core
- Full `Models.swift` / `Views.swift` file split
- Notarized Developer ID distribution
- Settings disk-write debouncing on every `@Published` mutation
- Compress README AppIcon assets

## Key code touchpoints

- `Sources/AriaFlow/Models.swift` — polling, pagination, selection, mapping, notifications
- `Sources/AriaFlow/EngineManager.swift` — runtime conf + certificate defaults
- `Sources/AriaFlow/Resources/aria2.conf` — safer defaults
- `Sources/AriaFlow/Views.swift` — truncation hint, Dock help text
- `scripts/package_app.sh`, `scripts/verify_release.sh`, `.github/workflows/ci.yml`
- `Tests/AriaFlowTests/TaskMappingTests.swift`

## Verification

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test --disable-sandbox
# optional release gate:
scripts/verify_release.sh
```

## Follow-ups

1. Monitor user reports of TLS failures on self-signed download hosts; consider a settings toggle if needed.
2. Shared core package with AriaLite once both trees stabilize on this behavior.
3. Notarization when distribution audience expands beyond ad-hoc installs.


## Follow-up: Models/Views file split (2026-07-20)

Completed a pure structural split (no behavior change):

### Models
- `Persistence.swift` — app support paths, JSON, RPC secret
- `TaskModels.swift` — filters, statuses, download task types
- `AppSettings.swift` — persisted preferences
- `AppStore.swift` — orchestration (kept as one file: Swift `private` is file-scoped)

### Views
- `MainWindowViews.swift` — window chrome / navigation shell
- `TaskListViews.swift` — lists, rows, status bar
- `AddTaskSheet.swift`, `DeleteConfirmationSheet.swift` (+ `FileSelectionSheet.swift` on AriaFlow)
- `SettingsViews.swift` — settings tabs

`AppStore` remains large by design until helpers are intentionally promoted from `private` for extension-based splits.
