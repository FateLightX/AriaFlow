# AriaFlow 开发进度

更新时间：2026-07-10

## 当前阶段

项目处于 macOS 原生客户端 v1 可打包 MVP 验证阶段。

当前重点是先完成本机单用户核心闭环，并把本地分发包做到可独立启动下载引擎：

- 主窗口任务管理 UI。
- 设置窗口。
- 本地设置和历史持久化。
- aria2 JSON-RPC 客户端。
- 真实 aria2 任务读取。

暂不做浏览器扩展、账号、云同步、主题系统、远程 aria2 管理和跨平台支持。

## 已完成

### 文档

- `docs/PRD.md`：第一版产品需求文档。
- `docs/UI_PROTOTYPE.md`：整体 UI Markdown 线框。
- `docs/PROGRESS.md`：当前开发进度文档。
- `docs/SIDECAR.md`：sidecar 安装和验证说明。

### 项目基础

- 使用 SwiftPM 初始化 macOS SwiftUI 应用。
- macOS 目标版本：macOS 26。
- 项目已可通过 `swift build` 编译。
- 未引入第三方 Swift 依赖。
- SwiftPM 已配置 `Sources/AriaFlow/Resources` 资源目录，用于放置 sidecar 和默认配置。
- 已新增黑金风格自定义 macOS App Icon，`AppIcon.icns` 随包进入 `Contents/Resources`，源图保存在 `docs/assets/AppIcon.png`。
- 已新增 `scripts/generate_app_icon.sh` 和 `scripts/generate_app_icon.swift`，可重新生成 `AppIcon.png`、iconset 和 `AppIcon.icns`。
- 已从 `AnInsomniacy/aria2-next` GitHub Releases 下载 `v2.4.9` macOS Intel 预编译二进制。
- 已通过 `aria2-next-2.4.9-checksums.sha256` 校验 `aria2-next-2.4.9-macos-x86_64`。
- 已通过同一 checksum 文件校验 `aria2-next-2.4.9-macos-arm64`，SHA-256 与本地已有 release 二进制一致。
- 已将 Intel sidecar 安装到 `Sources/AriaFlow/Resources/motrix-next-engine-x86_64-apple-darwin`。
- 已将 Apple Silicon sidecar 安装到 `Sources/AriaFlow/Resources/motrix-next-engine-aarch64-apple-darwin`。
- 已新增 `scripts/package_app.sh`，可生成本地可运行的 `dist/AriaFlow.app`。
- `scripts/package_app.sh` 默认构建 universal 主程序，包含 `x86_64` 和 `arm64` 两个架构；需要快速本机包时可用 `UNIVERSAL=0`。
- `scripts/package_app.sh` 支持通过 `BUNDLE_ID`、`APP_VERSION`、`BUILD_NUMBER` 覆盖包信息。
- `scripts/package_app.sh` 支持通过 `SIGN_IDENTITY` 做 Developer ID 签名；未传入时保持本机 ad-hoc 签名。
- `scripts/package_app.sh` 支持通过 `NOTARY_PROFILE` 调用 `xcrun notarytool` 公证并 staple。
- `dist/AriaFlow.app` 使用标准 macOS bundle 结构：可执行文件位于 `Contents/MacOS/`，资源位于 `Contents/Resources/`。
- `dist/AriaFlow.app` 的 `Info.plist` 声明 `.torrent` 文档类型和 `magnet:` / `ed2k:` URL Scheme。
- `dist/AriaFlow.app` 的 `Info.plist` 声明 `CFBundleIconFile=AppIcon`。
- 打包脚本会同时生成 `dist/AriaFlow-<version>.zip`。
- 打包脚本会同时生成 zip 的 sha256 校验文件。
- 已新增 `scripts/install_sidecar.sh`，用于把本地 aria2 可执行文件落位到 SwiftPM 资源目录。
- `scripts/install_sidecar.sh` 支持 `--arch arm64` 和 `--arch x86_64`，可在一台机器上安装双架构 sidecar。
- 已新增 `scripts/smoke_sidecar_download.sh`，用于启动包内当前架构 sidecar 并通过 JSON-RPC 下载本地测试文件。
- 已新增 `scripts/smoke_app_download.sh`，用于通过打包后 app 的隐藏 smoke 入口启动 sidecar 并添加 URL 下载任务。
- 已新增 `scripts/verify_release.sh`，用于一键打包、校验 universal app、验证签名/checksum，并运行 sidecar/app 下载 smoke。
- `scripts/verify_release.sh` 会跟随 `APP_VERSION` 校验对应 zip。
- `scripts/install_sidecar.sh` 和 `scripts/package_app.sh` 已设置执行位，可直接运行。
- 已新增 `README.md`，包含范围、构建、打包、签名、公证和验证入口。
- 已新增 `docs/RELEASE_CHECKLIST.md`，用于发布前 GUI 手动回归、Apple Silicon 实机检查和分发检查。
- 打包时如果没有随包 sidecar，会输出 warning 并继续生成可运行 app。

