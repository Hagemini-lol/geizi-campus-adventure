import hashlib
import json
from pathlib import Path

game = Path(r"D:\Godot\校园自由漫游")
art = Path(r"D:\Godot\地图重绘预览")
indoor = art / "内景"
def read(p):
    return json.loads(p.read_text(encoding="utf-8-sig"))

checks = read(indoor / "内景检查.json")
boards = read(indoor / "告示牌检查.json")
assert not checks["failures"] and checks["max_active_scenes"] == 1 and boards["passed"]
assert read(game / "区块验证报告.json")["passed"]
assert read(game / "贴图碰撞验证报告.json")["passed"]
assert read(game / "跨区实际移动验证.json")["passed"]
images = [p for p in game.rglob("*") if p.suffix.lower() in (".png", ".jpg", ".jpeg")]
assert not images
snapshot = read(indoor / "原素材校验.json")
for item in snapshot:
    assert hashlib.sha256(Path(item["Path"]).read_bytes()).hexdigest().upper() == item["SHA256"], item["Path"]
report = read(game / "完成检查.json")
for item in report["ReferencedFiles"]:
    assert hashlib.sha256(Path(item["Path"]).read_bytes()).hexdigest().upper() == next(r["SHA256"] for r in read(game / "原素材校验快照.json") if r["Path"] == item["Path"])
report.update(InteriorChecks=checks["checks"], InteriorChecksPassed=True, InteriorFloors=17,
              ClassroomScenes=150, InteriorBuildings=["春华楼", "夏耘楼", "秋实楼", "实验楼"],
              ThirdFloorLeftClass10=True, TeleportBoards=14, WholeMapLocations=30,
              RoadPortalIconsVisible=False, MaximumInteriorTextureBytes=checks["largest_interior_texture_bytes"],
              ImageFilesInGameFolder=0, OriginalInteriorAssetsUnchanged=True)
(game / "完成检查.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

manifest = read(art / "静态区块" / "清单.json")
assets = [{"id":row["id"], "path":str(art / row["image"]), "pixels":row["pixels"],
           "sha256":hashlib.sha256((art / row["image"]).read_bytes()).hexdigest()} for row in manifest["regions"]]
(art / "静态区块" / "素材校验.json").write_text(json.dumps(assets, ensure_ascii=False, indent=2), encoding="utf-8")

path = game / "说明.md"
text = path.read_text(encoding="utf-8-sig")
text = text.replace("仅含校园外景和自由移动，没有剧情。", "包含校园外景、四栋教学楼室内和自由移动，没有剧情。")
text = text.replace("- M：校园区块图；点击目的地可发起跨区寻路。", "- E：与附近的门、楼梯或墙上告示牌交互。也可点击门的贴图自动走向入口。\n- M：打开带地点文字的学校原始全图；室外点击目的地自动寻路。通过告示牌打开时，点击地点直接黑屏传送。")
text = text.replace("浅绿色圆圈标出道路出口。", "道路出口的传送图标已隐藏，切换功能保留。")
text = text.replace("建筑室内尚未接入。", "四栋楼的室内已接入，详见下方操作说明。")
text = text.replace("同一时间只保留一个区块场景及一张合成背景纹理，不保留整张原地图。", "同一时间只保留当前一个室外区块、楼层走廊或教室场景。学校原始大图仅在全图界面开启时临时加载，关闭后释放。")
text = text.replace("原地图只用于制作参考和道路分析，运行时不加载它。", "原地图用于参考、道路分析及全图界面，漫游时只加载当前区块。")
addition = """
## 四栋楼的内景与全图传送

春华楼为 5 层，每层 10 间教室；夏耘楼 4 层，每层 7 间；秋实楼 4 层，每层 12 间；实验楼 4 层，每层 6 间。合计 17 个楼层走廊、150 个教室入口。每间教室对应主楼立面连续三个窗户；中央楼梯间和边缘余量单独保留。门的横向位置记录在外部「内景/内外对应.json」中，与外墙窗列使用同一坐标。四栋楼三楼最左侧均为「十班」，使用原有十班教室素材和双扇前门；普通教室有前后门，出门后返回对应走廊门的位置。

走到四栋楼的门口，按 E 或点击门进入一楼走廊。走廊中央楼梯为上楼，两侧小楼梯为下楼；顶楼没有上楼入口，一楼没有地下楼层。靠近楼梯按 E，或直接走入楼梯口切换楼层。一楼中央下方的「校园出口」返回室外。教室门可按 E 或点击进入；进入教室后，只加载当前教室，不保留走廊和室外区块。切换采用原有黑屏渐入渐出，落点留在触发范围之外，避免刚进入就返回。

14 栋实体建筑门口均有墙上「校园导览」告示牌；食堂和小食堂南侧紧贴相邻建筑，使用可到达的西侧入口。走近告示牌按 E，或在附近点击告示牌，打开全图传送界面。界面使用学校原始大图，标出 30 个建筑、场地和入口，右侧可直接选择地点。传送到对应室外入口或安全空地，加载目的地所属区块。M / Esc 关闭界面；普通室外 M 全图保持自动寻路功能，室内 M 可打开全图传送。

走廊地面、墙体、门和门牌预先合成到外部的 17 张楼层图片中。普通教室和十班素材按人体、门和家具比例只读加载，碰撞按透视中的桌腿、椅子、讲台、储物柜及墙面与地面的交界设置。F3 可检查实际物理形状。室内最大的背景 RGBA 纹理约 6.3 MB；不同时加载全部楼层和教室。

本次室内通行检查、告示牌检查及实际游戏截图位于「地图重绘预览/内景」。普通教室、十班、走廊、门图层和学校全图原素材校验一致，没有改动或复制进游戏目录。游戏仍需保留外部引用路径；素材入包继续等待你的确认。
"""
marker = "\n## 四栋楼的内景与全图传送"
if marker in text: text=text.split(marker)[0]
path.write_text(text.rstrip()+"\n"+addition, encoding="utf-8")
(indoor / "检查说明.md").write_text(f"# 内景检查\n\n通过 {checks['checks']} 项检查：四栋楼的外墙三窗分组、17 层走廊、150 间教室、四处三楼左侧十班，以及实际进入、上下楼、前后门返回和单场景加载。14 处告示牌及 30 个安全传送目的地通过检查。\n\n实际游戏预览保存在「实际游戏预览」文件夹。原素材未修改，图片未复制进游戏包体。\n", encoding="utf-8")
print("INTERIORS_FINAL: source assets unchanged; 17 corridor textures; 150 classroom entries; 14 boards; no images in game folder")
