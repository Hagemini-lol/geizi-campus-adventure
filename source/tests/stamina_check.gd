extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
var sweep: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok:failures.append(text);push_error(text)
func _process(_delta: float) -> bool:
	if game!=null and game.dialogue_view!=null and game.dialogue_view.visible:game.dialogue_view.accept()
	return false
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.game_started=true;game.front_end.hide_title();game.gameplay_hud.show();game.story_system.stage=6;game.story_system.reward_given=true
	game.campaign.index=1;game.campaign.support_id="lao_shuo"
	var r: RefCounted=game.combat_rules
	for level: int in range(61):
		r.reset_hero();r.set_hero_level(level,true)
		var recover: int=r.energy_recovery()
		var total:=0
		for id: String in ["shoulder_check","short_combo","brace_guard","wind_step"]:
			var cost: int=r.energy_cost(r.data["skills"][id]);total+=cost
			check(cost>recover and cost<=int(r.hero["energy"]),"affordable burst, not self-funding %d %s" % [level,id])
		check(total-4*recover>=int(r.hero["energy"])*.4,"four distinct burst actions spend at least40%% net %d" % level)
		r.hero["energy_current"]=int(r.hero["energy"])-1
		check(r.recover_turn_energy()==1 and r.hero["energy_current"]==r.hero["energy"],"automatic recovery clamps %d" % level)
		sweep.append({"level":level,"maximum":r.hero["energy"],"per_turn":recover,"burst_cost":total,"net_four_actions":total-4*recover})
	r.reset_hero();r.set_hero_level(10,true)
	for id: String in r.data["skills"]:r.learn(id)
	game.economy.inventory["water"]=3
	var stats: Dictionary=r.monster_stats("gou_ga_boss",45)
	var monster: Dictionary={"uid":"stamina","id":"gou_ga_boss","level":45,"hp":stats["hp"]}
	game.battle_view.start({"monster":monster},"test")
	var v: Control=game.battle_view
	r.hero["energy_current"]=0;v.update_ui()
	var turn: int=v.turn
	await v.perform("short_combo")
	check(v.turn==turn and r.hero["energy_current"]==0,"insufficient stamina neither acts nor regenerates")
	r.hero["energy_current"]=100;var regen: int=r.energy_recovery()
	v.tactics.staggered=true;await v.perform("guard")
	check(r.hero["energy_current"]==100+regen,"guard only receives standard turn regeneration")
	v.tactics.staggered=true;await v.perform("rest")
	check(r.hero["energy_current"]==100+2*regen,"rest does not create extra stamina")
	var before: int=r.hero["energy_current"];var water: int=game.economy.quantity("water");turn=v.turn
	v.tactics.staggered=true;await v.perform("supply/water")
	check(game.economy.quantity("water")==water-1 and v.turn==turn+1,"battle water consumes one item and one turn")
	check(r.hero["energy_current"]==before+30+floori(int(r.hero["energy"])*.2)+regen,"item plus one standard turn regeneration")
	check(game.event_state.get("item_used/water",0)>=1,"battle supply publishes use event")
	r.hero["energy_current"]=int(r.hero["energy"]);v.update_ui()
	water=game.economy.quantity("water");turn=v.turn
	await v.perform("supply/water")
	check(game.economy.quantity("water")==water and v.turn==turn,"full stamina cannot waste water or farm turn")
	# Physical skills have no mana payment, no elemental hit, and a real cooldown.
	for id: String in ["shoulder_check","short_combo","brace_guard","wind_step"]:
		r.refill_hero();v.cooldowns.clear();v.ailments.clear();v.update_ui()
		v.tactics.staggered=true
		var mp: int=r.hero["mp_current"];before=r.hero["energy_current"]
		var cost: int=v.action_map[id]["energy_cost"]
		await v.perform(id)
		check(r.hero["energy_current"]==before-cost+regen,"actual energy spending "+id)
		check(r.hero["mp_current"]==mp,"physical action never spends or creates MP "+id)
		check(int(v.cooldowns[id])>v.turn,"cooldown enforced "+id)
		turn=v.turn;await v.perform(id);check(v.turn==turn,"cooldown denial cannot farm regeneration "+id)
	# Shoulder catches a physical windup but cannot silence Gouga's spell.
	for kind: String in ["physical","magic"]:
		r.refill_hero();v.cooldowns.clear();v.ailments.clear();v.update_ui()
		v.tactics.intent={"kind":kind,"power":.1,"name":"test","counters":[]}
		var hp: int=r.hero["hp_current"]
		var attacker: Dictionary=v.enemy.duplicate();attacker["attack"]=floori(int(attacker["attack"])*.1)
		var expected: int=r.damage(attacker,r.hero,kind,.65 if kind=="physical" else .2)
		await v.perform("shoulder_check")
		check(hp-int(r.hero["hp_current"])==expected,"shoulder mitigation distinguishes "+kind)
	v.finish("escape");before=r.hero["energy_current"];v.close();await process_frame
	game.battle_view.start({"monster":monster},"test")
	check(r.hero["energy_current"]==before,"retreat and reopen cannot farm regeneration")
	game.battle_view.finish("escape");game.battle_view.close()
	var f:=FileAccess.open(game.package_root.path_join("runtime/stamina_checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"levels":sweep,"recovery":"3% max, minimum10, once per completed living battle turn; water/bread use consumes one turn"},"  "))
	print("STAMINA_CHECKS ",checks," FAILURES ",failures.size());quit(0 if failures.is_empty() else 1)
