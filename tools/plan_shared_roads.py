"""Plan overlapping visual bounds without changing movement ownership."""
import json
import math
import sys
import struct
from pathlib import Path

root = Path(r"D:\Godot\地图重绘预览")
model = json.loads((root / "运行数据.json").read_text(encoding="utf-8"))
width, height = model["width"], model["height"]

def road_span(x, y, dx, dy):
    cells = set()
    for direction in (-1, 1):
        cx, cy = x, y
        while 0 <= cx < width and 0 <= cy < height:
            cell = cy * width + cx
            if model["roads"][cell] != "1" or model["blocked"][cell] != "0":
                break
            cells.add((cx, cy))
            cx += dx * direction
            cy += dy * direction
    return cells

extents = []
for region in model["regions"]:
    x, y, w, h = region["world_bounds"]
    extents.append([max(0, x-14), max(0, y-14), min(width, x+w+14), min(height, y+h+14)])

sections = []
for a, b, x, y in model["gates"]:
    # The shorter paved span estimates road width, rather than its length.
    cells = min((road_span(math.floor(x), math.floor(y), 1, 0),
                 road_span(math.floor(x), math.floor(y), 0, 1)), key=len)
    sections.append((a, b, cells))
    for region in (a, b):
        box = extents[region]
        for cx, cy in cells:
            box[0] = max(0, min(box[0], cx-2))
            box[1] = max(0, min(box[1], cy-2))
            box[2] = min(width, max(box[2], cx+3))
            box[3] = min(height, max(box[3], cy+3))

checked = 0
for a, b, cells in sections:
    for region in (a, b):
        left, top, right, bottom = extents[region]
        for x, y in cells:
            assert left <= x+.5 < right and top <= y+.5 < bottom
            checked += 1

regions = []
for source, (l, t, r, b) in zip(model["regions"], extents):
    regions.append({"id": source["id"], "visual_bounds": [l, t, r-l, b-t]})
result = {"minimum_overlap_meters": 14, "curb_margin_meters": 2,
          "road_width_samples_verified": checked, "regions": regions}
out = root / "静态区块" / "道路分割方案.json"
if "--verify" in sys.argv:
    manifest = json.loads((out.parent / "清单.json").read_text(encoding="utf-8"))
    assert manifest["version"] >= 2 and len(manifest["regions"]) == len(regions)
    for expected, entry in zip(regions, manifest["regions"]):
        assert expected["id"] == entry["id"]
        # Rect2 uses 32-bit coordinates in Godot; allow sub-pixel serialization
        # rounding, while still catching meaningful clipping or mapping errors.
        assert all(math.isclose(a, b, rel_tol=0, abs_tol=0.0001)
                   for a, b in zip(expected["visual_bounds"], entry["visual_bounds"]))
        header = (root / entry["image"]).read_bytes()[:24]
        assert list(struct.unpack(">II", header[16:24])) == entry["pixels"]
    result["passed"] = True
    (out.parent / "道路覆盖验证.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"ROAD_OVERLAP_VERIFIED: {len(regions)} baked images; {checked} road-width samples covered")
else:
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"ROAD_OVERLAP_PLAN: {len(regions)} regions; {checked} road-width samples covered")
