extends Control

const Assets=preload("res://external_battle_assets.gd")
const MonsterScene=preload("res://monster_scene.gd")
var game: Node2D
var interface: Control
var enemy: Dictionary={}
var monster: Dictionary={}
var zone: String
var turn:=1
var busy:=false
var auto_battle:=false
var result:=""
var log_label: Label
var hero_label: Label
var enemy_label: Label
var close_button: Button
var escape_confirmation: ConfirmationDialog
var root_panel: Control
var history: Array[String]=[]
var action_map: Dictionary={}
var base_pose: Texture2D
var punch_pose: Texture2D
var dodge_pose: Texture2D
var charge_toggle: CheckButton
var pending_spell: Dictionary={}
var cooldowns: Dictionary={}
var barrier_turns:=0
var focus_ready:=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hide()

func start(record: Dictionary, key: String) -> bool:
	if visible or game.transition_busy:return false
	Assets.root=game.battle_asset_root
	var source: PackedScene=Assets.fetch("res://scenes/ui/battle/battle_interface.tscn")
	if source==null:game.show_notice("战斗界面素材缺失");return false
	monster=record["monster"];zone=key
	game.record_game_event("monster_seen/"+str(monster["id"]))
	enemy=game.combat_rules.monster_stats(monster["id"],int(monster["level"]))
	enemy["hp_current"]=monster["hp"]
	turn=1;busy=false;auto_battle=false;result="";history.clear();action_map.clear()
	pending_spell={};cooldowns={};barrier_turns=0;focus_ready=false
	root_panel=Control.new();root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root_panel)
	var background:=ColorRect.new();background.color=Color("202b2e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root_panel.add_child(background)
	interface=source.instantiate();interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_panel.add_child(interface)
	base_pose=Assets.fetch("res://assets/characters/hero/battle/zhao_mugei_rear_quarter.png")
	punch_pose=Assets.fetch("res://assets/characters/hero/battle/zhao_mugei_punch.png")
	dodge_pose=Assets.fetch("res://assets/characters/hero/battle/zhao_mugei_dodge.png")
	interface.ally_slot.set_combatant("赵慕gei",base_pose)
	var enemy_texture: Texture2D=record["sprite"].texture if record.has("sprite") else MonsterScene.portrait(game.battle_asset_root.path_join(game.combat_rules.data["monsters"][enemy["id"]]["art"]))
	if enemy["id"]=="gate_entity":
		var effect: Dictionary=game.story_system.effects["world_magic_circle"]
		var art: Image=Image.load_from_file(game.battle_asset_root.path_join(str(effect["texture"]).trim_prefix("res://")))
		var region: Array=effect["frame_regions"][1];art=art.get_region(Rect2i(region[0],region[1],region[2],region[3]));art.generate_mipmaps();enemy_texture=ImageTexture.create_from_image(art)
	interface.enemy_slot.set_combatant(enemy["name"],enemy_texture)
	interface.ally_slot.portrait_view.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	interface.enemy_slot.portrait_view.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	interface.action_selected.connect(selected)
	# The source UI's category names/slots/menus and stage are used directly.
	interface.category_buttons["items"].text="休整"
	interface.category_buttons["surrender"].text="撤离"
	hero_label=game.label("",17);hero_label.position=Vector2(22,14);root_panel.add_child(hero_label)
	enemy_label=game.label("",17);enemy_label.anchor_left=.73;enemy_label.anchor_right=.99;enemy_label.offset_top=14;root_panel.add_child(enemy_label)
	log_label=game.label("",17);log_label.anchor_left=.05;log_label.anchor_right=.95;log_label.anchor_top=.59;log_label.anchor_bottom=.65
	log_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;log_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	root_panel.add_child(log_label)
	charge_toggle=CheckButton.new();charge_toggle.text="蓄力施法（双倍 MP / 等待一回合）"
	charge_toggle.position=Vector2(420,72);charge_toggle.add_theme_font_override("font",game.ui_font)
	charge_toggle.add_theme_font_size_override("font_size",17);root_panel.add_child(charge_toggle)
	charge_toggle.toggled.connect(func(_value: bool):update_ui())
	close_button=Button.new();close_button.text="返回地图";close_button.custom_minimum_size=Vector2(190,50)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	close_button.offset_left=-95;close_button.offset_right=95;close_button.offset_top=-90;close_button.offset_bottom=-40
	close_button.pressed.connect(close);root_panel.add_child(close_button);close_button.hide()
	escape_confirmation=ConfirmationDialog.new();escape_confirmation.title="撤离战斗"
	escape_confirmation.dialog_text="撤离后双方保留剩余血量。确定撤离？"
	escape_confirmation.ok_button_text="确认";escape_confirmation.cancel_button_text="取消"
	escape_confirmation.theme=interface.theme;escape_confirmation.confirmed.connect(func():finish("escape"))
	root_panel.add_child(escape_confirmation)
	game.pending_npc_talk="";game.pending_monster="";game.player.path.clear();game.player.velocity=Vector2.ZERO
	game.gameplay_hud.hide();show();game.refresh_player_freeze();game.update_time_display()
	append_log("遭遇 "+enemy["name"]+"。请选择操作。")
	update_ui()
	return true

func append_log(text_value: String) -> void:
	history.append(text_value)
	log_label.text=text_value

func update_ui() -> void:
	var hero: Dictionary=game.combat_rules.hero
	hero_label.text="赵慕gei  Lv.%d\nHP %d / %d    MP %d / %d\n精力 %d / %d    SAN %d / %d" % [hero["level"],hero["hp_current"],hero["hp"],hero["mp_current"],hero["mp"],hero["energy_current"],hero["energy"],hero["san_current"],hero["san"]]
	hero_label.text+="\n经验 %d%s" % [hero["experience"],"（已满级）" if int(hero["level"])>=game.combat_rules.maximum_level() else " / "+str(game.combat_rules.experience_required(int(hero["level"])))]
	enemy_label.text="%s  Lv.%d\nHP %d / %d" % [enemy["name"],enemy["level"],enemy["hp_current"],enemy["hp"]]
	if enemy.get("rarity","") in ["elite","boss"]:enemy_label.text+="\n护壳：单次最多扣除 70% 生命"
	var weakness_names: Array[String]=[]
	var element_names: Dictionary={"fire":"火","lightning":"电","frost":"冰","light":"光"}
	for element: String in enemy.get("elemental_reductions",{}):
		if float(enemy["elemental_reductions"][element])<0:weakness_names.append(element_names.get(element,element))
	if not weakness_names.is_empty():enemy_label.text+="\n弱点："+" / ".join(weakness_names)
	interface.set_turn_state(turn,"战斗结束" if not result.is_empty() else ("敌方行动" if busy else ("挂机中" if auto_battle else "我方行动")),not busy and result.is_empty())
	var categories: Dictionary={}
	var available: Array=game.combat_rules.data["actions"].duplicate(true)
	for id: String in hero.get("skills",[]):
		var spec: Dictionary=game.combat_rules.data["skills"][id]
		var action: Dictionary={"id":id,"label":spec["name"],"category":"magic" if spec["kind"]=="magic" else "dodge","description":spec.get("description","")}
		if spec["kind"]=="magic":
			action.merge({"damage_kind":"magic","element":spec["element"],"tier":spec["tier"],"effect":spec["effect"],"mp_cost":game.combat_rules.spell_cost(spec["tier"],charge_toggle.button_pressed)})
			if spec.get("element","")=="dark":action["mp_cost"]=maxi(1,int(action["mp_cost"])/2)
			action["description"]="消耗 %d MP · %s" % [action["mp_cost"],"蓄力一回合后双倍伤害" if charge_toggle.button_pressed else "立即施法"]
		else:
			if id=="barrier":action["mp_cost"]=20+5*int(hero["level"])
			elif id=="focus":action["energy_cost"]=20
			else:action["energy_cost"]=30
		available.append(action)
	if not pending_spell.is_empty():available.append({"id":"release_spell","category":"magic","label":"释放 · "+str(pending_spell["label"]),"description":"已支付 MP，释放双倍伤害"})
	action_map.clear()
	charge_toggle.disabled=busy or not result.is_empty() or not pending_spell.is_empty()
	for action: Dictionary in available:
		action_map[action["id"]]=action
		var category: String=action["category"]
		if not categories.has(category):categories[category]=[]
		var enabled:=int(hero["mp_current"])>=int(action.get("mp_cost",0)) and int(hero["energy_current"])>=int(action.get("energy_cost",0))
		if int(cooldowns.get(action["id"],0))>turn:enabled=false;action["description"]+=" · 冷却 %d 回合" % (int(cooldowns[action["id"]])-turn)
		if not pending_spell.is_empty() and not action["id"] in ["release_spell","escape","auto"]:enabled=false
		categories[category].append({"id":action["id"],"label":action["label"],"description":action.get("description",""),"enabled":enabled})
	for category: String in categories:
		var entries: Array[Dictionary]=[];entries.assign(categories[category]);interface.set_category_entries(category,entries)
	close_button.visible=not result.is_empty()
	if not result.is_empty():interface.dock.hide()

func selected(_category: StringName, command: StringName, _payload: Dictionary) -> void:
	perform(str(command))

func perform(id: String) -> void:
	if id=="magic":
		if visible and not busy and result.is_empty() and not escape_confirmation.visible:interface.open_category(&"magic")
		return
	if not visible or busy or not result.is_empty() or not action_map.has(id):return
	if escape_confirmation.visible:return
	if id=="auto":
		auto_battle=not auto_battle
		update_ui()
		if auto_battle:automatic_turn()
		return
	if id=="escape":
		auto_battle=false;escape_confirmation.popup_centered(Vector2i(480,180));return
	var action: Dictionary=action_map[id]
	if not pending_spell.is_empty() and id!="release_spell":append_log("正在蓄力，请释放已蓄力的法术。");return
	if int(cooldowns.get(id,0))>turn:append_log("技能正在冷却。");return
	var hero: Dictionary=game.combat_rules.hero
	if int(hero["mp_current"])<int(action.get("mp_cost",0)) or int(hero["energy_current"])<int(action.get("energy_cost",0)):append_log("资源不足，请先休整。");return
	if game.campaign!=null and not game.campaign.before_action(action,charge_toggle.button_pressed):return
	busy=true
	hero["mp_current"]-=int(action.get("mp_cost",0));hero["energy_current"]-=int(action.get("energy_cost",0))
	for key: String in ["mp","energy"]:hero[key+"_current"]=mini(int(hero[key]),int(hero[key+"_current"])+int(action.get(key+"_restore",0)))
	update_ui()
	var message: String=action["label"]
	var charging: bool=action.get("damage_kind","")=="magic" and charge_toggle.button_pressed
	var releasing: bool=id=="release_spell"
	if charging:
		pending_spell=action.duplicate(true);message=action["label"]+"蓄力中……本回合敌方行动，下回合释放。"
	elif action.has("damage_kind") or releasing:
		if releasing:action=pending_spell.duplicate(true);pending_spell={}
		var multiplier:=1.0
		if action.get("damage_kind","")=="magic":multiplier=float(game.combat_rules.data["magic_tiers"][action["tier"]]["multiplier"])
		var amplifier: float=(2.0 if releasing else 1.0)*(1.25 if focus_ready and action.get("damage_kind","")=="magic" else 1.0)
		if action.get("element","")=="lightning" and game.economy.quantity("insulation_bracer")>0:amplifier*=1.1
		var damage: int=game.combat_rules.damage(hero,enemy,action["damage_kind"],0,str(action.get("element","")),multiplier,amplifier)
		if action.get("damage_kind","")=="magic":focus_ready=false
		enemy["hp_current"]=maxi(0,int(enemy["hp_current"])-damage);monster["hp"]=enemy["hp_current"]
		message="%s造成 %d 点伤害。" % [action["label"],damage]
		interface.ally_slot.set_pose(punch_pose if id=="physical" else base_pose)
		if action.has("effect"):await spell_effect(action["effect"],interface.enemy_slot)
		await flash_actor(interface.enemy_slot)
	elif id=="dodge":interface.ally_slot.set_pose(dodge_pose)
	elif id=="barrier":barrier_turns=2;cooldowns[id]=turn+3;await spell_effect("world_barrier",interface.ally_slot)
	elif id=="focus":focus_ready=true;cooldowns[id]=turn+3;await spell_effect("world_magic_circle",interface.ally_slot)
	elif id=="mana_cycle":
		hero["mp_current"]=mini(int(hero["mp"]),int(hero["mp_current"])+10+10*int(hero["level"]));cooldowns[id]=turn+3
	elif id=="steady_guard":action["reduction"]=.65;cooldowns[id]=turn+3
	if game.campaign!=null:game.campaign.ally_support(self)
	append_log(message);update_ui()
	await get_tree().create_timer(.3).timeout
	interface.ally_slot.restore_pose()
	if int(enemy["hp_current"])<=0:finish("victory");return
	var dodged: bool=id=="dodge" and game.monster_world.rng.randf()<float(action.get("dodge_chance",0))
	if dodged:message+=" 闪避成功！"
	else:
		var kind: String=game.combat_rules.data["monsters"][enemy["id"]].get("attack_kind","physical")
		var reduction: float=maxf(float(action.get("reduction",0)),.5 if barrier_turns>0 else 0)
		if game.campaign!=null:reduction=maxf(reduction,game.campaign.battle_reduction(enemy["id"]))
		var damage: int=game.combat_rules.damage(enemy,hero,kind,reduction)
		hero["hp_current"]=maxi(0,int(hero["hp_current"])-damage)
		message+=" %s造成 %d 点伤害。" % [enemy["name"],damage]
		await flash_actor(interface.ally_slot)
	append_log(message)
	if barrier_turns>0:barrier_turns-=1
	if int(hero["hp_current"])<=0:finish("defeat");return
	turn+=1;busy=false;update_ui()
	if auto_battle:automatic_turn()

func flash_actor(actor: Control) -> void:
	actor.modulate=Color(1,.35,.35)
	await get_tree().create_timer(.13).timeout
	actor.modulate=Color.WHITE

func spell_effect(id: String, actor: Control) -> void:
	var effect:=preload("res://magic_effect.gd").new()
	if not effect.setup(game,id,260,.6):effect.free();return
	effect.position=actor.get_global_rect().get_center();root_panel.add_child(effect)
	await effect.completed

func automatic_turn() -> void:
	await get_tree().create_timer(.6).timeout
	if not visible or busy or not result.is_empty() or not auto_battle:return
	if not pending_spell.is_empty():perform("release_spell")
	else:perform("physical" if int(game.combat_rules.hero["energy_current"])>=10 else "rest")

func finish(outcome: String) -> void:
	if not result.is_empty():return
	busy=false;auto_battle=false;result=outcome
	if outcome=="victory":
		game.record_game_event("monsters_defeated")
		game.record_game_event("monster_defeated/"+str(enemy["id"]))
		var rarity: String=game.combat_rules.data["monsters"][enemy["id"]].get("rarity","normal")
		var loot: Dictionary=game.economy.award_loot(rarity)
		for id: String in loot:
			append_log("获得物资：%s ×%d" % [game.economy.catalog[id]["name"],loot[id]])
			game.record_game_event("item_received/"+id,int(loot[id]))
		game.monster_world.remove(zone,str(monster["uid"]))
		var awarded: Dictionary=game.combat_rules.grant_kill_experience(int(enemy["hp"]))
		if game.campaign!=null and game.campaign.active():game.campaign.change_san(0)
		append_log("胜利！获得 %d 经验。%s" % [awarded["gained"],"升至 %d 级！" % [awarded["level"]] if int(awarded["levels"])>0 else ""])
	elif outcome=="defeat":append_log("战斗失败。返回地图后恢复状态，回到南门。")
	else:append_log("已撤离。双方保留剩余血量。")
	update_ui()

func close() -> void:
	if result.is_empty() or busy:return
	var outcome:=result
	var story_battle: bool=game.campaign!=null and game.campaign.is_story_battle()
	var remaining: Dictionary=monster.duplicate(true)
	hide();root_panel.queue_free();root_panel=null;interface=null
	base_pose=null;punch_pose=null;dodge_pose=null
	monster={};enemy={};action_map.clear()
	game.gameplay_hud.show();game.refresh_player_freeze();game.interaction_delay=1.0
	game.sync_monsters()
	if game.campaign!=null and game.campaign.active() and game.campaign.san()<=0:game.campaign.present_ending("BE-2")
	elif story_battle:game.campaign.battle_closed(outcome,remaining)
	elif outcome=="defeat":
		game.combat_rules.refill_hero()
		if game.campaign!=null and game.campaign.active():game.campaign.change_san(0)
		game.reset_player()
	else:
		if outcome=="victory" and game.campaign!=null and game.campaign.active():game.campaign.world_victory(remaining.get("id",""))
		game.show_notice("战斗胜利" if outcome=="victory" else "已撤离战斗")
