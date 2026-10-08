extends RefCounted
const KEYS: Array[String]=["exploration","dialogue","combat","menu"]
var seconds: Dictionary={"exploration":0.0,"dialogue":0.0,"combat":0.0,"menu":0.0}
var idle:=0.0
func activity() -> void:idle=0.0
func tick(delta: float,category: String,focused: bool,moving: bool=false) -> void:
	if not focused or not category in KEYS:return
	delta=clampf(delta,0.0,1.0)
	if moving:idle=0.0
	var active:=minf(delta,maxf(0.0,60.0-idle));idle+=delta
	seconds[category]+=active
func total() -> float:
	var result:=0.0
	for key: String in KEYS:result+=float(seconds[key])
	return result
func snapshot() -> Dictionary:return seconds.duplicate()
func valid(value: Variant) -> bool:
	if not value is Dictionary:return false
	for key: String in KEYS:
		var n: Variant=value.get(key,0)
		if not (n is float or n is int) or not is_finite(float(n)) or float(n)<0 or float(n)>1e9:return false
	return true
func restore(value: Dictionary) -> void:
	for key: String in KEYS:seconds[key]=float(value.get(key,0))
	idle=0.0
func display() -> String:
	var minutes:=floori(total()/60.0)
	return "本存档有效游玩 %d小时%02d分（旧档从本次更新起计；后台、暂停与连续60秒无操作不计）" % [minutes/60,minutes%60]
