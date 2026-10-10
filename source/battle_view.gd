extends Control

const Assets=preload("res://external_battle_assets.gd")
const MonsterScene=preload("res://monster_scene.gd")
const Tactics=preload("res://tactical_combat.gd")
const Motion=preload("res://battle_motion.gd")
var tactics:=Tactics.new()
var enemy_motion: RefCounted
var hero_motion: RefCounted
var ailments: Dictionary={}
var clarity_turns:=0
var intent_label: Label
var combat_start_level:=0
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
var npc_target: Dictionary={}
var lethal_npc:=false
var hostile_npc:=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	hide()

func start(record: Dictionary, key: String) -> bool:
	if visible or game.transition_busy:return false
	Assets.root=game.battle_asset_root
	var source: Script=preload("res://battle_interface.gd")
	if source==null:game.show_notice("战斗界面素材缺失");return false
	monster=record["monster"];zone=key
	npc_target=record.get("npc_target",{}).duplicate();lethal_npc=record.get("lethal",false)
	hostile_npc=record.get("hostile",false)
	if npc_target.is_empty():game.record_game_event("monster_seen/"+str(monster["id"]))
	enemy=game.combat_rules.monster_stats(monster["id"],int(monster["level"]))
	enemy["hp_current"]=monster["hp"]
	turn=1;busy=false;auto_battle=false;result="";history.clear();action_map.clear()
	pending_spell={};cooldowns={};barrier_turns=0;focus_ready=false
	ailments={};clarity_turns=0;combat_start_level=int(game.combat_rules.hero["level"])
	var tactical_spec: Dictionary=game.combat_rules.data["monsters"][enemy["id"]].duplicate(true)
	if str(enemy["id"]).begins_with("gou_ga"):
		var relief: int=int(monster.get("relationship_relief",game.relationships.final_relief()))
		monster["relationship_relief"]=relief
		for group: String in ["patterns","phase_patterns"]:
			for intent: Dictionary in tactical_spec.get("tactics",{}).get(group,[]):
				intent["power"]=float(intent.get("power",1))*(1-relief/100.0)
				intent["mp_drain"]=float(intent.get("mp_drain",0))*(1-relief/100.0)
		if relief>=24:tactical_spec["tactics"]["break_limit"]=1
		if not game.relationships.alive("gou_ga"):enemy["name"]="勾尬的门底残响"
	tactics.setup(tactical_spec,monster.get("tactics_state",{}))
	turn=int(tactics.state["turn"]);tactics.begin_turn(enemy,turn)
	root_panel=Control.new();root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root_panel)
	var background:=ColorRect.new();background.color=Color("202b2e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root_panel.add_child(background)
	interface=source.new();interface.game=game;interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_panel.add_child(interface)
	base_pose=Assets.fetch("res://assets/characters/hero/battle/zhao_mugei_rear_quarter.png")
	punch_pose=Assets.fetch("res://assets/characters/hero/battle/zhao_mugei_punch.png")
	dodge_pose=Assets.fetch("res://assets/characters/hero/battle/zhao_mugei_dodge.png")
	interface.ally_slot.set_combatant("赵慕gei",base_pose)
	var enemy_texture: Texture2D=record["portrait"] if record.has("portrait") else record["sprite"].texture if record.has("sprite") else MonsterScene.portrait(game.battle_asset_root.path_join(game.combat_rules.data["monsters"][enemy["id"]]["art"]))
	interface.enemy_slot.set_combatant(enemy["name"],enemy_texture)
	if enemy.get("rarity","")=="boss":interface.stage.set_composition(Vector2(.25,.90),Vector2(.73,.64),.91,.53)
	enemy_motion=Motion.new();enemy_motion.configure(game.battle_asset_root,game.combat_rules.data["monsters"][enemy["id"]],interface.enemy_slot)
	hero_motion=Motion.new();hero_motion.configure(game.battle_asset_root,{"portrait_atlas":"assets/characters/hero/battle/actions-v2/atlas.png"},interface.ally_slot)
	interface.ally_slot.portrait_view.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	interface.enemy_slot.portrait_view.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	interface.action_selected.connect(selected)
	var environment:=preload("res://battle_environment.gd").new()
	interface.set_battle_background(environment.capture(game,root_panel))
	interface.location_name=environment.scene_name
	interface.stage.set_composition(environment.ally_foot,environment.enemy_foot,.85,.53 if enemy.get("rarity","")=="boss" else .42)
	hero_label=interface.hero_label;enemy_label=interface.enemy_label
	log_label=interface.log_label;intent_label=interface.intent_label
	charge_toggle=interface.charge_toggle;close_button=interface.close_button
	charge_toggle.toggled.connect(func(_value: bool):update_ui())
	close_button.pressed.connect(close)
	escape_confirmation=ConfirmationDialog.new();escape_confirmation.title="撤离战斗"
	escape_confirmation.dialog_text="撤离后双方保留剩余血量。确定撤离？"
	escape_confirmation.ok_button_text="确认";escape_confirmation.cancel_button_text="取消"
	escape_confirmation.theme=interface.theme;escape_confirmation.confirmed.connect(func():finish("escape"))
	root_panel.add_child(escape_confirmation)
	game.pending_npc_talk="";game.pending_monster="";game.player.path.clear();game.player.velocity=Vector2.ZERO
	game.gameplay_hud.hide();show();game.refresh_player_freeze();game.update_time_display()
	append_log("遭遇 "+enemy["name"]+"。请选择操作。")
	if int(monster.get("relationship_relief",0))>0:append_log("她在回路失控前收住了一部分力量：招式威力与抽蓝降低 %d%%。" % int(monster["relationship_relief"]))
	if not tactics.spec.is_empty():append_log(str(tactics.spec.get("intro",""))+" 看右侧预告选择反制元素。")
	update_ui()
	return true

func _process(delta: float) -> void:
	if not visible or interface==null or not result.is_empty():return
	if enemy_motion!=null:enemy_motion.tick(delta)
	if hero_motion!=null and not busy:hero_motion.tick(delta)

func append_log(text_value: String) -> void:
	history.append(text_value)
	while history.size()>100:history.pop_front()
	log_label.text=text_value

func update_ui() -> void:
	var hero: Dictionary=game.combat_rules.hero
	hero_label.text="赵慕gei  Lv.%d\nHP %d / %d    MP %d / %d\n精力 %d / %d    SAN %d / %d" % [hero["level"],hero["hp_current"],hero["hp"],hero["mp_current"],hero["mp"],hero["energy_current"],hero["energy"],hero["san_current"],hero["san"]]
	hero_label.text+="\n经验 %d%s" % [hero["experience"],"（已满级）" if int(hero["level"])>=game.combat_rules.maximum_level() else " / "+str(game.combat_rules.experience_required(int(hero["level"])))]
	hero_label.text+=" · 每回合回精 %d" % game.combat_rules.energy_recovery()
	if not ailments.is_empty():hero_label.text+="\n状态："+" / ".join(ailments.keys())
	intent_label.text=tactics.description()
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
		var action: Dictionary={"id":id,"label":spec["name"],"category":"magic" if spec["kind"]=="magic" else "attack" if spec["kind"]=="physical" else "dodge","description":spec.get("description","")}
		if spec["kind"]=="magic":
			action.merge({"damage_kind":"magic","element":spec["element"],"tier":spec["tier"],"effect":spec["effect"],"mp_cost":game.combat_rules.spell_cost(spec["tier"],charge_toggle.button_pressed)})
			if spec.get("element","")=="dark":action["mp_cost"]=maxi(1,int(action["mp_cost"])/2)
			action["description"]="消耗 %d MP · %s" % [action["mp_cost"],"蓄力一回合后双倍伤害" if charge_toggle.button_pressed else "立即施法"]
		else:
			if spec.has("mp_base"):action["mp_cost"]=int(spec["mp_base"])+int(spec.get("mp_growth",0))*int(hero["level"])
			elif id=="barrier":action["mp_cost"]=20+5*int(hero["level"])
			else:action["energy_cost"]=game.combat_rules.energy_cost(spec)
			if spec["kind"]=="physical":action.merge({"damage_kind":"physical","multiplier":spec["multiplier"]})
			if spec.has("cooldown"):action["cooldown"]=spec["cooldown"]
			action["description"]+=" · %s" % (str(action["mp_cost"])+" MP" if action.has("mp_cost") else str(action.get("energy_cost",0))+" 精力")
		available.append(action)
	for item_id: String in game.economy.catalog:
		var item: Dictionary=game.economy.catalog[item_id]
		if item.get("plot_item",false) or item.get("restore",{}).is_empty() and item.get("restore_ratio",{}).is_empty():continue
		if game.economy.quantity(item_id)<=0:continue
		available.append({"id":"supply/"+item_id,"label":str(item["name"])+" ×"+str(game.economy.quantity(item_id)),"category":"items","item_id":item_id,"description":str(item["description"])+" · 消耗一回合，敌方仍会行动"})
	if int(ailments.get("封蓝",0))>=turn:
		for action: Dictionary in available:
			if action.get("damage_kind","")=="magic":
				action["mp_cost"]=ceili(int(action.get("mp_cost",0))*1.3);action["description"]+=" · 封蓝耗蓝+30%"
	if not pending_spell.is_empty():available.append({"id":"release_spell","category":"magic","label":"释放 · "+str(pending_spell["label"]),"description":"已支付 MP，释放双倍伤害"})
	action_map.clear()
	charge_toggle.disabled=busy or not result.is_empty() or not pending_spell.is_empty()
	for action: Dictionary in available:
		action_map[action["id"]]=action
		var category: String=action["category"]
		if not categories.has(category):categories[category]=[]
		var enabled:=int(hero["mp_current"])>=int(action.get("mp_cost",0)) and int(hero["energy_current"])>=int(action.get("energy_cost",0))
		if action.has("item_id"):enabled=game.economy.can_use(action["item_id"],hero)
		if not enabled:action["description"]+=" · "+("状态已满或物品不足" if action.has("item_id") else "精力不足" if int(hero["energy_current"])<int(action.get("energy_cost",0)) else "MP 不足")
		if int(cooldowns.get(action["id"],0))>turn:enabled=false;action["description"]+=" · 冷却 %d 回合" % (int(cooldowns[action["id"]])-turn)
		if not pending_spell.is_empty() and not action["id"] in ["release_spell","escape","auto"]:enabled=false
		var caption: String=action["label"]
		if action.has("energy_cost"):caption+=" · %d精" % int(action["energy_cost"])
		elif action.has("mp_cost"):caption+=" · %dMP" % int(action["mp_cost"])
		if int(cooldowns.get(action["id"],0))>turn:caption+="（冷%d）" % (int(cooldowns[action["id"]])-turn)
		var move_hints: Dictionary={"shoulder_check":"1.45倍物伤 · 抗物理反击","short_combo":"1.85倍物伤 · 出拳不格挡","brace_guard":"物理减伤70% / 法术30%","wind_step":"必闪一次 · 冷却3回合"}
		if move_hints.has(action["id"]):caption+="\n"+str(move_hints[action["id"]])
		if action.has("item_id"):
			var item: Dictionary=game.economy.catalog[action["item_id"]]
			var amounts: Array[String]=[]
			for stat: String in ["hp","mp","energy","san"]:
				var amount:=int(item.get("restore",{}).get(stat,0))+floori(int(hero[stat])*float(item.get("restore_ratio",{}).get(stat,0)))
				if amount>0:amounts.append(str(amount)+str({"hp":"HP","mp":"MP","energy":"精","san":"SAN"}[stat]))
			caption+="\n回 "+" / ".join(amounts)+" · 占一回合"
		categories[category].append({"id":action["id"],"label":caption,"description":action.get("description",""),"enabled":enabled})
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
	if not visible or busy or not result.is_empty() or not action_map.has(id) or escape_confirmation.visible:return
	if id=="auto":
		auto_battle=not auto_battle;update_ui()
		if auto_battle:automatic_turn()
		return
	if id=="escape":auto_battle=false;escape_confirmation.popup_centered(Vector2i(480,180));return
	if not pending_spell.is_empty() and id!="release_spell":return
	if int(cooldowns.get(id,0))>turn:append_log("技能正在冷却。");return
	var action: Dictionary=action_map[id].duplicate(true)
	var hero: Dictionary=game.combat_rules.hero
	if action.has("item_id") and not game.economy.can_use(action["item_id"],hero):append_log("物品不足或状态已满。");return
	if int(hero["mp_current"])<int(action.get("mp_cost",0)) or int(hero["energy_current"])<int(action.get("energy_cost",0)):append_log("资源不足，请先休整。");return
	var releasing:=id=="release_spell"
	# SAN was paid on the charging turn. Release cannot charge it twice.
	if not releasing and game.campaign!=null and not game.campaign.before_action(action,charge_toggle.button_pressed):return
	busy=true
	hero["mp_current"]-=int(action.get("mp_cost",0));hero["energy_current"]-=int(action.get("energy_cost",0))
	for key: String in ["mp","energy"]:hero[key+"_current"]=mini(int(hero[key]),int(hero[key+"_current"])+int(action.get(key+"_restore",0)))
	var message: String=action["label"]
	var charging: bool=action.get("damage_kind","")=="magic" and charge_toggle.button_pressed and not releasing
	if charging:
		game.sounds.play("charge")
		pending_spell=action.duplicate(true);message=action["label"]+"蓄力中；本回合敌方行动，下回合释放。"
		await hero_motion.play("windup")
	elif action.has("damage_kind") or releasing or id=="resonance_break":
		if releasing:action=pending_spell.duplicate(true);pending_spell={}
		if id=="resonance_break":
			action["damage_kind"]="magic";action["element"]=str(tactics.intent.get("counters",["light"])[0]) if not tactics.intent.get("counters",[]).is_empty() else "light"
			action["effect"]="light_low";cooldowns[id]=turn+3
		var multiplier: float=.6 if id=="resonance_break" else float(action.get("multiplier",1.0))
		if action.has("cooldown"):cooldowns[id]=turn+int(action["cooldown"])
		if action.get("damage_kind","")=="magic" and action.has("tier"):multiplier=float(game.combat_rules.data["magic_tiers"][action["tier"]]["multiplier"])
		var amplifier: float=(2.0 if releasing else 1.0)*(1.25 if focus_ready and action.get("damage_kind","")=="magic" else 1.0)
		if action.get("element","")=="lightning" and game.economy.quantity("insulation_bracer")>0:amplifier*=1.1
		var response:=tactics.hit(action)
		if id=="shoulder_check" and tactics.intent.get("kind","physical")=="physical":
			action["reduction"]=.65
		var damage: int=game.combat_rules.damage(hero,enemy,action["damage_kind"],0,str(action.get("element","")),multiplier,amplifier)
		if action.get("damage_kind","")=="magic":focus_ready=false
		enemy["hp_current"]=maxi(0,int(enemy["hp_current"])-damage);monster["hp"]=enemy["hp_current"]
		message="%s造成 %d 伤害。%s" % [action["label"],damage,"破势！本次敌方无法行动。" if response["break"] else "反制成功，本次反击减伤65%。" if response["counter"] else "冰系迟滞，本次反击减伤20%。" if response["slow"] else ""]
		if action.get("damage_kind","")=="physical":game.sounds.play("attack_swing")
		if id=="shoulder_check":
			message+=" 沉肩抢进；对本次物理反击减伤65%。" if action.has("reduction") else " 对手正在施法，贴身撞击无法截住法术。"
			await hero_motion.play("guard",.16);await hero_motion.play("attack",.24)
		elif id=="short_combo":
			interface.ally_slot.set_pose(punch_pose);await move_hero(Vector2(13,0));await hero_motion.play("attack",.2)
		elif id=="physical":interface.ally_slot.set_pose(punch_pose);await move_hero(Vector2(20,0))
		else:await hero_motion.play("attack")
		if action.has("effect"):await spell_effect(action["effect"],interface.enemy_slot)
		game.sounds.play("impact") if action.get("damage_kind","")=="physical" else game.sounds.effect(str(action.get("effect",action.get("element","light"))))
		if response["break"]:game.sounds.play("break_stance")
		await enemy_motion.play("hit");await flash_actor(interface.enemy_slot)
	elif id in ["dodge","wind_step"]:
		game.sounds.play("dodge")
		interface.ally_slot.set_pose(dodge_pose);await move_hero(Vector2(-22,0))
		if id=="wind_step":
			cooldowns[id]=turn+3
			message="蹬地撤步，爆发换位避开这次攻击及干扰；没有额外回复。"
	elif id=="barrier":
		barrier_turns=2;cooldowns[id]=turn+3;game.sounds.play("guard");await hero_motion.play("guard");await spell_effect("world_barrier",interface.ally_slot)
	elif id=="focus":
		focus_ready=true;cooldowns[id]=turn+3;await hero_motion.play("windup");await spell_effect("world_magic_circle",interface.ally_slot)
	elif id=="mana_cycle":
		action["reduction"]=.5 # Close the circuit before drawing mana back.
		var restored:=maxi(game.combat_rules.spell_cost("low"),maxi(10+10*int(hero["level"]),floori(int(hero["mp"])*.12)))
		hero["mp_current"]=mini(int(hero["mp"]),int(hero["mp_current"])+restored);cooldowns[id]=turn+3
		message="魔力回流，恢复 %d MP。" % restored;game.sounds.play("heal" if action.has("item_id") else "rest");await hero_motion.play("rest")
	elif id=="steady_guard":action["reduction"]=.65;cooldowns[id]=turn+3;game.sounds.play("guard");await hero_motion.play("guard")
	elif id=="brace_guard":
		action["reduction"]=.7 if tactics.intent.get("kind","physical")=="physical" else .3
		cooldowns[id]=turn+int(action["cooldown"]);message="架臂护住要害，本次%s减伤%d%%。" % ["物理" if action["reduction"]==.7 else "法术",roundi(float(action["reduction"])*100)]
		game.sounds.play("guard");await hero_motion.play("guard")
	elif id=="second_wind":
		var healed:=mini(int(hero["hp"])-int(hero["hp_current"]),floori(int(hero["hp"])*.18))
		hero["hp_current"]+=healed;action["reduction"]=.35;cooldowns[id]=turn+3
		message="稳住呼吸，恢复 %d HP；本次减伤35%%。" % healed;game.sounds.play("heal" if action.has("item_id") else "rest");await hero_motion.play("rest")
	elif id=="clarity":
		ailments.clear();clarity_turns=2;action["reduction"]=.35;cooldowns[id]=turn+3
		message="清明印净化干扰，并保护两次敌方行动。";game.sounds.play("guard");await hero_motion.play("guard")
	elif id=="rest":
		var restored:=maxi(20,floori(int(hero["mp"])*.05))
		hero["mp_current"]=mini(int(hero["mp"]),int(hero["mp_current"])+restored-20)
		message="休整：恢复 %d MP。精力按回合自然恢复，敌方仍会行动。" % restored;game.sounds.play("heal" if action.has("item_id") else "rest");await hero_motion.play("rest")
	elif action.has("item_id"):
		var used: Dictionary=game.economy.use(action["item_id"],hero)
		if used["ok"]:
			game.record_game_event("item_used/"+str(action["item_id"]))
			if game.campaign!=null and game.campaign.active():game.campaign.flags["SAN"]=clampi(ceili(float(hero["san_current"])*100/maxi(1,int(hero["san"]))),0,100)
		message=used["message"]+"，敌方仍会行动。";game.sounds.play("heal" if action.has("item_id") else "rest");await hero_motion.play("rest")
	elif id=="guard":game.sounds.play("guard");await hero_motion.play("guard")
	append_log(message)
	if game.campaign!=null:game.campaign.ally_support(self)
	if tactics.change_phase(enemy):
		game.sounds.play("boss_phase" if enemy["id"]=="gou_ga_boss" else "story_rumble");enemy_motion.phase=2;append_log(str(tactics.spec.get("phase_line","阶段改变")));await enemy_motion.play("phase",.6)
	monster["hp"]=enemy["hp_current"]
	update_ui();await get_tree().create_timer(.2).timeout
	if int(enemy["hp_current"])<=0:
		recover_energy();finish("victory");return
	var dodged: bool=id=="wind_step" or id=="dodge" and game.monster_world.rng.randf()<float(action.get("dodge_chance",0))
	if tactics.staggered:append_log("敌方架势被打断，失去这次行动。")
	elif dodged:append_log("换位成功！躲开 "+str(tactics.intent.get("name","攻击"))+"，附加效果一并避开。")
	else:
		var reduction: float=maxf(float(action.get("reduction",0)),.5 if barrier_turns>0 else 0)
		if game.campaign!=null:reduction=maxf(reduction,game.campaign.battle_reduction(enemy["id"]))
		reduction=1.0-(1.0-reduction)*(1.0-tactics.reduction())
		var power: float=float(tactics.intent.get("power",1.0))*(1.2 if int(ailments.get("易伤",0))>=turn else 1.0)
		var attacker: Dictionary=enemy.duplicate();attacker["attack"]=floori(int(enemy["attack"])*power)
		var kind: String=tactics.intent.get("kind",game.combat_rules.data["monsters"][enemy["id"]].get("attack_kind","physical"))
		var damage: int=game.combat_rules.damage(attacker,hero,kind,reduction)
		game.sounds.play("boss_thread" if enemy["id"]=="gou_ga_boss" else "attack_swing" if kind=="physical" else "dark")
		await enemy_motion.play("windup",.2);await enemy_motion.play("attack")
		if not npc_target.is_empty() and kind=="magic":await spell_effect("world_magic_circle",interface.enemy_slot)
		hero["hp_current"]=maxi(0,int(hero["hp_current"])-damage)
		game.sounds.play("guard" if reduction>=.5 else "impact");await hero_motion.play("hit");await flash_actor(interface.ally_slot)
		var speech: String=""
		if not npc_target.is_empty():speech=game.relationships.social.say(npc_target,"attack")
		append_log((enemy["name"]+"："+speech+"\n" if not speech.is_empty() else "")+"%s · %s：%d 伤害。" % [enemy["name"],tactics.intent.get("name","攻击"),damage])
		var protected: bool=clarity_turns>0 or barrier_turns>0 or float(action.get("reduction",0))>=.5 or tactics.countered
		if not protected:
			var status: String=tactics.intent.get("status","")
			if not status.is_empty():
				ailments["封蓝" if status=="seal" else "易伤"]=turn+2
				append_log("受到干扰："+("封蓝，法术耗蓝+30%" if status=="seal" else "易伤，受到伤害+20%")+"。两回合后消退，可用清明印解除。")
			var drain:=floori(int(hero["mp"])*float(tactics.intent.get("mp_drain",0)))
			hero["mp_current"]=maxi(0,int(hero["mp_current"])-drain)
			if drain>0:append_log("勾尬牵线抽走 %d MP。防守、屏障、净化或元素反制可阻止干扰。" % drain)
	interface.ally_slot.restore_pose()
	if barrier_turns>0:barrier_turns-=1
	if clarity_turns>0:clarity_turns-=1
	if int(hero["hp_current"])<=0:finish("defeat");return
	recover_energy()
	turn+=1
	for status: String in ailments.keys():
		if int(ailments[status])<turn:ailments.erase(status)
	tactics.begin_turn(enemy,turn);monster["tactics_state"]=tactics.snapshot()
	busy=false;update_ui()
	if auto_battle:automatic_turn()

func recover_energy() -> void:
	var recovered: int=game.combat_rules.recover_turn_energy()
	if recovered>0:history.append("回合结算：精力自然恢复 %d。" % recovered)

func move_hero(offset: Vector2) -> void:
	var actor: Control=interface.ally_slot
	var at:=actor.position
	var tween:=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(actor,"position",at+offset,.15)
	tween.tween_property(actor,"position",at,.15)
	await tween.finished

func flash_actor(actor: Control) -> void:
	actor.modulate=Color(1,.35,.35)
	await get_tree().create_timer(.13).timeout
	actor.modulate=Color.WHITE

func spell_effect(id: String, actor: Control) -> void:
	game.sounds.effect(id)
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
	game.sounds.play("victory" if outcome=="victory" else "defeat" if outcome=="defeat" else "escape")
	busy=false;auto_battle=false;result=outcome
	monster["tactics_state"]=tactics.snapshot()
	if outcome=="victory" and enemy_motion!=null and not enemy_motion.frames.is_empty():interface.enemy_slot.set_pose(enemy_motion.texture("defeat"))
	if outcome=="victory" and not npc_target.is_empty():
		if lethal_npc:
			game.relationships.kill(npc_target)
			append_log(str(npc_target["name"])+"死亡。幸存队友好感大幅下降；死亡已写入当前冒险状态。")
		else:
			if not hostile_npc:game.relationships.once(game.relationships.identity(npc_target),"duel",1)
			game.relationships.social.remember(game.relationships.identity(npc_target),"spared")
			append_log(str(npc_target["name"])+"："+game.relationships.social.say(npc_target,"defeat")+"\n"+("拦截被击退。没有角色死亡，也不获得好感、经验或物资。" if hostile_npc else "切磋结束，双方收手。没有角色死亡。"))
	elif outcome=="victory":
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
	elif outcome=="defeat":append_log((str(npc_target["name"])+"："+game.relationships.social.say(npc_target,"victory")+"\n" if not npc_target.is_empty() else "")+"战斗失败。结束后恢复状态。")
	else:append_log((str(npc_target["name"])+"："+game.relationships.social.say(npc_target,"escape")+"\n" if not npc_target.is_empty() else "")+"已撤离。保留剩余血量。")
	update_ui()

func close() -> void:
	if result.is_empty() or busy:return
	var outcome:=result
	var story_battle: bool=game.campaign!=null and game.campaign.is_story_battle()
	var remaining: Dictionary=monster.duplicate(true)
	var npc_encounter: bool=not npc_target.is_empty()
	var npc_death: bool=npc_encounter and lethal_npc and outcome=="victory"
	var hostile: bool=hostile_npc
	hide();root_panel.queue_free();root_panel=null;interface=null
	base_pose=null;punch_pose=null;dodge_pose=null
	enemy_motion=null;hero_motion=null;ailments.clear()
	monster={};enemy={};action_map.clear()
	npc_target={};lethal_npc=false;hostile_npc=false
	if npc_encounter:game.combat_rules.data["monsters"].erase(str(remaining["id"]))
	game.gameplay_hud.show();game.refresh_player_freeze();game.interaction_delay=1.0
	if npc_encounter:
		if hostile:game.relationships.social.reset(45)
		if outcome=="defeat":game.combat_rules.refill_hero()
		game.sync_classroom_period()
		if npc_death:
			game.dialogue_view.begin_script([game.relationships.grievances[-1]])
		elif hostile and outcome=="defeat":game.reset_player()
		return
	game.sync_monsters()
	if game.campaign!=null and game.campaign.active() and game.campaign.san()<=0:game.campaign.present_ending("BE-2")
	elif story_battle:game.campaign.battle_closed(outcome,remaining)
	elif outcome=="defeat":
		game.combat_rules.refill_hero()
		if game.campaign!=null and game.campaign.active():game.campaign.change_san(0)
		game.reset_player()
	else:
		if outcome=="victory" and game.campaign!=null and game.campaign.active():game.campaign.world_victory(remaining.get("id",""))
		if outcome=="victory" and game.monster_world.zone_rule(game.interior_state).get("farming",false):game.advance_world_period()
		game.show_notice("战斗胜利" if outcome=="victory" else "已撤离战斗")
