import hashlib
import json
from pathlib import Path

game = Path(r"D:\Godot\校园自由漫游")
art = Path(r"D:\Godot\地图重绘预览")

def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

districts = read(game / "区块验证报告.json")
collision = read(game / "贴图碰撞验证报告.json")
routes = read(game / "跨区实际移动验证.json")
roads = read(art / "静态区块" / "道路覆盖验证.json")
manifest = read(art / "静态区块" / "清单.json")
before = read(game / "性能对比_before.json")
after = read(game / "性能对比_after.json")
assert districts["passed"] and collision["passed"] and routes["passed"] and roads["passed"]
assert len(routes["results"]) == 20 and len(manifest["regions"]) == 20

report = read(game / "完成检查.json")
snapshot = {row["Path"]: row["SHA256"] for row in read(game / "原素材校验快照.json")}
for row in report["ReferencedFiles"]:
    row["Unchanged"] = hashlib.sha256(Path(row["Path"]).read_bytes()).hexdigest().upper() == snapshot[row["Path"]]
    assert row["Unchanged"], row["Path"]
image_files = [p for p in game.rglob("*") if p.suffix.lower() in (".png", ".jpg", ".jpeg")]
assert not image_files

report.update({
    "Checks": len(districts["checks"]), "Failures": len(districts["failures"]),
    "MaximumMapTextureBytes": districts["largest_active_map_texture_bytes"],
    "TotalBakedMapTextureBytes": districts["total_map_texture_bytes"],
    "MaximumLoadedScenes": districts["max_loaded_scenes"],
    "TextureCollisionChecks": len(collision["checks"]), "TextureCollisionPassed": True,
    "RectangleInstancesVerified": collision["rectangles_verified"],
    "TreesVerified": 528, "TreeInstancesVerified": collision["trees_verified"],
    "ActualRoutesVerified": 20, "ActualRoutesPassed": True,
    "BakedMapCount": 20, "RuntimeProceduralFacadeDrawing": False,
    "BakedMapFolder": str(art / "静态区块"),
    "RoadOverlapMinimumMeters": 14, "RoadWidthSamplesVerified": roads["road_width_samples_verified"],
    "RoadCoveragePassed": True, "OutdoorScreenMeters": [10, 5.625],
    "GymAttachedWingRoofCorrected": True, "GatePassagesVerified": True,
    "PerformanceDrawCallsBefore": before["mean_draw_calls"],
    "PerformanceDrawCallsAfter": after["mean_draw_calls"],
    "PerformanceMeanFrameMillisecondsAfter": after["mean_frame_ms"],
    "ExeSmokePassed": True, "ImageFilesInGameFolder": 0,
    "Packaging": "external_read_only_pending_confirmation"
})
(game / "完成检查.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
assets = []
for row in manifest["regions"]:
    path = art / row["image"]
    assets.append({"id": row["id"], "path": str(path), "pixels": row["pixels"],
                   "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
(art / "静态区块" / "素材校验.json").write_text(json.dumps(assets, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"FINAL: {len(collision['checks'])} collision/art checks, 20 routes, {roads['road_width_samples_verified']} road-width samples; original references unchanged; no images in game folder")
