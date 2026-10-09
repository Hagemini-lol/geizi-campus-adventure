extends RefCounted

# Explicit, save-scoped edits. Normal balance/configuration files remain intact.
var game: Node2D
var unlocked:=false
var used:=false
var hero: Dictionary={}
var monsters: Dictionary={}
var validation: Dictionary={}
const HERO_FIELDS: Array[String]=["hp","mp","energy","san","attack","defense","magic_resistance","penetration","physical_reduction","magic_reduction"]
const MONSTER_FIELDS: Array[String]=["hp","attack","defense","magic_resistance","penetration","physical_reduction","magic_reduction"]

func bounds(field: String) -> Vector2:
	if field.ends_with("reduction"):return Vector2(0,1)
	return Vector2(1 if field=="hp" else 0,1000000000)

func apply_stats(stats: Dictionary, values: Dictionary) -> Dictionary:
	for field: String in values:stats[field]=float(values[field]) if field.ends_with("reduction") else int(values[field])
	return stats

func hero_values() -> Dictionary:return validation.get("hero",hero)
func monster_values(id: String) -> Dictionary:return validation.get("monsters",monsters).get(id,{})

func edit(scope: String, id: String, field: String, amount: float) -> bool:
	if not unlocked or not is_finite(amount):return false
	var n:=floori(amount)
	match scope:
		"hero":
			if field in HERO_FIELDS:
				var limits:=bounds(field);hero[field]=clampf(amount,limits.x,limits.y) if field.ends_with("reduction") else clampi(n,int(limits.x),int(limits.y))
				game.combat_rules.set_hero_level(int(game.combat_rules.hero["level"]))
			elif field=="level":game.combat_rules.set_hero_level(clampi(n,0,60))
			elif field=="experience":game.combat_rules.hero[field]=clampi(n,0,1000000000)
			elif field in ["hp_current","mp_current","energy_current","san_current"]:game.combat_rules.hero[field]=clampi(n,0,int(game.combat_rules.hero[field.trim_suffix("_current")]))
			else:return false
			if field in ["san","san_current"]:game.campaign.flags["SAN"]=clampi(roundi(float(game.combat_rules.hero["san_current"])*100/maxi(1,int(game.combat_rules.hero["san"]))),0,100)
		"money":game.economy.money=clampi(n,0,1000000000)
		"item":
			if not game.economy.catalog.has(id):return false
			game.economy.inventory[id]=clampi(n,0,game.economy.STACK_CAP)
		"affinity":
			if not game.npc_catalog.characters.has(id) and not id.begins_with("local/"):return false
			game.relationships.affinity[id]=clampi(n,-100,100)
			if not id.begins_with("local/"):game.campaign.flags["BOND_"+id]=clampi(n,-100,100)
			game.relationships.revision+=1
		"campaign":
			if not game.campaign.flags.has(id) or game.campaign.flags[id] is bool or game.campaign.flags[id] is String:return false
			game.campaign.flags[id]=clampi(n,-100 if id.begins_with("BOND_") else 0,5 if id=="GOU_UNDERSTAND" else 3 if id in ["STATE","rune_mistakes"] else 100)
			if id=="SAN":game.campaign.change_san(0)
			if id.begins_with("BOND_"):game.relationships.affinity[id.trim_prefix("BOND_")]=game.campaign.flags[id]
		"monster":
			if not game.combat_rules.data["monsters"].has(id) or not field in MONSTER_FIELDS:return false
			if not monsters.has(id):monsters[id]={}
			var limits:=bounds(field);monsters[id][field]=clampf(amount,limits.x,limits.y) if field.ends_with("reduction") else clampi(n,int(limits.x),int(limits.y))
		_:return false
	used=true;game.economy.changed.emit();game.update_time_display();return true

func snapshot() -> Dictionary:return {"version":1,"unlocked":unlocked,"used":used,"hero":hero.duplicate(),"monsters":monsters.duplicate(true)}

func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not value.get("unlocked") is bool or not value.get("used") is bool or not value.get("hero") is Dictionary or not value.get("monsters") is Dictionary:return false
	if value["monsters"].size()>800 or value["hero"].size()>HERO_FIELDS.size():return false
	for scope: String in ["hero","monsters"]:
		var entries: Array=[value[scope]] if scope=="hero" else value[scope].values()
		for entry: Variant in entries:
			if not entry is Dictionary:return false
			for field: Variant in entry:
				if not field in (HERO_FIELDS if scope=="hero" else MONSTER_FIELDS):return false
				var n: Variant=entry[field];var limits:=bounds(field)
				if not (n is float or n is int) or not is_finite(float(n)) or float(n)<limits.x or float(n)>limits.y:return false
				if not field.ends_with("reduction") and n!=floor(float(n)):return false
	for id: Variant in value["monsters"]:
		if not id is String or id.length()>100:return false
	return true

func restore(value: Dictionary) -> void:
	unlocked=value.get("unlocked",false);used=value.get("used",false);hero=value.get("hero",{}).duplicate();monsters=value.get("monsters",{}).duplicate(true)
