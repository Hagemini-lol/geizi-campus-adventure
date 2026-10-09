extends Node2D

signal selected(value: String)
var game: Node2D
var data: Dictionary={}
var index:=0
var flags: Dictionary={}
var done: Array=[]
var evidence: Dictionary={"li":[],"yang":[]}
var notes: Array=[]
var repeats: Dictionary={}
var wave:=0
var wave_node:=""
var battle_uid:=""
var failures:=0
var ending:=""
var started_day:=0
var case_day:=0
var ao_until:=0
var last_slot:=-1
var panel: Control
var modal_layer: CanvasLayer
var scene_stamp:=""
var saved_enemy: Dictionary={}
var support_id:="fei_yan"
var outdoor_points: Dictionary={}
var presentation_stamp:=""
const ROUTES: Array[String]=["H","W","D"]
const END_NAMES={"TE":"门后的人","GE-H":"一个都不少","GE-W":"与黑暗共处","GE-D":"新守印人","NE":"暂缓的门","BE-1":"门开之日","BE-2":"新的污染","BE-3":"孤岛","BE-4":"散场","GENOCIDE":"无人应答","SURVIVORS":"留下的人","REDEMPTION":"门外的明天"}

func configure(value: Dictionary) -> void:
	data=value
	for node: Dictionary in data.get("nodes",[]):
		var periods: Array=[]
		for value_period: Variant in node.get("timeWindow",[0,1,2,3,4]):periods.append(int(value_period))
		node["timeWindow"]=periods
	reset();install_interiors()

func reset() -> void:
	index=0;done=[];evidence={"li":[],"yang":[]};notes=[];repeats={};wave=0;wave_node="";battle_uid="";failures=0;ending="";started_day=-1;case_day=0;ao_until=0;last_slot=-1;scene_stamp="";saved_enemy={}
	support_id="fei_yan"
	flags={"RP_H":0,"RP_W":0,"RP_D":0,"GOU_UNDERSTAND":0,"BETRAY_COUNT":0,"STATE":0,"FINAL_ROUTE":"","SAN":100}
	for id: String in ["F_BOOK","F_TRUTH","F_LI_CLEAR","F_LI_PARTIAL","F_YANG_CLEAR","F_YANG_REMEDIED","F_AO_TRANSFORMED","F_CIVILIAN_SAFE","F_WR_CONTRACT","F_DONG_TRIAL"]:flags[id]=false

func install_interiors() -> void:
	for spec: Array in [["B06","科技中心",4],["B15","办公楼",4],["STORY_HOUSE","牢家旧宅",1],["STORY_SEAL","地下封印石室",1]]:
		var building: Dictionary=game.interior_info["buildings"]["B02"].duplicate(true)
		building["id"]=spec[0];building["name"]=spec[1];building["floors"].resize(int(spec[2]))
		for row: Dictionary in building["floors"]:
			for room: Dictionary in row["rooms"]:
				room["class10"]=false;room["office"]=false
				room["name"]="图书室" if spec[0]=="B06" else "房间"
				if spec[0]=="B15":room["office"]=true;room["office_asset"]="office_wood";room["name"]="政教处" if int(row.get("floor",1))==1 else "办公室"
		game.interior_info["buildings"][spec[0]]=building
	for entry: Dictionary in game.interior_info["entrances"]:
		if entry["id"] in ["B06","B15"]:entry["has_interior"]=true

func active() -> bool:return game.story_system.stage>=6 and not data.is_empty()
func current() -> Dictionary:return data["nodes"][index] if index<data.get("nodes",[]).size() else {}
func chapter() -> String:return str(current().get("chapter","part_9"))
func phase_slot() -> int:return game.day_clock.slot(game.economy.day_serial)
func available_now(node: Dictionary) -> bool:return game.day_clock.current_period in node.get("timeWindow",[0,1,2,3,4]) and phase_slot()!=last_slot and (started_day<0 or game.economy.day_serial>=started_day+int(node.get("min_day",0)))

func location_matches(value: String) -> bool:
	var parts:=value.split(":")
	if parts.size()==1:
		return game.interior_state.is_empty() and game.terrain.current_id>=0 and game.navigation.region_at(outdoor_point(value))==game.terrain.current_id
	return game.interior_state.get("building","")==parts[0] and int(game.interior_state.get("floor",0))==int(parts[1]) and (game.interior_state.get("kind","")=="corridor" if parts[2]=="corridor" else game.interior_state.get("kind","")=="classroom" and int(game.interior_state.get("room",-1))==int(parts[2]))

func location_name(value: String) -> String:
	if value.is_empty():return "当前休息；请在上午或下午工作时段来访"
	var parts:=value.split(":")
	if parts.size()>1:
		return str(game.interior_info["buildings"][parts[0]]["name"])+" %s楼 · " % parts[1]+("走廊" if parts[2]=="corridor" else "十班" if parts[0] in ["B01","B12"] else ("书库" if parts[2]=="1" else "图书室") if parts[0]=="B06" else "房间")
	for region: Dictionary in game.model["regions"]:
		if region["id"]==value:return region["name"]
	for zone: Dictionary in game.data["zones"]:
		if zone["id"]==value:return zone["name"]
	return value

func outdoor_point(id: String) -> Vector2:
	# Safe arrival probes are expensive; immutable campus geometry is cached.
	if outdoor_points.has(id):return outdoor_points[id]
	var result: Vector2=game.spawn
	for entry: Dictionary in game.interior_info["entrances"]:
		if entry["id"]==id:
			result=game.safe_outdoor(game.point(entry["arrival"])*24+Vector2(0,35))
			outdoor_points[id]=result;return result
	for zone: Dictionary in game.data["zones"]:
		if zone["id"]==id:
			result=game.safe_outdoor(preload("res://map_space.gd").project(game.point(zone["spawn"])));break
	outdoor_points[id]=result
	return result

func objective_text() -> String:
	if not ending.is_empty():return "结局 · "+END_NAMES.get(ending,ending)+"（菜单：剧情手册）"
	var node:=current()
	if node.is_empty():return "校园自由探索"
	return data["chapter_titles"][node["chapter"]]+"\n"+node["title"]+" → "+location_name(node["location"])

func marker_point() -> Vector2:
	var target: Vector2
	if game.interior_state.is_empty():
		target=outdoor_point(current().get("location","N02"))
	else:
		target=Vector2(75,180) if game.interior_state["kind"]=="classroom" else Vector2(95,142)
		var nav: RefCounted=game.motion_navigation()
		if not nav.walkable(target):
			var grid: AStarGrid2D=nav.astar
			for y: int in range(grid.region.size.y):
				for x: int in range(grid.region.size.x):
					if not grid.is_point_solid(Vector2i(x,y)):return grid.get_point_position(Vector2i(x,y))
	return target

func extra_interactions() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	result.append_array(game.side_quests.interactions())
	if not active() or not ending.is_empty():return result
	var node:=current()
	if not node.is_empty() and location_matches(node["location"]):
		var at:=marker_point()
		result.append({"action":"campaign","at":at,"art_rect":Rect2(at-Vector2(9,9),Vector2(18,18)),"trigger":Rect2(),"name":node["title"]})
	if location_matches("N02") and index>=20:
		var at: Vector2=game.safe_outdoor(outdoor_point("N02")+Vector2(40,0))
		result.append({"action":"campaign_house","at":at,"art_rect":Rect2(at-Vector2(8,8),Vector2(16,16)),"trigger":Rect2(),"name":"随牢董前往旧宅"})
	return result

