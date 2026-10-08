extends RefCounted

var data: Dictionary={}
var hero: Dictionary={}

func configure(path: String, content: Dictionary={}) -> bool:
	var parsed: Variant=content.duplicate(true) if not content.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:return false
	data=parsed
	if not data.get("monsters") is Dictionary or not data.get("hero") is Dictionary:return false
	reset_hero()
	return true

func growth(entry: Dictionary, level: int) -> int:
	var amount:=float(entry.get("base",0))+float(entry.get("growth",0))*pow(float(level),float(entry.get("exponent",1)))
	for term: Dictionary in entry.get("terms",[]):amount+=float(term.get("growth",0))*pow(float(level),float(term.get("exponent",1)))
	return floori(amount)

func maximum_level() -> int:
	return maxi(1,int(data.get("level_cap",60)))

func maximum_monster_level() -> int:
	return maxi(maximum_level(),int(data.get("monster_level_cap",maximum_level()+10)))

func character_stats(profile_id: String, level: int) -> Dictionary:
	var profile: Dictionary=data.get("character_profiles",{}).get(profile_id,{})
	if profile.is_empty():return {}
	var result: Dictionary={"id":profile_id,"level":clampi(level,0,maximum_level())}
	for key: String in profile.get("stats",{}):result[key]=growth(profile["stats"][key],int(result["level"]))
	return result

func hero_stats(level: int, equipment: Dictionary={}) -> Dictionary:
	level=clampi(level,0,maximum_level())
	var result: Dictionary={"level":level,"physical_reduction":0.0,"magic_reduction":0.0}
	for key: String in data["hero"]["stats"]:result[key]=growth(data["hero"]["stats"][key],level)
	for slot: String in equipment:
		var item: Dictionary=data.get("equipment",{}).get(equipment[slot],{})
		if item.get("slot","")!=slot:continue
		for key: String in item.get("bonuses",{}):result[key]=int(result.get(key,0))+int(item["bonuses"][key])
	return result

func reset_hero() -> void:
	hero=hero_stats(int(data["hero"].get("initial_level",0)))
	hero["experience"]=0
	hero["equipment"]={};hero["skills"]=[]
	for key: String in ["hp","mp","energy","san"]:hero[key+"_current"]=hero[key]

func set_hero_level(level: int, refill: bool=false) -> void:
	var updated:=hero_stats(level,hero.get("equipment",{}))
	updated["equipment"]=hero.get("equipment",{}).duplicate(true)
	updated["skills"]=hero.get("skills",[]).duplicate()
	updated["experience"]=int(hero.get("experience",0))
	for key: String in ["hp","mp","energy","san"]:updated[key+"_current"]=updated[key] if refill else mini(int(hero.get(key+"_current",updated[key])),int(updated[key]))
	hero=updated

func refill_hero() -> void:
	for key: String in ["hp","mp","energy","san"]:hero[key+"_current"]=hero[key]

func experience_required(level: int) -> int:
	var spec: Dictionary=data.get("experience",{"required_base":100,"required_exponent":1.5})
	return floori(float(spec["required_base"])*pow(float(clampi(level,0,maximum_level())),float(spec["required_exponent"])))

func grant_kill_experience(enemy_max_hp: int) -> Dictionary:
	var gained:=maxi(0,enemy_max_hp)*int(hero["level"])
	var before:=int(hero["level"])
	hero["experience"]=int(hero.get("experience",0))+gained
	# At level zero the threshold is exactly zero. Promotion is evaluated
	# only on a kill event, and increments the level, so it cannot loop forever.
	while int(hero["level"])<maximum_level() and int(hero["experience"])>=experience_required(int(hero["level"])):
		var level:=int(hero["level"])
		var remaining:=int(hero["experience"])-experience_required(level)
		var previous:=hero.duplicate()
		set_hero_level(level+1)
		hero["experience"]=remaining
		for key: String in ["hp","mp","energy","san"]:hero[key+"_current"]=mini(int(hero[key]),int(previous[key+"_current"])+int(hero[key])-int(previous[key]))
	return {"gained":gained,"levels":int(hero["level"])-before,"level":hero["level"],"experience":hero["experience"]}

func monster_stats(id: String, level: int) -> Dictionary:
	level=clampi(level,1,maximum_monster_level())
	var spec: Dictionary=data["monsters"][id]
	var bases: Dictionary=data["monster_base"]
	var result: Dictionary={"id":id,"name":spec["name"],"level":level,"physical_reduction":spec.get("physical_reduction",0.0),"magic_reduction":spec.get("magic_reduction",0.0),"penetration":0}
	result["rarity"]=spec.get("rarity","normal")
	result["elemental_reductions"]=spec.get("elemental_reductions",{}).duplicate()
	for key: String in ["hp","attack","defense","magic_resistance"]:result[key]=floori(growth(bases[key],level)*float(spec.get("multipliers",{}).get(key,1.0)))
	return result

