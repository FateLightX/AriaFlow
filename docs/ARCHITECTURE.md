# AriaFlow Architecture

## Runtime

AriaFlow is a SwiftPM macOS 14+ executable using SwiftUI and AppKit.

```text
SwiftUI views
    │
    ▼
AppStore ──────► Dock / notifications / local persistence
    │
    ▼
Aria2Client ───► local JSON-RPC
    │
    ▼
EngineManager ─► bundled aria2-next or system aria2
```

`AppStore` is the application state owner. Views mutate it directly or start short `Task` blocks for RPC operations.

## Source Modules

| Module | Responsibility |
| --- | --- |
| `AriaFlowApp.swift` | Scene declarations, commands, settings and menu bar entry points |
| `AppDelegate.swift` | Application lifecycle, file/URL opening and status-item events |
| `AppPresentation.swift` | Activation policy and main/settings window visibility |
| `Views.swift` | Main window, task/history views, sheets and settings |
| `MenuBarViews.swift` | Menu bar label, menu actions and startup bootstrap |
| `Models.swift` | `AppStore`, persisted settings, task/history models and orchestration |
| `Aria2Client.swift` | Typed JSON-RPC request and response layer |
| `EngineManager.swift` | Engine discovery, process launch, logs and peer blocklist validation |
| `DockService.swift` | Dock badge and aggregate progress |
| `NotificationService.swift` | Download state notifications |
| `LoginItemService.swift` | System Settings login-item navigation and legacy cleanup |
| `SmokeDownloadRunner.swift` | Headless packaged-app download verification |

## State and Persistence

Application data lives under `~/Library/Application Support/AriaFlow` unless `ARIAFLOW_APP_SUPPORT_DIR` overrides it.

| File | Contents |
| --- | --- |
| `settings.json` | `AppSettings`, excluding the RPC secret |
| `rpc-secret.txt` | Local RPC secret |
| `history.json` | Completed and removed task history |
| `download.session` | aria2 session state |
| `aria2-next.log` | Engine log with bounded rotation |

`AppSettings` uses backward-compatible `decodeIfPresent` defaults. New persisted fields must do the same.

## Engine Lifecycle

1. `AriaFlowMenuBarLabel` configures `AppDelegate` and starts automatic connection.
2. `AppStore.retryEngineConnection()` connects to the configured RPC port or starts an engine.
3. `EngineManager` searches bundled resources first, then known system paths.
4. The bundled engine receives RPC, download, session, logging and optional peer-blocklist arguments.
5. `AppStore` polls global stats and task lists while connected.
6. Shutdown saves the session when possible and terminates the managed process.

Bundled executable names:

- `motrix-next-engine-aarch64-apple-darwin`
- `motrix-next-engine-x86_64-apple-darwin`

System fallback paths are defined in `EngineManager.findSystemExecutable()`.

## Data Flows

### URL task

`AddTaskSheet` → `AppStore.addURLTask()` → `aria2.addUri` → task refresh.

Magnet tasks start paused until metadata and file selection are available.

### Torrent task

Torrent file bytes → Base64 → `aria2.addTorrent` with `pause=true` → file selection → `aria2.changeOption(select-file)` → unpause.

### Engine settings

- Runtime-compatible limits use `aria2.changeGlobalOption`.
- RPC port and secret changes restart the engine.
- Peer blocklists are validated locally, loaded at bundled-engine startup and reloaded with `aria2.changeGlobalOption`.

## UI Structure

- Main scene: sidebar filters, task/history content and status bar.
- Sheets: add task, torrent file selection and delete confirmation.
- Settings scene: general, downloads, engine and about tabs.
- Menu bar extra: window access, queue actions, speeds and quit.

Window activation and Dock visibility must remain centralized in `AppPresentation`.

## Scripts

| Script | Purpose |
| --- | --- |
| `install_sidecar.sh` | Install one architecture's verified engine binary |
| `package_app.sh` | Build, bundle, sign and archive the Universal app |
| `verify_release.sh` | Run the complete automated release gate |
| `smoke_sidecar_download.sh` | Verify engine RPC, peer blocklist and download behavior |
| `smoke_app_download.sh` | Verify packaged-app engine startup and download behavior |

## Extension Rules

- Add RPC methods in `Aria2Client`; keep transport details out of views.
- Add persisted preferences to `AppSettings` with decode defaults.
- Put engine arguments and executable discovery in `EngineManager`.
- Keep application orchestration in `AppStore`; views should only bind state and trigger actions.
- Update `THIRD_PARTY_NOTICES.md` and both checksums when replacing sidecars.
- Add one focused test or smoke assertion for non-trivial parsing, state or RPC behavior.

## Build and Verification

Use Xcode 26 or a Swift 6.2-compatible toolchain.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/verify_release.sh
```

`verify_release.sh` builds the Universal app, validates architecture and signing, verifies the ZIP checksum, and runs sidecar and packaged-app smoke tests.