func handle(item: Dictionary) -> bool:
	if item["action"]=="side_quest":game.side_quests.handle(item);return true
	if not active():return false
	if game.story_system.running:return true
	if item["action"]=="side_quest":game.side_quests.handle(item);return true
	if item["action"]=="campaign":run_event();return true
	if item["action"]=="campaign_house":game.change_interior({"building":"STORY_HOUSE","floor":1,"kind":"classroom","room":0});return true
	if game.interior_state.get("building","").begins_with("STORY_") and item["action"] in ["corridor","outside"]:
		var destination:="STORY_SEAL" if game.interior_state["building"]=="STORY_HOUSE" else "STORY_HOUSE"
		if item.get("side","")=="rear" or item["action"]=="outside":
			for entry: Dictionary in game.interior_info["entrances"]:
				if entry["id"]=="B01":game.teleport_outdoor(game.point(entry["arrival"])*24);return true
		game.change_interior({"building":destination,"floor":1,"kind":"classroom","room":0});return true
	if item["action"]=="npc":
		var record: Dictionary=game.terrain.current_scene.npcs.find(item["uid"])
		var node:=current()
		var bridge: String=str(node.get("bridge_quest",""))
		if not bridge.is_empty() and game.task_system.entries.get(bridge,{}).get("status","")!="completed" and not game.side_quests.options_for(str(record.get("character",""))).is_empty():
			npc_service(record["character"]);return true
		if record.get("character","") in node.get("cast",[]) and location_matches(node.get("location","")) and not node.get("require_medium",false) and not node.has("battle"):
			run_event();return true
		if record.get("character","") in ["lao_li","lao_chou","la_jiao","fei_yan","lao_dong","lao_shuo","wr","gou_ga","yang_zi","lao_ao"]:
			npc_service(record["character"]);return true
	return false

func _process(_delta: float) -> void:
	if not active() or game.terrain.current_scene==null:
		if not presentation_stamp.is_empty():presentation_stamp="";queue_redraw()
		return
	var stamp:=str(index)+"/"+ending+"/"+str(game.terrain.current_scene.get_instance_id())+"/"+str(game.transition_busy)+"/"+str(game.game_started)
	if stamp!=presentation_stamp:
		presentation_stamp=stamp;game.story_system.refresh_objective();queue_redraw()

func _draw() -> void:
	pass # Story regions have no world-space circles or floating captions.

func dialog(lines: Array) -> void:
	if lines.is_empty():return
	lines=lines.duplicate(true)
	for line: Dictionary in lines:
		if line.get("actor","")=="hero":line["actor"]="zhao_mugei"
		notes.append(str(game.npc_catalog.characters.get(line.get("actor",""),{}).get("display_name","提示"))+"："+str(line["text"]))
	while notes.size()>150:notes.pop_front()
	game.dialogue_view.begin_script(lines)
	await game.dialogue_view.script_finished

func choose(title: String, options: Array) -> String:
	modal_layer=CanvasLayer.new();modal_layer.layer=98;game.add_child(modal_layer)
	panel=Control.new();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal_layer.add_child(panel)
	var shade:=ColorRect.new();shade.color=Color(0,.02,.02,.88);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_child(shade)
	var box:=PanelContainer.new();box.theme=game.menu_view.shared_theme
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER);box.offset_left=-450;box.offset_right=450;box.offset_top=-320;box.offset_bottom=320;panel.add_child(box)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",12);box.add_child(column)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.custom_minimum_size.y=120;column.add_child(scroll)
	var caption: Label=game.label(title,21);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(caption)
	var grid:=GridContainer.new();grid.columns=2 if options.size()>4 else 1;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);column.add_child(grid)
	for pair: Array in options:
		var button:=Button.new();button.text=pair[1];button.custom_minimum_size=Vector2(420 if grid.columns==2 else 850,48);button.focus_mode=Control.FOCUS_NONE
		button.set_meta("campaign_option",str(pair[0]))
		button.add_theme_font_size_override("font_size",17);button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func():game.play_ui_click();selected.emit(str(pair[0])));grid.add_child(button)
	game.gameplay_hud.hide();game.refresh_player_freeze()
	var value: String=await selected
	modal_layer.queue_free();modal_layer=null;panel=null
	return value

func wait_window(node: Dictionary) -> void:
	await game.story_system.black_scene("休息与等待\n\n"+node["title"]+"\n推进到本章的下一个可用行动窗口。生活费照常发放。")
	for step: int in range(500):
		advance_phase()
		if available_now(node):break
	game.sync_classroom_period();game.apply_time_lighting()

func advance_phase() -> void:
	game.advance_world_period()

func run_event() -> void:
	if game.story_system.running or game.battle_view.visible:return
	var node:=current()
	if node.is_empty():return
	if started_day<0:started_day=game.economy.day_serial
	game.story_system.begin_sequence()
	game.music.story_tone="heroic" if node["id"] in ["ao_transform","preparation","choice"] else "tension" if node.has("battle") or node["id"] in ["office_infiltrate","rune","li_hearing","yang_hearing"] else ""
	if not available_now(node):
		if await choose("现在不是行动窗口。事件会保留，等待不会丢失任务。",[["wait","确认：休息到可用时间段"],["cancel","取消：继续自由探索"]])=="wait":await wait_window(node)
		game.story_system.end_sequence();return
	var bridge: String=str(node.get("bridge_quest",""))
	if not bridge.is_empty() and game.task_system.entries.get(bridge,{}).get("status","")!="completed":
		var spec: Dictionary=game.task_system.definitions[bridge]
		var entry: Dictionary=game.task_system.entries.get(bridge,{})
		var owner: String=spec["side_story"]["owner"]
		var next: String=game.side_quests.hint_for(spec,entry) if not entry.is_empty() else "找"+str(game.npc_catalog.characters[owner]["display_name"])+"接取 → "+location_name(scheduled_location(owner))
		await dialog([{"actor":"system","text":"章节调查 · "+str(spec["title"])+"\n"+next+"\n可在菜单“同学支线”查看进度。调查完成后回到原来的会面地点。"}]);game.story_system.end_sequence();return
	if int(game.combat_rules.hero["level"])<int(node.get("require_level",0)) or (node.get("require_medium",false) and not has_medium()):
		await dialog(node["dialogue"]);game.story_system.end_sequence();return
	if int(node.get("cost",0))>game.economy.money or not has_materials(node.get("materials",{})):
		await dialog([{ "actor":"lao_li","text":"讲义需要 20g 和一份墨渣。委托一直留着，生活费或卖墨渣都能凑齐。"}]);game.story_system.end_sequence();return
	if wave_node!=str(node["id"]) and not str(node["id"]) in done and not flags.get("intro/"+str(node["id"]),false):
		var absent: Array[String]=[]
		for actor: String in node.get("cast",[]):
			if not game.relationships.alive(actor):absent.append(str(game.npc_catalog.characters.get(actor,{}).get("display_name",actor)))
		if not absent.is_empty():
			var relay: String="、".join(absent)+"已经不在了。现场没有等来原定的人，赵慕gei翻出遗留记录，按仍然有效的计划亲自接手。后续标明的笔记只是旧记录，不是他们此刻的回应。"
			if node["id"] in ["li_start","yang_frame","li_hearing","yang_hearing"]:relay+="被指控的人可能已无法为自己辩解，原始证据仍需要核验，失去的人也不能成为随意改写记录的理由。"
			if node["id"]=="ao_transform":relay+="牢傲留存的光系引信还能使用；亮起的是预先封存的力量，没有人死而复生。"
			if game.relationships.massacre():relay+="幸存者拒绝靠近。他们没有替这些伤害背书，也不会为你袭击同学提供支援。"
			await dialog([{"actor":"system","text":relay}])
		await dialog(node["dialogue"])
		if not node.get("long_dialogue",[]).is_empty():await dialog(node["long_dialogue"])
		if node.has("extra"):
			var lines: Array=[]
			for pair: Array in node["extra"]:lines.append({"actor":pair[0],"text":pair[1]})
			await dialog(lines)
		flags["intro/"+str(node["id"])]=true
	if node.has("choice") and not await resolve_choice(node["choice"]):game.story_system.end_sequence();return
	if node.has("effect"):await game.story_system.play_effect(node["effect"],marker_point()-Vector2(0,15),90,.8)
	if node.get("rest",false):
		await game.story_system.black_scene("回家休息\n\n凌晨，生活费到账。天亮后回秋实楼找阳子。")
		while game.day_clock.current_period!=0:advance_phase()
		game.combat_rules.refill_hero()
	if node.has("battle"):
		if not await prepare_battle(node):game.story_system.end_sequence();return
		start_wave(node);game.story_system.end_sequence();return
	await complete_node()
	game.story_system.end_sequence()

