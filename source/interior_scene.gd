extends Node2D

const Navigation=preload("res://interior_navigation.gd")
const IndoorNpcs=preload("res://indoor_npcs.gd")
const CHAIR_FOOT_WIDTH:=6.0
var navigation:=Navigation.new()
var info: Dictionary
var building: Dictionary
var state: Dictionary
var portals: Array[Dictionary]=[]
var blockers: Array[Rect2]=[]
var furniture_footprints: Array[Rect2]=[]
var furniture_art: Array[Dictionary]=[]
var foreground: Array[Sprite2D]=[]
var dimensions:=Vector2.ZERO
var background: Sprite2D
var source_path: String
var texture_bytes:=0
var foreground_bytes:=0
var title: String
var npcs: Node2D
var monsters: Node2D
var life_layout:=""
var npc_stamp:=""
var source_factor:=.2
var is_office:=false
var is_ten_class:=false
var hero_seat:=Vector2.ZERO
var seat_marker: Line2D
const HERO_SEAT_INDEX:=16 # Four rows: window-side first column, second row from the back.
var scene_font: Font

func setup(value: Dictionary, context: Dictionary, directory: String, game: Node2D=null) -> bool:
	y_sort_enabled=true
	info=value
	if game!=null:scene_font=game.ui_font
	else:
		var fallback:=SystemFont.new();fallback.font_names=PackedStringArray(["Microsoft YaHei","SimHei"]);scene_font=fallback
	state=context.duplicate()
	state["floor"]=int(state["floor"])
	if state.has("room"):state["room"]=int(state["room"])
	building=info["buildings"][state["building"]]
	var level:=int(state["floor"])
	var row: Dictionary=building["floors"][level-1]
	title=str(building["name"])+" · "+str(level)+"楼"
	var factor:=1.0
	var polygon:=PackedVector2Array()
	if state["kind"]=="corridor":
		factor=1.0/float(info.get("corridor_image_density",1))
		source_path=directory.path_join(str(row["image"]))
		dimensions=Vector2(building["width_pixels"],building["height_pixels"])
		polygon=PackedVector2Array([Vector2(3,70),Vector2(dimensions.x-3,70),Vector2(dimensions.x-3,180),Vector2(3,180)])
		title+=" · 走廊"
		configure_corridor(row,level)
	else:
		var room: Dictionary=row["rooms"][int(state["room"])]
		var ten: bool=room["class10"]
		is_ten_class=ten
		is_office=bool(room.get("office",false))
		factor=.265 if ten else .2
		source_path=info["assets"][room["office_asset"] if is_office else ("class10" if ten else "ordinary")]
		dimensions=Vector2(1596,912)*factor if ten else Vector2(1536,1024)*factor
		title+=" · "+str(room["name"])
		polygon=classroom_floor(ten)
		if is_office:configure_office(factor)
		else:configure_classroom(ten,factor)
		if ten:hero_seat=seat_position(HERO_SEAT_INDEX)
		life_layout=str(room.get("life_layout",""))
		if not life_layout.is_empty() and game!=null:
			blockers.clear();furniture_footprints.clear();furniture_art.clear();portals.clear()
			factor=.3;source_path=game.campus_life.source(life_layout);dimensions=Vector2(1536,1024)*factor
			polygon=game.campus_life.polygon(life_layout);game.campus_life.configure_room(self,life_layout)
	source_factor=factor
	var image:=Image.load_from_file(source_path)
	if image==null or image.is_empty(): return false
	if state["kind"]=="classroom" and is_ten_class: image=image.get_region(Rect2i(0,0,1596,912))
	# Original furniture pixels become small foreground sprites. Sorting them
	# with actors by their floor edge prevents actors behind a desk painting over it.
	navigation.configure(dimensions,polygon,blockers,1.8 if state["kind"]=="classroom" else 3.6)
	if game!=null and state["building"] not in ["B02","B06","STORY_HOUSE","STORY_SEAL"]:
		y_sort_enabled=true
		npcs=IndoorNpcs.new()
		add_child(npcs)
		npcs.setup(self,game,image)
		npc_stamp="%d/%d/%d/%d/%d/%d" % [game.economy.day_serial,game.day_clock.current_period,game.campaign.index,game.story_system.stage,game.campaign.ao_until,game.relationships.revision]
	# Preserve the seated students already baked into the room image.
	build_foreground(image,factor)
	image.generate_mipmaps()
	texture_bytes=foreground_bytes+image.get_data_size()+(npcs.texture_bytes if npcs!=null else 0)
	background=Sprite2D.new()
	background.centered=false
	background.texture=ImageTexture.create_from_image(image)
	background.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background.scale=Vector2.ONE*factor
	if state["kind"]=="corridor":background.scale=dimensions/Vector2(image.get_size())
	background.z_index=-5
	add_child(background)
	for box: Rect2 in blockers: add_box(box)
	# Thin boundary bodies match the analytic walkable polygon, including the
	# sloping wall-floor junctions in the perspective classroom illustrations.
	for i: int in range(polygon.size()):
		var a:=polygon[i]
		var b:=polygon[(i+1)%polygon.size()]
		var body:=StaticBody2D.new()
		body.name="Wall_"+str(i)
		body.position=(a+b)*.5
		body.rotation=(b-a).angle()
		var collision:=CollisionShape2D.new()
		var shape:=RectangleShape2D.new()
		shape.size=Vector2(a.distance_to(b),.2)
		collision.shape=shape
		body.add_child(collision)
		add_child(body)
	return true

