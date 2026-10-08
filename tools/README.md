# 构建与内容工具

正式游戏配置在根目录六份 JSON，Godot 源码在 source。先阅读根目录 AGENTS.md；测试必须指定隔离存档、设置及 APPDATA，不操作实际玩家文件。

常规构建：Godot 导入 source 后导出 WindowsPack 到 runtime/campus.pck；build_launcher.py 生成同版本 Windows 启动器。prepare_android.py 同步共用源码和资源，导入 android_source，再运行 build_android.py，沿用本地原签名。check_android_payload.py 分别以标准和 --wide-mobile 运行最终 APK 导出内容，check_update_saves.py 验证旧存档副本；不启动模拟器。

内容工具是开发阶段的作者脚本，不是运行游戏的必要条件。不要把所有脚本按文件名顺序批量运行：早期 expand_character_arcs.py、wire_tactical_battle.py、configure_stamina.py 和 add_classmate_sidequests.py 会重写自己的基础字段。v1.4.0 当前配置已经是成品，普通修改直接编辑相应配置即可。

如需重新生成本轮内容，先备份配置并查看 diff。write_long_campaign.py 写长对白，write_chapter_investigations.py 写章节调查，write_classmate_sequels.py 写个人续篇，最后 write_story_puzzles.py 加入机关；调查与续篇生成器会替换自己的步骤，必须最后重新接入机关。write_mod_example.py 生成默认禁用的范例和内置安装数据。

audit_rpg_content.py 只做统计，输出 runtime/content_audit.json。source/tests 下的流程检查与正文资源分开，正式 PCK/APK 排除 tests；自动化通过不等同于真人时长或真机体验。

发布时 prepare_release.py 创建 releases/v版本 的独立 ZIP、APK、副本校验和及说明，保留工作区原分享 ZIP。Git 暂存后 check_git_release.py 检查个人文件排除及资源字节；verify_github_release.py 只读验证远端提交、标签、文件大小及 GitHub SHA-256，尊重现有仓库可见性。任何推送或发布应依据当前用户授权。
