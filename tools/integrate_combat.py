from pathlib import Path
import json

root=Path(__file__).resolve().parents[1]
path=root/'source/main.gd'
s=path.read_text(encoding='utf-8')
def change(old,new):
    global s
    assert old in s, old[:100]
    s=s.replace(old,new,1)
change('var npc_catalog:=NpcCatalog.new()', '''const CombatRules=preload("res://combat_rules.gd")
const MonsterWorld=preload("res://monster_world.gd")
const MonsterScene=preload("res://monster_scene.gd")
const BattleView=preload("res://battle_view.gd")
var combat_rules:=CombatRules.new()
var monster_world:=MonsterWorld.new()
var battle_view: Control
var battle_asset_root: String
var pending_monster:=""
var npc_catalog:=NpcCatalog.new()''')
change('\tmenu_assets=config.get("menu_assets",{})','''	menu_assets=config.get("menu_assets",{})
	battle_asset_root=resolve_path(str(config.get("battle_asset_root","../Projects/赵慕gei的牙林冒险")))
	if not combat_rules.configure(resolve_path(str(config.get("combat_rules","战斗与刷新配置.json")))):
		fail("战斗数值配置缺失或格式错误");return
	monster_world.configure(combat_rules)''')
change('\tif "--skip-title" in OS.get_cmdline_user_args():','''	var battle_layer:=CanvasLayer.new();battle_layer.layer=95;add_child(battle_layer)
	battle_view=BattleView.new();battle_view.game=self
	battle_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);battle_layer.add_child(battle_view)
	if "--skip-title" in OS.get_cmdline_user_args():''')
# Add battle exclusion to every pre-existing gameplay/modal guard.
s=s.replace('dialogue_view.visible or','dialogue_view.visible or (battle_view!=null and battle_view.visible) or')
s=s.replace('(dialogue_view!=null and dialogue_view.visible) or not game_started','(dialogue_view!=null and dialogue_view.visible) or (battle_view!=null and battle_view.visible) or not game_started')
s=s.replace('not dialogue_view.visible:', 'not dialogue_view.visible and not battle_view.visible:')
s=s.replace('not dialogue_view.visible else', 'not dialogue_view.visible and not battle_view.visible else')
change('\tif not game_started or transition_busy:return {"ok":false,"error":"场景切换结束后才能保存"}', '\tif not game_started or transition_busy or battle_view.visible:return {"ok":false,"error":"场景切换或战斗结束后才能保存"}')
change('\treturn save_store.write_slot(slot,state,location)','''	state["combat"]={"hero":combat_rules.hero.duplicate(true),"world":monster_world.snapshot()}
	return save_store.write_slot(slot,state,location)''')
change('\tvar clean: Dictionary=state.duplicate(true)','''	if state.has("combat"):
		if not combat_rules.valid_snapshot(state["combat"]) or not monster_world.valid_snapshot(state["combat"].get("world")):return {"ok":false,"error":"存档中的战斗或刷新区数据无效"}
	var clean: Dictionary=state.duplicate(true)''')
change('func load_game_slot(slot: int) -> Dictionary:\n\tif transition_busy:', 'func load_game_slot(slot: int) -> Dictionary:\n\tif transition_busy or battle_view.visible:')
change('func queue_restore(state: Dictionary, message: String) -> Dictionary:\n\tvar checked', 'func queue_restore(state: Dictionary, message: String) -> Dictionary:\n\tif battle_view.visible:return {"ok":false,"error":"战斗结束后才能读档"}\n\tvar checked')
change('\tevent_state=pending_restore.get("events",{}).duplicate(true)', '''	event_state=pending_restore.get("events",{}).duplicate(true)
	combat_rules.restore(pending_restore.get("combat",{}))
	monster_world.restore(pending_restore.get("combat",{}).get("world",{}))''')
