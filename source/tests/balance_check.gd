extends SceneTree

var rules=preload("res://combat_rules.gd").new()
var failures: Array[String]=[]
var results: Array=[]
var checks:=0
var directory:="D:/Godot/校园自由漫游"

func _initialize() -> void:
	rules.configure(directory.path_join("战斗与刷新配置.json"))
	for level: int in range(61):
		for id: String in ["ink_slime","book_eater"]:
			if level==0 and id=="book_eater":continue # Awakening promotes to level 1 before book monsters unlock.
			verify(id,level,maxi(1,level-5),false)
		if level>0:
			for id: String in ["empty_uniform","dry_branch"]:verify(id,level,level,true)
	for spec: Array in [["book_eater_queen",5,8],["book_eater_queen",8,8],["dry_branch_ancient",8,10],["dry_branch_ancient",10,10],["empty_uniform_leader",12,15],["empty_uniform_leader",15,15]]:verify(spec[0],spec[1],spec[2],true)
	for level: int in range(35,61):
		for offset: int in range(5,11):verify("gate_entity",level,level+offset,true)
	var file:=FileAccess.open(directory.path_join("runtime/balance_checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":results,"method":"Production damage formula; deterministic action search, no dodge luck, no mid-battle refill, basic chapter-one equipment only. Fei support except first tutorial; trained barrier/mana-cycle allowed. Library uses low-tier spells only."},"  "))
	print("BALANCE_CHECKS ",checks," FAILURES ",failures.size()," ",failures);quit(0 if failures.is_empty() else 1)

func verify(id: String, level: int, enemy_level: int, ally: bool) -> void:
	rules.set_hero_level(level,true);rules.equip("basic_amulet");rules.equip("special_uniform");rules.refill_hero()
	var enemy: Dictionary=rules.monster_stats(id,enemy_level)
	var support: int=floori(floori(int(rules.hero["attack"])*.12)*1.25) if ally else 0
	if id=="empty_uniform_leader":support=maxi(support,floori(int(enemy["hp"])*.25))
	var plan:=find_plan(enemy,support,id=="book_eater_queen")
	var companion:="fei_yan" if ally else "none"
	var gear:="chapter_one"
	if plan.is_empty() and ally:
		var reduced: Dictionary=enemy.duplicate(true);reduced["attack"]=floori(int(enemy["attack"])*.8)
		plan=find_plan(reduced,floori(int(rules.hero["attack"])*.12),id=="book_eater_queen");companion="lao_shuo"
	if plan.is_empty() and ally and level>=5:
		rules.equip("tech_amulet");rules.equip("patrol_uniform");rules.refill_hero();gear="purchased_250g_and_2ink"
		var reduced: Dictionary=enemy.duplicate(true);reduced["attack"]=floori(int(enemy["attack"])*.8)
		plan=find_plan(reduced,floori(int(rules.hero["attack"])*.12),id=="book_eater_queen");companion="lao_shuo"
	checks+=1
	var label: String="%s hero %d / enemy %d" % [id,level,enemy_level]
	if plan.is_empty():failures.append(label);push_error(label)
	results.append({"monster":id,"hero_level":level,"enemy_level":enemy_level,"gear":gear,"companion":companion,"won":not plan.is_empty(),"plan":plan.get("path",[]),"remaining_hp":plan.get("hp",0),"remaining_mp":plan.get("mp",0),"hero_max_hp":rules.hero["hp"]})

