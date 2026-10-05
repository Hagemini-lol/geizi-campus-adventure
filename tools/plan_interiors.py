import hashlib
import json
from pathlib import Path

root = Path(r"D:\Godot")
game = root / "校园自由漫游"
out = root / "地图重绘预览" / "内景"
out.mkdir(exist_ok=True)
project = root / "Projects" / "赵慕gei的牙林冒险"
model = json.loads((root / "地图重绘预览" / "运行数据.json").read_text(encoding="utf-8"))
data = json.loads((project / "data" / "campus_regions.json").read_text(encoding="utf-8"))
assets = {
    "corridor": str(project / "assets/maps/indoor/corridor/走廊-底图.png"),
    "top_corridor": str(project / "assets/maps/indoor/corridor/走廊-顶楼底图.png"),
    "doors": str(project / "assets/maps/indoor/corridor/走廊-门图层.png"),
    "ordinary": str(project / "assets/maps/indoor/普通教室.png"),
    "class10": str(project / "assets/maps/indoor/十班.png"),
    "whole_map": str(project / "assets/maps/outdoor/campus_named_v2.png"),
}
snapshot = [{"Path": path, "SHA256": hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()} for path in assets.values()]
(out / "原素材校验.json").write_text(json.dumps(snapshot, ensure_ascii=False, indent=2), encoding="utf-8")

teaching = {"B12", "B05", "B01", "B02"}
entrances, buildings = [], {}
for zone in data["zones"]:
    if zone["kind"] != "building":
        continue
    owner = zone["id"]
    boxes = [r for r, label in zip(model["solids"], model["solid_owners"]) if label == owner]
    if not boxes:
        continue
    box = max(boxes, key=lambda r: r[2]*r[3])
    x,y,w,h = box
    door_x = x+w*.59 if owner == "B03" else x+w/2
    entry = {"id": owner, "name": zone["name"], "box": box,
             "door": [door_x, y+h], "arrival": [door_x, y+h+1.9],
             "board": [door_x+2.5, y+h-1.25],
             "board_arrival": [door_x+2.5, y+h+1.5], "has_interior": owner in teaching}
    if owner in {"B07", "B08"}:
        # Adjacent buildings touch the southern frontage; the west-facing
        # entrance opens onto the actual continuous campus road instead.
        entry.update(side="west", door=[x, y+h-3], arrival=[x-1.9,y+h-3],
                     board=[x+1,y+h-6.5], board_arrival=[x-1.5,y+h-6.5])
    entrances.append(entry)
    if owner not in teaching:
        continue
    bay = 2.5 if owner == "B12" else 3.2
    columns = list(range(int(w/bay)))
    # Central windows serve the stairwell, so classroom windows form exact
    # consecutive groups of three on each side of the shared central stairs.
    left = [c for c in columns if (c+.5)*bay < w/2-3.6]
    right = [c for c in columns if (c+.5)*bay > w/2+3.6]
    left = left[:len(left)//3*3]
    right = right[:len(right)//3*3]
    groups = [side[i:i+3] for side in (left, right) for i in range(0,len(side),3)]
    floors = int(zone["storeys"])
    floor_rows = []
    for level in range(1, floors+1):
        rooms = []
        for index, group in enumerate(groups):
            start, end = group[0]*bay, (group[-1]+1)*bay
            ten = level == 3 and index == 0
            name = "十班" if ten else f"{level}{index+1:02}教室"
            front = (start+end)/2 if ten else start+1.5
            rear = end-1.5
            rooms.append({"index": index, "name": name, "class10": ten,
                          "windows": group, "outside_x": [x+(c+.5)*bay for c in group],
                          "span": [start,end], "front_door_x": front,
                          "rear_door_x": None if ten else rear})
        floor_rows.append({"floor":level, "image":f"{owner}_{level}F.png", "rooms":rooms})
    buildings[owner] = {"id":owner, "name":zone["name"], "box":box,
                        "bay_meters":bay, "columns":left+right, "floor_count":floors,
                        "width_pixels":w*24, "height_pixels":836*.26,
                        "stairs_center_x":w*12, "floors":floor_rows}

result = {"assets":assets, "buildings":buildings, "entrances":entrances, "corridor_image_density":3,
          "corridor_y_scale":.26, "door_foot_y":278*.26,
          "corridor_walk_top":78, "corridor_walk_bottom":180}
(out / "内外对应.json").write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
config = json.loads((game / "素材引用.json").read_text(encoding="utf-8-sig"))
config["interior_model"] = "../地图重绘预览/内景/内外对应.json"
(game / "素材引用.json").write_text(json.dumps(config,ensure_ascii=False,indent=2),encoding="utf-8")
print({k:{"floors":v["floor_count"],"rooms_per_floor":len(v["floors"][0]["rooms"])} for k,v in buildings.items()})
