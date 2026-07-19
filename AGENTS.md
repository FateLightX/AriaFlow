# AriaFlow Agent Context

## Start Here

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
git status -sb
git diff --stat
```

Read in order:

1. This file (ownership + invariants)
2. `docs/ARCHITECTURE.md` for modules and data flow
3. `docs/SIDECAR.md` only when changing the engine binary or launch args
4. `CHANGELOG.md` for recent user-visible behavior
5. The source file and every caller of the symbol being changed

Code and tests are authoritative. Do not recreate removed PRD, prototype, progress, or optimization narrative documents.

## Project Facts

- SwiftPM macOS app: SwiftUI + narrow AppKit hooks
- Deployment: macOS 14+; Liquid Glass on macOS 26
- Toolchain: Xcode 26 / Swift 6.2
- UI language: Simplified Chinese
- Universal arm64 + x86_64 executable and release bundle
- Download engine: bundled Aria2 Next 2.5.1 over local JSON-RPC
- System `aria2c` / `aria2-next` are fallback only
- Local-only app: no accounts, cloud sync, or remote aria2 management

## Ownership

| Area | Files |
| --- | --- |
| Scenes / lifecycle | `AriaFlowApp.swift`, `AppDelegate.swift`, `AppPresentation.swift` |
| UI only | `MainWindowViews.swift`, `TaskListViews.swift`, `*Sheet.swift`, `SettingsViews.swift`, `MenuBarViews.swift` |
| Persistence / models | `Persistence.swift`, `TaskModels.swift`, `AppSettings.swift` |
| Orchestration | `AppStore.swift` |
| RPC | `Aria2Client.swift` |
| Engine process | `EngineManager.swift` |
| macOS integrations | `DockService.swift`, `NotificationService.swift`, `LoginItemService.swift` |
| Packaging / smoke | `scripts/`, `SmokeDownloadRunner.swift` |
| Tests | `Tests/` |

## Invariants

- `AppStore` is `@MainActor` and owns shared UI/application state
- Keep JSON-RPC details out of views
- New `AppSettings` fields must use `decodeIfPresent` defaults
- Settings and history disk writes are debounced (400ms) and must flush on app termination
- RPC is localhost-only; never log or document live secrets
- Managed engine writes `rpc-secret` into `engine-runtime.conf` mode `0600` via `--conf-path`; do not put secrets on process argv
- Default TLS check-certificate on; `rpc-allow-origin-all=false`
- Window activation and Dock policy live only in `AppPresentation` (hide-Dock stays `.accessory` with windows open)
- Do not pass Aria2 Next-only flags to system fallback engines
- Peer blocklists are URL-sourced, cached locally; failed reloads keep prior rules
- Sidecar replacement needs both upstream checksums, source URL, and GPL notice updates
- Preserve arm64 / x86_64 resource names used by packaging scripts
- Preserve unrelated user changes in a dirty worktree

## Out of scope (unless explicitly requested)

- Shared Core / monorepo with AriaLite
- New product features (detail panel, multi-select, remote management, etc.)
- Developer ID notarization

## Verification

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test --disable-sandbox          # normal code changes
scripts/verify_release.sh             # engine, resources, downloads, persistence, packaging
```

Expected release outputs:

```text
dist/AriaFlow.app
dist/AriaFlow-<version>.zip
dist/AriaFlow-<version>.zip.sha256
```

Do not commit `dist/`, `.build/`, local app data, RPC secrets, certificates, or notarization credentials.

## Documentation Map

| Doc | Purpose |
| --- | --- |
| `README.md` | End-user install and feature summary |
| `docs/ARCHITECTURE.md` | Modules, runtime, persistence, UI, extension rules |
| `docs/SIDECAR.md` | Engine binaries, launch contract, peer blocklist |
| `docs/RELEASE_CHECKLIST.md` | Automated + manual release gate |
| `CHANGELOG.md` | Version history (user-visible) |
| `THIRD_PARTY_NOTICES.md` | Bundled binary provenance |
| `CONTRIBUTING.md` / `SECURITY.md` | External contribution and security reporting |
| `AGENTS.md` | This file |

Update only the smallest relevant document. Prefer code + tests over long narrative docs.