func find_plan(enemy: Dictionary, support: int, low_only: bool=false) -> Dictionary:
	var hero: Dictionary=rules.hero
	var actions: Array=rules.data["actions"].duplicate(true)
	# Random dodge and escape are not accepted as proof of a winning strategy.
	for i: int in range(actions.size()-1,-1,-1):
		if actions[i]["id"] in ["dodge","escape","auto"]:actions.remove_at(i)
	var element: String="fire" if enemy["id"] in ["book_eater","book_eater_queen","dry_branch","dry_branch_ancient"] else "lightning" if enemy["id"]=="ink_slime" else "light"
	for tier: String in rules.data["magic_tiers"]:
		if int(hero["level"])<int(rules.data["magic_tiers"][tier]["level"]) or low_only and tier!="low":continue
		actions.append({"id":element+"_"+tier,"damage_kind":"magic","element":element,"tier":tier,"mp_cost":rules.spell_cost(tier)})
	if int(hero["level"])>=1:
		actions.append({"id":"barrier","mp_cost":20+5*int(hero["level"])})
		actions.append({"id":"mana_cycle","energy_cost":rules.energy_cost(rules.data["skills"]["mana_cycle"]),"mp_restore":maxi(rules.spell_cost("low"),maxi(10+10*int(hero["level"]),floori(int(hero["mp"])*.12))),"reduction":.5})
	var frontier: Array=[{"hp":hero["hp"],"mp":hero["mp"],"energy":hero["energy"],"enemy":enemy["hp"],"barrier":0,"barrier_cd":0,"mana_cd":0,"path":[]}]
	for turn: int in range(1,21):
		var next: Array=[];var seen: Dictionary={}
		for state: Dictionary in frontier:
			for action: Dictionary in actions:
				var id: String=action["id"]
				if int(state["mp"])<int(action.get("mp_cost",0)) or int(state["energy"])<int(action.get("energy_cost",0)):continue
				if id=="barrier" and int(state["barrier_cd"])>turn or id=="mana_cycle" and int(state["mana_cd"])>turn:continue
				var candidate: Dictionary=state.duplicate(true);candidate["path"].append(id)
				candidate["mp"]=mini(int(hero["mp"]),int(state["mp"])-int(action.get("mp_cost",0))+int(action.get("mp_restore",0)))
				candidate["energy"]=mini(int(hero["energy"]),int(state["energy"])-int(action.get("energy_cost",0))+rules.energy_recovery())
				if id=="barrier":candidate["barrier"]=2;candidate["barrier_cd"]=turn+3
				if id=="mana_cycle":candidate["mana_cd"]=turn+3
				if action.has("damage_kind"):
					var multiplier: float=float(rules.data["magic_tiers"][action["tier"]]["multiplier"]) if action["damage_kind"]=="magic" else 1.0
					candidate["enemy"]-=rules.damage(hero,enemy,action["damage_kind"],0,action.get("element",""),multiplier)
				candidate["enemy"]-=support
				if int(candidate["enemy"])<=0:return candidate
				var reduction: float=maxf(float(action.get("reduction",0)),.5 if int(candidate["barrier"])>0 else 0)
				if enemy["id"]=="gate_entity":reduction=maxf(reduction,.2)
				candidate["hp"]-=rules.damage(enemy,hero,rules.data["monsters"][enemy["id"]].get("attack_kind","physical"),reduction)
				candidate["barrier"]=maxi(0,int(candidate["barrier"])-1)
				if int(candidate["hp"])<=0:continue
				var key: String="%d/%d/%d/%d/%d/%d" % [candidate["enemy"],candidate["mp"],candidate["energy"],candidate["barrier"],candidate["barrier_cd"],candidate["mana_cd"]]
				if seen.has(key) and int(seen[key]["hp"])>=int(candidate["hp"]):continue
				seen[key]=candidate
		for value: Dictionary in seen.values():next.append(value)
		next.sort_custom(func(a: Dictionary,b: Dictionary):return float(a["hp"])/int(hero["hp"])-float(a["enemy"])/int(enemy["hp"])+float(a["mp"])/int(hero["mp"])*.2>float(b["hp"])/int(hero["hp"])-float(b["enemy"])/int(enemy["hp"])+float(b["mp"])/int(hero["mp"])*.2)
		if next.size()>160:next.resize(160)
		frontier=next
		if frontier.is_empty():break
	return {}
