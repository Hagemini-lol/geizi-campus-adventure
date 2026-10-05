extends Node2D

const PPM := 24.0
const Space = preload("res://map_space.gd")
var model: Dictionary
var index: int
var preserved: Array[Rect2] = []
var planting: Array[Rect2] = []
var parts: Array[Dictionary] = []
var map_texture: Texture2D
var map_bounds: Rect2
var garden := Rect2()
var camera: Camera2D
var last_view := Vector2(INF,INF)
var last_zoom := Vector2.ZERO
var bake_bounds := Rect2()
var interior_info: Dictionary={}
var font: SystemFont

func _ready() -> void:
	z_index=-3
	var content: Variant=JSON.parse_string(FileAccess.get_file_as_string("D:/Godot/地图重绘预览/内景/内外对应.json"))
	if content is Dictionary: interior_info=content
	font=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
	font.oversampling=4.0
	# Future background bakes retain the same corrected sports geometry.
	add_child(preload("res://sports_art.gd").new())
	queue_redraw()

func _process(_delta: float) -> void:
	if bake_bounds.has_area(): return
	if camera != null and (last_view.distance_to(camera.get_screen_center_position())>6 or last_zoom!=camera.zoom):
		last_view=camera.get_screen_center_position()
		last_zoom=camera.zoom
		queue_redraw()

func clips(box: Rect2) -> Array[Rect2]:
	var result: Array[Rect2]=[]
	var region: Dictionary=model["regions"][index]
	for a: Array in region.get("visual_areas",region["world_areas"]):
		var area:=Rect2(Vector2(a[0],a[1])*PPM,Vector2(a[2],a[3])*PPM)
		if area.intersects(box): result.append(area.intersection(box))
	return result

func rect_owned(box: Rect2, color: Color) -> void:
	for clip: Rect2 in clips(box): draw_rect(clip,color)

func _draw() -> void:
	if camera==null and not bake_bounds.has_area(): return
	var visible:=bake_bounds
	if not visible.has_area():
		var view_size:=get_viewport_rect().size/camera.zoom
		visible=Rect2(camera.get_screen_center_position()-view_size/2,view_size).grow(80)
	for y: int in range(maxi(0,int(visible.position.y/PPM)),mini(360,int(visible.end.y/PPM)+1)):
		for x: int in range(maxi(0,int(visible.position.x/PPM)),mini(320,int(visible.end.x/PPM)+1)):
			var cell:=Rect2(x*PPM,y*PPM,PPM,PPM)
			var retain:=false
			for box: Rect2 in preserved:
				if box.intersects(cell): retain=true; break
			if retain: continue
			var lawn:=false
			for box: Rect2 in planting:
				if box.has_point(cell.get_center()): lawn=true; break
			for a: Array in model["bridges"]:
				if Rect2(a[0]*PPM,a[1]*PPM,a[2]*PPM,a[3]*PPM).has_point(cell.get_center()): lawn=false; break
			for clip: Rect2 in clips(cell):
				if lawn:
					draw_rect(clip,Color("6e9656") if (x+y)%2==0 else Color("739b5b"))
				else:
					draw_rect(clip,Color("d4c4ab") if (x+y)%2==0 else Color("cebea5"))
					for dy: int in range(2):
						for dx: int in range(2):
							var tile:=Rect2(cell.position+Vector2(dx,dy)*12,Vector2.ONE*12)
							if clip.encloses(tile): draw_rect(tile,Color("ad9d85"),false,.8)
	for part: Dictionary in parts:
		var box: Rect2=part["box"]
		if not visible.intersects(box.grow(2*PPM)): continue
		var owner: String=part["owner"]
		if owner=="wall" or owner.ends_with("canopy_post"):
			rect_owned(box,Color("8a9390"))
			for clip: Rect2 in clips(box): draw_rect(clip,Color("bec5bc"),false,2)
		elif owner=="outdoor_screen":
			draw_screen(box)
		elif owner.begins_with("B") or owner=="S02": draw_building(part)
	draw_boards()
	draw_gateways()
	if garden.has_area() and visible.intersects(garden):
		for e: Array in model.get("ellipses",[]):
			var center:=Vector2(e[0]+e[2]/2,e[1]+e[3]/2)*PPM
			# Keep the HD flower garden; bound the pool artwork to its physical rim.
			rect_owned(Rect2(e[0]*PPM,e[1]*PPM,e[2]*PPM,e[3]*PPM).grow(.25*PPM),Color("d0c5ad"))
			var radius:=Vector2(e[2],e[3])*PPM/2
			var rim:=PackedVector2Array()
			var water:=PackedVector2Array()
			var uvs:=PackedVector2Array()
			for i: int in range(49):
				var unit:=Vector2(cos(i*TAU/48),sin(i*TAU/48))
				rim.append(center+unit*radius)
				water.append(center+unit*(radius-Vector2.ONE*.45*PPM))
				uvs.append((water[-1]-map_bounds.position)/map_bounds.size)
			draw_colored_polygon(rim,Color("c9bfa6"))
			draw_colored_polygon(water,Color("548fb5"))
			draw_polygon(water,PackedColorArray([Color.WHITE]),uvs,map_texture)
			draw_polyline(rim,Color("8b8374"),2,true)
			draw_polyline(water,Color("96d3dc"),2,true)

