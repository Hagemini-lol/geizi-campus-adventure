import hashlib
import json
from pathlib import Path

game = Path(r"D:\Godot\校园自由漫游")
art = Path(r"D:\Godot\地图重绘预览")
def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

time = read(game / "时间昼夜验证报告.json")
assert time["passed"]
assert read(game / "区块验证报告.json")["passed"]
for snapshot in (game / "菜单素材校验.json", art / "内景/原素材校验.json"):
    for item in read(snapshot):
        assert hashlib.sha256(Path(item["Path"]).read_bytes()).hexdigest().upper() == item["SHA256"]
assert not [p for p in game.rglob("*") if p.suffix.lower() in (".png", ".jpg", ".jpeg")]
report = read(game / "完成检查.json")
report.update(TimeDayNightChecks=time["checks"], TimeDayNightChecksPassed=True,
              AutoRouteLineVisible=False, TimeRanges=time["ranges"], TimeFastForwardCooldownSeconds=2,
              TimeAutomaticProgression=False, TimeDisplayPeriodOnly=True, TimeEventAdvanceInterface=True,
              TimeSkipsWithBlackFade=True, TimeChangesPreserveCurrentScene=True,
              UILightingIndependent=True, DayNightInteriorLighting=True)
report.pop("TimeMinutesPerRealSecond",None)
(game / "完成检查.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
path = game / "说明.md"
text = path.read_text(encoding="utf-8")
marker = "\n## 时间与昼夜"
if marker in text:
    text = text.split(marker)[0]
text += """

## 时间与昼夜

左上角信息栏只显示当前时间段，时间后方的「快进 >>」按钮跳至下一时间段。启动时为「上午」，依次经过下午、晚上、深夜、凌晨，再回到上午。时间系统只保存五个时间段，没有日期、小时、分钟或自动读秒；等待、走路、开关菜单和切换场景都不会推进时间。

| 时间段 | 场景表现 |
| --- | --- |
| 凌晨 | 冷色、较暗 |
| 上午 | 明亮白昼 |
| 下午 | 暖色白昼 |
| 晚上 | 昏暗蓝紫色 |
| 深夜 | 深蓝夜色 |

快进使用 0.18 秒黑色渐入、短暂全黑停留和 0.22 秒渐出，在全黑时切换时段。每次接受快进后有 2 秒现实时间冷却，按钮显示「冷却中」并禁用，不显示读秒。快进期间暂停人物移动和其它切换，结束后恢复；保留人物位置、当前场景、高清缓存及已有自动寻路路线。

事件通过 source/main.gd 中的 advance_time_from_event() 显式推进到下一时段，使用相同黑屏和光照更新。接口返回是否接受本次推进，切换过程中拒绝重入；事件不消耗手动快进的冷却，并保留原来的菜单或暂停状态。当前没有新增剧情或自动触发事件，日后可由事件逻辑调用此接口。

室外地面、建筑、树木与主角同步调整色调和明暗。室内夜间保留较高亮度，方便辨认桌椅及门；信息栏、菜单和全图保持原亮度。明暗通过运行时色调实现，原贴图不改动，也不额外复制昼夜版本。

自动寻路的路线提示白线已隐藏，点击 5 倍速寻路、避障与跨区功能继续保留。时间与昼夜验证报告见「时间昼夜验证报告.json」，实际截图位于外部「地图重绘预览/时间与昼夜预览」。
"""
path.write_text(text,encoding="utf-8")
print("TIME_FINAL: periods only, event/fast-forward advancement, no auto clock/countdown; source images unchanged")
