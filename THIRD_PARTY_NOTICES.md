# Third-Party Notices

## aria2-next 3.0.6

AriaFlow bundles prebuilt `aria2-next` executables as separate local download-engine components:

- `Sources/AriaFlow/Resources/motrix-next-engine-aarch64-apple-darwin`
- `Sources/AriaFlow/Resources/motrix-next-engine-x86_64-apple-darwin`

Upstream project: <https://github.com/AnInsomniacy/aria2-next><br>
Upstream release: <https://github.com/AnInsomniacy/aria2-next/releases/tag/v3.0.6><br>
Corresponding source: <https://github.com/AnInsomniacy/aria2-next/archive/refs/tags/v3.0.6.tar.gz>

The sidecars are licensed under GNU General Public License version 2. The complete GPL-2.0 text is included at [third_party/aria2-next/COPYING](third_party/aria2-next/COPYING). AriaFlow's Swift source is independently licensed under the MIT License; it communicates with the engine over local JSON-RPC and does not link against the engine.

### Bundled Asset Record

| Architecture | Upstream release asset | SHA-256 |
| --- | --- | --- |
| Apple Silicon | `aria2-next-3.0.6-macos-arm64` | `ab8c82eff8e62cb1ce07eb9bd2ed14cede0c51d6c073972eaecd22d411fd7fc8` |
| Intel | `aria2-next-3.0.6-macos-x86_64` | `c276d94a50c24afebf9aaf7ce013db17428404443f9d70fb3c5adde1182a8f74` |

### Replacing A Sidecar

1. Download the matching upstream release asset and its published checksum file.
2. Verify the asset checksum before installation.
3. Install it with `scripts/install_sidecar.sh --arch arm64 <asset>` or `scripts/install_sidecar.sh --arch x86_64 <asset>`.
4. Update this notice with version, URLs, asset names, and SHA-256 values.
5. Run `scripts/verify_release.sh` before committing the replacement.

The generated application archive retains these notices through the repository source and GitHub Release attachments. Distributors must preserve the GPL notice and make the corresponding upstream source available with the sidecar distribution.
