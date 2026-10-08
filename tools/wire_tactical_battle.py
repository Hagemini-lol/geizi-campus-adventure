from pathlib import Path
root=Path(__file__).resolve().parents[1]
if (root/'VERSION').read_text(encoding='utf-8-sig').strip() not in ['1.0.0','1.1.0','1.2.0','1.2.1','1.2.2']:
    raise SystemExit('Historical first-pass battle template. It predates stamina and consumables; edit battle_view.gd directly.')
path=root/'source/battle_view.gd'
source=path.read_text(encoding='utf-8-sig')
start=source.index('func perform(id: String) -> void:')
end=source.index('func flash_actor(',start)
source=source[:start]+'''func perform(id: String) -> void:
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
		pending_spell=action.duplicate(true);message=action["label"]+"蓄力中；本回合敌方行动，下回合释放。"
		await hero_motion.play("windup")
	elif action.has("damage_kind") or releasing or id=="resonance_break":
		if releasing:action=pending_spell.duplicate(true);pending_spell={}
		if id=="resonance_break":
			action["damage_kind"]="magic";action["element"]=str(tactics.intent.get("counters",["light"])[0]) if not tactics.intent.get("counters",[]).is_empty() else "light"
			action["effect"]="light_low";cooldowns[id]=turn+3
		var multiplier:=.6 if id=="resonance_break" else 1.0
		if action.get("damage_kind","")=="magic" and action.has("tier"):multiplier=float(game.combat_rules.data["magic_tiers"][action["tier"]]["multiplier"])
		var amplifier: float=(2.0 if releasing else 1.0)*(1.25 if focus_ready and action.get("damage_kind","")=="magic" else 1.0)
		if action.get("element","")=="lightning" and game.economy.quantity("insulation_bracer")>0:amplifier*=1.1
		var response:=tactics.hit(action)
		var damage: int=game.combat_rules.damage(hero,enemy,action["damage_kind"],0,str(action.get("element","")),multiplier,amplifier)
		if action.get("damage_kind","")=="magic":focus_ready=false
		enemy["hp_current"]=maxi(0,int(enemy["hp_current"])-damage);monster["hp"]=enemy["hp_current"]
		message="%s造成 %d 伤害。%s" % [action["label"],damage,"破势！本次敌方无法行动。" if response["break"] else "反制成功，本次反击减伤65%。" if response["counter"] else "冰系迟滞，本次反击减伤20%。" if response["slow"] else ""]
		if id=="physical":interface.ally_slot.set_pose(punch_pose);await move_hero(Vector2(20,0))
		else:await hero_motion.play("attack")
		if action.has("effect"):await spell_effect(action["effect"],interface.enemy_slot)
		await enemy_motion.play("hit");await flash_actor(interface.enemy_slot)
	elif id in ["dodge","wind_step"]:
		interface.ally_slot.set_pose(dodge_pose);await move_hero(Vector2(-22,0))
		if id=="wind_step":
			cooldowns[id]=turn+3;hero["mp_current"]=mini(int(hero["mp"]),int(hero["mp_current"])+maxi(10,floori(int(hero["mp"])*.04)))
			message="踏风换位，避开这次攻击及干扰，恢复少量 MP。"
	elif id=="barrier":
		barrier_turns=2;cooldowns[id]=turn+3;await hero_motion.play("guard");await spell_effect("world_barrier",interface.ally_slot)
	elif id=="focus":
		focus_ready=true;cooldowns[id]=turn+3;await hero_motion.play("windup");await spell_effect("world_magic_circle",interface.ally_slot)
	elif id=="mana_cycle":
		var restored:=maxi(10+10*int(hero["level"]),floori(int(hero["mp"])*.12))
		hero["mp_current"]=mini(int(hero["mp"]),int(hero["mp_current"])+restored);cooldowns[id]=turn+3
		message="魔力回流，恢复 %d MP。" % restored;await hero_motion.play("rest")
	elif id=="steady_guard":action["reduction"]=.65;cooldowns[id]=turn+3;await hero_motion.play("guard")
	elif id=="second_wind":
		var healed:=mini(int(hero["hp"])-int(hero["hp_current"]),floori(int(hero["hp"])*.18))
		hero["hp_current"]+=healed;action["reduction"]=.35;cooldowns[id]=turn+3
		message="稳住呼吸，恢复 %d HP；本次减伤35%%。" % healed;await hero_motion.play("rest")
	elif id=="clarity":
		ailments.clear();clarity_turns=2;action["reduction"]=.35;cooldowns[id]=turn+3
		hero["energy_current"]=mini(int(hero["energy"]),int(hero["energy_current"])+25)
		message="清明印净化干扰，并保护两次敌方行动。";await hero_motion.play("guard")
	elif id=="rest":
		var restored:=maxi(20,floori(int(hero["mp"])*.05))
		hero["mp_current"]=mini(int(hero["mp"]),int(hero["mp_current"])+restored-20)
		message="休整：恢复 %d MP 和 50 精力。敌方仍会行动。" % restored;await hero_motion.play("rest")
	elif id=="guard":await hero_motion.play("guard")
	append_log(message)
	if game.campaign!=null:game.campaign.ally_support(self)
	if tactics.change_phase(enemy):
		enemy_motion.phase=2;append_log(str(tactics.spec.get("phase_line","阶段改变")));await enemy_motion.play("phase",.6)
	monster["hp"]=enemy["hp_current"]
	update_ui();await get_tree().create_timer(.2).timeout
	if int(enemy["hp_current"])<=0:finish("victory");return
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
		await enemy_motion.play("windup",.2);await enemy_motion.play("attack")
		hero["hp_current"]=maxi(0,int(hero["hp_current"])-damage)
		await hero_motion.play("hit");await flash_actor(interface.ally_slot)
		append_log("%s · %s：%d 伤害。" % [enemy["name"],tactics.intent.get("name","攻击"),damage])
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
	turn+=1
	for status: String in ailments.keys():
		if int(ailments[status])<turn:ailments.erase(status)
	tactics.begin_turn(enemy,turn);monster["tactics_state"]=tactics.snapshot()
	busy=false;update_ui()
	if auto_battle:automatic_turn()

func move_hero(offset: Vector2) -> void:
	var actor: Control=interface.ally_slot
	var at:=actor.position
	var tween:=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(actor,"position",at+offset,.15)
	tween.tween_property(actor,"position",at,.15)
	await tween.finished

'''+source[end:]
source=source.replace('busy=false;auto_battle=false;result=outcome','busy=false;auto_battle=false;result=outcome\n\tmonster["tactics_state"]=tactics.snapshot()\n\tif outcome=="victory" and enemy_motion!=null and not enemy_motion.frames.is_empty():interface.enemy_slot.set_pose(enemy_motion.texture("defeat"))')
source=source.replace('base_pose=null;punch_pose=null;dodge_pose=null','base_pose=null;punch_pose=null;dodge_pose=null\n\tenemy_motion=null;hero_motion=null;ailments.clear()')
path.write_text(source,encoding='utf-8')
print('Battle UI connected to telegraphs, counters, status and motions')
