import hashlib
import json
from pathlib import Path

game = Path(r"D:\Godot\校园自由漫游")
art = Path(r"D:\Godot\地图重绘预览")
def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

furniture = read(game / "室内家具通行验证.json")
interior = read(art / "内景/内景检查.json")
assert furniture["passed"] and not interior["failures"]
assert read(game / "跨区实际移动验证.json")["passed"]
for item in read(art / "内景/原素材校验.json"):
    assert hashlib.sha256(Path(item["Path"]).read_bytes()).hexdigest().upper() == item["SHA256"]
assert not [p for p in game.rglob("*") if p.suffix.lower() in (".png", ".jpg", ".jpeg")]
report = read(game / "完成检查.json")
report.update(IndoorFurnitureCollisionLogicalPixels=[1,1], FurnitureChecks=furniture["checks"],
              FurnitureCheckPassed=True, FurnitureActualWalkTargets=furniture["actual_walk_targets"],
              FurnitureWallsPreserved=True, InteriorChecks=interior["checks"], InteriorChecksPassed=True,
              ExactIndoorNavigationClearance=True, OriginalInteriorAssetsUnchanged=True)
(game / "完成检查.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
path = game / "说明.md"
text = path.read_text(encoding="utf-8")
text = text.replace("碰撞按透视中的桌腿、椅子、讲台、储物柜及墙面与地面的交界设置。", "桌椅、讲台与储物柜的碰撞缩小为贴图脚底中心的 1×1 逻辑像素，体积小于贴图；墙体保持原有边界。")
marker = "\n## 室内家具通行"
if marker in text:
    text = text.split(marker)[0]
text += """

## 室内家具通行

四栋楼的全部教室共用小型家具碰撞：每组桌椅、讲台及柜体只保留脚底中心的 1×1 逻辑像素核心。逻辑像素随镜头倍率显示，贴图与人物比例保持原样。人物脚底仍有半径，因此核心周边保留必要的避让距离。

点击寻路与实际物理共用这些小碰撞箱，并修正绕过桌角时提前跳过拐点、路线停止的问题。墙体和走廊护栏保留实体边界，门与楼梯按原位置交互。按 F3 可以查看真实碰撞形状。

普通教室及十班均通过实际人物移动验证：穿过旧桌椅碰撞范围、经过各排相邻桌椅之间的空隙、到达前后门，共验证 123 个移动目标。报告见「室内家具通行验证.json」。原图片未修改，素材仍从包体外只读加载。
"""
path.write_text(text,encoding="utf-8")
print("FURNITURE_FINAL: 1x1 logical pixels; 123 actual walk targets; source images unchanged")
