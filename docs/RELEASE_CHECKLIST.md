# AriaFlow Release Checklist

Use this checklist before sharing a build outside the development machine.

## Automated Verification

Run from the project root:

```bash
env HOME="$PWD/.build/home" \
  XDG_CACHE_HOME="$PWD/.build/cache" \
  CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" \
  scripts/verify_release.sh
```

Expected result:

- `dist/AriaFlow.app` exists.
- `dist/AriaFlow-0.1.0.zip` exists.
- `dist/AriaFlow-0.1.0.zip.sha256` verifies.
- Main executable reports `x86_64 arm64`.
- Both bundled sidecars exist and are executable.
- The app bundle contains `THIRD_PARTY_NOTICES.md` and `ThirdParty/aria2-next/COPYING`.
- Sidecar smoke download passes.
- Packaged app smoke download passes.

## Manual GUI Regression

Start the packaged app:

```bash
open dist/AriaFlow.app
```

Check:

- First launch connects to `aria2-next`, or shows a clear connection error with retry and settings entry.
- Empty task list shows the connected empty state.
- Add a small HTTP/HTTPS URL and confirm it appears in the task list.
- Pause and resume the active task.
- Delete the task without deleting local files.
- Add another small task and delete it with local files enabled; verify the delete summary.
- Add a torrent file and confirm the file selection sheet appears before download starts.
- Add a magnet link and confirm metadata waiting state, then file selection when metadata is available.
- Completed or failed tasks appear in History.
- History search, open location, copy location, and clear history work.
- Settings changes persist after closing and reopening the app.
- Settings -> Engine can retry connection, save session, open logs, and copy diagnostics.
- Menu bar item reflects speed when enabled and exposes show, new task, pause all, resume all, save session, clean results, and quit.
- Dock badge appears when active tasks exist and clears when no active tasks remain.
- Quit saves the aria2 session without hanging.

## Apple Silicon Check

On an Apple Silicon Mac:

```bash
lipo -info dist/AriaFlow.app/Contents/MacOS/AriaFlow
file dist/AriaFlow.app/Contents/Resources/motrix-next-engine-aarch64-apple-darwin
open dist/AriaFlow.app
```

Confirm Settings -> Engine reports a bundled sidecar and downloads work.

## Distribution Check

For the `v0.1.0` public developer build:

- Confirm the GitHub Release ZIP and `.sha256` file are uploaded together.
- Confirm the release notes say the archive is ad-hoc signed and not notarized.
- Confirm `THIRD_PARTY_NOTICES.md` and the aria2-next `COPYING` file are attached to the release.

For a future notarized build:

- Sign with `SIGN_IDENTITY="Developer ID Application: ..."` when running `scripts/package_app.sh`.
- Notarize with `NOTARY_PROFILE=...`.
- Confirm Gatekeeper accepts the ZIP on a clean macOS user account.
- Keep the `.zip.sha256` file with the uploaded ZIP.