func draw_screen(box: Rect2) -> void:
	# All panel artwork fits the same rectangle as the existing physical screen.
	rect_owned(box,Color("303940"))
	var panel:=box.grow(-.22*PPM)
	rect_owned(panel,Color("122c39"))
	rect_owned(Rect2(panel.position,Vector2(panel.size.x,.18*PPM)),Color("71838c"))
	var inset:=Rect2(panel.position+Vector2(.55,.5)*PPM,panel.size-Vector2(1.1,1)*PPM)
	if inset.size.y>.4*PPM:
		rect_owned(inset,Color("274b60"))
		for row: int in range(3):
			var stripe:=Rect2(inset.position+Vector2(.4*PPM,(row+1)*inset.size.y/5),Vector2(inset.size.x*(.62 if row==0 else .4),.10*PPM))
			rect_owned(stripe,Color("91c7ce"))
	for x: float in [box.position.x+.8*PPM,box.end.x-1.3*PPM]:
		rect_owned(Rect2(x,box.end.y-.45*PPM,.5*PPM,.45*PPM),Color("80878b"))

func draw_gateways() -> void:
	# Reference imagery had a different gate layout. Rebuild both entries from
	# the actual pillar colliders, leaving the passage open and unobstructed.
	for source: Array in [[220,40,13,25,258,40,13,25],[477,1332,23,41,558,1332,25,41]]:
		var left:=Space.box_to_world(Rect2(source[0],source[1],source[2],source[3]))
		var right:=Space.box_to_world(Rect2(source[4],source[5],source[6],source[7]))
		for post: Rect2 in [left,right]:
			rect_owned(post,Color("b96550"))
			var cap:=Rect2(post.position,Vector2(post.size.x,.35*PPM))
			rect_owned(cap,Color("e6e4d9"))
			rect_owned(Rect2(post.position.x,post.end.y-.3*PPM,post.size.x,.3*PPM),Color("9c9c91"))
			var panel:=post.grow(-.45*PPM)
			if panel.has_area(): rect_owned(panel,Color("a45244"))
			for row: int in range(int(post.position.y/6)+1,int(post.end.y/6)):
				for clip: Rect2 in clips(post):
					draw_line(Vector2(clip.position.x,row*6),Vector2(clip.end.x,row*6),Color("9f5545"),.6)
			var window:=Rect2(post.position.x+.6*PPM,post.end.y-2.4*PPM,1.2*PPM,1.3*PPM)
			rect_owned(window.grow(.07*PPM),Color("e9e6d8"))
			rect_owned(window,Color("577c8d"))
			rect_owned(Rect2(window.get_center().x-.025*PPM,window.position.y,.05*PPM,window.size.y),Color("e9e6d8"))
			var door:=Rect2(post.end.x-1.7*PPM,post.end.y-2.1*PPM,1.1*PPM,2.1*PPM)
			rect_owned(door,Color("38545e"))
		var opening:=Rect2(left.end.x,left.position.y,right.position.x-left.end.x,left.size.y)
		# A shallow overhead lintel is decoration; it does not add a new blocker.
		rect_owned(Rect2(left.position.x,left.position.y-.32*PPM,right.end.x-left.position.x,.32*PPM),Color("e9e6d8"))
		for edge: float in [opening.position.x,opening.end.x-.16*PPM]:
			rect_owned(Rect2(edge,opening.end.y-.5*PPM,.16*PPM,.5*PPM),Color("536069"))