func seat_position(index: int) -> Vector2:
	var footprint: Rect2=furniture_footprints[index]
	return footprint.get_center()+Vector2(0,footprint.size.y*.22)

func refresh_npcs(game: Node2D) -> void:
	if state["building"] in ["B02","B06","STORY_HOUSE","STORY_SEAL"]:return
	var stamp: String="%d/%d/%d/%d/%d/%d" % [game.economy.day_serial,game.day_clock.current_period,game.campaign.index,game.story_system.stage,game.campaign.ao_until,game.relationships.revision]
	if stamp==npc_stamp:return
	npc_stamp=stamp
	var image:=Image.load_from_file(source_path)
	if is_ten_class:image=image.get_region(Rect2i(0,0,1596,912))
	if npcs!=null:npcs.free()
	npcs=IndoorNpcs.new();add_child(npcs);npcs.setup(self,game,image)
	build_foreground(image,source_factor)
	image.generate_mipmaps();background.texture=ImageTexture.create_from_image(image)
	texture_bytes=foreground_bytes+image.get_data_size()+npcs.texture_bytes
	if seat_marker!=null:seat_marker.hide()
	queue_redraw()

func _draw() -> void:
	pass

static func classroom_floor(ten: bool) -> PackedVector2Array:
	var corners: Array=([[65,315],[285,235],[1350,235],[1480,315],[1490,850],[65,850]] if ten else [[60,345],[290,265],[1310,265],[1480,350],[1480,958],[60,958]])
	var result:=PackedVector2Array()
	for corner: Array in corners:result.append(Vector2(corner[0],corner[1])*(.265 if ten else .2))
	return result

func add_box(box: Rect2) -> void:
	var body:=StaticBody2D.new()
	body.name="Furniture_"+str(get_child_count())
	body.position=box.get_center()
	var collision:=CollisionShape2D.new()
	var shape:=RectangleShape2D.new()
	shape.size=box.size
	collision.shape=shape
	body.add_child(collision)
	add_child(body)

func add_furniture(footprint: Rect2) -> void:
	# Floor contact stays smaller than the art, but is large enough to prevent
	# characters walking through the centre of a workstation or cupboard.
	furniture_footprints.append(footprint)
	var size:=Vector2(maxf(footprint.size.x*.68,3),maxf(footprint.size.y*.30,3))
	var at:=Vector2(footprint.get_center().x,footprint.position.y+footprint.size.y*.78)
	blockers.append(Rect2(at-size*.5,size))
	furniture_art.append({"rect":footprint,"edge":footprint.end.y})

func build_foreground(image: Image, factor: float) -> void:
	for sprite: Sprite2D in foreground:sprite.free()
	foreground.clear();foreground_bytes=0
	for item: Dictionary in furniture_art:
		var rect: Rect2=item["rect"]
		var pixels:=Rect2i((rect.position/factor).floor(),(rect.size/factor).ceil())
		pixels=pixels.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
		if not pixels.has_area():continue
		var crop:=image.get_region(pixels);crop.generate_mipmaps()
		var sprite:=Sprite2D.new();sprite.centered=false;sprite.z_index=10
		sprite.texture=ImageTexture.create_from_image(crop)
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.scale=Vector2.ONE*factor
		sprite.position=Vector2(float(pixels.position.x)*factor,float(item["edge"]))
		sprite.offset=Vector2(0,float(pixels.position.y)-float(item["edge"])/factor)
		add_child(sprite);foreground.append(sprite);foreground_bytes+=crop.get_data_size()

