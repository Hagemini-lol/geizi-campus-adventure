from pathlib import Path
root=Path(r'D:\Godot\校园自由漫游\source')
p=root/'main.gd'
s=p.read_text(encoding='utf-8')
changes={
'player.facing=int(pending_restore["facing"])':'player.show_direction(int(pending_restore["facing"]))',
'query.shape=player.get_node("CollisionShape2D").shape':'var shape:=CircleShape2D.new()\n\tshape.radius=Player.RADIUS\n\tquery.shape=shape',
'time_skip_button.disabled=remaining>0 or transition_busy or paused or map_view.visible or menu_view.visible':'time_skip_button.disabled=remaining>0 or transition_busy or paused or map_view.visible or menu_view.visible or front_end.visible or not game_started',
'if transition_busy or paused or map_view.visible or menu_view.visible or time_skip_cooldown()>0:return':'if not game_started or front_end.visible or transition_busy or paused or map_view.visible or menu_view.visible or time_skip_cooldown()>0:return',
'if transition_busy:return false\n\tadvance_time_period()':'if not game_started or transition_busy:return false\n\tadvance_time_period()',
'player.frozen=paused or map_view.visible or menu_view.visible':'refresh_player_freeze()',
'func reset_player() -> void:\n\tif transition_busy:return':'func reset_player() -> void:\n\tif not game_started or front_end.visible or transition_busy:return',
'func toggle_map() -> void:\n\tif paused or transition_busy:return':'func toggle_map() -> void:\n\tif not game_started or front_end.visible or paused or transition_busy:return',
'player.frozen=map_view.visible':'refresh_player_freeze()',
'func toggle_pause() -> void:\n\tif transition_busy:return':'func toggle_pause() -> void:\n\tif not game_started or front_end.visible or transition_busy:return',
'player.frozen=paused\n':'refresh_player_freeze()\n',
'func toggle_menu() -> void:\n\tif transition_busy:return':'func toggle_menu() -> void:\n\tif not game_started or front_end.visible or transition_busy:return',
'player.frozen=paused or transition_busy or map_view.visible':'refresh_player_freeze()',
'"fullscreen":DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)':'"fullscreen":toggle_fullscreen()\n\t\t"preferences":front_end.open_settings()\n\t\t"save":front_end.open_slots("save")\n\t\t"load":front_end.open_slots("load")\n\t\t"title":return_to_title()',
'if transition_busy or paused or menu_view.visible:return false':'if not game_started or front_end.visible or transition_busy or paused or menu_view.visible:return false',
'player.position=landing\n\tinteraction_delay=.7':'player.position=landing\n\tapply_pending_restore()\n\tinteraction_delay=.7',
'await get_tree().physics_frame\n':'await get_tree().physics_frame\n\trestore_position_if_blocked()\n',
'player.frozen=paused or map_view.visible':'refresh_player_freeze()',
'if player==null or menu_view==null or transition_busy:return\n':'if player==null or menu_view==null or transition_busy:return\n\tif front_end!=null and front_end.visible:\n\t\tif front_end.has_modal() and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:\n\t\t\tfront_end.close_modal();get_viewport().set_input_as_handled()\n\t\telif front_end.has_modal() and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:\n\t\t\tfront_end.close_modal();get_viewport().set_input_as_handled()\n\t\treturn\n\tif not game_started:return\n',
'if player==null or transition_busy or menu_view.visible:return':'if player==null or not game_started or front_end.visible or transition_busy or menu_view.visible:return',
'KEY_F11:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)':'KEY_F11:toggle_fullscreen()',
'if player==null or location_label==null:return':'if player==null or location_label==null or not game_started or terrain.current_scene==null:return',
'if not transition_busy and not paused and not map_view.visible and not menu_view.visible:':'if not transition_busy and not paused and not map_view.visible and not menu_view.visible and not front_end.visible:',
'if not nearby.is_empty() and not map_view.visible and not menu_view.visible else':'if not nearby.is_empty() and not map_view.visible and not menu_view.visible and not front_end.visible else',
'player.camera.zoom=Vector2.ONE*2.4\n\tplayer.camera.reset_smoothing()':'player.camera.zoom=Vector2.ONE*2.4\n\tapply_pending_restore()\n\tplayer.camera.reset_smoothing()',
}
for a,b in changes.items():
    assert a in s, a
    s=s.replace(a,b)
a='\tvar cell: Vector2i=motion_navigation().closest_cell(original)\n\tif cell.x>=0:player.position=motion_navigation().astar.get_point_position(cell)'
b='''\tvar grid: AStarGrid2D=motion_navigation().astar
\tvar closest:=Vector2(INF,INF)
\tvar best:=INF
\tfor y: int in range(grid.region.size.y):
\t\tfor x: int in range(grid.region.size.x):
\t\t\tvar cell:=Vector2i(x,y)
\t\t\tif grid.is_point_solid(cell):continue
\t\t\tvar candidate:=grid.get_point_position(cell)
\t\t\tif interior_state.is_empty() and navigation.region_at(candidate)!=terrain.current_id:continue
\t\t\tvar distance:=original.distance_squared_to(candidate)
\t\t\tif distance>=best:continue
\t\t\tquery.transform.origin=candidate
\t\t\tif not get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():continue
\t\t\tclosest=candidate;best=distance
\tif is_finite(closest.x):player.position=closest;player.camera.reset_smoothing()'''
assert a in s
s=s.replace(a,b)
p.write_text(s,encoding='utf-8')
p=root/'front_end.gd';s=p.read_text(encoding='utf-8')
s=s.replace('var settings_open:=false','var settings_open:=false\nvar backdrop: ColorRect').replace('var black:=ColorRect.new()','var black:=ColorRect.new()\n\tbackdrop=black').replace('title_visible=true\n','title_visible=true\n\tbackdrop.show()\n').replace('title_visible=false\n','title_visible=false\n\tbackdrop.hide()\n')
p.write_text(s,encoding='utf-8')
p=root/'preferences.gd';s=p.read_text(encoding='utf-8').replace('if not persist:return true','if not persist:return true\n\tif DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK:return false')
p.write_text(s,encoding='utf-8')
