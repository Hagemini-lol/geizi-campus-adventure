extends "res://interior_scene.gd"

var room_style:=""
func setup(value: Dictionary, context: Dictionary, directory: String, game: Node2D=null) -> bool:
	var id: String=context["building"]
	if not id.begins_with("STORY_"):
		if not super.setup(value,context,directory,game):return false
		if context["kind"]=="classroom" and id=="B06":
			room_style="library"
			for box: Rect2 in [Rect2(65,58,35,10),Rect2(110,58,35,10),Rect2(155,58,35,10)]:
				blockers.append(box);add_box(box)
			navigation.configure(dimensions,classroom_floor(false),blockers,1.8)
		if context["kind"]=="classroom" and id=="B15" and int(context["floor"])==4:room_style="ritual"
		refresh_cast(game)
		return true
	info=value;state=context.duplicate();building=info["buildings"][id];scene_font=game.ui_font
	y_sort_enabled=true;dimensions=Vector2(307.2,204.8);title=building["name"];is_ten_class=false;is_office=false
	room_style="seal" if id=="STORY_SEAL" else "house"
	background=Sprite2D.new();background.centered=false;background.z_index=-5
	var image:=Image.create(1536,1024,false,Image.FORMAT_RGB8);image.fill(Color("28363c") if room_style=="seal" else Color("a29279"))
	image.generate_mipmaps();background.texture=ImageTexture.create_from_image(image);background.scale=Vector2.ONE*.2;add_child(background);texture_bytes=image.get_data_size()
	if room_style=="house":
		var wall_image:=Image.load_from_file(info["assets"]["office_wood"]);wall_image.generate_mipmaps()
		var wall:=Sprite2D.new();wall.centered=false;wall.texture=ImageTexture.create_from_image(wall_image);wall.region_enabled=true;wall.region_rect=Rect2(0,0,1536,265);wall.scale=Vector2.ONE*.2;wall.z_index=-4;wall.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(wall);texture_bytes+=wall_image.get_data_size()
	var polygon:=classroom_floor(false)
	if room_style=="house":blockers.append(Rect2(125,105,60,25))
	else:blockers.append(Rect2(125,56,55,15))
	# Props share actors' sorting layer and use their bottom edge as the footpoint.
	var prop:=Polygon2D.new();prop.z_index=10
	prop.position=Vector2(155,130) if room_style=="house" else Vector2(152.5,71)
	prop.polygon=PackedVector2Array([Vector2(-30,-35),Vector2(30,-35),Vector2(30,0),Vector2(-30,0)]) if room_style=="house" else PackedVector2Array([Vector2(-27.5,-55),Vector2(27.5,-55),Vector2(27.5,0),Vector2(-27.5,0)])
	prop.color=Color("66503a") if room_style=="house" else Color("4b555c");add_child(prop)
	var inset:=Polygon2D.new();inset.polygon=PackedVector2Array([Vector2(-23,-30),Vector2(23,-30),Vector2(23,-8),Vector2(-23,-8)]) if room_style=="house" else PackedVector2Array([Vector2(-21,-50),Vector2(21,-50),Vector2(21,-5),Vector2(-21,-5)])
	inset.color=Color("cab998") if room_style=="house" else Color("303c44");prop.add_child(inset)
	navigation.configure(dimensions,polygon,blockers,1.8)
	for box: Rect2 in blockers:add_box(box)
	for i: int in range(polygon.size()):
		var a: Vector2=polygon[i];var b: Vector2=polygon[(i+1)%polygon.size()]
		var body:=StaticBody2D.new();body.position=(a+b)*.5;body.rotation=(b-a).angle()
		var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(a.distance_to(b),.2);collision.shape=shape;body.add_child(collision);add_child(body)
	portal(Vector2(274,75),Rect2(266,66,20,20),"corridor",{"side":"front","art_rect":Rect2(264,56,22,22)})
	portal(Vector2(275,177),Rect2(266,167,20,20),"corridor",{"side":"rear","art_rect":Rect2(264,165,22,22)})
	return true

func refresh_cast(game: Node2D) -> void:
	if state["kind"]!="classroom" or state["building"].begins_with("STORY_"):return
	if npcs!=null:
		texture_bytes-=npcs.texture_bytes;remove_child(npcs);npcs.queue_free();npcs=null
	if not game.campaign.active():return
	var here: String="%s:%s:%s" % [state["building"],state["floor"],state.get("room",-1)]
	var ids: Array=[]
	for id: String in ["wr","wen_cong"]:
		if game.campaign.scheduled_location(id)==here:ids.append(id)
	if not ids.is_empty():
		npcs=preload("res://campaign_cast.gd").new();add_child(npcs);npcs.setup(game,self,ids);texture_bytes+=npcs.texture_bytes

func landing(side: String="front") -> Vector2:
	if state["building"].begins_with("STORY_"):return Vector2(260,85) if side=="front" else Vector2(260,175)
	return super.landing(side)

func _draw() -> void:
	super._draw()
	if room_style in ["house","seal"]:
		var seam:=Color("827660") if room_style=="house" else Color("3c4d54")
		for y: int in range(60,205,12):draw_line(Vector2(0,y),Vector2(307,y),seam,.45,true)
		for x: int in range(0,308,28):draw_line(Vector2(153+(x-153)*.8,60),Vector2(x,204.8),seam,.45,true)
	if room_style=="library":
		for x: int in [65,110,155]:
			draw_rect(Rect2(x,39,35,29),Color("5b4430"));draw_rect(Rect2(x+2,42,31,21),Color("2c3234"))
			for n: int in range(9):draw_rect(Rect2(x+3+n*3,44,2,17),[Color("a46551"),Color("7b9398"),Color("c3ad72")][n%3])
	elif room_style=="ritual" or room_style=="seal":
		draw_arc(Vector2(151,85),23,0,TAU,80,Color("c5a977"),1.2,true)
		draw_arc(Vector2(151,85),18,0,TAU,80,Color("738da3"),.8,true)
		for n: int in range(6):draw_line(Vector2(151,85)+Vector2.from_angle(n*TAU/6)*23,Vector2(151,85)+Vector2.from_angle((n+2)*TAU/6)*23,Color("aeb2a2"),.7,true)
	if room_style in ["house","seal"]:
		draw_string(scene_font,Vector2(228,61),"旧宅 / 石室",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("f1dfb6"))
		draw_string(scene_font,Vector2(233,193),"返回校园",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("f1dfb6"))
