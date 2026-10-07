# gei子的冒险

以 Godot 4.7.2 开发的校园探索游戏，包含分区地图、室内场景、NPC、时间、上课、战斗、任务、物资交易、剧情及存读档系统。

当前本地版本为 **1.2.2 离线版**，已接入第二章至终章。流程、补证、伙伴和战斗建议见 [剧情续写实现说明.md](剧情续写实现说明.md)。室外性能和第一章卡桌修复见 [分区加载与卡桌修复说明.md](分区加载与卡桌修复说明.md)。本版本通过现有私有仓库的 v1.2.2 标签及 Releases 管理；完整游戏包见下方下载入口。

## 下载与游玩

在 [Releases](https://github.com/Hagemini-lol/geizi-campus-adventure/releases) 下载对应平台的完整发布包。本仓库为私有仓库，需要获得访问授权。

- Windows 64 位：解压整个 Windows ZIP，然后双击 `gei子的冒险.exe`。请保留 `runtime`、`资源` 和配置文件；无需安装 Godot。
- Android 7.0 及以上 ARM 手机或平板：安装 APK，横屏游玩。摇杆移动、X 交互、Y 菜单、×2 奔跑，点击地面自动寻路。

Windows 操作、系统说明见 [说明.md](说明.md)；安卓操作与构建说明见 [安卓版使用说明.md](安卓版使用说明.md)。

已有玩家请按 [覆盖更新与存档说明.md](覆盖更新与存档说明.md) 更新：Windows 保留原存档文件夹，Android 直接覆盖安装，先保存退出，不卸载旧应用。

## 项目结构

- `source/`：共用 Godot 源码与检查脚本，用 Godot 打开其中的 `project.godot`。
- `资源/`：游戏使用的地图、人物、室内与 UI 素材副本，供源码运行与构建使用。
- 根目录 JSON：地图素材引用、战斗、剧情、任务、办公室、交易等配置。
- `tools/`：构建、资源准备与验证脚本。
- `VERSION`、`CHANGELOG.md`：版本号与变更记录。

生成的运行文件、APK、Windows ZIP、安卓工程镜像、SDK、缓存、个人存档和设置不提交到 Git。发布包在 Releases 单独保存，代码版本以 `v主版本.次版本.修订号` 标签对应。

首次版本为 `v1.0.1`，后续操作见 [GitHub版本管理.md](GitHub版本管理.md)。

## 构建与发布

Windows 使用 Godot 对 `source` 导出 `WindowsPack` 为 `runtime/campus.pck`，配合 Godot Windows 运行引擎和 `tools/Launcher.cs` 启动器。`tools/prepare_release.py` 可从当前运行文件生成独立 Windows ZIP、复制已签名 APK，并生成 SHA-256 校验和；它不会替换工作区已有的分享 ZIP。

Android 通过 `tools/prepare_android.py` 生成 `android_source`，再通过 `tools/build_android.py` 导出和签名。需要准备与引擎匹配的 Android 模板、JDK 17 和 Android SDK。签名密钥保存在本地 `android_tools/signing`，不会上传；后续 Android 更新必须沿用相同签名以保留存档。

个人存档、设置和签名密钥均不属于发布包。地图等素材沿用现有项目内容，本仓库未另行授予素材再分发许可。

安卓验证策略：停止使用 MuMu。本版执行导出 APK 内容的电脑引擎触控、签名与资源完整性检查，未进行安卓设备测试。