func has_medium() -> bool:
	for id: String in game.combat_rules.hero.get("skills",[]):
		if game.combat_rules.data["skills"].get(id,{}).get("tier","")=="medium":return true
	return false

func suggested_level(node: Dictionary) -> int:
	return {"part_2":1,"part_3":5,"part_4":5,"part_5":8,"part_5_plus":10,"part_6":10,"part_7":12,"part_8":15,"part_9":35}.get(node.get("chapter",""),1)

func train_and_recover() -> void:
	var reward: Dictionary=game.combat_rules.grant_kill_experience(maxi(200,game.combat_rules.experience_required(int(game.combat_rules.hero["level"]))))
	game.combat_rules.refill_hero();change_san(0)
	game.show_notice("补课获得 %d 经验，当前 %d 级。" % [reward["gained"],game.combat_rules.hero["level"]])

func prepare_battle(node: Dictionary) -> bool:
	while true:
		var hero: Dictionary=game.combat_rules.hero
		var extra: String="\n最终战守印屏障：至少减伤 20%。牢硕压制可配合屏障。" if node["id"]=="gate" else ""
		var options: Array=[["fight","确认：开始本波战斗"],["recover","休息：恢复 HP / MP / 精力，推进一个时段"],["train","练习：获取经验并恢复，推进一个时段"],["cancel","取消：自由准备 / 菜单学习技能"]]
		if support_available("lao_shuo"):options.insert(3,["shuo","改用牢硕：每回合压制敌方攻击20%"])
		if support_available("fei_yan"):options.insert(3,["fei","改用费眼：增加法术协同伤害"])
		var name: String=str(game.npc_catalog.characters[support_id]["display_name"]) if support_available(support_id) else "独自应战，当前伙伴无法协同"
		var answer: String=await choose("战前整备 · 第 %d/%d 波\n建议 %d 级 / 当前 %d 级，HP %d/%d，MP %d/%d\n协同：%s。空壳怕光，枯枝、书怪怕火，墨泥怕电。\n低级法术通常更省 MP；屏障持续两次反击。图书室只用精准低级火。%s" % [wave+1,battle_list(node).size(),suggested_level(node),hero["level"],hero["hp_current"],hero["hp"],hero["mp_current"],hero["mp"],name,extra],options)
		match answer:
			"fight":return true
			"cancel":return false
			"shuo":support_id="lao_shuo"
			"fei":support_id="fei_yan"
			"recover","train":
				await game.story_system.black_scene("退到已清理的安全位置，休息并检查补给。" if answer=="recover" else "gei 子照着已记录的弱点反复练习，整理自己的防御动作。")
				if answer=="train":train_and_recover()
				else:game.combat_rules.refill_hero();change_san(0)
				advance_phase();game.sync_classroom_period();game.apply_time_lighting()
	return false

func battle_reduction(enemy_id: String) -> float:
	return .2 if active() and enemy_id in ["gate_entity","gou_ga_boss"] else 0.0
func has_materials(materials: Dictionary) -> bool:
	for id: String in materials:
		if game.economy.quantity(id)<int(materials[id]):return false
	return true
func adjust(values: Dictionary) -> void:
	for id: String in values:
		if values[id] is bool:flags[id]=values[id]
		elif id.begins_with("BOND_"):game.relationships.change(id.trim_prefix("BOND_"),int(values[id]))
		elif id=="STATE":flags[id]=maxi(int(flags.get(id,0)),int(values[id]))
		else:flags[id]=clampi(int(flags.get(id,0))+int(values[id]),0,5 if id=="GOU_UNDERSTAND" else 100)

func complete_node() -> void:
	var node:=current()
	if node.is_empty() or node["id"] in done:return
	game.economy.money-=int(node.get("cost",0))
	for id: String in node.get("materials",{}):game.economy.inventory[id]-=int(node["materials"][id])
	for id: String in node.get("items",{}):game.economy.add_item(id,int(node["items"][id]))
	adjust(node.get("onTrigger",{}))
	for actor: String in node.get("cast",[]):
		if game.relationships.alive(actor):game.relationships.change(actor,3)
	if node.get("transform",false):ao_until=game.economy.day_serial+7
	if node["id"]=="tide_clear":
		game.economy.add_item("flash_bomb",3);game.economy.add_item("seal_shard");adjust({"F_LI_PARTIAL":true})
		flags["F_CIVILIAN_SAFE"]=game.relationships.dead.is_empty() and not (not flags["F_LI_CLEAR"] and not flags["F_YANG_CLEAR"] and low_bonds()>=3)
		if not flags["F_CIVILIAN_SAFE"]:notes.append("点名未完成，同学们对指挥失去信任。需要补证和修复羁绊，再找辣椒重新点名。")
	if node["id"]=="li_start" or node["id"]=="yang_frame":case_day=game.economy.day_serial
	if node.get("choice_after","")=="gou":await resolve_choice("gou")
	if node["id"] in ["li_hearing","yang_hearing"]:
		var cleared: bool=flags["F_LI_CLEAR" if node["id"]=="li_hearing" else "F_YANG_CLEAR"]
		await dialog([{"actor":"la_jiao" if node["id"]=="li_hearing" else "wen_cong","text":"核验完成，原指控撤回，错误的记录会更正。受伤的人不该再替误会承担代价。" if cleared else "目前还不能撤掉疑点。先保留原件，你们可以继续找独立证据；未核实的指控也不能当作定论。"}])
	for id: String in node.get("learn_skills",[]):
		if game.combat_rules.learn(id):notes.append("习得："+str(game.combat_rules.data["skills"][id]["name"]))
	if node.has("after_dialogue"):await dialog(node["after_dialogue"])
	game.sounds.play("story_reveal")
	done.append(node["id"]);index+=1;wave=0;wave_node="";battle_uid="";last_slot=phase_slot();saved_enemy={}
	if node["id"]=="preparation":failures=0
	game.record_game_event("campaign/"+str(node["id"]))
	if not str(node.get("event","")).begins_with("monster_defeated/") and node.get("event","")!="days_passed":game.record_game_event(str(node.get("event","story/"+node["id"])))
	advance_phase();game.sync_classroom_period();game.apply_time_lighting()
	game.show_notice("已完成："+node["title"])
	game.economy.changed.emit();game.story_system.refresh_objective()