### 主窗口 UI

- Toolbar：添加、继续、暂停、删除、详情、设置。
- Toolbar 已加入刷新任务。
- Sidebar：全部、下载中、等待中、已完成、已失败、历史。
- Content：任务列表、空状态、连接失败/停止状态。
- 首次启动不再显示原型假任务，任务列表默认来自真实 aria2 RPC。
- 任务列表支持搜索任务名、路径、GID 和协议。
- 任务列表支持按状态、名称和进度排序。
- 任务列表支持清理已完成/已失败结果。
- 任务列表右键菜单支持继续、暂停、打开文件夹、复制 GID、复制任务信息、删除。
- Inspector：默认关闭，点击 `详情` 后打开。
- Inspector 的“打开文件夹”会在 Finder 中定位任务文件或打开所在目录。
- Inspector 的“复制错误信息”和“复制任务信息”会写入系统剪贴板。
- Status Bar：位于主内容区底部，不横跨 Sidebar 和 Inspector。
- 已删除 Status Bar 中用于早期调试的“原型状态”切换菜单。
- 历史列表支持打开保存位置和清空历史。
- 历史列表支持搜索名称、结果、位置和完成时间。
- 历史列表支持复制保存位置。
- 任务完成或失败时会自动写入历史；首次拉取已有任务不会误写入历史。
- 内部状态模型已从 `PrototypeStore` / `PrototypeSettings` 重命名为正式的 `AppStore` / `AppSettings`。

### 设置窗口

- 使用独立 macOS Settings window。
- 左侧分类：通用、下载、通知、引擎。
- 右侧详情按分类切换。
- 支持字段：
  - 启动时自动连接引擎。
  - 菜单栏显示速度。
  - 启动后显示主窗口。
  - 默认保存位置。
  - 最大同时下载数。
  - 默认分片数。
  - 下载限速。
  - 上传限速。
  - 下载完成通知。
  - 下载失败通知。
  - 任务开始通知。
  - RPC 端口。
  - RPC Secret 预览和重新生成。
  - 引擎状态。
  - 重试连接。
  - 保存会话。
  - 打开日志。
  - 打开配置。
  - 打开数据目录。
  - 复制引擎诊断。
- 通用设置支持恢复默认设置。
- 下载设置会对并发数、分片数和 RPC 端口做范围校正。
- 引擎设置在找不到 aria2 可执行文件时显示明确提示。

### 本地数据

- 本地数据目录：`~/Library/Application Support/AriaFlow/`
- 已实现：
  - `settings.json`
  - `history.json`
  - `rpc-secret.txt`
  - `aria2-next.log` 占位/定位
- 设置修改后自动写入本地 JSON。
- 历史记录变更后自动写入本地 JSON。
- RPC Secret 首次启动自动生成并持久化。
- 首次启动历史记录默认为空，不再写入原型假历史。
- 历史记录默认最多保留 500 条，超出后自动丢弃最旧记录。
- 支持通过 `ARIAFLOW_APP_SUPPORT_DIR` 覆盖本地数据目录，供自动化回归使用，避免污染用户真实数据。

### aria2 JSON-RPC