func draw_building(part: Dictionary) -> void:
	var full: Rect2=part["box"]
	var owner: String=part["owner"]
	if owner=="B03" and not part.get("gym_section",false):
		# The sports hall and its attached western wing share a footprint, but
		# have different roof heights. Keep the two window rows of the tall hall.
		var split:=full.size.x*.18
		var wing: Dictionary=part.duplicate()
		wing["box"]=Rect2(full.position,Vector2(split,full.size.y))
		wing["stories"]=1
		wing["gym_section"]=true
		var hall: Dictionary=part.duplicate()
		hall["box"]=Rect2(full.position+Vector2(split,0),Vector2(full.size.x-split,full.size.y))
		hall["stories"]=2
		hall["gym_section"]=true
		draw_building(wing)
		draw_building(hall)
		return
	var stories: int=clampi(int(part["stories"]),1,5)
	var chunhua:=owner=="B12"
	var teaching: Dictionary=interior_info.get("buildings",{}).get(owner,{})
	var main_facade:=false
	if not teaching.is_empty():
		var a: Array=teaching["box"]
		main_facade=full.position.distance_to(Vector2(a[0],a[1])*PPM)<.1 and full.size.distance_to(Vector2(a[2],a[3])*PPM)<.1
	# Fit the visible facade into the existing top-down footprint. Windows and
	# ground-floor doors retain metre-based sizes, including on shallow wings.
	var wall_height:=minf(stories*3*PPM,full.size.y*(.84 if chunhua else .62))
	wall_height=maxf(minf(2.7*PPM,full.size.y),wall_height)
	if main_facade: wall_height=minf(stories*3*PPM,full.size.y-.6*PPM)
	var wall:=Rect2(full.position.x,full.end.y-wall_height,full.size.x,wall_height)
	var roof:=Rect2(full.position,Vector2(full.size.x,full.size.y-wall_height))
	var roof_color:=Color("899493") if chunhua else Color("777c79")
	var wall_color:=Color("815c52") if chunhua else Color("b96550")
	var trim:=Color("ebe8dc")
	var levels:=mini(stories,maxi(1,int(wall_height/(2.5*PPM))))
	if main_facade: levels=stories
	var pitch:=wall_height/levels
	var bay:=2.5*PPM if chunhua else 3.2*PPM
	var window_width:=1.3*PPM if chunhua else 1.5*PPM
	for clip: Rect2 in clips(roof):
		draw_rect(clip,roof_color)
		if owner=="B03":
			for rib: int in range(int(clip.position.x/(.5*PPM))+1,int(clip.end.x/(.5*PPM))):
				draw_line(Vector2(rib*.5*PPM,clip.position.y),Vector2(rib*.5*PPM,clip.end.y),Color("a1aaa7"),1.2)
			var ridge:=Rect2(roof.position.x,roof.get_center().y,roof.size.x,.16*PPM)
			if clip.intersects(ridge): draw_rect(clip.intersection(ridge),Color("c1c6bd"))
		# Neutral flat roof: old raster colours cannot leak onto the new facade.
		for row: int in range(int(clip.position.y/(2*PPM))+1,int(clip.end.y/(2*PPM))):
			draw_line(Vector2(clip.position.x,row*2*PPM),Vector2(clip.end.x,row*2*PPM),roof_color.darkened(.08),.8)
		draw_rect(clip,roof_color.darkened(.35),false,2)
	for clip: Rect2 in clips(wall):
		draw_rect(clip,wall_color)
		for row: int in range(int(clip.position.y/6)+1,int(clip.end.y/6)):
			var brick_y:=row*6.0
			draw_line(Vector2(clip.position.x,brick_y),Vector2(clip.end.x,brick_y),wall_color.darkened(.17),.6)
			for joint: int in range(int(clip.position.x/18),int(clip.end.x/18)+1):
				var joint_x:=joint*18.0+(9 if row%2==0 else 0)
				if joint_x>clip.position.x and joint_x<clip.end.x:
					draw_line(Vector2(joint_x,brick_y),Vector2(joint_x,minf(brick_y+6,clip.end.y)),wall_color.darkened(.12),.5)
		# Chunhua has continuous white pilasters; other buildings have brick piers.
		if chunhua:
			for column: int in range(int(full.size.x/bay)+1):
				var pilaster:=Rect2(full.position.x+column*bay,wall.position.y,.19*PPM,wall.size.y)
				if clip.intersects(pilaster): draw_rect(clip.intersection(pilaster),trim)
		for level: int in range(levels):
			var wy:=wall.end.y-level*pitch-minf(2.35*PPM,pitch-.1*PPM)
			if chunhua:
				var band:=Rect2(full.position.x,wall.end.y-(level+1)*pitch,full.size.x,.14*PPM)
				if clip.intersects(band): draw_rect(clip.intersection(band),trim)
			for column: int in range(int(full.size.x/bay)):
				if main_facade and not teaching["columns"].has(float(column)): continue
				var wx:=full.position.x+column*bay+(bay-window_width)/2
				if level==0 and absf(wx+window_width/2-full.get_center().x)<2.6*PPM: continue
				var window:=Rect2(wx,wy,window_width,1.5*PPM)
				if not clip.encloses(window): continue
				draw_rect(window,trim)
				draw_rect(window.grow(-1.6),Color("577c8d"))
				draw_rect(Rect2(window.position+Vector2(2,2),Vector2(window.size.x-4,window.size.y*.32)),Color("8dabb4"))
				for mullion: int in range(1,3):
					var mx:=window.position.x+window.size.x*mullion/3
					draw_line(Vector2(mx,window.position.y+1),Vector2(mx,window.end.y-1),trim,1.2)
				draw_line(Vector2(window.position.x+1,window.position.y+window.size.y*.4),Vector2(window.end.x-1,window.position.y+window.size.y*.4),trim,1.2)
				var sill:=Rect2(window.position.x-1,window.end.y,window.size.x+2,.10*PPM)
				if clip.encloses(sill): draw_rect(sill,trim.darkened(.12))
		var cornice:=Rect2(full.position.x,wall.position.y,full.size.x,.22*PPM)
		if clip.intersects(cornice): draw_rect(clip.intersection(cornice),trim)
		var plinth:=Rect2(full.position.x,full.end.y-.25*PPM,full.size.x,.25*PPM)
		if clip.intersects(plinth): draw_rect(clip.intersection(plinth),Color("948b80"))
		var door:=Rect2(full.get_center().x-.95*PPM,full.end.y-2.1*PPM,1.9*PPM,2.1*PPM)
		if clip.encloses(door) and owner not in ["B07","B08"]:
			draw_rect(door.grow(1),trim)
			draw_rect(door,Color("38545e"))
			draw_line(Vector2(door.get_center().x,door.position.y),Vector2(door.get_center().x,door.end.y),Color("b4c5c6"),1)
			if chunhua:
				var porch:=Rect2(full.get_center().x-2.4*PPM,door.position.y-.35*PPM,4.8*PPM,.35*PPM)
				if clip.encloses(porch):
					draw_rect(porch,trim)
					draw_line(Vector2(porch.position.x,porch.end.y),porch.end,Color("8e9692"),2)
			for step: int in range(5):
				var tread:=Rect2(full.get_center().x-2*PPM,full.end.y+step*.3*PPM,4*PPM,.3*PPM)
				rect_owned(tread,Color("9da7a9").lightened(step*.025))
		draw_rect(clip,Color("77716b"),false,1.5)
func draw_boards() -> void:
	# Boards are part of this one baked image, with no live window meshes.
	for entry: Dictionary in interior_info.get("entrances",[]):
		if entry.get("side","")=="west":
			var foot:=Vector2(entry["door"][0],entry["door"][1])*PPM
			var door:=Rect2(foot+Vector2(.1,-2.1)*PPM,Vector2(1.9,2.1)*PPM)
			rect_owned(door.grow(1),Color("ebe8dc"))
			rect_owned(door,Color("38545e"))
		var center:=Vector2(entry["board"][0],entry["board"][1])*PPM
		var board:=Rect2(center-Vector2(.9,.6)*PPM,Vector2(1.8,1.2)*PPM)
		rect_owned(board,Color("775b3c"))
		rect_owned(board.grow(-3),Color("e7ddbd"))
		for line: int in range(3): rect_owned(Rect2(board.position+Vector2(6,16+line*5),Vector2(31,1)),Color("708b75"))
		if font!=null:
			for owned: Rect2 in clips(board):
				if owned.encloses(board): draw_string(font,board.position+Vector2(4,11),"校园导览",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("26413e"))
