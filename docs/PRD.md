# AriaFlow PRD

状态：讨论稿
版本：v0.1
最后更新：2026-07-09
参考设计：`Design/主页面.png`

## 1. 产品概述

AriaFlow 是一个 macOS 原生多协议下载管理器。它复用 `aria2-next` 作为下载引擎，通过本机 JSON-RPC 控制下载任务，并提供更轻、更符合 macOS 桌面习惯的任务管理体验。

AriaFlow 的第一版目标不是完整复刻 Motrix Next，而是在保留核心下载能力的前提下，提供一个稳定、清晰、低负担的原生客户端。

## 2. 产品定位

### 2.1 定位

轻量原生 Motrix。

AriaFlow 保留 Motrix/Motrix Next 的核心能力：

- 多协议下载。
- aria2/aria2-next 下载引擎。
- 下载任务管理。
- BT/磁力/ED2K 支持。

但界面、交互和系统集成按 macOS 原生 App 重新设计，不直接复刻现有 Web/Tauri 界面。

### 2.2 目标用户

- 需要管理多个下载任务的 macOS 用户。
- 需要 BT、磁力、ED2K 等协议支持的高级下载用户。
- 喜欢 Motrix 能力，但希望使用更轻、更原生客户端的用户。
- 不想手动配置 aria2 RPC 的普通用户。

### 2.3 产品原则

- 原生优先：优先使用 SwiftUI、AppKit、系统菜单、系统通知和 Dock 能力。
- 少即是多：第一版只做高频下载管理能力，不搬运全部 Motrix Next 设置。
- 引擎隔离：下载引擎作为 sidecar 运行，避免下载进程崩溃影响 UI。
- 本地优先：核心配置、历史和会话数据保存在本机。

## 3. 第一版目标

### 3.1 必须完成

- macOS 26+ 原生客户端。
- Intel 和 Apple Silicon 支持。
- 内置 `aria2-next` sidecar。
- 自动启动和停止下载引擎。
- 支持 HTTP、HTTPS、FTP、磁力、`.torrent`、ED2K 文件链接。
- 支持任务添加、暂停、继续、删除。
- 支持任务筛选：全部、下载中、等待中、已完成、已失败。
- 支持任务详情。
- 支持 BT/磁力文件选择。
- 支持下载历史。
- 支持系统通知。
- 支持菜单栏图标。
- 支持 Dock badge 或 Dock progress。
- 中文界面。
- 本地可打包为 `.app`。

### 3.2 暂不包含

- 自动更新。
- 多语言切换。
- 完整 peer/tracker 调试控制台。

## 4. 使用场景

### 4.1 添加普通下载

用户点击工具栏添加按钮，输入一个或多个 URL，选择保存目录，确认后开始下载。主界面显示任务进度、速度和剩余时间。

### 4.2 添加 `.torrent`

用户打开或拖入 `.torrent` 文件。AriaFlow 显示 torrent 内文件列表，用户可选择全部或部分文件，确认后创建下载任务。

### 4.3 添加磁力链接

用户输入磁力链接。AriaFlow 先让 `aria2-next` 解析元数据。元数据可用后，弹出文件选择窗口。用户确认后开始下载选中的文件。

### 4.4 控制任务

用户可以对单个任务或多个任务执行暂停、继续、删除。删除默认只移除任务记录，不删除已下载文件。

### 4.5 查看状态

用户通过主窗口底部状态栏、菜单栏图标或 Dock 状态查看当前连接状态、下载速度、上传速度和任务数量。

### 4.6 下载完成

任务完成后，系统通知提示用户。任务进入历史记录，用户可查看保存路径并打开所在文件夹。

## 5. 信息架构

### 5.1 主窗口

主窗口由五个区域组成：

1. 标题栏。
2. 工具栏。
3. 筛选栏。
4. 内容区。
5. 状态栏。

参考设计图中的结构和视觉气质，但允许按原生控件和实际状态调整布局。

### 5.2 页面与弹窗

- 主任务列表。
- 新建任务窗口。
- 任务详情窗口。
- BT/磁力文件选择窗口。
- 设置窗口。
- 删除确认弹窗。
- 引擎连接失败提示。

## 6. 主界面需求

### 6.1 标题栏

标题栏显示：

- macOS traffic lights。
- 应用名：AriaFlow。
- 右侧工具按钮区域。

