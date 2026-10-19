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
var frames: Array[Array]=[]
const STEP_CYCLE: Array[int]=[1,0,2,0]
func configure(root: String,entry: Dictionary,target: Sprite2D,body_height: float,_idle: Array[Texture2D]) -> bool:
	var source:=Image.load_from_file(root.path_join(str(entry["source"]).trim_prefix("res://")))
	if source==null:return false
	source.generate_mipmaps();texture=ImageTexture.create_from_image(source)
	sprite=target;height=body_height;frames.clear()
	for direction: int in range(4):
		var cells: Array=[]
		for row: int in range(3):
			var cell:=AtlasTexture.new();cell.atlas=texture;cell.region=Rect2(direction*128,row*160,128,160);cells.append(cell)
		frames.append(cells)
	ready=true;paint_key="";stop();return true
func face(value: int) -> void:
	var next:=clampi(value,0,3)
	if next==facing:return
	facing=next;paint()
func stop() -> void:
	if not moving and rate==0 and not paint_key.is_empty():return
	moving=false;phase=0;rate=0;paint()
func advance(delta: float,speed: float) -> void:
	if not ready or delta<=0:return
	if speed<=.01:stop();return
	moving=true;rate=minf(4.0,maxf(2.0,speed/12*3));phase=fposmod(phase+delta*rate,4);frames_advanced+=delta*rate;paint()
func paint() -> void:
	if not ready:return
	var row: int=STEP_CYCLE[int(phase)] if moving else 0
	var key:="%d/%d" % [row,facing]
	if key==paint_key:return
	paint_key=key
	sprite.texture=frames[facing][row];sprite.centered=false;sprite.scale=Vector2.ONE*height/140
	sprite.offset=Vector2(-64,-156);sprite.rotation=0
