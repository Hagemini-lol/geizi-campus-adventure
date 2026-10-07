extends RefCounted

var rules: RefCounted
var zones: Dictionary={}
var overrides: Dictionary={}
var period_serial:=0
var next_uid:=1
var rng:=RandomNumberGenerator.new()

func configure(combat: RefCounted) -> void:
	rules=combat;rng.randomize()

func reset() -> void:
	zones={};overrides={};period_serial=0;next_uid=1

func zone_key(context: Dictionary) -> String:
	if context.is_empty():return ""
	return "%s/%d/%s/%d" % [context.get("building",""),int(context.get("floor",0)),context.get("kind",""),int(context.get("room",-1))]

func zone_rule(context: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for rule: Dictionary in rules.data.get("spawn_regions",[]):
		if rule.get("building")!=context.get("building") or not context.get("kind","") in rule.get("kinds",[]):continue
		if not rule.get("floors",[]).is_empty() and not int(context.get("floor",0)) in rule["floors"]:continue
		if context.get("kind")=="classroom" and not rule.get("rooms",[]).is_empty() and not int(context.get("room",-1)) in rule["rooms"]:continue
		result=rule.duplicate(true)
	var key:=zone_key(context)
	if overrides.has(key):result.merge(overrides[key],true)
	if result.is_empty() or not result.get("enabled",true):return {}
	# Architectural caps are absolute even when event rules change.
	result["capacity"]=clampi(int(result.get("capacity",3)),0,2 if context.get("kind")=="classroom" else 3)
	return result

func set_zone_rule(context: Dictionary, patch: Dictionary) -> void:
	var key:=zone_key(context)
	if key.is_empty():return
	var current: Dictionary=overrides.get(key,{})
	current.merge(patch.duplicate(true),true);overrides[key]=current

func activate(context: Dictionary) -> Array:
	var key:=zone_key(context)
	var rule:=zone_rule(context)
	if rule.is_empty():return []
	if not zones.has(key):
		zones[key]={"monsters":[],"last_period":period_serial}
		var spawning: Dictionary=rules.data["spawning"]
		var elite_weight:=maxf(0,float(spawning["initial_elite_weight"]))
		var normal_weight:=maxf(0,float(spawning["initial_normal_weight"]))
		var probability:=elite_weight/maxf(.00001,elite_weight+normal_weight)
		for count: int in range(mini(int(rule.get("initial_count",1)),int(rule["capacity"]))):add_monster(key,rule,"elite" if rng.randf()<probability else "normal")
	var entry: Dictionary=zones[key]
	# Reloading a zone does not reroll it or backfill unloaded time periods.
	entry["last_period"]=period_serial
	while entry["monsters"].size()>int(rule["capacity"]):entry["monsters"].pop_back()
	return entry["monsters"]

func advance(context: Dictionary) -> void:
	period_serial+=1
	var rule:=zone_rule(context)
	var key:=zone_key(context)
	if rule.is_empty():return
	if not zones.has(key):activate(context);return
	add_monster(key,rule,"normal")
	if rng.randf()<float(rules.data["spawning"]["period_elite_probability"]):add_monster(key,rule,"elite")
	zones[key]["last_period"]=period_serial

func add_monster(key: String, rule: Dictionary, rarity: String) -> void:
	var entry: Dictionary=zones[key]
	if entry["monsters"].size()>=int(rule["capacity"]):return
	var pool: Array=[]
	for id: String in rules.data["monsters"]:
		if rules.data["monsters"][id].get("rarity")==rarity and not rules.data["monsters"][id].get("scripted_only",false):pool.append(id)
	if pool.is_empty():return
	var id: String=pool[rng.randi_range(0,pool.size()-1)]
	var level:=spawn_level(rarity,rule)
	var stats: Dictionary=rules.monster_stats(id,level)
	entry["monsters"].append({"uid":str(next_uid),"id":id,"level":level,"hp":stats["hp"]})
	next_uid+=1

func spawn_level(rarity: String, rule: Dictionary={}) -> int:
	# Decide once at spawn time; existing creatures keep their saved stats.
	if rule.get("level_mode","hero_relative")=="fixed":return clampi(int(rule.get("level",1)),1,rules.maximum_monster_level())
	var spawning: Dictionary=rules.data["spawning"]
	var offset:=0
	if rarity=="boss":
		var low:=int(spawning.get("boss_level_offset_min",5))
		var high:=maxi(low,int(spawning.get("boss_level_offset_max",10)))
		offset=rng.randi_range(low,high)
	else:offset=int(spawning.get("level_offsets",{"normal":-5,"elite":0}).get(rarity,0))
	return clampi(int(rules.hero["level"])+offset,1,rules.maximum_monster_level())

func remove(key: String, uid: String) -> void:
	if not zones.has(key):return
	var list: Array=zones[key]["monsters"]
	for i: int in range(list.size()):
		if list[i]["uid"]==uid:list.remove_at(i);return

func snapshot() -> Dictionary:
	return {"zones":zones.duplicate(true),"overrides":overrides.duplicate(true),"period_serial":period_serial,"next_uid":next_uid}

func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or not value.get("zones") is Dictionary or not value.get("overrides") is Dictionary:return false
	for field: String in ["period_serial","next_uid"]:
		var n: Variant=value.get(field)
		if not (n is float or n is int) or not is_finite(float(n)) or float(n)!=floor(float(n)) or int(n)<0:return false
	if int(value["next_uid"])<1 or value["zones"].size()>1000:return false
	var seen: Dictionary={}
	for key: String in value["zones"]:
		var parts:=key.split("/")
		if parts.size()!=4 or not parts[2] in ["classroom","corridor"]:return false
		var entry: Variant=value["zones"][key]
		if not entry is Dictionary or not entry.get("monsters") is Array:return false
		if entry["monsters"].size()>(2 if parts[2]=="classroom" else 3):return false
		for monster: Variant in entry["monsters"]:
			if not monster is Dictionary or not rules.data["monsters"].has(monster.get("id")) or not monster.get("uid") is String:return false
			var uid: String=monster["uid"]
			if not uid.is_valid_int() or int(uid)<1 or int(uid)>=int(value["next_uid"]) or seen.has(uid):return false
			seen[uid]=true
			for field: String in ["level","hp"]:
				var n: Variant=monster.get(field)
				if not (n is float or n is int) or not is_finite(float(n)) or float(n)!=floor(float(n)):return false
			if int(monster["level"])<1 or int(monster["level"])>rules.maximum_monster_level():return false
			if int(monster["hp"])<1 or int(monster["hp"])>int(rules.monster_stats(monster["id"],int(monster["level"]))["hp"]):return false
			if monster.has("position"):
				if not monster["position"] is Array or monster["position"].size()!=2:return false
				for number: Variant in monster["position"]:
					if not (number is float or number is int) or not is_finite(float(number)):return false
	for key: String in value["overrides"]:
		if not value["overrides"][key] is Dictionary:return false
		var patch: Dictionary=value["overrides"][key]
		if patch.has("enabled") and not patch["enabled"] is bool:return false
		for field: String in ["level","initial_count","capacity"]:
			if not patch.has(field):continue
			var n: Variant=patch[field]
			if not (n is int or n is float) or not is_finite(float(n)) or float(n)!=floor(float(n)) or int(n)<0 or int(n)>100:return false
			if field=="level" and int(n)>rules.maximum_monster_level():return false
		if patch.has("level_mode") and not patch["level_mode"] in ["fixed","hero_relative"]:return false
		if patch.has("bounds"):
			if not patch["bounds"] is Array or patch["bounds"].size()!=4:return false
			for number: Variant in patch["bounds"]:
				if not (number is int or number is float) or not is_finite(float(number)):return false
			if float(patch["bounds"][2])<=0 or float(patch["bounds"][3])<=0:return false
	return true

func restore(value: Dictionary) -> void:
	reset()
	if value.is_empty():return
	zones=value["zones"].duplicate(true);overrides=value["overrides"].duplicate(true)
	period_serial=int(value["period_serial"]);next_uid=int(value["next_uid"])