- 已新增 `Aria2Client`。
- 已封装：
  - `aria2.getVersion`
  - `aria2.getGlobalStat`
  - `aria2.tellActive`
  - `aria2.tellWaiting`
  - `aria2.tellStopped`
  - `aria2.tellStatus`
  - `aria2.addUri`
  - `aria2.addTorrent`
  - `aria2.pause`
  - `aria2.forcePause`
  - `aria2.pauseAll`
  - `aria2.unpause`
  - `aria2.unpauseAll`
  - `aria2.remove`
  - `aria2.forceRemove`
  - `aria2.removeDownloadResult`
  - `aria2.getFiles`
  - `aria2.changeOption`
  - `aria2.changeGlobalOption`
  - `aria2.saveSession`
- `重试连接` 已真实调用 `aria2.getVersion`。
- JSON-RPC 客户端请求已携带本地 RPC Secret。
- 自动连接已有 aria2 RPC 时，如果 Secret 连接失败，会尝试兼容未启用 Secret 的本机 RPC。
- 已实现从 `tellActive / tellWaiting / tellStopped` 映射到 UI `DownloadTask`。
- Status Bar 下载/上传速度已接入 `aria2.getGlobalStat`。
- 启动时会按设置自动尝试连接本机 aria2 RPC。
- 连接成功后会每 2 秒轮询 `getGlobalStat / tellActive / tellWaiting / tellStopped`。
- 轮询失败后会进入连接失败状态并停止当前轮询任务。
- 任务从下载中/等待中切换到完成或失败时，会写入下载历史并按设置发送通知。
- 暂停、继续、删除已接入 aria2 RPC：
  - 暂停：`aria2.pause`
  - 继续：`aria2.unpause`
  - 暂停全部：`aria2.pauseAll`
  - 继续全部：`aria2.unpauseAll`
  - 删除活动/等待任务：`aria2.forceRemove`
  - 删除完成/失败结果：`aria2.removeDownloadResult`
- 清理结果会批量调用 `aria2.removeDownloadResult` 清理已完成/已失败任务，并写入历史。
- 删除确认里的“同时删除本地文件”会把解析后的文件或文件夹目标移到废纸篓。
- 删除确认会预览最多 3 个将删除的本地目标，超过 3 项时显示剩余数量。
- 删除本地文件会展开 `~`、去重，并把 aria2 返回的相对路径按任务保存目录补齐。
- 删除本地文件会区分全部成功、部分成功、失败、文件不存在和路径未知，历史记录会写入成功/失败/未找到数量。
- 删除历史时间已改为具体时间戳。
- URL 新建任务已接入 `aria2.addUri`。
- URL 新建任务会使用设置中的下载目录、分片数、下载限速和上传限速。
- 添加 URL/Torrent 任务前会自动创建保存目录，避免默认 `~/Downloads/AriaFlow` 不存在时下载失败。
- 新建任务 sheet 的保存目录选择已接入系统目录选择器。
- 新建 URL 任务默认不填示例链接，开始按钮会在输入为空时禁用。
- 新建 URL 任务支持从剪贴板粘贴链接。
- 新建 URL 任务会校验 `http / https / ftp / magnet / ed2k` 链接，存在无效行时禁用开始按钮。
- Magnet 链接会通过 URL 新建任务入口调用 `aria2.addUri`。
- Torrent 文件选择已接入系统文件选择器。
- Torrent 新建任务支持拖放 `.torrent` 文件。
- 系统打开 `.torrent` 文件会交给 AriaFlow 添加 torrent 任务。
- 系统打开 `magnet:` / `ed2k:` URL 会交给 AriaFlow 添加 URL 任务。
- 应用菜单已加入 `打开 Torrent...`。
- Torrent 文件读取后会调用 `aria2.addTorrent`。
- BT/magnet 文件选择已接入真实 aria2 文件列表：
  - 添加 BT/magnet 时先使用 `pause=true`。
  - 通过 `aria2.getFiles` 获取文件列表。
  - 文件选择窗口支持全选和反选。
  - 用户确认后通过 `aria2.changeOption` 设置 `select-file`。
  - 随后调用 `aria2.unpause` 开始下载。

### EngineManager

- 已新增 `EngineManager`。
- 自动连接流程现在会：
  - 先尝试连接已有本机 aria2 RPC。
  - 连接失败后查找并启动 `aria2c` 或 `aria2-next`。
  - 启动后短时间重试 RPC 连接。
