extends RefCounted

# Pose keys share one atlas. Only the portrait moves; names, floor shadows
# and responsive slot layout remain anchored. Tweening needs no extra art.
var frames: Array[Texture2D]=[]
var poses: Dictionary={}
var view: Control
var base_position:=Vector2.ZERO
var elapsed:=0.0
var key:=-1
var acting:=false
var phase:=1
var toward:=-1.0

func configure(root: String, spec: Dictionary, target: Control) -> bool:
	view=target;frames.clear();poses.clear();elapsed=0;key=-1;acting=false
	var path: String=spec.get("portrait_atlas","")
	if path.is_empty():return false
	var metadata: Variant=JSON.parse_string(FileAccess.get_file_as_string(root.path_join(path.get_base_dir()).path_join("motion.json")))
	if not metadata is Dictionary:return false
	var image:=Image.load_from_file(root.path_join(path))
	if image==null:return false
	image.generate_mipmaps()
	var sheet:=ImageTexture.create_from_image(image)
	var cell: Array=metadata["cell"]
	for i: int in range(int(metadata["columns"])*int(metadata["rows"])):
		var frame:=AtlasTexture.new();frame.atlas=sheet
		frame.region=Rect2((i%int(metadata["columns"]))*int(cell[0]),(i/int(metadata["columns"]))*int(cell[1]),int(cell[0]),int(cell[1]))
		frames.append(frame)
	poses=metadata["poses"].duplicate(true)
	return true

static func cropped(source: Texture2D) -> Texture2D:
	if source==null or source is AtlasTexture:return source
	var image:=source.get_image()
	if image==null:return source
	var region:=image.get_used_rect()
	if not region.has_area():return source
	var crop:=AtlasTexture.new();crop.atlas=source;crop.region=region
	return crop

func register_pose(action: String, source: Texture2D) -> void:
	if source==null:return
	poses[action]=[frames.size()];frames.append(cropped(source))

func texture(action: String, index: int=0) -> Texture2D:
	var sequence: Array=poses.get(action,poses.get("idle",[0]))
	return frames[int(sequence[index%sequence.size()])] if not frames.is_empty() else null

func set_action(action: String, index: int=0) -> void:
	if not frames.is_empty() and is_instance_valid(view):
		var next:=texture(action,index)
		if view.displayed_pose!=next:view.set_pose(next)

func portrait() -> Control:
	return view.portrait_view if is_instance_valid(view) else null

func tick(delta: float) -> void:
	var body:=portrait()
	if body==null:return
	body.pivot_offset=Vector2(body.size.x*.5,body.size.y)
	if acting:return
	elapsed+=delta
	body.scale=Vector2(1,1+sin(elapsed*2.1)*.006)
	var next:=int(elapsed*3.0)%2
	if next!=key:
		key=next;set_action("phase" if phase==2 else "idle",next)

func play(action: String, seconds: float=.36) -> void:
	var body:=portrait()
	if body==null:return
	acting=true;base_position=body.position
	body.scale=Vector2.ONE;body.rotation=0;body.pivot_offset=Vector2(body.size.x*.5,body.size.y)
	var span:=maxf(seconds,.375 if action in ["attack","physical","combo"] else .25 if action in ["hit","rest","evade"] else .1)
	var offset:=Vector2.ZERO
	match action:
		"windup":offset=Vector2(-toward*4,1)
		"attack","physical","combo":offset=Vector2(toward*18,-2)
		"hit":offset=Vector2(-toward*7,1)
		"evade":offset=Vector2(-toward*24,-2)
		"guard":offset=Vector2(-toward*2,1)
	var tween:=body.create_tween()
	if action in ["attack","physical","combo"]:
		set_action("idle" if action in ["physical","combo"] else "windup")
		tween.tween_property(body,"position",base_position-Vector2(toward*3,0),span*.25).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(set_action.bind("physical" if action in ["physical","combo"] else "attack"))
		tween.tween_property(body,"position",base_position+offset,span*.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if action=="combo":
			tween.tween_property(body,"position",base_position+offset*.45,span*.1).set_trans(Tween.TRANS_SINE)
			tween.tween_property(body,"position",base_position+offset,span*.1).set_trans(Tween.TRANS_SINE)
		tween.tween_property(body,"position",base_position,span*(.33 if action=="combo" else .53)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		set_action(action)
		tween.tween_property(body,"position",base_position+offset,span*.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(body,"position",base_position,span*.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if is_instance_valid(body):body.position=base_position;body.scale=Vector2.ONE;body.rotation=0
	if action not in ["windup","guard","phase"]:set_action("phase" if phase==2 else "idle")
	acting=false;key=-1
