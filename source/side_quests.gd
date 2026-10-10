extends RefCounted

# Quest state lives in the existing quest save, not campaign indices. No NPC
# duplicates, frame polling, or background maps are needed for side stories.
var game: Node2D
var busy:=false
var point_scene:=0
var point_cache: Dictionary={}

func quests() -> Dictionary:
	var result: Dictionary={}
	for id: String in game.task_system.definitions:
		if game.task_system.definitions[id].has("side_story"):result[id]=game.task_system.definitions[id]
	return result

func unlocked(spec: Dictionary) -> bool:
	var story: Dictionary=spec["side_story"]
	var entry: Dictionary=game.task_system.entries.get(spec["id"],{})
	if not (game.campaign.active() or story.get("life_story",false)) or game.campaign.index<int(story.get("min_index",3)) or not game.task_system.prerequisites_met(spec["id"]):return false
	# Accepted investigations survive a falling bond or their owner's death.
	if not entry.is_empty() and not can_restart(spec,entry):return true
	if story.get("chapter_bridge",false):return true
	return game.relationships.alive(story["owner"]) and game.relationships.bond(story["owner"])>=int(story.get("requires_affinity",0))

func can_restart(spec: Dictionary, entry: Dictionary) -> bool:
	return spec["side_story"].get("daily",false) and entry.get("reward_claimed",false) and int(entry.get("reward_day",-1))<game.economy.day_serial

func options_for(actor: String) -> Array:
	var options: Array=[]
	for id: String in quests():
		var spec: Dictionary=game.task_system.definitions[id]
		if not unlocked(spec):continue
		var owner: String=spec["side_story"]["owner"]
		var entry: Dictionary=game.task_system.entries.get(id,{})
		var wanted: String=""
		if entry.get("status","")=="active":wanted=spec["steps"][int(entry["step"])].get("actor","")
		if actor!=owner and actor!=wanted:continue
		var state: String="接取" if entry.is_empty() or can_restart(spec,entry) else "继续" if wanted==actor else "进度" if entry.get("status","")=="active" else "回访" if entry.get("reward_claimed",false) else "领取奖励"
		options.append(["side/"+id,("十班旧事" if spec["side_story"].get("memo_story",false) else "章节调查" if spec["side_story"].get("chapter_bridge",false) else "日常委托" if spec["side_story"].get("daily",false) else "校园支线" if spec["side_story"].get("life_story",false) else "同学支线")+" · "+spec["title"]+"（"+state+"）"])
	return options

func rewards_text(spec: Dictionary) -> String:
	var reward: Dictionary=spec["side_story"]["reward"]
	var parts: Array[String]=["%dg" % int(reward.get("g",0))]
	for id: String in reward.get("items",{}):parts.append(str(game.economy.catalog[id]["name"])+" ×"+str(int(reward["items"][id])))
	return " / ".join(parts)

func hint_for(spec: Dictionary, entry: Dictionary) -> String:
	if entry.get("status","")=="completed":return "已完成并领取" if entry.get("reward_claimed",false) else "返回委托人领取奖励"
	var step: Dictionary=spec["steps"][int(entry["step"])]
	var actor: String=step.get("actor","")
	return str(step["hint"])+( " → "+game.campaign.location_name(game.campaign.scheduled_location(actor)) if not actor.is_empty() else "")

func journal_text() -> String:
	var text:="同学支线与日常委托：走近对应同学，选择支线。奖励需完成并交回；日常委托每天各一次。\n"
	for id: String in quests():
		var spec: Dictionary=game.task_system.definitions[id]
		var entry: Dictionary=game.task_system.entries.get(id,{})
		var owner: String=spec["side_story"]["owner"]
		text+="\n"+str(spec["title"])+" · "+str(game.npc_catalog.characters[owner]["display_name"])+"\n"
		if not unlocked(spec):text+="需主线进度与好感%d；委托人死亡后不再开启新的个人故事。" % int(spec["side_story"].get("requires_affinity",0))
		elif entry.is_empty() or can_restart(spec,entry):text+="可接取 → "+game.campaign.location_name(game.campaign.scheduled_location(owner))
		else:text+=hint_for(spec,entry)
		text+="\n报酬："+rewards_text(spec)+"\n"
	return text

func open_journal() -> void:
	if game.story_system.running or game.battle_view.visible:return
	game.menu_view.hide()
	game.story_system.begin_sequence()
	var options: Array=[["close","关闭：去找对应同学"]]
	for id: String in quests():
		if archive_available(id):options.push_front([id,"遗留调查 · "+str(quests()[id]["title"])])
	var answer: String=await game.campaign.choose(journal_text(),options)
	if answer!="close" and archive_available(answer):await archive_service(answer)
	game.story_system.end_sequence()

