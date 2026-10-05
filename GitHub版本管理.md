# GitHub 版本管理

仓库：[Hagemini-lol/geizi-campus-adventure](https://github.com/Hagemini-lol/geizi-campus-adventure)（私有）。

源码、配置和现有游戏资源副本在 `main` 分支中保存。每次正式版本添加 `vX.Y.Z` 标签，Windows ZIP、Android APK 和 `SHA256SUMS.txt` 作为该版本的 Release 附件。Android 发布始终沿用本地原签名，版本升级同时提高 Android versionCode。

## 本次版本

`v1.0.1` 包含桌椅避让与遮挡修复，以及 Windows 和安卓版本。发布文件暂存在本地 `releases/v1.0.1`，该目录不纳入 Git。已存在的工作区分享 ZIP 不会被替换。

## 后续更新

1. 修改共用 `source` 与必要配置，完成相应功能检查。
2. 更新 `VERSION`、`CHANGELOG.md` 和 Android 导出版本号，重新导出 Windows `runtime/campus.pck` 及已签名 APK。
3. 运行 `python tools/prepare_release.py` 生成当前版本的独立发布文件与校验和；此脚本不会修改原分享 ZIP。
4. 将源码更改提交到 `main`，添加对应版本标签，再推送至仓库。
5. 使用 GitHub 的创建 Release 功能，为对应标签上传 Windows ZIP、APK 和校验和；本地 `release-notes.md` 为可编辑说明。

本机便携 GitHub CLI 位于工作区外层的 `version_tools/gh/bin/gh.exe`，登录配置位于 `version_tools/github_config`。执行前将 `GH_CONFIG_DIR` 指向该目录。CLI 登录凭据由系统凭据存储保管，不复制到仓库或附件。

本地仓库由沙盒初始化，命令如遇 Git 所有权检查，可针对这一个已知目录使用 `git -c safe.directory=D:/Godot/校园自由漫游 -C D:/Godot/校园自由漫游 ...`；不要将所有目录设为可信。

`.gitignore` 排除了个人存档、设置、运行二进制、构建缓存、SDK、APK、ZIP 和签名密钥。`资源/**` 禁止 Git 转换换行，保证素材字节与清单一致。推送前可运行 `python tools/check_git_release.py` 复查资源和索引排除规则。
