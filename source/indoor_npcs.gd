extends Node2D

const WalkAnimation=preload("res://walk_animation.gd")

const CLASSROOM_OCCUPANTS:=12
const CORRIDOR_OCCUPANTS:=4
const WALK_SPEED:=12.0
var scene: Node2D
var game: Node2D
var records: Array[Dictionary]=[]
var movers: Array[Dictionary]=[]
var rng:=RandomNumberGenerator.new()
var path_plans:=0
var texture_bytes:=0
var lesson_active:=false

func _ready() -> void:
	set_process(not movers.is_empty())

func setup(owner_scene: Node2D, owner_game: Node2D, image: Image) -> void:
	scene=owner_scene;game=owner_game
	y_sort_enabled=true
	rng.randomize()
	set_process(false)
	if scene.state["building"]=="B02":return
	var identity: String="%s/%d/%s/%d" % [scene.state["building"],int(scene.state["floor"]),scene.state["kind"],int(scene.state.get("room",-1))]
	var seed_value:=absi(identity.hash())
	if scene.is_office:
		var points: Array[Vector2]=[Vector2(495,535)*.2,Vector2(790,552)*.2,Vector2(1063,880)*.2]
		for i: int in range(game.office_plan.data["staff_ids"].size()):
			var id: String=game.office_plan.data["staff_ids"][i]
			var at:=valid_point(points[i%points.size()],Rect2(20,65,270,120))
			var record:=make_record(identity+"/staff/"+id,id,game.npc_catalog.characters[id]["display_name"],at,0,true)
			record["role"]=id;records.append(record)
		for i: int in range(clampi(int(game.office_plan.data.get("student_count",1)),0,3)):
			var id: String=game.npc_catalog.ORDINARY_IDS[(seed_value+i)%6]
			var at:=valid_point(Vector2(88+32*i,180),Rect2(20,65,270,120))
			var record:=make_record(identity+"/office_student/"+str(i),id,"同学",at,0,false)
			record["role"]="office_student";records.append(record)
		bake_ordinary(image)
		return
	var ten_class: bool=scene.state["kind"]=="classroom" and int(scene.state["floor"])==3 and int(scene.state.get("room",-1))==0
	if ten_class and game.day_clock.current_period in [1,2]:
		lesson_active=true
		var named_index:=0
		for seat: int in range(32):
			if seat==scene.HERO_SEAT_INDEX:continue
			var named: bool=named_index<game.npc_catalog.NAMED_IDS.size()
			var id: String=game.npc_catalog.NAMED_IDS[named_index] if named else game.npc_catalog.ORDINARY_IDS[(seed_value+seat)%6]
			if named:named_index+=1
			var name: String=game.npc_catalog.characters[id]["display_name"] if named else "同学"
			var record:=make_record(identity+"/seat/"+str(seat),id,name,scene.seat_position(seat),1,named)
			record["seat_index"]=seat;record["seated"]=true;record["height"]*=.68
			# Raise the seated torso above the desktop while its interaction point
			# remains at the chair. The desk foreground masks the lower torso.
			record["art_offset"]=Vector2(0,-scene.furniture_footprints[seat].size.y*.30)
			records.append(record)
		var teacher_id: String="homeroom_teacher" if game.day_clock.current_period==1 else "english_teacher"
		var teacher_at:=valid_point(Vector2(780,295)*.265,Rect2(70,70,280,30))
		var teacher:=make_record(identity+"/teacher",teacher_id,game.npc_catalog.characters[teacher_id]["display_name"],teacher_at,0,true)
		teacher["role"]=teacher_id;teacher["teacher"]=true;records.append(teacher)
		bake_ordinary(image);return
	var static_named: Array=[]
	# All ten named classmates now have a moving copy in each teaching building.
	# Ordinary classrooms keep baked students; ten class contains only named movers.
	if scene.state["kind"]=="classroom":
		var seats: Array[int]=[0,2,4,6,9,11,13,15,16,18,20,22]
		for i: int in range(0 if ten_class else CLASSROOM_OCCUPANTS):
			var footprint: Rect2=scene.furniture_footprints[seats[i]]
			var at:=footprint.get_center()+Vector2(0,footprint.size.y*.22)
			var id: String=game.npc_catalog.ORDINARY_IDS[(seed_value+i)%6]
			var facing:=1 if i%3!=0 else 0
			var name_value: String="同学"
			var named:=i<static_named.size()
			if named:id=static_named[i];name_value=game.npc_catalog.characters[id]["display_name"];facing=0
			var student:=make_record(identity+"/student_"+str(i),id,name_value,at,facing,named)
			student["seated"]=true;student["seat_index"]=seats[i];student["height"]*=.68
			student["art_offset"]=Vector2(0,-footprint.size.y*.30)
			records.append(student)
	else:
		for i: int in range(CORRIDOR_OCCUPANTS):
			var at:=Vector2(scene.dimensions.x*[.18,.37,.63,.82][i],141+9*(i%2))
			var id: String=game.npc_catalog.ORDINARY_IDS[(seed_value+i)%6]
			records.append(make_record(identity+"/student_"+str(i),id,"同学",at,0 if i%2==0 else 2,false))
	bake_ordinary(image)
	if ten_class:
		var range_box:=Rect2(35,92,338,134)
		for i: int in range(game.npc_catalog.NAMED_IDS.size()):
			var id: String=game.npc_catalog.NAMED_IDS[i]
			var at:=valid_point(Vector2(48+float(i%5)*72,112+float(i/5)*78),range_box)
			if not is_finite(at.x):continue
			var record:=make_record(identity+"/named/"+id,id,game.npc_catalog.characters[id]["display_name"],at,0,true)
			var sprite:=Sprite2D.new()
			sprite.position=at;sprite.z_index=10
			sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			var frames: Array[Texture2D]=[]
			var source: Image=game.npc_catalog.source_image(id)
			for direction: int in range(4):
				var crop: Image=game.npc_catalog.frame(id,direction,source)
				crop.generate_mipmaps();frames.append(ImageTexture.create_from_image(crop))
				texture_bytes+=crop.get_data_size()
			add_child(sprite)
			record.merge({"sprite":sprite,"frames":frames,"range":range_box,"path":PackedVector2Array(),"wait":float(i)*.15},true)
			var gait:=WalkAnimation.new()
			if gait.configure(game.npc_catalog.project_root,game.walk_library.get(id,{}),sprite,record["height"],frames):record["gait"]=gait
			else:push_error("NPC 行走差分加载失败："+id)
			records.append(record);movers.append(record)
			face(record,0)
			set_process(true)