func archive_available(id: String) -> bool:
	var spec: Dictionary=quests()[id];var story: Dictionary=spec["side_story"]
	if not unlocked(spec):return false
	var entry: Dictionary=game.task_system.entries.get(id,{})
	if entry.is_empty():return story.get("chapter_bridge",false) and not game.relationships.alive(story["owner"])
	if entry.get("status","")=="completed":return not entry.get("reward_claimed",false) and not game.relationships.alive(story["owner"])
	var actor: String=spec["steps"][int(entry["step"])].get("actor","")
	return not actor.is_empty() and not game.relationships.alive(actor)

func archive_service(id: String) -> void:
	if not archive_available(id) or busy:return
	busy=true
	var spec: Dictionary=quests()[id];var entry: Dictionary=game.task_system.entries.get(id,{})
	await game.campaign.dialog([{"actor":"system","text":"角色已经死亡。这是他留下的调查笔记和未完成的工作；物资、机关与行动时段仍需亲自完成。奖励来自原先封存的任务物资，不会让死者复活。"}])
	if entry.is_empty():
		await game.campaign.dialog(spec["side_story"]["intro"])
		if await game.campaign.choose(spec["title"]+"\n接手遗留的章节调查？",[["accept","整理笔记，接手调查"],["cancel","暂时放下"]])=="accept":game.task_system.start(id);changed()
	elif entry.get("status","")=="completed":claim(id)
	else:await perform_step(id,int(entry["step"]))
	busy=false

func service(actor: String, id: String) -> void:
	if busy or not quests().has(id):return
	var spec: Dictionary=game.task_system.definitions[id]
	if not unlocked(spec):return
	busy=true
	var entry: Dictionary=game.task_system.entries.get(id,{})
	if entry.is_empty() or can_restart(spec,entry):
		if actor!=spec["side_story"]["owner"]:busy=false;return
		await game.campaign.dialog(spec["side_story"]["intro"])
		if await game.campaign.choose(spec["title"]+"\n"+str(spec["side_story"]["description"])+"\n报酬："+rewards_text(spec),[["accept","接下委托"],["later","下次再来"]])=="accept":
			if not entry.is_empty():game.task_system.entries.erase(id)
			game.task_system.start(id);changed()
		busy=false;return
	if entry.get("status","")=="completed":
		if not entry.get("reward_claimed",false):claim(id)
		await game.campaign.dialog(spec["side_story"].get("epilogue",spec["side_story"]["outro"]))
	elif spec["steps"][int(entry["step"])].get("actor","")==actor:
		await perform_step(id,int(entry["step"]))
	else:await game.campaign.dialog([{"actor":actor,"text":"这件事不用急，任务记录里写着下一步："+hint_for(spec,entry)}])
	busy=false

func interactions() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var groups: Dictionary={}

	for id: String in quests():
		var spec: Dictionary=game.task_system.definitions[id]
		var entry: Dictionary=game.task_system.entries.get(id,{})
		if entry.get("status","")!="active" or not unlocked(spec):continue
		var step: Dictionary=spec["steps"][int(entry["step"])];var location: String=step.get("location","")
		if location.is_empty() or not game.campaign.location_matches(location):continue
		var at: Vector2=game.campaign.outdoor_point(location) if not location.contains(":") else Vector2(120,180)
		if location.contains(":"):
			at=interior_point(location)
		if groups.has(location):
			var group: Dictionary=result[int(groups[location])]
			group["quests"].append(id);group["name"]="支线调查（%d项）" % group["quests"].size()
			continue
		groups[location]=result.size()
		# Distinct quests can share a location, but each has its own command.
		result.append({"action":"side_quest","quest":id,"quests":[id],"location":location,"step":int(entry["step"]),"at":at,"art_rect":Rect2(at-Vector2(8,8),Vector2(16,16)),"trigger":Rect2(),"name":"支线 · "+str(step.get("marker",spec["title"]))})
	return result

func interior_point(location: String) -> Vector2:
	var scene_id: int=game.terrain.current_scene.get_instance_id()
	if scene_id!=point_scene:point_scene=scene_id;point_cache.clear()
	if point_cache.has(location):return point_cache[location]
	var target:=Vector2(120,180);var at:=target
	var nav: RefCounted=game.motion_navigation()
	if not nav.walkable(at):
		var distance:=INF;var grid: AStarGrid2D=nav.astar
		for y: int in range(grid.region.size.y):
			for x: int in range(grid.region.size.x):
				var cell:=Vector2i(x,y)
				if grid.is_point_solid(cell):continue
				var candidate:=grid.get_point_position(cell)
				if candidate.distance_squared_to(Vector2(75,180))<900:continue
				if candidate.distance_squared_to(target)<distance:distance=candidate.distance_squared_to(target);at=candidate
	point_cache[location]=at
	return at