- 当前可查找的位置：
  - SwiftPM 资源目录中的 `motrix-next-engine-aarch64-apple-darwin`。
  - SwiftPM 资源目录中的 `motrix-next-engine-x86_64-apple-darwin`。
  - SwiftPM 资源目录中的 `aria2-next`。
  - SwiftPM 资源目录中的 `aria2c`。
  - 应用资源目录中的同名二进制。
  - `/opt/homebrew/bin/aria2c`
  - `/usr/local/bin/aria2c`
  - `/usr/bin/aria2c`
  - `/opt/homebrew/bin/aria2-next`
  - `/usr/local/bin/aria2-next`
- 已使用本地数据目录：
  - `download.session`
  - `aria2-next.log`
- 启动 aria2 前会创建默认下载目录，并带入下载目录、最大同时下载数、默认分片数和全局限速。
- 启动 aria2 时会传入 `--rpc-secret`。
- 如果 aria2 启动后立即退出或 RPC 长时间不可用，连接失败信息会附带 `aria2-next.log` 尾部日志，便于定位端口占用、权限或配置问题。
- 已新增随包默认配置 `Resources/aria2.conf`，启动时会通过 `--conf-path` 加载。
- 设置页引擎分类已增加 `停止引擎`。
- 停止引擎前会先尝试保存 aria2 session。
- 设置页引擎分类已增加 `保存会话`，调用 `aria2.saveSession`。
- 设置页可复制引擎诊断：可执行文件、配置、数据目录、session、日志、端口、Secret 状态、托管进程状态。
- 引擎诊断会区分 `随包 sidecar`、`系统 aria2` 和 `未找到`。
- 设置页下载分类中的最大同时下载数、下载限速、上传限速会在引擎已连接时同步到 aria2 全局选项。

### 系统通知

- 已请求 macOS 通知权限。
- 任务状态从非完成切换到完成时，按设置发送下载完成通知。
- 任务状态从非失败切换到失败时，按设置发送下载失败通知。
- 任务状态切换到下载中时，可按设置发送任务开始通知。
- 首次拉取任务列表不会误发历史任务通知。

### 菜单栏

- 已新增 macOS 菜单栏状态项。
- 菜单栏可显示下载速度，受设置项 `菜单栏显示速度` 控制。
- 菜单包含：
  - 显示 AriaFlow。
  - 新建任务。
  - 继续全部。
  - 暂停全部。
  - 保存会话。
  - 清理结果。
  - 下载速度。
  - 上传速度。
  - 退出 AriaFlow。

### Dock

- 已新增 Dock badge。
- 活动下载任务数大于 0 时，Dock 图标显示活动任务数量。
- 下载中会在 Dock 图标底部绘制简单整体进度条。

## 当前限制

- 当前已随包放入 Intel 和 Apple Silicon `aria2-next 2.4.9` sidecar，app 主程序已构建为 universal；Apple Silicon 实机运行还未验证。
- Developer ID 签名和公证已有脚本入口，但当前环境没有真实证书和 notary 凭据，尚未执行真实公证。
- RPC Secret 更新后需要重启引擎后生效。
- 如果 bundled sidecar 启动失败、RPC 端口被占用或本机 aria2 RPC 不可用，启动后会显示连接失败状态。
- 删除本地文件不会主动清空整个下载根目录；仅删除解析出的任务文件、文件夹目标，或在 aria2 未返回文件列表时回退删除任务保存路径。
- Dock progress 是简单整体进度条，不做精细视觉。
- 任务搜索/排序是本地 UI 层能力，不改变 aria2 队列顺序。
- 第一版不做 thunder 转换、浏览器扩展、账号、云同步、主题系统、远程 aria2 管理和跨平台支持。
- 第一版不做多选任务管理；已实现的是队列级暂停全部、继续全部和清理结果。
- 退出 App 时会尝试自动保存 session，但还未做真实退出生命周期回归测试。
- 当前环境已可运行本地 TCP 下载回归，`scripts/smoke_sidecar_download.sh` 和 `scripts/smoke_app_download.sh` 均已通过。

## 最近验证

已执行：

