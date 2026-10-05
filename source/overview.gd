extends Control
const Space=preload("res://map_space.gd")
var game: Node2D
var map_texture: Texture2D
var map_box:=Rect2()
var teleport_mode:=false
var selections: Array[Dictionary]=[]
var label_boxes: Array[Rect2]=[]
var list_boxes: Array[Rect2]=[]

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func open_map(teleport: bool=false) -> void:
	teleport_mode=teleport
	var source:=Image.load_from_file(game.interior_info["assets"]["whole_map"])
	if source==null: game.show_notice("学校全图素材缺失"); return
	source.generate_mipmaps()
	map_texture=ImageTexture.create_from_image(source)
	selections=[]
	for region: Dictionary in game.model["regions"]:
		var matching: Dictionary={}
		for zone: Dictionary in game.data["zones"]:
			if zone["id"]==region["id"]: matching=zone; break
		if matching.is_empty(): continue
		var f: Array=matching["footprint"]
		var source_at:=Vector2(f[0]+f[2]*.5,f[1]+f[3]*.5)
		var destination:=Space.project(game.point(matching.get("spawn",[source_at.x,source_at.y])))
		for entrance: Dictionary in game.interior_info["entrances"]:
			if entrance["id"]==region["id"]: destination=game.point(entrance["arrival"])*24
		selections.append({"id":region["id"],"name":matching["name"],"source_at":source_at,"destination":destination})
	for zone: Dictionary in game.data["zones"]:
		var found:=false
		for item: Dictionary in selections:
			if item["id"]==zone["id"]:found=true;break
		if found:continue
		var p: Array=zone["label"]
		selections.append({"id":zone["id"],"name":zone["name"],"source_at":Vector2(p[0],p[1]),"destination":Space.project(game.point(zone["spawn"]))})
	var short_names: Dictionary={"B09":"辅助用房","B11":"礼堂后台","B17":"连廊","S01":"田径场 / 足球场","S02":"主席台","S03":"北看台","S04":"南看台","S07":"篮球场","G02":"林荫步道","N01":"北门","N02":"南门","P01":"围墙步道"}
	for item: Dictionary in selections: item["name"]=short_names.get(item["id"],item["name"])
	show()
	queue_redraw()

func close_map() -> void:
	hide()
	map_texture=null
	game.player.frozen=game.paused or game.transition_busy

func _draw() -> void:
	if map_texture==null:return
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,.055,.065,.995))
	var display_scale:=get_viewport().get_stretch_transform().get_scale().abs()
	var height:=minf(size.y-106,map_texture.get_height()/maxf(display_scale.x,display_scale.y))
	var factor:=height/map_texture.get_height()
	map_box=Rect2(34,57,map_texture.get_width()*factor,height)
	draw_texture_rect(map_texture,map_box,false)
	draw_rect(map_box,Color("c8d8ce"),false,2)
	label_boxes=[]
	list_boxes=[]
	for index: int in range(selections.size()):
		var item: Dictionary=selections[index]
		var center: Vector2=map_box.position+item["source_at"]*factor
		var title: String=item["name"]
		var width: float=game.ui_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+10
		var box:=Rect2(center-Vector2(width*.5,9),Vector2(width,21))
		# Preserve legible names on narrow or adjoining footprints, using a
		# leader line whenever a label needs to move away from the actual object.
		for attempt: int in range(12):
			var intersects:=false
			for used: Rect2 in label_boxes:
				if used.grow(2).intersects(box):intersects=true;break
			if not intersects:break
			box.position.y+=23 if attempt%2==0 else -46
		box.position.x=clampf(box.position.x,map_box.position.x,map_box.end.x-box.size.x)
		box.position.y=clampf(box.position.y,map_box.position.y,map_box.end.y-box.size.y)
		label_boxes.append(box)
		if box.get_center().distance_to(center)>14: draw_line(center,box.get_center(),Color("ffedb5"),1,true)
		draw_rect(box,Color(.025,.1,.12,.87))
		draw_string(game.ui_font,box.position+Vector2(5,15),title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffedb5"))
		var columns_width: float=(size.x-map_box.end.x-65)*.5
		var list_box:=Rect2(map_box.end.x+25+(index/16)*columns_width,66+(index%16)*38,columns_width-8,33)
		list_boxes.append(list_box)
		draw_rect(list_box,Color("1d393e") if index%2==0 else Color("152c31"))
		draw_string(game.ui_font,list_box.position+Vector2(12,23),str(index+1)+". "+title,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e1eee7"))
	if game.interior_state.is_empty():
		var hero: Vector2=map_box.position+Space.unproject(game.player.position)*factor
		draw_circle(hero,6,Color.BLACK)
		draw_circle(hero,4,Color("ffcf65"))
	draw_string(game.ui_font,Vector2(28,34),"校园全图 · "+("点击建筑文字或右侧地点传送" if teleport_mode else "点击地图空地自动寻路 · 点击文字选择地点"),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
	draw_string(game.ui_font,Vector2(28,size.y-20),"学校原始大图 · 320 × 360 米 · M / Esc 关闭",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("a6d6c9"))

func choose(index: int) -> void:
	var target: Vector2=game.safe_outdoor(selections[index]["destination"])
	close_map()
	if teleport_mode: game.teleport_outdoor(target)
	else: game.request_path(target)

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return
	if label_boxes.size()!=selections.size() or list_boxes.size()!=selections.size():return
	for index: int in range(selections.size()):
		if label_boxes[index].has_point(event.position) or list_boxes[index].has_point(event.position):
			choose(index)
			accept_event()
			return
	if map_box.has_point(event.position):
		var source: Vector2=(event.position-map_box.position)/map_box.size*map_texture.get_size()
		var target:=Space.project(source)
		if game.navigation.walkable(target):
			close_map()
			if teleport_mode: game.teleport_outdoor(target)
			else: game.request_path(target)
		else: game.show_notice("点击地点文字，可抵达对应入口或空地")
		accept_event()