func start_wave(node: Dictionary) -> void:
	wave_node=node["id"]
	var enemy_id: String=battle_list(node)[wave]
	var spec: Dictionary=game.combat_rules.data["monsters"][enemy_id]
	var level: int=int(spec.get("level",0))
	if level<1:level=game.monster_world.spawn_level(spec["rarity"])
	var stats: Dictionary=game.combat_rules.monster_stats(enemy_id,level)
	var uid: String=str(game.monster_world.next_uid);game.monster_world.next_uid+=1;battle_uid=uid
	var monster: Dictionary={"uid":uid,"id":enemy_id,"level":level,"hp":stats["hp"],"campaign":node["id"]}
	if enemy_id.begins_with("gou_ga") and not game.relationships.alive("gou_ga"):
		await dialog([{"actor":"system","text":"勾尬已经死去，门底留存的回路却没有停止。眼前只是她被门记下的残响；击败它无法把她带回来。"}])
	if saved_enemy.get("id","")==enemy_id:
		monster["hp"]=saved_enemy["hp"];monster["level"]=saved_enemy["level"]
		if saved_enemy.has("tactics_state"):monster["tactics_state"]=saved_enemy["tactics_state"].duplicate(true)
		if saved_enemy.has("relationship_relief"):monster["relationship_relief"]=saved_enemy["relationship_relief"]
	# Story waves are one at a time, including outdoor defence; they never add
	# creatures to a loaded classroom/corridor above its architectural capacity.
	game.battle_view.start({"monster":monster},"campaign/"+str(node["id"]))
	if node.get("transform",false) and saved_enemy.is_empty():game.battle_view.enemy["hp_current"]=maxi(1,int(stats["hp"])*3/10);monster["hp"]=game.battle_view.enemy["hp_current"]

func is_story_battle() -> bool:return not battle_uid.is_empty() and game.battle_view.monster.get("uid","")==battle_uid

func world_victory(enemy_id: String) -> void:
	if current().get("id","")!="night_hunt" or enemy_id!="ink_slime" or game.interior_state.get("building","")!="B02" or game.day_clock.current_period!=4:return
	game.story_system.begin_sequence();await complete_node();game.story_system.end_sequence()
func battle_list(node: Dictionary) -> Array:
	var result: Array=node.get("battle",[]).duplicate()
	if node.get("id","")=="seal_defend":
		for count: int in range(int(flags.get("rune_mistakes",0))):result.append("empty_uniform")
	return result

func battle_closed(outcome: String, remaining: Dictionary={}) -> void:
	if battle_uid.is_empty():return
	battle_uid=""
	var node:=current()
	if outcome=="victory":
		wave+=1;saved_enemy={}
		if wave>=battle_list(node).size():
			game.story_system.begin_sequence();await complete_node();game.story_system.end_sequence()
		else:game.show_notice("本波已结束（%d/%d）。可整备，回到交战区域继续。" % [wave,battle_list(node).size()])
	elif outcome=="defeat":
		failures+=1;saved_enemy={};game.combat_rules.refill_hero()
		change_san(0)
		if node["id"]=="gate" and failures>int(data.get("ending_retry_limit",2)):await present_ending("BE-1")
		else:game.show_notice("队友把你拖回安全位置。可以补给再挑战；任务和已清波次保留。")
	else:saved_enemy=remaining.duplicate();game.show_notice("撤离成功，返回交战区域可继续挑战，双方血量保留。")

func resolve_choice(id: String) -> bool:
	var answer: String
	match id:
		"entry":
			answer=await choose("选择图书室进入方式",[["trust","请辣椒开条子（信任 -5）"],["key","牢李配钥匙（20g）"],["window","傍晚侧窗（损失 50 HP）"],["cancel","取消"]])
			if answer=="cancel":return false
			if answer=="key":
				if game.economy.money<20:game.show_notice("配钥匙需要 20g。");return false
				game.economy.money-=20
			elif answer=="window":
				if not game.day_clock.current_period in [3,4]:game.show_notice("等到晚上或深夜再翻侧窗。");return false
				game.combat_rules.hero["hp_current"]=maxi(1,int(game.combat_rules.hero["hp_current"])-50)
			else:adjust({"BOND_la_jiao":-5})
		"li_start","yang_start":
			answer=await choose("伙伴被指控。选择会留下记录。\n主动推队友自保累计两次会导致【散场】。",[["help","先去取证，和伙伴站一起"],["leave","暂时搁置，之后仍可补救"],["betray","警告：推出伙伴，自己撇清"],["cancel","取消"]])
			if answer=="cancel":return false
			if answer=="betray":adjust({"BETRAY_COUNT":1,"BOND_fei_yan":-30,"BOND_lao_li":-30,"BOND_lao_chou":-30})
		"li_hearing","yang_hearing":
			var kind: String="li" if id=="li_hearing" else "yang"
			var expired: bool=game.economy.day_serial-case_day>=(3 if kind=="li" else 4)
			answer=await choose("已收集 %d/3 份证据。向牢抽、牢李、辣椒或费眼取证。\n%s" % [evidence[kind].size(),"窗口已过，可日后补证翻案。" if expired else "现在可以取证后再来，也可以暂时搁置。"],[["submit","提交证据"],["stale","暂时搁置，不锁后续剧情"],["cancel","取消，继续取证"]])
			if answer=="cancel":return false
			if answer=="submit" and evidence[kind].size()<3:game.show_notice("还需要更多独立证据。");return false
			if answer=="submit" and not expired:clear_case(kind)
			else:flags["F_LI_CLEAR" if kind=="li" else "F_YANG_CLEAR"]=false;game.record_game_event("story/"+("li_defame_stale" if kind=="li" else "yang_frame_stale"))
		"rune":
			answer=await choose("点亮下一根石柱：2 → 4 → 8 → 16 → ?",[["32","32"],["24","24"],["30","30"],["cancel","取消，重看线索"]])
			if answer=="cancel":return false
			if answer!="32":
				game.economy.add_item("ink_fragment");game.combat_rules.hero["energy_current"]=maxi(0,int(game.combat_rules.hero["energy_current"])-20)
				flags["rune_mistakes"]=mini(3,int(flags.get("rune_mistakes",0))+1)
				game.show_notice("符文未亮，多来一波空壳。答案翻倍，再试一次。");return false
		"grid":
			answer=await choose("牢李广播：先疏散，再合闸，最后亮灯。按什么顺序？",[["safe","疏散 → 合闸 → 亮灯"],["rush","先亮灯诱敌"],["cancel","取消"]])
			if answer=="cancel":return false
			if answer!="safe":game.show_notice("牢硕及时挡住了怪物，重新听牢李指挥。");return false
		"gou":
			answer=await choose("勾尬眯眼望向图书室。",[["ask","追问：你在躲什么？"],["leave","先照顾受伤的阳子"]])
			if answer=="ask":adjust({"GOU_UNDERSTAND":1});notes.append("勾尬不是养怪物的人。她更像在维持混乱，又害怕门真正打开。")
		"exam":
			answer=await choose("期中考试：不使用魔法作弊。",[["study","和牢抽复习后认真作答"],["blank","尽力写完会做的题"],["cancel","取消，继续复习"]])
			if answer=="cancel":return false
			if answer=="study":adjust({"RP_H":5,"BOND_la_jiao":10})
			await game.story_system.black_scene("期中考试\n\n铃声响起。赵慕gei交上试卷，窗外的校园暂时安静。")
		"route":
			answer=await choose("锁定最终路线前仍可自由准备，旧路线点全部保留。\n建议 35 级。真结局还需真相、碎片、理解与三线合作。",[["H","凡人线：阳子与全班"],["W","魔女线：wr 的契约"],["D","世家线：牢董与守印人"],["cancel","取消：继续准备 / 同伴对话"]])
			if answer=="cancel":return false
			if answer=="W" and (game.economy.quantity("dark_page")==0 or int(flags.get("BOND_wr",0))<20 or san()<40):game.show_notice("魔女线需要残页、wr 羁绊 20 与理智至少 40。");return false
			flags["FINAL_ROUTE"]=answer
		"ending":
			answer=await choose("最终抉择\n理智 %d · 三线 %d/%d/%d · 理解 %d/5 · 真碎片 %d\n【解开】条件不足时按当前路线与完成度结算。" % [san(),flags["RP_H"],flags["RP_W"],flags["RP_D"],flags["GOU_UNDERSTAND"],game.economy.quantity("seal_shard")],[["seal","封门：守住校园"],["devour","吞噬：控制淤积魔力"],["open","解开：不封也不杀"],["cancel","取消：重看线索"]])
			if answer=="cancel":return false
			await present_ending(evaluate_ending(answer));return true
	return true