func make_record(uid: String, id: String, name_value: String, at: Vector2, facing: int, special: bool) -> Dictionary:
	var height: float=game.npc_catalog.height(id)
	return {"uid":uid,"character":id,"name":name_value,"at":at,"facing":facing,"height":height,"width":height*.48,"special":special}

func bake_ordinary(image: Image) -> void:
	image.convert(Image.FORMAT_RGBA8)
	var density: Vector2=Vector2(image.get_size())/scene.dimensions
	var frame_cache: Dictionary={}
	var needed: Dictionary={}
	for record: Dictionary in records:
		var id: String=record["character"]
		if not needed.has(id):needed[id]=[]
		if not record["facing"] in needed[id]:needed[id].append(record["facing"])
	# Decode one source at a time; keep only the small resized frames until this bake ends.
	for id: String in needed:
		var source: Image=game.npc_catalog.source_image(id)
		for direction: int in needed[id]:
			var crop: Image=game.npc_catalog.frame(id,direction,source)
			var size: Vector2=Vector2(crop.get_size())*game.npc_catalog.height(id)/crop.get_height()*density
			crop.resize(maxi(1,roundi(size.x)),maxi(1,roundi(size.y)),Image.INTERPOLATE_LANCZOS)
			var seated:=false
			for record: Dictionary in records:
				if record["character"]==id and record.get("seated",false):seated=true;break
			if seated:
				crop=crop.get_region(Rect2i(0,0,crop.get_width(),maxi(1,roundi(crop.get_height()*.68))))
			frame_cache[id+str(direction)]=crop
	var desk_patches: Array[Dictionary]=[]
	if scene.state["kind"]=="classroom" and not scene.is_office:
		var ten: bool=scene.building["floors"][int(scene.state["floor"])-1]["rooms"][int(scene.state["room"])] ["class10"]
		var factor:=.265 if ten else .2
		var rows: Array=[320,428,538,651] if ten else [365,485,612]
		for i: int in range(records.size()):
			if records[i].get("teacher",false):continue
			var seat: int=int(records[i]["seat_index"]) if lesson_active else [0,2,4,6,9,11,13,15,16,18,20,22][i]
			var footprint: Rect2=scene.furniture_footprints[seat]
			var desk:=Rect2(footprint.position.x,float(rows[int(seat/8)])*factor,footprint.size.x,(35 if ten else 45)*factor)
			var rect:=Rect2i((desk.position*density).round(),(desk.size*density).ceil())
			desk_patches.append({"at":rect.position,"image":image.get_region(rect)})
	for record: Dictionary in records:
		var crop: Image=frame_cache[record["character"]+str(record["facing"])]
		record["width"]=float(crop.get_width())/density.x
		var at: Vector2=(Vector2(record["at"])+Vector2(record.get("art_offset",Vector2.ZERO)))*density-Vector2(crop.get_width()*.5,crop.get_height())
		image.blend_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(at.round()))
	for patch: Dictionary in desk_patches:
		var crop: Image=patch["image"]
		image.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),patch["at"])