标题栏应保持清爽，不放置过多文字说明。

### 6.2 工具栏

工具栏包含：

- 添加任务。
- 开始或继续。
- 暂停。
- 删除。
- 设置。

按钮使用系统图标或 SF Symbols。不可用状态需要置灰。

### 6.3 筛选栏

筛选项：

- 全部。
- 下载中。
- 等待中。
- 已完成。
- 已失败。

每个筛选项显示当前数量。选中状态应明确，但不要使用过重视觉。

### 6.4 内容区

内容区根据状态显示：

- 任务列表。
- 空任务状态。
- 引擎连接失败状态。
- 加载状态。

#### 空任务状态

当引擎连接正常但无任务时：

- 标题：没有下载任务。
- 操作：添加任务。

#### 连接失败状态

当无法连接内置 `aria2-next` RPC 时：

- 标题：无法连接。
- 说明：无法连接 aria2-next RPC。
- 操作：重试连接、打开设置。

### 6.5 状态栏

状态栏显示：

- 引擎连接状态。
- 当前下载速度。
- 当前上传速度。
- 下载中数量。
- 等待中数量。
- 已完成数量。
- 已失败数量。

速度格式：

- 小于 1024 B/s：`B/s`。
- 小于 1024 KB/s：`KB/s`。
- 小于 1024 MB/s：`MB/s`。
- 更大：`GB/s`。

## 7. 任务列表需求

### 7.1 任务字段

每个任务显示：

- 任务名。
- 协议类型。
- 状态。
- 进度百分比。
- 进度条。
- 已下载大小。
- 总大小。
- 下载速度。
- 上传速度。
- 剩余时间。
- 保存目录。

### 7.2 任务状态

任务状态映射：

- `active`：下载中。
- `waiting`：等待中。
- `paused`：已暂停。
- `complete`：已完成。
- `error`：已失败。
- `removed`：已移除。

### 7.3 单任务操作

单任务支持：

- 暂停。
- 继续。
- 删除。
- 打开详情。
- 打开所在文件夹。
- 复制链接或任务信息。

### 7.4 队列操作

第一版不做多选任务管理。队列级操作支持：

- 暂停全部。
- 继续全部。
- 清理已完成/已失败结果。

### 7.5 删除行为

默认删除行为：

- 从 aria2 任务列表移除。
- 不删除已经下载的文件。

删除文件作为二次确认选项，第一版可先作为待确认项。

## 8. 新建任务需求

### 8.1 入口

新建任务入口：

- 工具栏添加按钮。
- 菜单 `文件 > 新建任务`。
- 打开 `.torrent` 文件。
- 协议链接打开。
- 拖入 `.torrent` 文件。
- 拖入链接文本。

### 8.2 URL 任务

输入内容：

- 单个 URL。
- 多行 URL。
- 磁力链接。
- ED2K 文件链接。
- FTP 链接（通过 aria2 透传支持，不做专门 FTP UI）。

基础选项：

- 保存目录。
- 文件名。
- 分片数。

高级选项：

- Referer。
- Cookie。
- User-Agent。
- Authorization。
- 自定义请求头。
- 代理。

### 8.3 `.torrent` 任务

流程：

1. 用户选择或拖入 `.torrent`。
2. AriaFlow 将 torrent 内容提交给 `aria2-next`。
3. 通过 `getFiles` 获取文件列表。
4. 用户选择文件。
5. AriaFlow 写入 `select-file`。
6. 开始或继续任务。

第一版不强制实现完整 bencode/torrent 解析器，优先复用 aria2 的元数据结果。

### 8.4 磁力任务

流程：

1. 用户输入 magnet 链接。
2. AriaFlow 使用 `pause-metadata=true` 添加任务。
3. `aria2-next` 解析元数据。
4. AriaFlow 轮询或监听任务状态。
5. 元数据完成后显示文件选择窗口。
6. 用户确认选择。
7. AriaFlow 调用 `changeOption` 设置 `select-file`。
8. AriaFlow 调用 `unpause` 继续下载。

## 9. 任务详情需求

任务详情显示：

- 名称。
- 状态。
- GID。
- 协议类型。
- 保存路径。
- 总大小。
- 已完成大小。
- 下载速度。
- 上传速度。
- 连接数。
- 剩余时间。
- 错误码。
- 错误消息。
- 文件列表。