func clear_case(kind: String) -> void:
	var flag: String="F_LI_CLEAR" if kind=="li" else "F_YANG_CLEAR"
	if flags.get(flag,false):return
	flags[flag]=true;adjust({"RP_H":15,"GOU_UNDERSTAND":1})
	if kind=="li":game.economy.add_item("insulation_bracer")
	else:flags["F_YANG_REMEDIED"]=true
	if kind=="yang":flags["yang_resolute"]=true
	game.record_game_event("story/"+("li_defame_clear" if kind=="li" else "yang_frame_clear"))
	notes.append("证据链相互印证，"+("牢李" if kind=="li" else "阳子")+"的指控已澄清。")

func npc_service(actor: String) -> void:
	game.story_system.begin_sequence()
	var options: Array=[["talk","交谈：决战前夜与伙伴约定" if index>=29 else "交谈：线索与伙伴近况"],["cancel","取消"]]
	if actor in ["fei_yan","lao_li","lao_shuo"] and game.relationships.alive(actor):options.push_front(["shop","技能 / 装备 / 委托清单"])
	if actor in ["fei_yan","lao_shuo"] and not game.relationships.alive(actor):options.push_front(["self_study","遗留教案：自行练习技能"])
	if actor in ["lao_chou","lao_li","la_jiao","fei_yan"]:
		if index>=13 and not flags.get("F_LI_CLEAR",false):options.push_front(["li","牢李案：核实证据 / 补救"])
		if index>=18 and not flags.get("F_YANG_CLEAR",false):options.push_front(["yang","阳子案：核实证据 / 补救"])
	if actor=="lao_li":options.append(["handout","补印讲义：20g + 墨渣 1"]);options.append(["fake","仿制碎片：100g + 墨渣 2"])
	if actor=="fei_yan":options.append(["training","补课：获得经验，推进一个时间段"])
	if actor=="lao_shuo":options.append(["training","训练：获得经验，推进一个时间段"])
	if actor=="lao_dong" and index>=23:options.append(["trial","牢家试炼 / 寻找碎片"])
	if actor=="wr" and index>=12:options.append(["witch","阅读残页 / 订立契约（理智风险）"])
	if actor in ["lao_chou","lao_li","wr"] and index>=28:options.append(["truth","复核碎片与内鬼线索"])
	if actor in ["wr","lao_dong","gou_ga"] and index>=23:options.append(["gou","追问勾尬与门底的联系"])
	if actor=="la_jiao" and index>=29 and not flags["F_CIVILIAN_SAFE"]:options.append(["recount","补证之后，重新组织点名"])
	options.append_array(game.side_quests.options_for(actor))
	var answer: String=await choose(game.npc_catalog.characters[actor]["display_name"],options)
	if answer.begins_with("side/"):
		await game.side_quests.service(actor,answer.trim_prefix("side/"));game.story_system.end_sequence();return
	if answer=="shop":game.story_system.end_sequence();game.story_system.named_conversation({"character":actor});return
	if answer=="self_study":game.story_system.end_sequence();game.menu_view.open_archive(actor);return
	if answer=="cancel":game.story_system.end_sequence();return
	if int(repeats.get(actor+"/"+answer,-1))==game.economy.day_serial:
		game.show_notice("今天已完成这项行动，明天再来。");game.story_system.end_sequence();return
	var succeeded:=true
	match answer:
		"li","yang":
			if not actor in evidence[answer]:evidence[answer].append(actor)
			var text: String={"lao_chou":"时间线对不上，截图字体和群号有破绽，口供又一字不差。","lao_li":"原始记录、报修单和监控物证都留着。护腕压在碎玻璃上面，先后顺序反了。","la_jiao":"考勤和值日台账在这里。报失的物品也已经找到，应当撤回失窃指控。","fei_yan":"巡夜后勤大爷愿意作证：撬锁的是矮胖的圆眼镜身影，不是高瘦的阳子。"}[actor]
			await dialog([{"actor":actor,"text":text}])
			if evidence[answer].size()>=3 and index>(14 if answer=="li" else 19):clear_case(answer)
		"handout","fake":
			var cost: int=20 if answer=="handout" else 100
			var amount: int=1 if answer=="handout" else 2
			if game.economy.money<cost or game.economy.quantity("ink_fragment")<amount:succeeded=false
			else:
				game.economy.money-=cost;game.economy.inventory["ink_fragment"]-=amount;game.economy.add_item("basic_spell_handout" if answer=="handout" else "seal_shard_fake")
		"training":
			var level: int=game.combat_rules.hero["level"]
			var reward: Dictionary=game.combat_rules.grant_kill_experience(maxi(200,game.combat_rules.experience_required(level)))
			game.combat_rules.refill_hero();change_san(0);game.show_notice("训练获得 %d 经验。" % reward["gained"]);adjust({"RP_H":5})
		"trial":
			if await choose("守印试炼：力量与伙伴发生冲突时，先守住什么？",[["team","守住伙伴，与他们分担代价"],["power","先把力量全部拿到手"],["cancel","取消"]])!="team":game.show_notice("试炼未通过，随时可以重新选择。");game.story_system.end_sequence();return
			if not flags["F_DONG_TRIAL"]:
				flags["F_DONG_TRIAL"]=true;game.economy.add_item("seal_shard");adjust({"RP_D":15})
			else:
				adjust({"RP_D":15})
				if not flags.get("trial_extra_shard",false):game.economy.add_item("seal_shard");flags["trial_extra_shard"]=true
			await dialog([{"actor":actor,"text":"试炼不是谁法术更强，而是谁肯守住别人。碎片交给你；我们明天再练。"}])
		"witch":
			if game.economy.quantity("dark_page")==0:game.economy.add_item("dark_page");flags["F_BOOK"]=true
			if await choose("黑魔法消耗理智，归零会成为新的污染。\n是否签订可控契约？",[["yes","确认：理智 -5，学习黑火"],["no","取消"]])=="yes":
				change_san(-5);flags["F_WR_CONTRACT"]=true;adjust({"RP_W":8,"BOND_wr":10});game.combat_rules.learn("dark_flame")
			else:succeeded=false
		"truth":
			flags["truth_source/"+actor]=true;notes.append(game.npc_catalog.characters[actor]["display_name"]+"核验了引流、现场物证或监控线索。第二种危险的人，是自信能修好门的人。")
			var sources:=0
			for source: String in ["lao_chou","lao_li","wr"]:
				if flags.get("truth_source/"+source,false):sources+=1
			if sources>=2:
				flags["F_TRUTH"]=true
				if not flags.get("truth_shard",false):game.economy.add_item("seal_shard");flags["truth_shard"]=true
		"gou":
			if not flags.get("gou_source/"+actor,false):adjust({"GOU_UNDERSTAND":1});flags["gou_source/"+actor]=true
			await dialog([{"actor":actor,"text":"她幼时接触门底，成了半人半闸。搅局是泄压，可伤害别人的恶也是真的。理解不等于替她开脱。"}])
		"talk":
			if actor=="yang_zi" and index>=29:flags["F_YANG_REMEDIED"]=true
			if game.relationships.alive(actor):adjust({"BOND_"+actor:10})
			var route: String="W" if actor=="wr" else "D" if actor=="lao_dong" else "H"
			adjust({"RP_"+route:8})
			var reply: String="明天一起站住。该补的证据，该找的碎片，我们一件一件来。" if index>=29 else "先把眼前的线索理清。遇到危险就回来找大家，一起想办法。"
			if actor_weak(actor):reply="你先坐着休息，这几天的巡查我们来。恢复了再一起行动。"
			var conversations: Array=data.get("banter",{}).get(actor,[])
			if not conversations.is_empty():
				var sequence: int=int(flags.get("talk_count/"+actor,0))
				await dialog(conversations[sequence%conversations.size()])
				flags["talk_count/"+actor]=mini(100,sequence+1)
			else:await dialog([{"actor":actor,"text":game.story_system.data["role_greetings"][actor][0]},{"actor":"zhao_mugei","text":reply}])
		"recount":
			if game.relationships.dead.is_empty() and (flags["F_LI_CLEAR"] or flags["F_YANG_CLEAR"] or low_bonds()<3):flags["F_CIVILIAN_SAFE"]=true;adjust({"RP_H":10})
			else:succeeded=false
	if succeeded:
		repeats[actor+"/"+answer]=game.economy.day_serial;last_slot=phase_slot();advance_phase();game.sync_classroom_period();game.apply_time_lighting();game.economy.changed.emit()
	else:game.show_notice("行动未完成。请核对资金、材料或所选条件。")
	game.story_system.end_sequence()

