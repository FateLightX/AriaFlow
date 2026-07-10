# AriaFlow Sidecar

AriaFlow can run with a bundled aria2-compatible executable or fall back to a system `aria2c`.

## Install A Sidecar

AriaFlow v1 uses prebuilt binaries from:

https://github.com/AnInsomniacy/aria2-next/releases

The bundled `aria2-next 2.4.9` sidecars are GPL-2.0 components. Their source URL, local SHA-256 values, and the GPL text are recorded in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md). Preserve those files when redistributing a packaged app.

Use the macOS assets for both CPU architectures when building the release app:

- Apple Silicon: `aria2-next-<version>-macos-arm64`
- Intel: `aria2-next-<version>-macos-x86_64`

Download `aria2-next-<version>-checksums.sha256` from the same release and verify the binary before packaging.

Copy a local aria2 executable into the SwiftPM resource directory:

```bash
scripts/install_sidecar.sh /path/to/aria2c
```

Install a specific architecture from a downloaded release asset:

```bash
scripts/install_sidecar.sh --arch arm64 /path/to/aria2-next-<version>-macos-arm64
scripts/install_sidecar.sh --arch x86_64 /path/to/aria2-next-<version>-macos-x86_64
```

If `aria2c` is already on `PATH`, the script can be run without arguments:

```bash
scripts/install_sidecar.sh
```

The script writes the executable to:

- Apple Silicon: `Sources/AriaFlow/Resources/motrix-next-engine-aarch64-apple-darwin`
- Intel: `Sources/AriaFlow/Resources/motrix-next-engine-x86_64-apple-darwin`

Then rebuild the app:

```bash
scripts/package_app.sh
```

`scripts/package_app.sh` builds a universal macOS executable by default. For a faster current-architecture-only local package, run:

```bash
UNIVERSAL=0 scripts/package_app.sh
```

## Verify

Open Settings -> Engine. `引擎来源` should show `随包 sidecar`.

The packaged executable will be copied to:

```text
dist/AriaFlow.app/Contents/Resources/
```

Verify the app binary and bundled sidecars:

```bash
lipo -info dist/AriaFlow.app/Contents/MacOS/AriaFlow
file dist/AriaFlow.app/Contents/Resources/motrix-next-engine-aarch64-apple-darwin
file dist/AriaFlow.app/Contents/Resources/motrix-next-engine-x86_64-apple-darwin
```

Run the local sidecar download smoke test:

```bash
scripts/smoke_sidecar_download.sh
```

Run the packaged app download smoke test:

```bash
scripts/smoke_app_download.sh
```

Both smoke tests start local TCP listeners. Run them from a normal macOS terminal; restricted sandboxes may block local listeners and report that explicitly.

## Current Fallback

If no bundled sidecar is present, AriaFlow searches these system paths:

- `/opt/homebrew/bin/aria2c`
- `/usr/local/bin/aria2c`
- `/usr/bin/aria2c`
- `/opt/homebrew/bin/aria2-next`
- `/usr/local/bin/aria2-next`