func valid_point(at: Vector2, box: Rect2) -> Vector2:
	if box.has_point(at) and scene.navigation.walkable(at):return at
	for radius: int in range(1,20):
		for step: int in range(16):
			var candidate:=at+Vector2.from_angle(step*TAU/16)*radius*2
			if box.has_point(candidate) and scene.navigation.walkable(candidate):return candidate
	return Vector2(INF,INF)

func face(record: Dictionary, direction: int) -> void:
	record["facing"]=direction
	if record.has("gait"):
		record["gait"].face(direction)
		record["width"]=record["sprite"].texture.get_width()*record["sprite"].scale.x
		return
	var sprite: Sprite2D=record["sprite"]
	sprite.texture=record["frames"][direction]
	sprite.scale=Vector2.ONE*float(record["height"])/sprite.texture.get_height()
	sprite.offset=Vector2(0,-sprite.texture.get_height()*.5)
	record["width"]=sprite.texture.get_width()*sprite.scale.x

func _process(delta: float) -> void:
	if game.player.frozen or not game.game_started:
		for record: Dictionary in movers:
			if record.has("gait"):record["gait"].stop()
		return
	for record: Dictionary in movers:
		if record["uid"]==game.pending_npc_talk:
			if record.has("gait"):record["gait"].stop()
			continue
		var path: PackedVector2Array=record["path"]
		if path.is_empty():
			if record.has("gait"):record["gait"].stop()
			record["wait"]-=delta
			if record["wait"]>0:continue
			record["wait"]=rng.randf_range(1.2,3.0)
			var box: Rect2=record["range"]
			for attempt: int in range(8):
				var target:=Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
				if not scene.navigation.walkable(target) or target.distance_to(record["at"])<12:continue
				var candidate: PackedVector2Array=scene.navigation.route(record["at"],target)
				path_plans+=1
				var contained:=not candidate.is_empty()
				for waypoint: Vector2 in candidate:
					if not box.has_point(waypoint):contained=false;break
				if contained:record["path"]=candidate;break
			continue
		var before: Vector2=record["at"]
		var next:=before.move_toward(path[0],WALK_SPEED*delta)
		if not scene.navigation.segment_clear(before,next):
			record["path"]=PackedVector2Array()
			if record.has("gait"):record["gait"].stop()
			continue
		record["at"]=next
		record["sprite"].position=next
		if record.has("gait"):record["gait"].advance(delta,next.distance_to(before)/maxf(delta,.001))
		var direction:=before.direction_to(next)
		if not direction.is_zero_approx():face(record,(3 if direction.x>0 else 2) if absf(direction.x)>absf(direction.y) else (0 if direction.y>0 else 1))
		if next.distance_to(path[0])<.02:path.remove_at(0)
		record["path"]=path

func find(uid: String) -> Dictionary:
	for record: Dictionary in records:
		if record["uid"]==uid:return record
	return {}

func interactions() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for record: Dictionary in records:
		var at: Vector2=record["at"]
		var art_at: Vector2=at+Vector2(record.get("art_offset",Vector2.ZERO))
		result.append({"action":"npc","uid":record["uid"],"name":record["name"],"at":at,"trigger":Rect2(),"art_rect":Rect2(art_at-Vector2(record["width"]*.5,record["height"]),Vector2(record["width"],record["height"]))})
	return result

func approach(uid: String, from: Vector2) -> PackedVector2Array:
	var record:=find(uid)
	if record.is_empty():return PackedVector2Array()
	var at: Vector2=record["at"]
	var best:=PackedVector2Array()
	var best_length:=INF
	for radius: int in [9,11]:
		for step: int in range(12):
			var goal:=at+Vector2.from_angle(step*TAU/12)*radius
			if not scene.navigation.walkable(goal):continue
			var path: PackedVector2Array=scene.navigation.route(from,goal)
			if path.is_empty():continue
			var length:=0.0
			var previous:=from
			for waypoint: Vector2 in path:length+=previous.distance_to(waypoint);previous=waypoint
			if length<best_length:best_length=length;best=path
	return best
