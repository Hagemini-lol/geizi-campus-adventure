extends RefCounted

var game: Node2D
var scene_id:=0
var inside: Dictionary={}

func candidates() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	result.append_array(game.story_system.extra_interactions())
	if game.story_system.door_active():
		for portal: Dictionary in game.terrain.current_scene.portals:
			if portal["action"]=="room" and int(portal["room"])==int(game.story_system.data["lab_room"]):result.append(portal)
	if game.story_system.stage==2 and game.interior_state.is_empty():
		for entry: Dictionary in game.interior_info["entrances"]:
			if entry["id"]=="B02":result.append({"action":"entrance","building":"B02","at":game.point(entry["arrival"])*24})
	if game.campaign!=null:
		for item: Dictionary in game.campaign.extra_interactions():
			if item["action"]=="campaign_house" and not str(game.campaign.current().get("location","")).begins_with("STORY_"):continue
			result.append(item)
	return result

func key_for(item: Dictionary) -> String:
	return "side/"+str(item.get("location","")) if item["action"]=="side_quest" else "main" if item["action"]=="campaign" else str(item["action"])

func radius_for(item: Dictionary) -> float:
	if game.interior_state.is_empty():return 100.0
	if item["action"]=="story_seat":return 32.0
	if item["action"]=="room":return 40.0
	return 48.0

func eligible(item: Dictionary) -> bool:
	if item["action"]=="campaign":
		var node: Dictionary=game.campaign.current()
		if not game.campaign.available_now(node):return false
		var bridge: String=str(node.get("bridge_quest",""))
		if not bridge.is_empty() and game.task_system.entries.get(bridge,{}).get("status","")!="completed":return false
		if int(game.combat_rules.hero["level"])<int(node.get("require_level",0)) or node.get("require_medium",false) and not game.campaign.has_medium():return false
		return int(node.get("cost",0))<=game.economy.money and game.campaign.has_materials(node.get("materials",{}))
	if item["action"]=="side_quest":
		for id: String in item.get("quests",[item["quest"]]):
			var entry: Dictionary=game.task_system.entries.get(id,{})
			if entry.get("status","")!="active":continue
			var step: Dictionary=game.task_system.definitions[id]["steps"][int(entry["step"])]
			if step.has("periods") and step["periods"].filter(func(p: Variant):return int(p)==game.day_clock.current_period).is_empty():continue
			var enough:=true
			for material: String in step.get("consume",{}):
				if game.economy.quantity(material)<int(step["consume"][material]):enough=false
			if enough and str(step["event"]).begins_with("side/"):return true
		return false
	return true

func tick() -> bool:
	if OS.get_cmdline_user_args().has("--manual-story-checks"):return false
	if game.terrain.current_scene==null:return false
	var token: int=game.terrain.current_scene.get_instance_id()
	if token!=scene_id:scene_id=token;inside.clear()
	if not game.game_started or game.transition_busy or game.paused or game.player.frozen or game.interaction_delay>0 or game.map_view.visible or game.menu_view.visible or game.front_end.visible or game.dialogue_view.visible or game.battle_view.visible or game.lesson_blocked() or game.story_blocked() or game.side_quests.busy:return false
	var present: Dictionary={}
	for item: Dictionary in candidates():
		var key:=key_for(item)
		var entered: bool=game.player.position.distance_to(item["at"])<=radius_for(item)
		present[key]=entered
		if not entered:inside.erase(key);continue
		if inside.has(key) or not eligible(item):continue
		inside[key]=true
		game.player.path.clear();game.player.velocity=Vector2.ZERO
		if item["action"]=="campaign":game.campaign.run_event()
		elif item["action"]=="side_quest":game.side_quests.handle(item)
		elif item["action"]=="campaign_house":game.campaign.handle(item)
		else:game.story_system.handle(item)
		return true
	for key: String in inside.keys():
		if not present.get(key,false):inside.erase(key)
	return false
