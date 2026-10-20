# Third-Party Notices

## aria2-next 3.0.8

AriaFlow bundles prebuilt `aria2-next` executables as separate local download-engine components:

- `Sources/AriaFlow/Resources/motrix-next-engine-aarch64-apple-darwin`
- `Sources/AriaFlow/Resources/motrix-next-engine-x86_64-apple-darwin`

Upstream project: <https://github.com/AnInsomniacy/aria2-next><br>
Upstream release: <https://github.com/AnInsomniacy/aria2-next/releases/tag/v3.0.8><br>
Corresponding source: <https://github.com/AnInsomniacy/aria2-next/archive/refs/tags/v3.0.8.tar.gz>

The sidecars are licensed under GNU General Public License version 2. The complete GPL-2.0 text is included at [third_party/aria2-next/COPYING](third_party/aria2-next/COPYING). AriaFlow's Swift source is independently licensed under the MIT License; it communicates with the engine over local JSON-RPC and does not link against the engine.

### Bundled Asset Record

| Architecture | Upstream release asset | SHA-256 |
| --- | --- | --- |
| Apple Silicon | `aria2-next-3.0.8-macos-arm64` | `9404fbbe68f5e888a435e14b917d95b94c7acba0d4f8a4ff2451a5110b62f66e` |
| Intel | `aria2-next-3.0.8-macos-x86_64` | `037eadd8d8feae4dad371bde215bfc47e3a6b7ab0714612a4c1b6bf90240c0bb` |

### Replacing A Sidecar

1. Download the matching upstream release asset and its published checksum file.
2. Verify the asset checksum before installation.
3. Install it with `scripts/install_sidecar.sh --arch arm64 <asset>` or `scripts/install_sidecar.sh --arch x86_64 <asset>`.
4. Update this notice with version, URLs, asset names, and SHA-256 values.
5. Run `scripts/verify_release.sh` before committing the replacement.

The generated application archive retains these notices through the repository source and GitHub Release attachments. Distributors must preserve the GPL notice and make the corresponding upstream source available with the sidecar distribution.