func san() -> int:return clampi(int(flags.get("SAN",100)),0,100)
func low_bonds() -> int:
	var count:=0
	for id: String in ["fei_yan","lao_li","lao_chou","la_jiao","yang_zi","lao_dong"]:
		if int(flags.get("BOND_"+id,0))<5:count+=1
	return count
func before_action(action: Dictionary, charged: bool) -> bool:
	if not active():return true
	if action.get("element","")=="dark":
		if flags["FINAL_ROUTE"]=="H":game.battle_view.append_log("凡人路线坚持不用黑魔法；仍可使用已学会的四系法术与同伴道具。");return false
		if san()<=8 and not flags.get("san_warning",false):
			flags["san_warning"]=true;game.battle_view.append_log("警告：再次施放会使理智归零，触发【新的污染】。若仍决定施放，请再次点击。");return false
		change_san(-8)
		if san()==0:game.battle_view.finish("corrupted");return false
	if game.interior_state.get("building","")=="B06" and action.get("element","")=="fire" and (charged or action.get("tier","") in ["medium","high","super"]):
		game.economy.money=maxi(0,game.economy.money-20);adjust({"BOND_la_jiao":-5});game.battle_view.append_log("大火触发喷淋，毁书赔偿 20g，辣椒信任下降。请用精准低级法术。")
	return true

func ally_support(view: Control) -> void:
	if not active() or index<2 or view.enemy.is_empty() or view.result!="":return
	if not view.npc_target.is_empty():return
	if support_available(support_id):
		var damage: int=maxi(1,floori(int(game.combat_rules.hero["attack"])*.12))
		if support_id=="fei_yan":damage=floori(damage*1.25)
		if support_id=="yang_zi" and game.economy.quantity("basic_spell_handout")>0:damage=floori(damage*1.2)
		if support_id=="lao_shuo":view.enemy["attack"]=floori(int(game.combat_rules.monster_stats(view.enemy["id"],int(view.enemy["level"]))["attack"])*.8)
		if support_id=="lao_ao":damage=0 if game.economy.day_serial<ao_until else damage*2
		if current().get("transform",false):damage=maxi(damage,floori(int(view.enemy["hp"])*.25))
		if int(view.enemy["hp_current"])>0:
			view.enemy["hp_current"]=maxi(0,int(view.enemy["hp_current"])-damage);view.monster["hp"]=view.enemy["hp_current"]
			view.append_log((("牢傲变身支援" if game.relationships.alive("lao_ao") else "牢傲遗留的光系引信") if current().get("transform",false) else game.npc_catalog.characters[support_id]["display_name"]+"协同")+"造成 %d 点伤害。" % damage)
		if index>=23 and support_id=="lao_dong":
			var hero: Dictionary=game.combat_rules.hero
			hero["hp_current"]=mini(int(hero["hp"]),int(hero["hp_current"])+floori(int(hero["hp"])*.02))
	if game.economy.day_serial<ao_until and view.turn==1 and game.economy.quantity("flash_bomb")>0:
		game.economy.inventory["flash_bomb"]-=1
		var flash_damage: int=mini(int(view.enemy["hp_current"]),floori(int(view.enemy["hp"])*.4))
		view.enemy["hp_current"]-=flash_damage;view.monster["hp"]=view.enemy["hp_current"];view.append_log("消耗强光雷，替代牢傲的光系支援：%d 伤害。" % flash_damage)
	if current().get("disruption",false) and view.turn%2==0:
		game.combat_rules.hero["energy_current"]=maxi(0,int(game.combat_rules.hero["energy_current"])-(16 if flags.get("yang_resolute",false) else 20));view.append_log("勾尬搅局：地板震动，调整站位消耗精力。")
func support_available(actor: String) -> bool:
	return game.relationships.alive(actor) and game.relationships.bond(actor)>=0 and not actor_weak(actor)

func change_san(amount: int) -> void:
	flags["SAN"]=clampi(san()+amount,0,100)
	game.combat_rules.hero["san_current"]=floori(int(game.combat_rules.hero["san"])*san()/100.0)

func evaluate_ending(choice: String, final_defeat: bool=false) -> String:
	if game.relationships.massacre():return "GENOCIDE"
	var route: String=flags.get("FINAL_ROUTE","")
	if route.is_empty():
		route="H"
		for candidate: String in ROUTES:
			if int(flags["RP_"+candidate])>int(flags["RP_"+route]):route=candidate
	if san()<=0:return "BE-2"
	if final_defeat:return "BE-1"
	if int(flags["BETRAY_COUNT"])>=2:return "BE-4"
	if choice=="open" and game.relationships.redemption_ready():return "REDEMPTION"
	if not game.relationships.dead.is_empty() and choice in ["open","seal","devour"]:return "SURVIVORS"
	if route=="H" and not flags["F_CIVILIAN_SAFE"]:return "BE-3"
	var shards: int=game.economy.quantity("seal_shard")
	if flags["F_TRUTH"] and (shards>=4 or shards>=3 and game.economy.quantity("seal_shard_fake")>=1) and int(flags["GOU_UNDERSTAND"])>=4 and int(flags["RP_H"])>=40 and int(flags["RP_W"])>=40 and int(flags["RP_D"])>=40 and san()>=60 and flags["F_CIVILIAN_SAFE"] and choice=="open":return "TE"
	if route=="D" and int(flags["RP_D"])>=80 and flags["F_DONG_TRIAL"]:return "GE-D"
	if route=="W" and int(flags["RP_W"])>=80 and flags["F_WR_CONTRACT"] and san()>=40:return "GE-W"
	if route=="H" and int(flags["RP_H"])>=80 and (flags["F_LI_CLEAR"] or flags["F_LI_PARTIAL"]) and (flags["F_YANG_CLEAR"] or flags["F_YANG_REMEDIED"]) and flags["F_CIVILIAN_SAFE"]:return "GE-H"
	return "NE"

