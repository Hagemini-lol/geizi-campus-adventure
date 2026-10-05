from pathlib import Path
p=Path(r'D:\Godot\校园自由漫游\source\main.gd')
old=p.read_text(encoding='utf-8')
ui=old[old.index('func label('):old.index('func fail(')]
ui=ui.replace('WASD / 方向键 移动    Shift 奔跑    M 全图    滚轮 缩放    R 回到南门    Esc 暂停','WASD / 方向键 移动    Shift 2倍速    点击 5倍寻路    M 全图    滚轮 缩放    R 南门    Esc 暂停')
ui=ui.replace('Esc 暂停", 17','Esc 暂停", 16')
head='''extends Node2D

const Player = preload("res://player.gd")
const Space = preload("res://map_space.gd")
const Stream = preload("res://district_stream.gd")
const RoadNavigation = preload("res://road_navigation.gd")
var package_root := ""
var data: Dictionary = {}
var model: Dictionary = {}
var navigation := RoadNavigation.new()
var player: CharacterBody2D
var terrain: Node2D
var bounds: Rect2
var spawn: Vector2
var overlay: PanelContainer
var fade: ColorRect
var location_label: Label
var map_view: Control
var ui_font: SystemFont
var debug_geometry := false
var paused := false
var transition_busy := false
var load_error := ""
var notice := ""
var notice_time := 0.0

func _ready() -> void:
	y_sort_enabled=true
	package_root=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--game-root="): package_root=arg.trim_prefix("--game-root=")
	ui_font=SystemFont.new()
	ui_font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"])
	var config_value: Variant=JSON.parse_string(FileAccess.get_file_as_string(package_root.path_join("素材引用.json")))
	if not config_value is Dictionary:
		fail("素材引用配置缺失或格式错误")
		return
	var config: Dictionary=config_value
	var geometry: Variant=JSON.parse_string(FileAccess.get_file_as_string(resolve_path(str(config["geometry"]))))
	var model_path:=resolve_path(str(config.get("district_model","")))
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(model_path))
	if not parsed is Dictionary or not geometry is Dictionary:
		fail("地图区块数据缺失，请保留地图重绘预览文件夹")
		return
	model=parsed
	data=geometry
	var hero:=Image.load_from_file(resolve_path(str(config["hero"])))
	if hero==null or hero.get_size()!=Vector2i(1265,1243):
		fail("主角素材缺失或尺寸错误")
		return
	navigation.configure(model)
	terrain=Node2D.new()
	terrain.set_script(Stream)
	add_child(terrain)
	terrain.configure(model,model_path.get_base_dir())
	player=CharacterBody2D.new()
	player.set_script(Player)
	player.game=self
	add_child(player)
	player.set_art(hero)
	bounds=rect(data["campus_bounds"])
	spawn=Space.project(point(data["hub_spawn"]))
	player.position=spawn
	create_ui()
	var curtain:=CanvasLayer.new()
	curtain.layer=100
	add_child(curtain)
	fade=ColorRect.new()
	fade.color=Color.BLACK
	fade.modulate.a=0.0
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	curtain.add_child(fade)
	if not load_district(navigation.region_at(spawn)):
		fail("高清地图文件缺失，请保留地图重绘预览文件夹")
		return
	DisplayServer.window_set_title("校园自由漫游")
	print("CAMPUS_READY: 20 districts, one loaded ground texture, road gates, 1x/2x/5x movement")

func resolve_path(value: String) -> String:
	return value if value.is_absolute_path() else package_root.path_join(value).simplify_path()

func rect(a: Array) -> Rect2:
	return Rect2(a[0],a[1],a[2],a[3])

func point(a: Array) -> Vector2:
	return Vector2(a[0],a[1])

'''
tail='''func fail(message: String) -> void:
	load_error=message
	push_error(message)
	var hud:=CanvasLayer.new()
	add_child(hud)
	var item:=label("无法打开校园漫游\\n\\n"+message,22)
	item.position=Vector2(40,120)
	hud.add_child(item)

func load_district(index: int) -> bool:
	if index<0 or not terrain.load_region(index): return false
	var values: Array=model["regions"][index]["world_bounds"]
	player.camera.limit_left=int(values[0]*24)
	player.camera.limit_top=int(values[1]*24)
	player.camera.limit_right=int((values[0]+values[2])*24)
	player.camera.limit_bottom=int((values[1]+values[3])*24)
	player.camera.reset_smoothing()
	return true

func reset_player() -> void:
	if transition_busy:return
	player.path.clear()
	begin_transition(navigation.region_at(spawn),spawn)

func toggle_map() -> void:
	if paused or transition_busy:return
	map_view.visible=not map_view.visible
	player.frozen=map_view.visible
	map_view.queue_redraw()

func toggle_pause() -> void:
	if transition_busy:return
	if map_view.visible:
		toggle_map()
		return
	paused=not paused
	overlay.visible=paused
	player.frozen=paused

func show_notice(value: String) -> void:
	notice=value
	notice_time=2.5

func request_path(destination: Vector2) -> bool:
	if transition_busy or paused:return false
	var path:=navigation.route(player.position,destination)
	if path.is_empty():
		show_notice("目的地无法到达，请点击道路或空地")
		return false
	player.path=path
	return true

func allow_motion(from: Vector2, proposed: Vector2) -> bool:
	if transition_busy:return false
	var destination:=navigation.region_at(proposed)
	if destination==terrain.current_id:return true
	if destination<0:return false
	if navigation.can_cross(terrain.current_id,destination,proposed):begin_transition(destination,proposed)
	return false

func begin_transition(destination: int, landing: Vector2) -> void:
	if transition_busy:return
	transition_busy=true
	player.frozen=true
	player.velocity=Vector2.ZERO
	var cover:=create_tween()
	cover.tween_property(fade,"modulate:a",1.0,0.18)
	await cover.finished
	terrain.unload()
	await get_tree().process_frame
	if not load_district(destination):
		fail("区块加载失败，请检查高清地图文件")
		return
	player.position=landing
	player.camera.reset_smoothing()
	await get_tree().physics_frame
	var reveal:=create_tween()
	reveal.tween_property(fade,"modulate:a",0.0,0.22)
	await reveal.finished
	transition_busy=false
	player.frozen=paused or map_view.visible

func _unhandled_input(event: InputEvent) -> void:
	if player==null or transition_busy:return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_M:toggle_map()
			KEY_ESCAPE:toggle_pause()
			KEY_R:
				if not paused and not map_view.visible:reset_player()
			KEY_F3:debug_geometry=not debug_geometry
			KEY_F11:DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event is InputEventMouseButton and event.pressed and not paused and not map_view.visible:
		if event.button_index==MOUSE_BUTTON_LEFT:
			request_path(get_global_mouse_position())
			return
		if event.button_index==MOUSE_BUTTON_RIGHT:
			player.path.clear()
			return
		var amount:=0.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else (-0.1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else 0.0)
		player.camera.zoom=Vector2.ONE*clampf(player.camera.zoom.x+amount,0.6,2.4)

func _process(delta: float) -> void:
	if player==null or location_label==null:return
	notice_time=maxf(0.0,notice_time-delta)
	if terrain.current_id>=0:
		var place: String=model["regions"][terrain.current_id]["name"]
		location_label.text=notice if notice_time>0 else place+" · "+("5倍自动寻路" if not player.path.is_empty() else "赵慕gei")
	queue_redraw()

func _draw() -> void:
	if model.is_empty() or terrain==null or terrain.current_id<0:return
	var shown: Dictionary={}
	for gate: Array in model["gates"]:
		if terrain.current_id!=int(gate[0]) and terrain.current_id!=int(gate[1]):continue
		var target:=int(gate[1]) if terrain.current_id==int(gate[0]) else int(gate[0])
		var at:=Vector2(gate[2],gate[3])*24.0
		var key:=Vector3i(target,int(at.x/180),int(at.y/180))
		if shown.has(key):continue
		shown[key]=true
		draw_circle(at,10,Color(0.05,0.25,0.22,0.85))
		draw_arc(at,10,0,TAU,20,Color("8cf0d0"),2,true)
	if player!=null and not player.path.is_empty():
		var previous: Vector2=player.position
		for waypoint: Vector2 in player.path:
			if navigation.region_at(waypoint)==terrain.current_id:draw_line(previous,waypoint,Color(0.55,1,0.85,0.7),2)
			previous=waypoint
	if debug_geometry:
		for v: Array in model["solids"]:draw_rect(Rect2(v[0]*24,v[1]*24,v[2]*24,v[3]*24),Color(1,0.2,0.1,0.25))
		for tree: Array in model["trees"]:
			if int(tree[2])==terrain.current_id:draw_circle(Vector2(tree[0],tree[1])*24,4.2,Color(1,0.2,0.1,0.7))
'''
p.write_text(head+ui+tail,encoding='utf-8')
