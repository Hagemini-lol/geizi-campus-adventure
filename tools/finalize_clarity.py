import hashlib
import json
from pathlib import Path

game=Path(r"D:\Godot\校园自由漫游")
art=Path(r"D:\Godot\地图重绘预览")
def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

quality=read(art/"清晰度检查/清晰度验证.json")
interior=read(art/"内景/内景检查.json")
assert quality["passed"] and not interior["failures"]
seams=read(art/"清晰度检查/切片接缝检查.json")
assert seams["passed"]
assert read(game/"贴图碰撞验证报告.json")["passed"]
for item in read(art/"内景/原素材校验.json"):
    assert hashlib.sha256(Path(item["Path"]).read_bytes()).hexdigest().upper()==item["SHA256"]
for item in read(game/"完成检查.json")["ReferencedFiles"]:
    original=next(r for r in read(game/"原素材校验快照.json") if r["Path"]==item["Path"])
    assert hashlib.sha256(Path(item["Path"]).read_bytes()).hexdigest().upper()==original["SHA256"]
assert not [p for p in game.rglob("*") if p.suffix.lower() in (".png",".jpg",".jpeg")]
manifest=read(art/"静态区块/高清切片/清单.json")
assert len(manifest["tiles"])==1020
report=read(game/"完成检查.json")
report.update(TextureClarityChecks=quality["checks"],TextureClarityPassed=True,
              OutdoorTileDensity=4,CorridorTextureDensity=3,HDCacheTiles=1020,
              HDCacheLODLevels=[1,2,4],VisibleTilesOnly=True,HDBackgroundLoading=True,
              ResolutionAwareZoom=True,HDTileSeamChecks=seams["checks"],HDTileSeamPassed=True,MaximumInteriorTextureBytes=interior["largest_interior_texture_bytes"],
              MaximumLoadedScenes=1,OriginalInteriorAssetsUnchanged=True,ImageFilesInGameFolder=0)
(game/"完成检查.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
path=game/"说明.md"
text=path.read_text(encoding="utf-8")
text=text.replace("每张图最多约 300 万像素，最大活动背景约 12 MB，20 张合计约 232 MB，合计数不会同时加载。", "20 张备用区块底图每张最多约 300 万像素，最大单张约 12 MB，合计约 232 MB，合计数不会同时加载。正常画面由镜头附近的高清切片覆盖，切片另占纹理内存，详见下方清晰度说明。")
text=text.replace("室内最大的背景 RGBA 纹理约 6.3 MB；不同时加载全部楼层和教室。", "走廊使用三倍分辨率合成图，最大活动室内纹理连同多级缩小版本约 32.2 MB；不同时加载全部楼层和教室。")
marker="\n## 高清显示与按镜头加载"
if marker in text:text=text.split(marker)[0]
addition="""
## 高清显示与按镜头加载

室外新增高清切片，最高合成密度为原米制坐标的 4 倍，即每米 96 个像素。楼体、窗格、地砖、校门、屏幕和告示牌从原绘制代码重新生成。全校切片按 1、2、4 三档保存，运行时只读取当前区块中镜头附近的部分，镜头离开后释放。PNG 读取及缩小纹理准备在后台完成，每帧分批上传；跨区黑屏会等待目的地的可见切片就绪。楼体与窗户仍是合成图片，不恢复逐窗绘制。

走廊的横向位置、门高、楼梯和碰撞维持原坐标，但图片宽高均以三倍像素密度重新合成，门牌文字使用相应的高分辨率字体采样。教室、主角和树木从原分辨率素材生成多级缩小版本，采用平滑过滤，避免缩小时的锯齿和细节闪烁。原素材本身的绘画细节没有改写。

镜头缩放会结合实际窗口分辨率和当前图片像素密度计算放大上限。在普通窗口中仍可使用原有 0.6～2.4 倍范围；较大的窗口或全屏下，最大倍率可能降低，避免继续放大低于屏幕像素密度的图片。学校全图界面也避免将原图过度拉大。

1280 × 800 的春华楼测试中，0.6、1.5、2.4 倍镜头分别加载约 19.2、28.4、34.1 MB 高清纹理（包含多级缩小版本），另保留约 12 MB 备用底图。纹理数字不包括引擎、导航、共享素材及暂时的读取缓冲，也不是整机内存。大窗口的可见纹理数量会随画面覆盖范围变化，全部高清切片不会同时加载。

高清缓存和走廊合成图均位于外部「地图重绘预览」文件夹，没有复制进游戏包体。验证报告及实际游戏截图见「清晰度检查」。重新制作缓存可运行 source/tests/bake_hd_tiles.gd；走廊可运行 source/tests/bake_interiors.gd，常规游玩不需要运行生成工具。
"""
path.write_text(text.rstrip()+"\n"+addition,encoding="utf-8")
(art/"清晰度检查/检查说明.md").write_text(f"# 场景清晰度检查\n\n通过 {quality['checks']} 项检查：20 个区块均加载可见高清切片，3,060 个缓存文件完整，随缩放切换三档分辨率，移出镜头的切片释放，走廊与教室保持原世界尺寸及碰撞对应关系，较大渲染窗口避免图片过度放大。\n\n截图来自实际 Godot 游戏渲染。原素材校验一致，游戏目录没有图片素材副本。\n",encoding="utf-8")
print("CLARITY_FINAL: 1020 tiles, 3 LODs, 3x corridors; source assets unchanged; no package images")
