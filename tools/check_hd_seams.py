import json
from pathlib import Path
from PIL import Image, ImageChops, ImageStat

root = Path(r"D:\Godot\地图重绘预览")
cache = root / "静态区块/高清切片"
out = root / "清晰度检查/切片接缝检查.json"
previous = None
checks = 0
differences = []
for y in range(34):
    row = [Image.open(cache / f"{x}_{y}_4.png").convert("RGBA") for x in range(30)]
    for x, image in enumerate(row):
        pairs = []
        if x:
            pairs.append(("horizontal", row[x-1].crop((1024,0,1032,1032)), image.crop((0,0,8,1032))))
        if previous is not None:
            pairs.append(("vertical", previous[x].crop((0,1024,1032,1032)), image.crop((0,0,1032,8))))
        for direction, a, b in pairs:
            stats = ImageStat.Stat(ImageChops.difference(a,b))
            maximum = max(v[1] for v in stats.extrema)
            mean = max(stats.mean)
            checks += 1
            if maximum:
                differences.append(dict(x=x,y=y,direction=direction,max_difference=maximum,mean_difference=mean))
    previous = row
largest = max((v["max_difference"] for v in differences),default=0)
report = dict(checks=checks,exact_matches=checks-len(differences),passed=largest<=1,max_channel_difference=largest,tolerance=1,differences=differences)
out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps(dict(checks=checks,exact_matches=report["exact_matches"],difference_count=len(differences),largest=max((v["max_difference"] for v in differences),default=0))))
