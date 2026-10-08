extends RefCounted

# All frames in a boss atlas share ONE GPU texture; AtlasTexture only stores
# a region. Per-battle cache is released on close. Idle changes at 3 fps;
# action poses use at most six visual keys a second with tweened motion.
var frames: Array[Texture2D]=[]
var poses: Dictionary={}
var view: Control
var base_position:=Vector2.ZERO
var base_scale:=Vector2.ONE
var elapsed:=0.0
var key:=-1
var acting:=false
var phase:=1

func configure(root: String, spec: Dictionary, target: Control) -> bool:
	view=target;base_position=target.position;base_scale=target.scale
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
		var texture:=AtlasTexture.new();texture.atlas=sheet
		texture.region=Rect2((i%int(metadata["columns"]))*int(cell[0]),(i/int(metadata["columns"]))*int(cell[1]),int(cell[0]),int(cell[1]))
		frames.append(texture)
	poses=metadata["poses"]
	return true

func texture(action: String, index: int=0) -> Texture2D:
	var sequence: Array=poses.get(action,[0])
	return frames[int(sequence[index%sequence.size()])] if not frames.is_empty() else null

func tick(delta: float) -> void:
	if frames.is_empty() or acting or not is_instance_valid(view):return
	elapsed+=delta
	var next:=int(elapsed*3.0)%2
	if next!=key:
		key=next
		view.set_pose(texture("phase" if phase==2 else "idle",next))

func play(action: String, seconds: float=.36) -> void:
	if not is_instance_valid(view):return
	acting=true
	if not frames.is_empty():view.set_pose(texture(action))
	var direction:=1.0 if action=="hit" else -1.0
	var tween:=view.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(view,"position",base_position+Vector2(14*direction,-3 if action=="attack" else 0),seconds*.45)
	tween.tween_property(view,"position",base_position,seconds*.55)
	await tween.finished
	acting=false;key=-1