func portal(at: Vector2, trigger: Rect2, action: String, extra: Dictionary={}) -> void:
	var item: Dictionary={"at":at,"trigger":trigger,"action":action}
	item.merge(extra)
	portals.append(item)

func stair_x(source_x: float) -> float:
	return float(building["stairs_center_x"])-72+(source_x-605)*144/670

func configure_corridor(row: Dictionary, level: int) -> void:
	var top:=78.0
	# Pillars and railings divide the three stair mouths without blocking them.
	for pair: Array in [[605,667],[784,819],[1063,1101],[1214,1275]]:
		blockers.append(Rect2(stair_x(pair[0]),70,stair_x(pair[1])-stair_x(pair[0]),22))
	var gaps: Array[Vector2]=[]
	for item: Array in [[728,672,784,"down_left"],[941,819,1063,"up"],[1157,1101,1213,"down_right"]]:
		var allowed: bool=(level<int(building["floor_count"])) if item[3]=="up" else (level>1)
		var left:=stair_x(item[1])
		var right:=stair_x(item[2])
		if allowed:
			gaps.append(Vector2(left,right))
			portal(Vector2(stair_x(item[0]),83),Rect2(left,70,right-left,19),str(item[3]))
		else: blockers.append(Rect2(left,70,right-left,14))
	# The main wall is continuous except at the stair mouths.
	gaps.sort_custom(func(a: Vector2,b: Vector2): return a.x<b.x)
	var cursor:=3.0
	for gap: Vector2 in gaps:
		blockers.append(Rect2(cursor,70,gap.x-cursor,top-70))
		cursor=gap.y
	blockers.append(Rect2(cursor,70,dimensions.x-3-cursor,top-70))
	for room: Dictionary in row["rooms"]:
		for side: String in ["front","rear"]:
			var raw: Variant=room[side+"_door_x"]
			if raw==null: continue
			var x:=float(raw)*24
			var width:=45.6 if room["class10"] else 24.0
			portal(Vector2(x,97),Rect2(x-13,85.5,26,16),"room",{"room":int(room["index"]),"side":side,"art_rect":Rect2(x-width*.5,21.88,width,50.4)})
			if room.get("office",false) or room.has("life_layout"):
				var sign:=PanelContainer.new();sign.position=Vector2(x-48,1);sign.size=Vector2(96,23)
				var plate:=StyleBoxFlat.new();plate.bg_color=Color("435d52");plate.border_color=Color("9cae9a")
				plate.set_border_width_all(1);sign.add_theme_stylebox_override("panel",plate)
				add_child(sign)
				var plaque:=Label.new();plaque.text=str(room.get("name","办公室"))+(" 后门" if side=="rear" else "")
				plaque.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
				plaque.add_theme_font_size_override("font_size",11)
				plaque.add_theme_font_override("font",scene_font)
				plaque.add_theme_color_override("font_color",Color("fff2ca"))
				sign.add_child(plaque)
	if level==1:
		var exit_x:=float(building["stairs_center_x"])
		portal(Vector2(exit_x,168),Rect2(exit_x-25,161,50,12),"outside")