BT 任务额外显示：

- Info hash。
- 种子数。
- 是否做种。
- 磁力链接。

ED2K 任务额外显示：

- ED2K hash。
- 服务器连接数。
- peer 数量。

第一版不要求显示完整 peer 列表和 tracker 列表。

## 10. 设置需求

第一版设置只保留高频项：

- 默认下载目录。
- 最大同时下载数。
- 单任务默认分片数。
- 全局下载限速。
- 全局上传限速。
- 开机自动启动，待确认。
- 启动时自动连接引擎。
- 菜单栏显示速度。
- 下载完成通知。
- 下载失败通知。
- RPC 端口。
- 重置引擎连接。

默认值：

- 下载目录：`~/Downloads/AriaFlow`。
- RPC 端口：`29100`。
- RPC host：`127.0.0.1`。
- 最大同时下载数：5。
- 默认分片数：16。
- 通知：开启。

## 11. 系统集成需求

### 11.1 菜单栏

菜单栏图标支持：

- 显示主窗口。
- 新建任务。
- 暂停全部。
- 继续全部。
- 显示当前速度，用户可关闭。
- 退出 AriaFlow。

### 11.2 Dock

Dock 支持：

- 下载中显示 badge 或速度。
- 下载中显示整体进度，若实现成本过高可后置。
- 点击 Dock 图标恢复主窗口。

### 11.3 系统通知

通知类型：

- 任务开始。
- 任务完成。
- 任务失败。

通知文案应包含任务名。多个任务同时开始或完成时可聚合。

### 11.4 文件和协议关联

第一版声明：

- `.torrent`。
- `magnet:`。
- `ed2k:`。

第一版只处理传入事件，不提供完整“设为默认应用”管理 UI。

## 12. 引擎需求

### 12.1 sidecar

AriaFlow 内置 `aria2-next` sidecar。

#### 12.1.1 二进制来源

第一版不要求在 AriaFlow 仓库内从源码编译 `aria2-next`。下载引擎使用 `AnInsomniacy/aria2-next` GitHub Releases 发布的预编译二进制。

来源：

- 仓库：https://github.com/AnInsomniacy/aria2-next
- Releases：https://github.com/AnInsomniacy/aria2-next/releases

上游 release 产物命名规则：

| 平台 | 上游产物 |
| --- | --- |
| macOS Apple Silicon | `aria2-next-<version>-macos-arm64` |
| macOS Intel | `aria2-next-<version>-macos-x86_64` |
| 校验文件 | `aria2-next-<version>-checksums.sha256` |

打包前必须校验：

- 下载对应架构的 macOS 二进制。
- 下载同版本 `checksums.sha256`。
- 使用 SHA-256 校验二进制。
- 确认二进制可执行：`chmod +x <binary>`。
- 执行 `<binary> --version` 确认可启动。

#### 12.1.2 AriaFlow 资源落位

AriaFlow 打包时接受以下资源名：

- `motrix-next-engine-x86_64-apple-darwin`。
- `motrix-next-engine-aarch64-apple-darwin`。
- `aria2-next`。
- `aria2c`。
- `aria2.conf`。
- ED2K bootstrap 数据。
- GeoIP 数据，是否启用待确认。

推荐落位规则：

| 当前架构 | 上游产物 | AriaFlow 资源名 |
| --- | --- | --- |
| Apple Silicon | `aria2-next-<version>-macos-arm64` | `motrix-next-engine-aarch64-apple-darwin` |
| Intel | `aria2-next-<version>-macos-x86_64` | `motrix-next-engine-x86_64-apple-darwin` |

资源目录：

`Sources/AriaFlow/Resources/`

运行时根据当前架构优先选择随包二进制；如果随包二进制不存在，可回退查找系统路径中的 `aria2c` 或 `aria2-next`，但正式分发包必须内置随包 sidecar。

### 12.2 启动参数

启动时必须设置：

- `--enable-rpc=true`。
- `--rpc-listen-all=false`。
- `--rpc-listen-port=<port>`。
- `--rpc-secret=<secret>`。
- `--conf-path=<bundled aria2.conf>`。
- `--save-session=<Application Support>/download.session`。
- 如果 session 存在，传入 `--input-file=<session>`。
- `--log=<Application Support>/aria2-next.log`。