```bash
shasum -a 256 .build/sidecar-downloads/aria2-next-2.4.9-macos-x86_64
shasum -a 256 Sources/AriaFlow/Resources/motrix-next-engine-aarch64-apple-darwin Sources/AriaFlow/Resources/motrix-next-engine-x86_64-apple-darwin
scripts/install_sidecar.sh --arch arm64 /Users/x/Documents/Codex/App/AriaFlow/motrix-next/src-tauri/binaries/motrix-next-engine-aarch64-apple-darwin
scripts/install_sidecar.sh --arch x86_64 .build/sidecar-downloads/aria2-next-2.4.9-macos-x86_64
swift build
swift build -c release
scripts/package_app.sh
lipo -info dist/AriaFlow.app/Contents/MacOS/AriaFlow
scripts/smoke_sidecar_download.sh
scripts/smoke_app_download.sh
scripts/verify_release.sh
plutil -lint dist/AriaFlow.app/Contents/Info.plist
codesign --verify --deep --strict --verbose=2 dist/AriaFlow.app
shasum -a 256 -c dist/AriaFlow-0.1.0.zip.sha256
```

结果：

- `aria2-next-2.4.9-macos-x86_64` 校验通过，SHA-256 为 `6b896b485e2c75c85fa06fb04ffc2df7c6ecced497c49619742616a344d3cc57`。
- `aria2-next-2.4.9-macos-arm64` 校验通过，SHA-256 为 `5a41e30f86bcb68ad0af9748bc2121f17769868bca26f4acc42cf2811e1d1ba6`。
- `Sources/AriaFlow/Resources/motrix-next-engine-x86_64-apple-darwin` 已安装，版本输出为 `Aria2 Next version 2.4.9`。
- `Sources/AriaFlow/Resources/motrix-next-engine-aarch64-apple-darwin` 已安装，文件类型为 `Mach-O 64-bit executable arm64`。
- 编译通过。
- 已移除主窗口和历史页的原型假数据，空状态由真实任务/历史驱动。
- 当前代码可生成 debug 可执行文件。
- release 编译通过。
- `dist/AriaFlow.app` 已生成，主程序为 `x86_64 arm64` universal binary。
- `dist/AriaFlow.app/Contents/Resources/motrix-next-engine-x86_64-apple-darwin` 和 `motrix-next-engine-aarch64-apple-darwin` 已随包存在并具有执行权限。
- `dist/AriaFlow-0.1.0.zip` 已生成。
- `dist/AriaFlow-0.1.0.zip.sha256` 已生成。
- zip 校验通过。
- `Info.plist` 校验通过。
- 本地 ad-hoc 签名校验通过。
- 打包脚本会给随包 sidecar 二进制补执行权限，并在脚本内执行 plist 和签名校验。
- 已直接启动包内 sidecar 做 JSON-RPC 烟测，`aria2.getVersion` 返回 `2.4.9`。
- `scripts/smoke_sidecar_download.sh` 已通过，包内 sidecar 可通过 JSON-RPC 下载本地测试文件。
- `scripts/smoke_app_download.sh` 已通过，打包后的 app 可启动 sidecar 并添加 URL 下载任务。
- `scripts/verify_release.sh` 已通过，可作为本地 release 验收入口。

## 下一步开发顺序

1. Apple Silicon 实机验证
   - 在 Apple Silicon 机器上启动 universal app，确认 arm64 主程序和 arm64 sidecar 路径选择正确。
   - 后续如迁移 Xcode 工程，需要同步资源复制规则。

2. 真实 App 下载回归
   - 从 `dist/AriaFlow.app` 启动 UI，添加小文件 URL，验证下载、暂停、继续、删除和历史。
   - 按 `docs/RELEASE_CHECKLIST.md` 执行完整 GUI 手动回归。

3. 引擎兼容性
   - 后续可补更细的连接失败分类。

4. 删除本地文件增强
   - 后续可补删除失败明细弹窗；当前已在状态消息和历史结果中显示失败摘要。

## 验收目标

MVP 达标标准：

- 首次启动能启动或连接本机 aria2。
- 添加 URL 后能真实下载。
- 任务列表显示真实进度、速度、状态。
- 暂停、继续、删除能真实作用于 aria2 任务。
- 设置和历史能跨启动保留。
- 连接失败有明确错误和重试入口。
