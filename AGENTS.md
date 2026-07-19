# AriaFlow Agent Context

## Start Here

Before changing anything:

```bash
git status -sb
git diff --stat
```

Then read:

1. `docs/ARCHITECTURE.md` for module ownership and data flow.
2. `CHANGELOG.md` for unreleased behavior.
3. The nearest source file and every caller of the symbol being changed.

Code and tests are authoritative. Do not reconstruct removed PRD, prototype or progress documents.

## Project Facts

- SwiftPM macOS app using SwiftUI with narrow AppKit hooks.
- Deployment target: macOS 14.
- Release toolchain: Xcode 26 / Swift 6.2.
- UI language: Simplified Chinese.
- Main executable and release bundle are Universal arm64 + x86_64.
- Download engine: bundled Aria2 Next 2.5.1 over local JSON-RPC.
- System `aria2c` / `aria2-next` paths are fallback only.
- The app is local-only: no accounts, cloud sync or remote aria2 management.

## Ownership

- `AriaFlowApp.swift`, `AppDelegate.swift`, `AppPresentation.swift`: scenes, lifecycle and window activation.
- `Views.swift`, `MenuBarViews.swift`: UI only; bind state and trigger actions.
- `Models.swift`: `AppStore`, persistence and application orchestration.
- `Aria2Client.swift`: JSON-RPC methods and transport.
- `EngineManager.swift`: executable discovery, launch arguments, logs and peer-blocklist validation.
- `DockService.swift`, `NotificationService.swift`, `LoginItemService.swift`: macOS integrations.
- `scripts/`: packaging and executable smoke tests.
- `Tests/`: focused parser and persistence compatibility tests.

## Invariants

- `AppStore` is `@MainActor` and owns shared UI/application state.
- Keep JSON-RPC details out of views.
- New `AppSettings` fields must use `decodeIfPresent` defaults.
- Keep RPC bound to localhost; never expose secrets in logs or documentation.
- Keep window activation and Dock policy in `AppPresentation`.
- Do not pass Aria2 Next-only launch flags to system fallback engines.
- Sidecar replacement requires both upstream checksums, source URL and GPL notice updates.
- Preserve arm64 and x86_64 resource names; packaging scripts depend on them.
- Peer blocklists are URL-sourced and cached as local files for the engine; failed reloads must keep prior active rules.
- Preserve unrelated user changes in a dirty worktree.

## Verification

Use the Xcode toolchain explicitly; the active Command Line Tools may be older.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/verify_release.sh
```

Run `swift test` for normal code changes. Run full release verification for engine, resources, downloads, persistence or packaging changes.

Expected release outputs:

```text
dist/AriaFlow.app
dist/AriaFlow-<version>.zip
dist/AriaFlow-<version>.zip.sha256
```

Do not commit `dist/`, `.build/`, local app data, RPC secrets, certificates or notarization credentials.

## Documentation

- `docs/ARCHITECTURE.md`: current module and runtime design.
- `docs/SIDECAR.md`: engine replacement and launch contract.
- `docs/RELEASE_CHECKLIST.md`: release gate.
- `THIRD_PARTY_NOTICES.md`: bundled binary provenance.
- `CHANGELOG.md`: release history and pending user-visible changes.

Update only the smallest relevant document. Avoid narrative status logs and duplicated specifications.