func present_ending(id: String) -> void:
	if game.relationships.massacre():id="GENOCIDE"
	elif not game.relationships.dead.is_empty() and id in ["TE","GE-H","GE-W","GE-D","REDEMPTION"]:id="SURVIVORS"
	ending=id
	var lines: Dictionary={"GENOCIDE":"勾尬站在空荡的门前。你曾经把魔力称作保护，如今幸存者只听见你的脚步就会躲开。门被你封住了，点名却再没有应答。\n赵慕gei低下头，发现没有人还愿意接过那份胜利。","SURVIVORS":"点名的人停顿很久，念出那些不会再回答的名字。留下的人带着伤痕把门封住；这不是一个都不少的胜利。\n赵慕gei：我会记住，谁没能回来。","TE":"牢董打开锁链，wr 疏导淤积，阳子和辣椒带普通人点亮灯阵。没有人被当成祭品。\n阳子：恨你，跟拉你一把，不耽误。\n赵慕gei：别玩了，放学了，回家。","GE-D":"封印重铸，新的守印人留下。\n牢董：守印的人，不再是一个人了。","GE-W":"黑火安静地燃着。\n赵慕gei：黑暗没消失，但从今天起，它得听好人的。","GE-H":"辣椒挨个点名，每个名字都有人答到。\n赵慕gei：拯救世界这活儿，一个班就够了。","NE":"门暂时被封上，后山心跳未停。\n这回算我们欠它的……下次吧。\n可继续补证、培养路线，再次结算。","BE-1":"秋实楼的灯一盏盏灭。废墟里，护符最后的光也熄了。","BE-2":"黑魔法从工具变成主人。\nwr：我说过，收的利息是你自己。","BE-3":"花名册被风吹散，再点不齐。","BE-4":"伙伴沉默离开。\n费眼：法术我能教你；选人站哪边，我教不了。"}
	var was_running: bool=game.story_system.running
	if not game.relationships.alive("gou_ga"):lines["GENOCIDE"]="勾尬死后留在门底的残响终于散去。你曾把魔力称作保护，如今幸存者听见你的脚步就会躲开。门被封住了，点名却再没有应答。\n没有人回来，也没有人愿意接过这份胜利。"
	lines["REDEMPTION"]="她终于自己松开牵线。赵慕gei没有把她推回门底，也没有抹掉她写下的证词。四枚真碎片留在新的封印里，所有人都活着走到了灯下。\n勾尬：明天他们可能还是不想理我。\n赵慕gei：那就从更正一份记录、好好说一句话开始。你可以活着把责任担完。\n勾尬把手从回路上拿开。这一次，门外也有她自己的明天。"
	if not was_running:game.story_system.begin_sequence()
	await dialog([{"actor":"system","text":END_NAMES[id]+"\n\n"+lines[id]}])
	if data.get("ending_dialogues",{}).has(id):await dialog(data["ending_dialogues"][id])
	await game.story_system.black_scene(id+" · "+END_NAMES[id]+"\n\n结局已记录。原存档保留，可在剧情手册继续准备。")
	if not was_running:game.story_system.end_sequence()

func open_journal() -> void:
	if not active():game.show_notice("完成第一章后开启剧情手册。");return
	game.close_menu();game.story_system.begin_sequence()
	var summary: String=objective_text()+"\n\n凡人 %d / 魔女 %d / 世家 %d · 理智 %d\n理解 %d/5 · 真碎片 %d · 赝品 %d\n牢李澄清 %s · 阳子翻案 %s\n牢傲：%s\n\n证据与对话日志\n%s" % [flags["RP_H"],flags["RP_W"],flags["RP_D"],san(),flags["GOU_UNDERSTAND"],game.economy.quantity("seal_shard"),game.economy.quantity("seal_shard_fake"),"已完成" if flags["F_LI_CLEAR"] else "待补证","已完成" if flags["F_YANG_CLEAR"] else "待补证","虚弱，剩余 %d 天；牢董 / 强光雷代替" % (ao_until-game.economy.day_serial) if game.economy.day_serial<ao_until else "可以参战","\n".join(notes)]
	summary+="\n\n"+game.relationships.journal()
	summary+="\n\n"+game.farming.journal()
	summary+="\n\n剧情物品\n"
	for id: String in game.economy.catalog:
		if game.economy.catalog[id].get("plot_item",false) and game.economy.quantity(id)>0:summary+=str(game.economy.catalog[id]["name"])+" ×%d\n" % game.economy.quantity(id)
	summary+="\n图鉴 · 已遇到的怪物\n"
	for id: String in game.combat_rules.data["monsters"]:
		if int(game.event_state.get("monster_seen/"+id,0))<1:continue
		var spec: Dictionary=game.combat_rules.data["monsters"][id]
		summary+=str(spec["name"])+"："+("普通怪" if spec["rarity"]=="normal" else "精英 / Boss 护壳 70%")+"，击败 %d 次\n" % int(game.event_state.get("monster_defeated/"+id,0))
		for element: String in spec.get("elemental_reductions",{}):
			if float(spec["elemental_reductions"][element])<0:summary+="弱点："+{"fire":"火","lightning":"电","light":"光","frost":"冰"}.get(element,element)+"\n"
	var options: Array=[["support","伙伴调度：选择当前协同角色"],["close","关闭手册"]]
	if not game.relationships.dead.is_empty():options.push_front(["archive","遗留档案：笔记、证词与训练记录"])
	if not ending.is_empty():options.push_front(["resume","继续准备与探索，保留结局记录"])
	var answer: String=await choose(summary,options)
	if answer=="archive":
		var archives: Array=[["cancel","放回档案"]]
		for actor: String in game.relationships.COMPANIONS:
			if not game.relationships.alive(actor):archives.push_front([actor,"查看 · "+str(game.npc_catalog.characters[actor]["display_name"])+"留下的记录"])
		var actor: String=await choose("死者不会回来；遗留的证据和训练记录仍可亲自核验。",archives)
		game.story_system.end_sequence()
		if actor!="cancel":npc_service(actor)
		return
	if answer=="support":
		var roster: Array=[["fei_yan","费眼：法术协同"],["lao_shuo","牢硕：压制敌方攻击"]]
		if index>=3:roster.append(["yang_zi","阳子：体术 / 讲义法术"])
		if index>=24:roster.append(["lao_dong","牢董：伤害协同与恢复"])
		if index>=28 and game.economy.day_serial>=ao_until:roster.append(["lao_ao","牢傲：恢复后的强光支援"])
		roster=roster.filter(func(row: Array):return game.relationships.alive(row[0]) and game.relationships.bond(row[0])>=0)
		roster.append(["cancel","取消"])
		var actor: String=await choose("每回合由一位伙伴协同。虚弱的牢傲不能参战，可用强光雷替代。",roster)
		if actor!="cancel":support_id=actor
	if answer=="resume":
		ending="";index=data["nodes"].size()-2;wave=0;wave_node="";failures=0
		for id: String in ["gate","choice"]:done.erase(id)
	game.story_system.end_sequence()