func damage(attacker: Dictionary, defender: Dictionary, kind: String="physical", temporary_reduction: float=0.0, element: String="", multiplier: float=1.0, amplifier: float=1.0) -> int:
	var attack:=maxi(0,floori(int(attacker["attack"])*multiplier))
	# Level zero is legal: numerator remains zero; only a zero denominator is
	# replaced with one. Apply the user's minimum after all mitigation.
	var ratio:=float(attacker["level"])/maxi(1,int(defender["level"]))
	var amount:=0.0
	if kind=="magic":amount=attack*ratio*(1.0-float(defender.get("magic_reduction",0)))*(1.0-temporary_reduction)-float(defender.get("magic_resistance",0))
	else:
		var defense:=maxf(0,float(defender.get("defense",0))-float(attacker.get("penetration",0)))
		amount=attack*ratio*maxf(0,(100.0-defense)/100.0)*(1.0-float(defender.get("physical_reduction",0)))*(1.0-temporary_reduction)
	if kind=="magic":amount*=1.0-float(defender.get("elemental_reductions",{}).get(element,0))
	var value:=floori(maxf(floori(attack*.1),floori(amount))*amplifier)
	if defender.get("rarity","") in ["elite","boss"]:value=mini(value,maxi(1,floori(int(defender["hp"])*float(data.get("elite_damage_cap_ratio",.7)))))
	return value

func restore(snapshot: Dictionary) -> void:
	reset_hero()
	if not snapshot.has("hero"):return
	var saved: Dictionary=snapshot["hero"]
	hero["equipment"]=saved.get("equipment",{}).duplicate(true)
	hero["skills"]=saved.get("skills",[]).duplicate()
	set_hero_level(int(saved.get("level",0)),true)
	hero["experience"]=int(saved.get("experience",0))
	for key: String in ["hp","mp","energy","san"]:hero[key+"_current"]=clampi(int(saved.get(key+"_current",hero[key])),0,int(hero[key]))

func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary:return false
	if not value.get("hero") is Dictionary:return false
	var saved: Dictionary=value["hero"]
	for key: String in ["level","hp_current","mp_current","energy_current","san_current"]:
		var number: Variant=saved.get(key)
		if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floor(float(number)):return false
	if int(saved["level"])<0 or int(saved["level"])>maximum_level():return false
	var xp: Variant=saved.get("experience",0)
	if not (xp is float or xp is int) or not is_finite(float(xp)) or float(xp)!=floor(float(xp)) or float(xp)<0 or float(xp)>1e12:return false
	if not saved.get("equipment",{}) is Dictionary or not saved.get("skills",[]) is Array:return false
	for slot: String in saved.get("equipment",{}):
		var spec: Dictionary=data.get("equipment",{}).get(saved["equipment"][slot],{})
		if spec.is_empty() or spec.get("slot")!=slot:return false
	var learned_ids: Dictionary={}
	for id: Variant in saved.get("skills",[]):
		if not id is String or not data.get("skills",{}).has(id):return false
		if learned_ids.has(id):return false
		learned_ids[id]=true
	var stats:=hero_stats(int(saved["level"]),saved.get("equipment",{}))
	for key: String in ["hp","mp","energy","san"]:
		# Earlier builds used MP exponent 2; load and clamp those saves on restore.
		var ceiling: int=maxi(int(stats[key]),100+20*int(saved["level"])*int(saved["level"])) if key=="mp" else int(stats[key])
		if int(saved[key+"_current"])<0 or int(saved[key+"_current"])>ceiling:return false
	return true

func equip(id: String) -> bool:
	var item: Dictionary=data.get("equipment",{}).get(id,{})
	if item.is_empty():return false
	hero["equipment"][item["slot"]]=id;set_hero_level(int(hero["level"]));return true

func learn(id: String) -> bool:
	if not data.get("skills",{}).has(id) or id in hero["skills"]:return false
	hero["skills"].append(id);return true

func spell_cost(tier: String, doubled: bool=false) -> int:
	var spec: Dictionary=data["magic_tiers"][tier]
	return (int(spec["base"])+int(spec["growth"])*int(hero["level"]))* (2 if doubled else 1)

func energy_cost(spec: Dictionary) -> int:
	return int(spec.get("energy_cost",0))+ceili(int(hero["energy"])*float(spec.get("energy_ratio",0)))

func energy_recovery() -> int:
	var spec: Dictionary=data.get("energy_rules",{})
	return maxi(int(spec.get("minimum",10)),floori(int(hero["energy"])*float(spec.get("turn_ratio",.03))))

func recover_turn_energy() -> int:
	var amount:=mini(energy_recovery(),int(hero["energy"])-int(hero["energy_current"]))
	hero["energy_current"]+=amount
	return amount
