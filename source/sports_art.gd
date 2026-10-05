extends Node2D

# Offline drawing only. Baked into the same background/HD tiles as the campus.
const PPM:=24.0
const TRACK:=Rect2(18,45,150,250)
const PITCH:=Rect2(33,80,120,180)
const CANOPY:=Rect2(5.7735849,152.8,12.2264151,33.6)
const LANE_WIDTH:=1.22
const GOAL_WIDTH:=7.32
const CENTER_RADIUS:=9.15

static func relevant(bounds: Rect2) -> bool:
	return bounds.intersects(Rect2(TRACK.position*PPM,TRACK.size*PPM).grow(6)) or bounds.intersects(Rect2(CANOPY.position*PPM,CANOPY.size*PPM).grow(6))

func rounded(box: Rect2, radius: float) -> PackedVector2Array:
	var points:=PackedVector2Array()
	var centers: Array[Vector2]=[box.position+Vector2(radius,radius),Vector2(box.end.x-radius,box.position.y+radius),box.end-Vector2(radius,radius),Vector2(box.position.x+radius,box.end.y-radius)]
	for corner: int in range(4):
		for i: int in range(49):
			points.append((centers[corner]+Vector2.from_angle(PI+corner*PI/2+i*PI/96)*radius)*PPM)
	return points

func outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed: PackedVector2Array=points.duplicate();closed.append(points[0]);draw_polyline(closed,color,width*PPM,true)

func field_box(box: Rect2) -> void:
	draw_rect(Rect2(box.position*PPM,box.size*PPM),Color("f2f4df"),false,.10*PPM,true)

func field_line(a: Vector2,b: Vector2) -> void:
	draw_line(a*PPM,b*PPM,Color("f2f4df"),.10*PPM,true)

func _draw() -> void:
	# All coordinates are metres, keeping goals, markings, and lanes human scaled.
	draw_rect(Rect2(TRACK.position*PPM,TRACK.size*PPM),Color("85977b"))
	draw_colored_polygon(rounded(TRACK,35),Color("aa5148"))
	var inner:=TRACK.grow(-LANE_WIDTH*8)
	draw_colored_polygon(rounded(inner,35-LANE_WIDTH*8),Color("587c49"))
	for i: int in range(9):
		outline(rounded(TRACK.grow(-i*LANE_WIDTH),35-i*LANE_WIDTH),Color("edd4b9"),.06)
	for y: int in range(30):
		draw_rect(Rect2(Vector2(PITCH.position.x,PITCH.position.y+y*6)*PPM,Vector2(PITCH.size.x,6)*PPM),Color("658a52") if y%2==0 else Color("5b814b"))
	field_box(PITCH)
	var centre:=PITCH.get_center()
	field_line(Vector2(PITCH.position.x,centre.y),Vector2(PITCH.end.x,centre.y))
	draw_arc(centre*PPM,CENTER_RADIUS*PPM,0,TAU,180,Color("f2f4df"),.1*PPM,true)
	draw_circle(centre*PPM,.16*PPM,Color("f2f4df"))
	for end: int in range(2):
		var y: float=PITCH.position.y if end==0 else PITCH.end.y
		var sign: float=1 if end==0 else -1
		for dims: Vector2 in [Vector2(40.32,16.5),Vector2(18.32,5.5)]:
			field_box(Rect2(Vector2(centre.x-dims.x/2,y if end==0 else y-dims.y),dims))
		draw_circle(Vector2(centre.x,y+sign*11)*PPM,.16*PPM,Color("f2f4df"))
		var arc_center:=Vector2(centre.x,y+sign*11)
		var angle:=asin(5.5/CENTER_RADIUS)
		draw_arc(arc_center*PPM,CENTER_RADIUS*PPM,angle if end==0 else PI+angle,PI-angle if end==0 else TAU-angle,64,Color("f2f4df"),.1*PPM,true)
		goal(Vector2(centre.x,y),sign)
		for x: float in [PITCH.position.x,PITCH.end.x]:
			var start:=0.0 if x==PITCH.position.x else PI/2
			if end==1:start=-PI/2 if x==PITCH.position.x else PI
			draw_arc(Vector2(x,y)*PPM,PPM,start,start+PI/2,24,Color("f2f4df"),.1*PPM,true)
	# Finish line crosses only the lane band, not the entire pitch.
	field_line(Vector2(TRACK.end.x-LANE_WIDTH*8,246),Vector2(TRACK.end.x,246))
	canopy()

func goal(at: Vector2, sign: float) -> void:
	var half:=GOAL_WIDTH/2
	var back_y:=at.y-sign*2
	var cross_y:=at.y-2.44*.58
	var ground_left:=Vector2(at.x-half,at.y)*PPM
	var ground_right:=Vector2(at.x+half,at.y)*PPM
	var top_left:=Vector2(at.x-half,cross_y)*PPM
	var top_right:=Vector2(at.x+half,cross_y)*PPM
	var back_left:=Vector2(at.x-half,back_y)*PPM
	var back_right:=Vector2(at.x+half,back_y)*PPM
	draw_colored_polygon(PackedVector2Array([back_left,back_right,ground_right,ground_left]),Color(1,1,1,.12))
	for i: int in range(25):
		var t:=i/24.0;draw_line(back_left.lerp(back_right,t),ground_left.lerp(ground_right,t),Color("bcc5b1"),.018*PPM,true)
	for i: int in range(8):
		var t:=i/7.0;draw_line(back_left.lerp(ground_left,t),back_right.lerp(ground_right,t),Color("bcc5b1"),.018*PPM,true)
	for segment: Array in [[ground_left,top_left],[top_left,top_right],[top_right,ground_right],[top_left,back_left],[top_right,back_right],[back_left,back_right]]:
		draw_line(segment[0],segment[1],Color("f1f4eb"),.10*PPM,true)

func canopy() -> void:
	# Open sports stand, replacing the erroneously baked red-brick facade.
	var box:=Rect2(CANOPY.position*PPM,CANOPY.size*PPM)
	draw_rect(box,Color("aab4b5"))
	for row: int in range(5):
		var x: float=box.position.x+(1+row*1.8)*PPM
		draw_rect(Rect2(x,box.position.y+.9*PPM,1.4*PPM,box.size.y-1.8*PPM),Color("829698"))
		draw_line(Vector2(x,box.position.y+.9*PPM),Vector2(x,box.end.y-.9*PPM),Color("d3dadd"),.10*PPM)
	# Roof and slender support columns remain proportionate to a 1.7 m person.
	var roof:=Rect2(box.position,Vector2(box.size.x*.43,box.size.y))
	draw_rect(roof,Color("d6e0df"))
	for rib: int in range(24):
		var y:=roof.position.y+(rib+.5)*roof.size.y/24
		draw_line(Vector2(roof.position.x,y),Vector2(roof.end.x,y),Color("b3c5c8"),.05*PPM)
	draw_rect(roof,Color("527483"),false,.18*PPM)
	for i: int in range(6):
		var at:=Vector2(roof.end.x,roof.position.y+(i+.5)*roof.size.y/6)
		draw_line(at,at+Vector2(.65,.2)*PPM,Color("67767a"),.24*PPM)