func classmates_for(context: Dictionary) -> Array:
	if not active():return game.npc_catalog.NAMED_IDS.filter(func(id: String):return game.relationships.alive(id))
	var available: Array=[]
	var here: String="%s:%s:%s" % [context["building"],int(context["floor"]),int(context.get("room",-1))]
	for id: String in game.npc_catalog.NAMED_IDS:
		if scheduled_location(id)==here:available.append(id)
	return available

func scheduled_location(id: String) -> String:
	if not game.relationships.alive(id):return ""
	if id in game.campus_life.STAFF:return game.campus_life.location(id)
	if id=="wen_cong":return "B15:1:0"
	var home: String="B06:1:0" if id=="wr" and index>=12 else "B01:3:0"
	if actor_weak(id):return home
	var required: bool=id in current().get("cast",[])
	if not required and active():return game.campus_life.student_location(id,home)
	var at: String=current().get("location",home) if required else home
	var parts:=at.split(":")
	# Outdoor/corridor story appearances are scripted portraits; persistent
	# service actors must remain findable in an actual room. Labs stay empty.
	return at if parts.size()==3 and parts[2]!="corridor" and parts[0]!="B02" else home

func actor_weak(id: String) -> bool:
	return active() and id=="lao_ao" and game.economy.day_serial<ao_until

func snapshot() -> Dictionary:
	return {"version":1,"slot_cycle":6,"index":index,"flags":flags.duplicate(true),"done":done.duplicate(),"evidence":evidence.duplicate(true),"notes":notes.duplicate(),"repeats":repeats.duplicate(),"wave":wave,"wave_node":wave_node,"failures":failures,"ending":ending,"started_day":started_day,"case_day":case_day,"ao_until":ao_until,"last_slot":last_slot,"saved_enemy":saved_enemy.duplicate(),"support_id":support_id}

func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not value.get("flags") is Dictionary:return false
	var cycle: Variant=value.get("slot_cycle",5)
	if not (cycle is float or cycle is int) or float(cycle) not in [5.0,6.0]:return false
	for key: String in ["index","wave","failures","started_day","case_day","ao_until","last_slot"]:
		var number: Variant=value.get(key)
		if not (number is float or number is int) or not is_finite(float(number)) or float(number)!=floor(float(number)) or float(number)<(-1 if key in ["last_slot","started_day"] else 0) or float(number)>1000000:return false
	if int(value["index"])>data["nodes"].size() or not value.get("ending","") in ["","TE","GE-H","GE-W","GE-D","NE","BE-1","BE-2","BE-3","BE-4","GENOCIDE","SURVIVORS","REDEMPTION"]:return false
	for key: String in ["RP_H","RP_W","RP_D","GOU_UNDERSTAND","BETRAY_COUNT","STATE","FINAL_ROUTE","SAN","F_BOOK","F_TRUTH","F_LI_CLEAR","F_LI_PARTIAL","F_YANG_CLEAR","F_YANG_REMEDIED","F_AO_TRANSFORMED","F_CIVILIAN_SAFE","F_WR_CONTRACT","F_DONG_TRIAL"]:
		if not value["flags"].has(key):return false
		if flags[key] is bool and not value["flags"][key] is bool:return false
		if flags[key] is int and (not (value["flags"][key] is float or value["flags"][key] is int) or not is_finite(float(value["flags"][key])) or float(value["flags"][key])!=floor(float(value["flags"][key])) or float(value["flags"][key])<0 or float(value["flags"][key])>100):return false
	if not value["flags"]["FINAL_ROUTE"] in ["","H","W","D"]:return false
	for key: Variant in value["flags"]:
		if not key is String or key.length()>96:return false
		var entry: Variant=value["flags"][key]
		if key=="FINAL_ROUTE" or entry is bool:continue
		if not (entry is float or entry is int) or not is_finite(float(entry)) or floor(float(entry))!=float(entry) or float(entry)<(-100 if key.begins_with("BOND_") else 0) or float(entry)>100:return false
	if int(value["flags"]["GOU_UNDERSTAND"])>5 or int(value["flags"]["STATE"])>3 or int(value["flags"].get("rune_mistakes",0))>3:return false
	if not value.get("notes") is Array or value["notes"].size()>150 or not value.get("done") is Array or not value.get("evidence") is Dictionary or not value.get("repeats") is Dictionary:return false
	for note: Variant in value["notes"]:
		if not note is String or note.length()>4096:return false
	if value["done"].size()>data["nodes"].size() or value["repeats"].size()>1000:return false
	for entry: Variant in value["repeats"].values():
		if not (entry is float or entry is int) or not is_finite(float(entry)) or floor(float(entry))!=float(entry) or float(entry)<0 or float(entry)>1000000:return false
	for key: String in ["li","yang"]:
		if not value["evidence"].get(key) is Array or value["evidence"][key].size()>4:return false
	if not value.get("wave_node") is String:return false
	if not value["wave_node"].is_empty():
		if int(value["index"])>=data["nodes"].size():return false
		var node: Dictionary=data["nodes"][int(value["index"])]
		if node["id"]!=value["wave_node"] or int(value["wave"])>=node.get("battle",[]).size()+int(value["flags"].get("rune_mistakes",0)):return false
	if not value.get("saved_enemy",{}) is Dictionary:return false
	if not value.get("support_id","fei_yan") in ["fei_yan","yang_zi","lao_shuo","lao_dong","lao_ao"]:return false
	var enemy: Dictionary=value.get("saved_enemy",{})
	if not enemy.is_empty():
		if not game.combat_rules.data["monsters"].has(enemy.get("id",null)):return false
		for key: String in ["hp","level"]:
			if not (enemy.get(key) is int or enemy.get(key) is float) or not is_finite(float(enemy[key])) or floor(float(enemy[key]))!=float(enemy[key]) or int(enemy[key])<1:return false
		if int(enemy["level"])>70 or int(enemy["hp"])>int(game.combat_rules.monster_stats(enemy["id"],int(enemy["level"]))["hp"]):return false
	return true

func restore(value: Dictionary) -> void:
	reset()
	if value.is_empty():return
	index=int(value["index"]);flags=value["flags"].duplicate(true);done=value["done"].duplicate();evidence=value["evidence"].duplicate(true);notes=value["notes"].duplicate();repeats=value["repeats"].duplicate(true)
	# JSON represents numbers as floats; restore the integer gameplay contract.
	for key: String in flags:
		if flags[key] is float:flags[key]=floori(flags[key])
	for key: String in repeats:repeats[key]=int(repeats[key])
	wave=int(value["wave"]);wave_node=value["wave_node"];failures=int(value["failures"]);ending=value["ending"];started_day=int(value["started_day"]);case_day=int(value["case_day"]);ao_until=int(value["ao_until"]);last_slot=game.DayClock.migrate_slot(int(value["last_slot"]),int(value.get("slot_cycle",5)))
	saved_enemy=value.get("saved_enemy",{}).duplicate()
	if saved_enemy.get("id","")=="gate_entity":saved_enemy["id"]="gou_ga_boss"
	for key: String in ["hp","level"]:
		if saved_enemy.has(key):saved_enemy[key]=int(saved_enemy[key])
	support_id=value.get("support_id","fei_yan");change_san(0)
	# Old saves receive chapter rewards they already earned, exactly once.
	for event_id: String in data.get("skill_milestones",{}):
		if event_id in done:
			for skill: String in data["skill_milestones"][event_id]:game.combat_rules.learn(skill)