func configure_classroom(ten: bool, factor: float) -> void:
	var row_edges: Array=(
		[[181,269,284,373,458,544,556,643,716,803,816,903,984,1070,1084,1172],
		[169,258,276,366,455,543,556,644,720,810,826,916,996,1085,1104,1193],
		[157,251,268,362,450,540,556,646,725,817,835,929,1008,1102,1122,1216],
		[147,242,260,354,446,538,554,646,727,822,845,940,1019,1117,1137,1235]] if ten else
		[[207,304,322,421,519,614,632,728,812,908,928,1024,1115,1211,1229,1325],
		[194,296,315,417,512,610,631,729,815,914,937,1038,1123,1224,1241,1343],
		[180,286,309,411,504,606,629,731,818,922,945,1049,1134,1237,1258,1360],
		[168,276,300,407,497,602,628,733,821,929,953,1060,1142,1247,1276,1385]])
	var rows: Array=([320,428,538,651] if ten else [365,485,612,744])
	var bottoms: Array=([427,533,646,767] if ten else [478,610,741,876])
	for index: int in range(4):
		var edges: Array=row_edges[index]
		for column: int in range(8):
			var top:=float(rows[index])+(35 if ten else 45)
			var x:=float(edges[column*2]);var width:=float(edges[column*2+1]-edges[column*2])
			var row_y:=float(rows[index])
			var footprint:=Rect2(Vector2(x,top)*factor,Vector2(width,bottoms[index]-top)*factor)
			furniture_footprints.append(footprint)
			# The desktop and chair use distinct floor contacts. Keeping the
			# table base shallow preserves row aisles while excluding the legs.
			blockers.append(Rect2(Vector2(x+width*.16,top)*factor,Vector2(width*.68,20 if ten else 10)*factor))
			var chair_y:=row_y+(87 if ten else 105)
			blockers.append(Rect2(Vector2((x+width*.5)*factor-CHAIR_FOOT_WIDTH*.5,chair_y*factor-2),Vector2(CHAIR_FOOT_WIDTH,4)))
			furniture_art.append({"rect":Rect2(Vector2(x,row_y)*factor,Vector2(width,60 if ten else 75)*factor),"edge":(row_y+(60 if ten else 75))*factor})
			furniture_art.append({"rect":Rect2(Vector2(x+width*.22,row_y+(60 if ten else 75))*factor,Vector2(width*.56,bottoms[index]-row_y-(60 if ten else 75))*factor),"edge":float(bottoms[index])*factor})
	if ten:
		add_furniture(Rect2(600*factor,220*factor,160*factor,65*factor))
		add_furniture(Rect2(1430*factor,285*factor,40*factor,250*factor))
		portal(Vector2(1250,265)*factor,Rect2(Vector2(1190,235)*factor,Vector2(150,50)*factor),"corridor",{"side":"front","art_rect":Rect2(Vector2(1170,38)*factor,Vector2(170,195)*factor)})
	else:
		add_furniture(Rect2(690*factor,260*factor,160*factor,65*factor))
		add_furniture(Rect2(1415*factor,376*factor,68*factor,289*factor))
		portal(Vector2(1370,352)*factor,Rect2(Vector2(1350,330)*factor,Vector2(96,30)*factor),"corridor",{"side":"front","art_rect":Rect2(Vector2(1380,92)*factor,Vector2(87,253)*factor)})
		portal(Vector2(1430,900)*factor,Rect2(Vector2(1390,895)*factor,Vector2(56,35)*factor),"corridor",{"side":"rear","art_rect":Rect2(Vector2(1440,660)*factor,Vector2(64,260)*factor)})

func landing(side: String="front") -> Vector2:
	if state["kind"]=="corridor":
		return Vector2(building["stairs_center_x"],125)
	var room: Dictionary=building["floors"][int(state["floor"])-1]["rooms"][int(state["room"])]
	if not life_layout.is_empty():return Vector2(1400,850)*.3
	if room["class10"]: return Vector2(1250,310)*.265
	return Vector2(1370,390)*.2 if side=="front" else Vector2(1430,850)*.2

func configure_office(factor: float) -> void:
	# Office drawings contain eight paired workstations (sixteen desks).
	for box: Array in [[256,340,80,151],[345,340,79,151],[527,304,173,90],[520,394,180,100],[831,306,180,87],[825,393,185,100],[1097,306,182,86],[1091,392,187,102],[227,600,175,91],[213,691,188,105],[516,600,182,91],[507,691,190,98],[826,600,190,91],[817,691,202,96],[1105,635,84,149],[1190,635,85,149],[425,180,139,76],[565,180,116,76],[687,180,161,76],[853,180,151,76],[1245,228,68,40]]:
		add_furniture(Rect2(Vector2(box[0],box[1])*factor,Vector2(box[2],box[3])*factor))
	# Both illustrated doors correspond to the original front/rear corridor doors.
	portal(Vector2(1370,352)*factor,Rect2(Vector2(1350,330)*factor,Vector2(96,30)*factor),"corridor",{"side":"front","art_rect":Rect2(Vector2(1380,92)*factor,Vector2(87,253)*factor)})
	portal(Vector2(1430,900)*factor,Rect2(Vector2(1390,895)*factor,Vector2(56,35)*factor),"corridor",{"side":"rear","art_rect":Rect2(Vector2(1440,660)*factor,Vector2(64,260)*factor)})
