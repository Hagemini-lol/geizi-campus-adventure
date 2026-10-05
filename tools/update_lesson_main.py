from pathlib import Path

root = Path(__file__).resolve().parents[1]
p = root / 'source/main.gd'
s = p.read_text(encoding='utf-8')
def edit(old, new, count=1):
    global s
    assert old in s, old
    s = s.replace(old, new, count)
edit('const OfficePlan=preload', 'const LessonSystem=preload("res://lesson_system.gd")\nconst INTERACTION_RADIUS:=12.0\nvar lesson_view: Control\nconst OfficePlan=preload')
edit('\tif "--skip-title"', '\tvar lesson_layer:=CanvasLayer.new();lesson_layer.layer=96;add_child(lesson_layer)\n\tlesson_view=LessonSystem.new();lesson_view.game=self;lesson_layer.add_child(lesson_view)\n\tif "--skip-title"')
edit(' or not game_started\n', ' or lesson_blocked() or not game_started\n', 2)
edit('or battle_view.visible:return {"ok":false', 'or battle_view.visible or lesson_blocked():return {"ok":false')
edit('\trestore_position_guard=true\n', '\trestore_position_guard=true\n\tsync_classroom_period()\n')
edit('or time_skip_cooldown()>0:return', 'or lesson_blocked() or time_skip_cooldown()>0:return')
edit('or battle_view.visible:return false', 'or battle_view.visible or lesson_blocked():return false')
edit('\tsync_monsters()\n\tapply_time_lighting()\n\tupdate_time_display()', '\tsync_monsters()\n\tsync_classroom_period()\n\tapply_time_lighting()\n\tupdate_time_display()')
edit('\tif battle_view!=null and battle_view.visible:\n', '\tif lesson_blocked():\n\t\tif event is InputEventKey and event.pressed and not event.echo:\n\t\t\tif event.keycode==KEY_ESCAPE:lesson_view.close()\n\t\t\telif event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_E]:lesson_view.start_lesson()\n\t\t\tget_viewport().set_input_as_handled()\n\t\telif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:\n\t\t\tlesson_view.close();get_viewport().set_input_as_handled()\n\t\treturn\n\tif battle_view!=null and battle_view.visible:\n')
edit('or transition_busy or menu_view.visible:return', 'or transition_busy or menu_view.visible or lesson_blocked():return')
s = s.replace('player.position.distance_to(record["at"])<46', 'within_interaction(record["at"])')
s = s.replace('player.position.distance_to(item["at"])<46', 'within_interaction(item["at"])')
s = s.replace('player.position.distance_to(selected["at"])<46', 'within_interaction(selected["at"])')
edit('and not battle_view.visible:\n\t\tvar best', 'and not battle_view.visible and not lesson_blocked():\n\t\tvar best')
edit('if distance<46 and distance<best:', 'if distance<=INTERACTION_RADIUS and distance<best:')
edit('not item["action"] in ["board","npc","monster"] and item["trigger"].has_point(player.position)', 'not item["action"] in ["board","npc","monster","lesson"] and within_interaction(item["at"]) and item["trigger"].has_point(player.position)')
edit('and not battle_view.visible else ""', 'and not battle_view.visible and not lesson_blocked() else ""')
edit('\t\treturn result\n\tvar items:', '\t\tif lesson_view.available():\n\t\t\tvar seat: Vector2=terrain.current_scene.hero_seat\n\t\t\tresult.append({"action":"lesson","at":seat,"trigger":Rect2(),"art_rect":Rect2(seat-Vector2(8,8),Vector2(16,16))})\n\t\treturn result\n\tvar items:')
edit('\t\tif item["action"]=="board":', '\t\tif item["action"]=="lesson":\n\t\t\tif within_interaction(item["at"]):execute_interaction(item)\n\t\t\telse:\n\t\t\t\tplayer.path=approach_interaction(item["at"])\n\t\t\t\tshow_notice("到达白色圆圈后，按 E 上课")\n\t\telif item["action"]=="board":')
edit('\t\t"monster":return', '\t\t"lesson":return "坐到自己的座位上课"\n\t\t"monster":return')
edit('or nearby.is_empty() or interaction_delay>0:return', 'or lesson_blocked() or nearby.is_empty() or interaction_delay>0:return')
edit('or transition_busy:return\n\tvar context:', 'or transition_busy or lesson_blocked() or not within_interaction(item["at"]):return\n\tvar context:')
edit('\tmatch str(item["action"]):\n', '\tmatch str(item["action"]):\n\t\t"lesson":lesson_view.open()\n')
insert = '''func lesson_blocked() -> bool:
	return lesson_view!=null and (lesson_view.visible or lesson_view.running)

func within_interaction(at: Vector2) -> bool:
	return player.position.distance_to(at)<=INTERACTION_RADIUS

func approach_interaction(at: Vector2) -> PackedVector2Array:
	var best:=PackedVector2Array()
	var length:=INF
	var nav: RefCounted=motion_navigation()
	for radius: float in [9.0,11.0]:
		for direction: int in range(16):
			var target:=at+Vector2.from_angle(direction*TAU/16)*radius
			if not nav.walkable(target):continue
			var route: PackedVector2Array=nav.path(player.position,target)
			if route.is_empty():continue
			var distance:=0.0
			var previous:=player.position
			for point: Vector2 in route:distance+=previous.distance_to(point);previous=point
			if distance<length:length=distance;best=route
	return best

func sync_classroom_period() -> void:
	if terrain==null or terrain.current_scene==null or interior_state.is_empty():return
	var scene: Node2D=terrain.current_scene
	if scene.is_ten_class and not scene.is_office and scene.state["building"]!="B02":
		scene.refresh_npcs(self)
		terrain.active_texture_bytes=scene.texture_bytes

'''
edit('func motion_navigation()',insert+'func motion_navigation()')
p.write_text(s,encoding='utf-8')
p=root/'AGENTS.md'
s=p.read_text(encoding='utf-8').replace('三个教学楼三楼最左侧十班仅生成具名 NPC，不生成普通学生；实验楼仍不生成 NPC。','三个教学楼三楼最左侧十班：上午、下午安排具名学生入座，用普通学生补满除主角座位之外的座位，并安排讲台旁老师；其余时段仅生成具名 NPC。办公室和走廊保持原配置；实验楼仍不生成 NPC。')
p.write_text(s,encoding='utf-8')
