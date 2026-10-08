# Mod 制作说明 · API 1

v1.4.0 提供实际加载的 JSON 内容扩展接口。可增加物品、支线、机关谜题、基于现有怪物的变种，以及在指定主事件后追加对白。当前接口复用现有地图、人物和怪物动作；自定义地图、脚本、技能公式与外部立绘还没有开放接口。

## 安装

Windows 完整游戏目录下使用 `mods/包目录/manifest.json` 和 `content.json`。示例 `mods/campus_example` 默认禁用；可以将 manifest 的 `enabled` 改成 `true`，保存后完全退出并重开游戏。

Windows 和 Android 都可在菜单安装内置示例，或打开“导入 Mod JSON”粘贴 `{"manifest": {...}, "content": {...}}` 数据包并安装。Android 写入应用私有 `user://mods`，不要求访问公共目录。导入后重启生效；已有同名自定义目录不会自动覆盖。示例任务在初期觉醒后找牢李接取，去主席台取便笺并交回，奖励温茶和 g。

菜单显示已加载数量和失败原因。单包校验失败会跳过该包，基础剧情继续运行。移除 Mod 后，其物品、任务和怪物存档记录保留但暂不参与游戏，装回相同 ID 可继续。更新 Mod 请保持任务 ID、步骤顺序和谜题尺寸；当前接口没有自动迁移工具。卸载 Android 应用会删除私有存档及 Mod。

## 清单与命名空间

```json
{
  "api": 1,
  "id": "my_story",
  "name": "校园新故事",
  "version": "1.0.0",
  "enabled": true,
  "order": 100,
  "requires": [],
  "content": "content.json"
}
```

包 ID 使用 1–48 个小写英文字母、数字或下划线；新增 ID 用 `my_story:tea` 形式。加载按 `order` 再按目录名排序；依赖包须列入 `requires` 且先加载。content 只接受包内 JSON 文件名，不能写相对路径或绝对路径。最多 32 个启用包，每个 JSON 最多 2MiB；单包 64 物品、64 任务、32 怪物，总物品和任务分别最多 800 项。

## 内容格式

直接复制随游戏附带的 `mods/campus_example/content.json` 修改，是最小可运行范例。顶层可使用 `items`、`quests`、`monsters`、`event_dialogue`。

物品包含 `id/name/description/buy_price/sell_price/restore`，可选 `restore_ratio`。回复属性为 `hp/mp/energy/san`；比例取 0–1，固定回复取正整数。`buy_price: -1` 表示不售卖，卖价不能高于非负买价。战斗使用仍消耗一回合并从背包扣除，满状态不能空耗。

怪物包含 `id/name/base` 和可选 `hp_scale/attack_scale`，倍率 0.5–3。base 可为 `ink_slime/book_eater/empty_uniform/dry_branch`，复用对应贴图、动作及基础战斗规则。新增任务可以用 `monster_defeated/my_story:ink_drop` 目标来要求击败变种。

任务必须 `type: "side"`、`auto_start: false`，包含 `title/prerequisites/side_story/steps`。side_story 包含 `owner/min_index/description/intro/outro/reward`，可选 `epilogue/daily`；奖励为 `{"g":20,"items":{"my_story:tea":2}}`。min_index 是 0–33 主事件完成门槛。完成奖励只领取一次；daily 按游戏日重开，避免设计超额收益。

对白为 `[{"actor":"lao_li","text":"台词"}]`。可用主人公 `hero/zhao_mugei`、旁白 `system`、勾尬 `gou_ga`、闻聪 `wen_cong` 和九位同学。任务委托人和步骤交谈人使用下列 ID：

| ID | 角色 |
| --- | --- |
| lao_li | 牢李 |
| lao_chou | 牢抽 |
| fei_yan | 费眼 |
| lao_ao | 牢傲 |
| lao_shuo | 牢硕 |
| yang_zi | 阳子 |
| lao_dong | 牢董 |
| la_jiao | 辣椒 |
| wr | wr |

每步包含 `hint/event`，现场调查加 `location`，交谈加 `actor`，可配 `dialogue/resolution/retry/consume`。本包调查事件使用 `side/my_story:note/0` 格式。击败事件为 `monster_defeated/怪物ID`，`count` 为 1–10。每任务 1–32 步；前置任务不能自引用或形成环。

可用地点：`S02` 主席台、`B04` 食堂；室内 `楼ID:楼层:房间`，例如 `B01:3:0`。楼 ID 为 B01/B02/B12（3 层）、B06（4 层）、STORY_HOUSE（1 层），房间为 0–9 或 corridor。应先在基础游戏中确认该房间可以抵达，再发布任务；实验楼常态没有常驻同学，不宜作为委托人固定位置。

选择题包含 `question/choices/correct`，choices 是 `[["right","选项文本"],["wrong","另一选项"],["cancel","稍后"]]`；道德选择用 `branches` 给出各非 cancel 选项对应的对白，两边都推进并保存选择，避免把人物分歧写成唯一正确答案。

`event_dialogue` 用稳定主事件 ID 作为键追加对白，例如 `{"patrol_done":[{"actor":"lao_li","text":"补充台词"}]}`。完整主事件 ID 可查看 `剧情配置.json` 的 campaign.nodes。不能覆盖基础事件、奖励或战斗规则。

## 机关谜题

步骤可添加 `puzzle`，共用字段为 `kind/title/description/hint/initial/target/controls/clues`，可选 `helper/success/failure`。clues 是 `[{"title":"便笺","text":"线索内容"}]`；success/failure 为对白数组。机关需有 3–4 个状态位，线索 1–4 条。

- dials：tokens 是每个拨盘的字符串选项数组；initial/target 是各选项的从零索引；controls 为每个拨盘按钮名。
- sequence：pieces 是卡片文本；initial/target 是 0 到卡片数减一的排列；controls 数量为卡片数减一，每个按钮交换该位置与下一位置。
- switches：initial/target 为 0/1 灯状态；links 是每个按钮连动灯位的从零索引数组，controls 与 links 等长。系统检查目标是否可达。

可参考 `任务配置.json` 中 chapter_signal、chapter_record、chapter_legacy 的 puzzle。失败不推进、不扣道具；随时提示及退出，排列随任务存档。

## 测试

开发时可用 `--mods-dir=测试目录 --save-dir=测试存档目录 --settings-path=测试设置文件` 隔离数据。先检查菜单加载结果，再验证接取、定位、步骤、失败重试、存读档、奖励及禁用重装。内置 `source/tests/mod_check.gd` 覆盖加载、实际任务流程、消耗品、变种和禁用恢复；正式发布前仍应试玩自己写的对白与谜题。

这个接口校验数据格式和范围，不保证作者设计的路线可通、谜题有趣或经济数值合理。不要改动正式玩家的存档来调试。
