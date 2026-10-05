from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=root/'source/main.gd';s=p.read_text('utf-8-sig')
def replace(a,b,n=1):
    global s
    assert a in s, a[:100]
    s=s.replace(a,b,n)
replace('const INTERACTION_RADIUS:=12.0','const StorySystem=preload("res://story_system.gd")\nvar story_system: Node2D\nconst INTERACTION_RADIUS:=12.0')
replace('\tif "--skip-title" in OS.get_cmdline_user_args():','\tstory_system=StorySystem.new();story_system.game=self\n\tif not story_system.configure(package_root.path_join("剧情配置.json")):\n\t\tfail("剧情素材或配置缺失");return\n\tadd_child(story_system)\n\tif "--skip-title" in OS.get_cmdline_user_args():')
replace('or lesson_blocked() or not game_started','or lesson_blocked() or story_blocked() or not game_started')
replace('},"开始自由漫游")','},"第一章 · 去秋实楼十班")')
replace('or battle_view.visible or lesson_blocked():return {"ok":false,"error":','or battle_view.visible or lesson_blocked() or story_blocked() or dialogue_view.visible:return {"ok":false,"error":')
replace('\tstate["economy"]=economy.snapshot()','\tstate["economy"]=economy.snapshot()\n\tstate["story"]=story_system.snapshot()')
replace('\tif state.has("combat"):', '\tif state.has("story") and not story_system.valid_snapshot(state["story"]):return {"ok":false,"error":"存档中的剧情进度无效"}\n\tif state.has("combat"):')
replace('\tmonster_world.restore(pending_restore.get("combat",{}).get("world",{}))','\tmonster_world.restore(pending_restore.get("combat",{}).get("world",{}))\n\tstory_system.restore(pending_restore.get("story",{}))')
replace('\tcolumn.add_child(time_row)','\tcolumn.add_child(time_row)\n\tvar objective:=label("",15);objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;objective.custom_minimum_size=Vector2(335,0)\n\tcolumn.add_child(objective)\n\t# Story node is created after the HUD; bind once all systems exist.\n\tcall_deferred("bind_story_objective",objective)')
replace('\tif lesson_blocked():\n', '\tif story_blocked() and not dialogue_view.visible:\n\t\tget_viewport().set_input_as_handled();return\n\tif lesson_blocked():\n')
replace('and not item["action"] in ["board","npc","monster","lesson"]','and not item["action"] in ["board","npc","monster","lesson","story_window","story_seat"]')
# The vibrating door needs explicit E instead of ordinary portal auto-entry.
replace('\t\t\t\texecute_interaction(item)','\t\t\t\tif not (story_system.door_active() and item["action"]=="room" and int(item["room"])==int(story_system.data["lab_room"])):execute_interaction(item)')
replace('\t\tif lesson_view.available():\n','\t\tif lesson_view.available() and not story_system.seat_active():\n')
replace('\t\treturn result\n\tvar items:', '\t\tresult.append_array(story_system.extra_interactions())\n\t\treturn result\n\tvar items:')
replace('\treturn items\n\nfunc click_interaction','\titems.append_array(story_system.extra_interactions())\n\treturn items\n\nfunc click_interaction')
replace('\t# The hero\'s empty seat marker takes priority over nearby seated artwork.','\t# Chapter seat/window markers take priority over artwork.\n\tfor item: Dictionary in story_system.extra_interactions():\n\t\tif item["art_rect"].has_point(at):\n\t\t\tif within_interaction(item["at"]):execute_interaction(item)\n\t\t\telse:player.path=approach_interaction(item["at"]);show_notice("到达白圈后按 E")\n\t\t\treturn true\n\t# The hero\'s empty seat marker takes priority over nearby seated artwork.')
replace('func interaction_text(item: Dictionary) -> String:\n','func interaction_text(item: Dictionary) -> String:\n\tvar story_hint: String=story_system.interaction_label(item)\n\tif not story_hint.is_empty():return story_hint\n')
replace('\tvar context: Dictionary=interior_state.duplicate()\n\tmatch str(item["action"]):','\tif story_system.handle(item):return\n\tvar context: Dictionary=interior_state.duplicate()\n\tmatch str(item["action"]):')
replace('\tvar scene: Node2D=terrain.current_scene\n\tif scene.monsters==null:', '\tvar scene: Node2D=terrain.current_scene\n\tif interior_state.get("building")=="B02" and story_system.blocks_lab_spawns():\n\t\tif scene.monsters!=null:scene.monsters.queue_free();scene.monsters=null\n\t\treturn\n\tif scene.monsters==null:')
replace('func set_monster_region(context:', 'func story_blocked() -> bool:\n\treturn story_system!=null and story_system.running\n\nfunc bind_story_objective(value: Label) -> void:\n\tif story_system!=null:story_system.objective=value;story_system.refresh_objective()\n\nfunc set_monster_region(context:')
# Make all free-mode UI/navigation controls obey the cutscene lock.
s=s.replace('or lesson_blocked() or transition_busy:return','or lesson_blocked() or story_blocked() or transition_busy:return')
s=s.replace('or transition_busy or menu_view.visible or lesson_blocked():return','or transition_busy or menu_view.visible or lesson_blocked() or story_blocked():return')
s=s.replace('and not lesson_blocked():','and not lesson_blocked() and not story_blocked():')
p.write_text(s,'utf-8')
print('Story hooks wired')