### 12.3 连接状态

连接状态：

- 未启动。
- 启动中。
- 已连接。
- 连接失败。
- 已停止。

连接失败时必须显示错误，并允许重试。

## 13. 数据存储

第一版使用 Application Support 下的 JSON 文件。

目录：

`~/Library/Application Support/AriaFlow/`

文件：

- `settings.json`：用户设置。
- `history.json`：历史记录。
- `download.session`：aria2 session。
- `aria2-next.log`：引擎日志。

### 13.1 Settings

设置字段：

- 默认下载目录。
- RPC 端口。
- 最大同时下载数。
- 默认分片数。
- 下载限速。
- 上传限速。
- 菜单栏显示速度。
- 通知开关。

### 13.2 History

历史字段：

- GID。
- 任务名。
- 状态。
- URL 或磁力链接。
- 保存路径。
- 总大小。
- 完成时间。
- 错误信息。

历史记录用于展示完成/失败任务，不作为 aria2 session 的替代。

## 14. 技术方案

### 14.1 技术栈

- Swift 6。
- SwiftUI。
- AppKit。
- Foundation URLSession。
- UserNotifications。
- Swift Package Manager。

第一版不引入第三方 Swift 依赖。

### 14.2 模块

- `AriaFlowApp`：应用入口。
- `AppDelegate`：菜单栏、URL/file open、退出生命周期。
- `EngineManager`：sidecar 启停。
- `Aria2Client`：JSON-RPC 客户端。
- `TaskStore`：任务状态和轮询。
- `SettingsStore`：设置读写。
- `HistoryStore`：历史读写。
- `NotificationService`：系统通知。
- `DockService`：Dock badge/progress。
- `StatusItemController`：菜单栏图标。
- `MainWindowView`：主窗口。
- `AddTaskView`：新建任务。
- `TaskListView`：任务列表。
- `TaskDetailView`：任务详情。
- `FileSelectionView`：BT/磁力文件选择。
- `SettingsView`：设置。

### 14.3 RPC 方法

必须封装：

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
- `aria2.unpause`
- `aria2.remove`
- `aria2.forceRemove`
- `aria2.getFiles`
- `aria2.changeOption`
- `aria2.changeGlobalOption`
- `aria2.saveSession`

## 15. 验收标准

### 15.1 启动

- App 能本地打包为 `.app`。
- 首次启动自动创建 Application Support 目录。
- 如果随包 sidecar 已存在，首次启动自动启动 bundled `aria2-next`。
- 如果随包 sidecar 不存在，可回退系统 `aria2c/aria2-next`，并在设置页诊断中提示来源。
- 连接成功后主窗口显示已连接状态。
- 连接失败时显示失败状态和重试入口。

### 15.2 下载

- 可添加 HTTP URL 并完成下载。
- 可添加 FTP URL（依赖 aria2 引擎协议支持）。
- 可添加 ED2K 文件链接。
- 可添加 `.torrent` 文件。
- 可添加 magnet 链接。
- 下载任务显示进度和速度。
- 暂停、继续、删除操作生效。

### 15.3 BT/磁力

- `.torrent` 可显示文件列表。
- magnet 元数据完成后可显示文件列表。
- 用户可选择部分文件下载。
- 选择后 `select-file` 生效。

### 15.4 系统集成

- 菜单栏图标可显示窗口。
- 菜单栏可暂停/继续全部。
- 下载完成有系统通知。
- Dock 状态随下载变化。
- 退出时保存 session。
- 下次启动恢复未完成任务。

## 16. 待确认问题

- 删除任务时是否提供“同时删除文件”。
- 是否第一版加入剪贴板自动检测。
- 任务详情是否必须显示 BT peer 列表。
- 是否启用 GeoIP peer 国家信息。
- 是否需要专门设计 AriaFlow 图标。
- 是否需要深色模式专门视觉稿。
- 菜单栏速度默认开启还是关闭。
- Dock badge 显示速度还是活动任务数。
- 历史记录保留上限是多少。

## 17. 后续版本候选

- 自动更新。
- 多语言。
- SQLite 历史记录。
- 高级代理策略。
- 文件分类下载。
- BT peer/tracker 面板。
- 任务重试策略 UI。
- 速度计划任务。
- 完整协议默认应用管理。