func handle(item: Dictionary) -> void:
	if busy or game.story_system.running:return
	if not game.campaign.location_matches(str(item.get("location",""))):return
	busy=true;game.story_system.begin_sequence()
	var id: String=item["quest"]
	if item.get("quests",[]).size()>1:
		var choices: Array=[]
		for quest_id: String in item["quests"]:choices.append([quest_id,str(game.task_system.definitions[quest_id]["title"])])
		choices.append(["cancel","暂时离开"])
		id=await game.campaign.choose("此处的支线调查",choices)
	if id!="cancel" and game.task_system.entries.get(id,{}).get("status","")=="active":await perform_step(id,int(game.task_system.entries[id]["step"]))
	game.story_system.end_sequence();busy=false

func perform_step(id: String, number: int) -> void:
	var entry: Dictionary=game.task_system.entries.get(id,{})
	if entry.get("status","")!="active" or int(entry["step"])!=number:return
	var spec: Dictionary=game.task_system.definitions[id];var step: Dictionary=spec["steps"][number]
	if step.has("periods") and step["periods"].filter(func(value: Variant):return int(value)==game.day_clock.current_period).is_empty():
		game.show_notice("请在"+"、".join(step.get("period_names",[]))+"进行这一步；任务会保留。");return
	if not str(step["event"]).begins_with("side/"):return # Combat objectives require actual game events.
	for material: String in step.get("consume",{}):
		if game.economy.quantity(material)<int(step["consume"][material]):
			game.show_notice("材料不足："+str(game.economy.catalog[material]["name"])+" ×"+str(step["consume"][material]));return
	if spec["side_story"].get("memo_story",false) and not game.relationships.alive(spec["side_story"]["owner"]):
		await game.campaign.dialog([{"actor":"system","text":"委托人已经不在了。接下来的话语和动作都出自先前留存的班史记录；你正在读旧页、整理未完的工作，不是在与死者见面。"}])
	await game.campaign.dialog(step.get("dialogue",[]))
	if step.has("puzzle"):
		var board:=preload("res://puzzle_board.gd").new();board.game=game
		if not await board.run(step["puzzle"],entry,str(number)):return
	if step.has("choices"):
		var answer: String=await game.campaign.choose(step["question"],step["choices"])
		if answer=="cancel":return
		if step.get("branches",{}).has(answer):
			await game.campaign.dialog(step["branches"][answer])
			if not entry.has("decisions"):entry["decisions"]={}
			entry["decisions"][str(number)]=answer
		elif answer!=step.get("correct",""):
			await game.campaign.dialog(step["retry"]);return
		else:await game.campaign.dialog(step.get("resolution",[]))
	for material: String in step.get("consume",{}):game.economy.inventory[material]=game.economy.quantity(material)-int(step["consume"][material])
	game.record_game_event(step["event"])
	if entry["status"]=="completed":
		await game.campaign.dialog(spec["side_story"]["outro"]);claim(id)
	game.campaign.advance_phase();game.sync_classroom_period();game.apply_time_lighting();changed()

func claim(id: String) -> bool:
	var entry: Dictionary=game.task_system.entries.get(id,{})
	if entry.get("status","")!="completed" or entry.get("reward_claimed",false):return false
	var spec: Dictionary=game.task_system.definitions[id];var reward: Dictionary=spec["side_story"]["reward"]
	for material: String in reward.get("items",{}):
		if game.economy.quantity(material)+int(reward["items"][material])>game.economy.STACK_CAP:
			game.show_notice("背包物资已满，整理后找委托人领取。奖励会保留。");return false
	# Mark before emitting inventory/task signals. Save/load cannot pay twice.
	game.sounds.play("quest_complete")
	entry["reward_claimed"]=true;entry["reward_day"]=game.economy.day_serial
	game.economy.money+=int(reward.get("g",0))
	for material: String in reward.get("items",{}):game.economy.add_item(material,int(reward["items"][material]))
	if not spec["side_story"].get("daily",false) and game.relationships.alive(spec["side_story"]["owner"]):game.campaign.adjust({"BOND_"+str(spec["side_story"]["owner"]):8})
	game.show_notice("支线完成："+spec["title"]+" · "+rewards_text(spec));changed();return true

func changed() -> void:
	game.task_system.changed.emit();game.economy.changed.emit();game.campaign.queue_redraw()
