# Sidecar

AriaFlow ships `aria2-next 2.5.1` for arm64 and x86_64. Source URLs, licenses and SHA-256 values are recorded in [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

## Resource Names

| Architecture | Resource |
| --- | --- |
| arm64 | `Sources/AriaFlow/Resources/motrix-next-engine-aarch64-apple-darwin` |
| x86_64 | `Sources/AriaFlow/Resources/motrix-next-engine-x86_64-apple-darwin` |

`EngineManager` selects the current architecture's bundled resource before checking system `aria2c` and `aria2-next` paths.

## Replace Binaries

Download both macOS assets and the checksum file from the same upstream release:

```bash
shasum -a 256 -c aria2-next-<version>-checksums.sha256
scripts/install_sidecar.sh --arch arm64 aria2-next-<version>-macos-arm64
scripts/install_sidecar.sh --arch x86_64 aria2-next-<version>-macos-x86_64
```

Then update:

- About-window engine version
- `THIRD_PARTY_NOTICES.md` release URL, source URL and both hashes
- `CHANGELOG.md`

Do not replace binaries without the upstream checksum and GPL source record.

## Launch Contract

Runtime arguments are assembled in `EngineManager.startIfNeeded()`:

- local-only JSON-RPC port and optional secret
- download directory and concurrency limits
- session input/save paths
- `info` log level
- bundled `aria2.conf`
- validated `bt-peer-blocklist` path when configured

Aria2 Next owns log rotation. Defaults are 10 MB per file and four files.

## Peer Blocklist

Settings store a blocklist **URL** (`http` / `https` only). AriaFlow downloads the list into Application Support (`bt-peer-blocklist.txt`), validates it, and passes the **local cache path** to the bundled engine. Local file paths and `file://` URLs are not accepted.

The downloaded text format is one IPv4, IPv6 or CIDR rule per line. Empty lines and lines beginning with `#` are ignored.

AriaFlow:

1. downloads remote lists with `PeerBlocklistFile.materialize` (atomic cache replace);
2. validates rules before replacing the previous cache;
3. passes the cache path at bundled-engine startup when present;
4. reloads or clears through `aria2.changeGlobalOption`;
5. keeps the previous active engine rules when a reload fails.

There is no scheduled refresh; use **重新加载** to re-download. Smoke tests seed the cache file and set a placeholder `https` URL.

## Verification

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/verify_release.sh
```

The verification script checks the Universal app, both sidecars, signing, archive checksum, peer-blocklist RPC behavior and local downloads.
