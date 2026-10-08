extends RefCounted

const BASE_SPEED:=100.8 # 4.2 m/s in world pixels.
const BASE_FPS:=4.0
const DIRECTIONS: Array[String]=["front","back","left","right"]
var ready:=false
var sprite: Sprite2D
var idle: Array[Texture2D]=[]
var poses: Array[Array]=[]
var height:=40.8
var foot_bias:=0.0
var facing:=0
var phase:=0.0
var rate:=0.0
var moving:=false
var displayed_frame:=-1
var frames_advanced:=0.0
var paint_key:=""

func configure(root: String, entry: Dictionary, target: Sprite2D, body_height: float, standing: Array[Texture2D], bias: float=0.0) -> bool:
	ready=false;poses.clear();idle=standing;sprite=target;height=body_height;foot_bias=bias
	var source:=Image.load_from_file(root.path_join(str(entry.get("source","")).trim_prefix("res://")))
	if source==null or not entry.get("source_regions") is Dictionary or idle.size()!=4:return false
	for direction: String in DIRECTIONS:
		var reference:=Image.load_from_file(root.path_join("assets/characters/runtime/"+str(entry["id"])+"/"+direction+".png"))
		if reference==null:return false
		var target_head:=head_center(reference)
		var steps: Array=[]
		for step: String in ["a","b"]:
			var values: Array=entry["source_regions"][direction][step]
			var box:=Rect2i(int(values[0]),int(values[1]),int(values[2]),int(values[3]))
			if not Rect2i(Vector2i.ZERO,source.get_size()).encloses(box):return false
			var crop:=source.get_region(box)
			var anchor:=Vector2(head_center(crop)+(64.0-target_head)*crop.get_height()/float(entry["height_px"]),crop.get_height())
			crop.generate_mipmaps()
			steps.append({"texture":ImageTexture.create_from_image(crop),"anchor":anchor})
		poses.append(steps)
	ready=true;paint_key="";stop();return true

func head_center(image: Image) -> float:
	var bounds:=image.get_used_rect()
	var head:=image.get_region(Rect2i(0,bounds.position.y,image.get_width(),maxi(1,roundi(bounds.size.y*.24)))).get_used_rect()
	return head.get_center().x

func face(direction: int) -> void:
	facing=clampi(direction,0,3)
	paint()

func stop() -> void:
	phase=0;rate=0;moving=false;displayed_frame=-1
	paint()

func advance(delta: float, actual_speed: float) -> void:
	if not ready:return
	if actual_speed<=.01 or delta<=0:
		stop();return
	moving=true;rate=minf(8.0,BASE_FPS*actual_speed/BASE_SPEED)
	var advance_by:=rate*delta
	frames_advanced+=advance_by
	phase=fposmod(phase+advance_by,2.0)
	displayed_frame=int(floor(phase))
	paint()

func paint() -> void:
	if not ready:return
	var key: String="%d/%d" % [facing,displayed_frame]
	if key==paint_key:return
	paint_key=key
	var texture: Texture2D=idle[facing]
	var anchor:=Vector2(texture.get_width()*.5,texture.get_height())
	if moving and displayed_frame>=0:
		texture=poses[facing][displayed_frame]["texture"]
		anchor=poses[facing][displayed_frame]["anchor"]
	var factor:=height/texture.get_height()
	sprite.texture=texture;sprite.centered=true;sprite.rotation=0
	sprite.scale=Vector2.ONE*factor
	sprite.offset=Vector2(texture.get_size())*.5-anchor+Vector2(0,foot_bias/factor)