change('func return_to_title() -> void:\n\tif transition_busy:return', 'func return_to_title() -> void:\n\tif transition_busy or battle_view.visible:return')
change('\tif not game_started or transition_busy:return false\n\tadvance_time_period()', '\tif not game_started or transition_busy or battle_view.visible:return false\n\tadvance_time_period()')
change('\tday_clock.next_period()', '\tday_clock.next_period()\n\tmonster_world.advance(interior_state)\n\tsync_monsters()')
# Clear deferred interaction targets whenever routes/scenes/menus are changed.
s=s.replace('\tpending_npc_talk=""\n', '\tpending_npc_talk=""\n\tpending_monster=""\n')
change('\tapply_pending_restore()\n\tinteraction_delay=.7','\tapply_pending_restore()\n\tsync_monsters()\n\tinteraction_delay=.7')
change('\tapply_pending_restore()\n\tplayer.camera.reset_smoothing()', '\tapply_pending_restore()\n\tsync_monsters()\n\tplayer.camera.reset_smoothing()')
change('\tif dialogue_view!=null and dialogue_view.visible:', '''	if battle_view!=null and battle_view.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ENTER,KEY_KP_ENTER] and not battle_view.result.is_empty():battle_view.close()
			elif event.keycode==KEY_ESCAPE and not battle_view.busy:
				if not battle_view.result.is_empty():battle_view.close()
				elif battle_view.escape_confirmation.visible:battle_view.escape_confirmation.hide()
				else:battle_view.perform("escape")
			elif event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6]:battle_view.perform(["physical","magic","dodge","guard","rest","auto"][event.keycode-KEY_1])
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
			if not battle_view.busy and battle_view.result.is_empty():battle_view.perform("escape")
			get_viewport().set_input_as_handled()
		return
	if dialogue_view!=null and dialogue_view.visible:''')
change('\tif terrain.current_id>=0:\n\t\tvar place:', '''	if not pending_monster.is_empty() and not transition_busy and not player.frozen:
		if not player.input_direction().is_zero_approx():pending_monster=""
		elif player.path.is_empty():
			var manager: Node2D=active_monsters()
			var record: Dictionary=manager.find(pending_monster) if manager!=null else {}
			pending_monster=""
			if not record.is_empty() and player.position.distance_to(record["at"])<46:battle_view.start(record,manager.key)
	if terrain.current_id>=0:
		var place:''')
s=s.replace('not item["action"] in ["board","npc"]','not item["action"] in ["board","npc","monster"]')
change('\t\tif terrain.current_scene.npcs!=null:result.append_array(terrain.current_scene.npcs.interactions())', '\t\tif terrain.current_scene.npcs!=null:result.append_array(terrain.current_scene.npcs.interactions())\n\t\tif active_monsters()!=null:result.append_array(active_monsters().interactions())')
change('func click_interaction(at: Vector2) -> bool:\n', '''func click_interaction(at: Vector2) -> bool:
	var monsters: Node2D=active_monsters()
	if monsters!=null:
		for item: Dictionary in monsters.interactions():
			if not item["art_rect"].has_point(at):continue
			if player.position.distance_to(item["at"])<46:execute_interaction(item)
			else:
				var route: PackedVector2Array=monsters.approach(item["uid"],player.position)
				if route.is_empty():show_notice("请走近怪物，再按 E 战斗")
				else:pending_npc_talk="";player.path=route;pending_monster=item["uid"]
			return true
''')
change('\t\t"npc":return "和"', '\t\t"monster":return "与"+str(item["name"])+"战斗"\n\t\t"npc":return "和"')
change('\tmatch str(item["action"]):\n\t\t"npc":', '''	match str(item["action"]):
		"monster":
			var manager: Node2D=active_monsters()
			if manager!=null:
				var record: Dictionary=manager.find(item["uid"])
				if not record.is_empty():battle_view.start(record,manager.key)
		"npc":''')
s+='''
func active_monsters() -> Node2D:
	return terrain.current_scene.monsters if terrain!=null and terrain.current_scene!=null and not interior_state.is_empty() else null

func sync_monsters() -> void:
	if terrain==null or terrain.current_scene==null or interior_state.is_empty():return
	var scene: Node2D=terrain.current_scene
	if scene.monsters==null:
		if monster_world.zone_rule(interior_state).is_empty():return
		scene.monsters=MonsterScene.new();scene.add_child(scene.monsters)
		scene.monsters.setup(self,scene)
	else:scene.monsters.refresh()

# Event API: overrides may enable/disable a scene, change level, count, or
# bounds [x,y,width,height] in local map pixels. No story is introduced here.
func set_monster_region(context: Dictionary, patch: Dictionary) -> void:
	monster_world.set_zone_rule(context,patch)
	if monster_world.zone_key(context)==monster_world.zone_key(interior_state):sync_monsters()
'''
path.write_text(s,encoding='utf-8')
config=json.loads((root/'素材引用.json').read_text(encoding='utf-8-sig'))
config.update(combat_rules='战斗与刷新配置.json',battle_asset_root='../Projects/赵慕gei的牙林冒险',battle_ui_library='../Projects/赵慕gei的牙林冒险/data/battle_ui_library.json')
(root/'素材引用.json').write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
