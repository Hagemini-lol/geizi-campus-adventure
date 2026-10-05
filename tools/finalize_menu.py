import hashlib
import json
from pathlib import Path

game = Path(r"D:\Godot\校园自由漫游")
def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

menu = read(game / "菜单验证报告.json")
assert menu["passed"]
for item in read(game / "菜单素材校验.json"):
    assert hashlib.sha256(Path(item["Path"]).read_bytes()).hexdigest().upper() == item["SHA256"]
assert not [p for p in game.rglob("*") if p.suffix.lower() in (".png", ".jpg", ".jpeg")]
report = read(game / "完成检查.json")
report.update(MenuChecks=menu["checks"], MenuChecksPassed=True, RightClickMenu=True,
              MenuTabs=menu["tabs"], MenuSourceImagesUnchanged=True, MenuSourceImagesExternal=True,
              MenuStopsMovement=True, MenuBlocksSceneClicks=True)
(game / "完成检查.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
path = game / "说明.md"
text = path.read_text(encoding="utf-8")
text = text.replace("- 右键或手动移动：取消自动寻路。", "- 右键：打开 / 关闭角色菜单，并取消自动寻路；手动移动：取消自动寻路。")
text = text.replace("Esc：暂停；F3：碰撞显示。", "Esc：关闭菜单或暂停；F3：碰撞显示。")
marker = "\n## 鼠标右键菜单"
if marker in text:
    text = text.split(marker)[0]
text += """

## 鼠标右键菜单

在室外、走廊或教室点击鼠标右键，打开角色菜单，再次右键、Esc 或右上角 × 关闭。打开时停止人物与自动寻路，关闭后恢复操作；点击菜单按钮不会向地图发送寻路点击。正在黑屏切换时暂不打开菜单。

菜单只读调用原素材「菜单UI.png」中的角色人像，以及配套面板、普通、悬停和选中按钮图片。包含状态、装备、物品、技能、设置五个页签。状态显示当前位置、实际移动速度和操作说明；HP、MP、精力及 SAN 尚无数值系统，以 — 显示，装备、物品与技能页为空。

设置可继续漫游、打开校园全图、回到南门、切换全屏或退出。室内打开全图时保留地点传送功能。菜单与全图、暂停界面互相切换，不叠加冻结状态。

图片通过「素材引用.json」从原项目读取，没有改动原素材或将其复制到包体。菜单验证报告见「菜单验证报告.json」，实际截图位于外部「地图重绘预览/菜单预览」。
"""
path.write_text(text,encoding="utf-8")
print("MENU_FINAL: right-click toggle; five external menu textures unchanged; no package images")
