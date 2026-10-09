extends RefCounted

var sprite: Sprite2D
var texture: Texture2D
var height:=40.0
var facing:=0
var moving:=false
var phase:=0.0
var paint_key:=""
var frames_advanced:=0.0
var rate:=0.0
var ready:=false
func configure(root: String,entry: Dictionary,target: Sprite2D,body_height: float,_idle: Array[Texture2D]) -> bool:
	var source:=Image.load_from_file(root.path_join(str(entry["source"]).trim_prefix("res://")))
	if source==null:return false
	source.generate_mipmaps();texture=ImageTexture.create_from_image(source)
	sprite=target;height=body_height;ready=true;stop();return true
func face(value: int) -> void:facing=clampi(value,0,3);paint()
func stop() -> void:moving=false;phase=0;rate=0;paint()
func advance(delta: float,speed: float) -> void:
	if speed<=.01:stop();return
	moving=true;rate=minf(4.0,maxf(2.0,speed/12*3));phase=fposmod(phase+delta*rate,2);frames_advanced+=delta*rate;paint()
func paint() -> void:
	if not ready:return
	var row:=1+int(phase) if moving else 0
	var key:="%d/%d" % [row,facing]
	if key==paint_key:return
	paint_key=key
	var frame:=AtlasTexture.new();frame.atlas=texture;frame.region=Rect2(facing*128,row*160,128,160)
	sprite.texture=frame;sprite.centered=false;sprite.scale=Vector2.ONE*height/140
	sprite.offset=Vector2(-64,-156);sprite.rotation=0
