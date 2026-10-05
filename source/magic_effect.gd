extends Sprite2D

var regions: Array=[]
var fps:=10.0
var elapsed:=0.0
var duration:=.6
var reverse:=false
var effect_id:=""
signal completed

func setup(game: Node2D, id: String, width: float, seconds: float=.6) -> bool:
	effect_id=id
	var spec: Dictionary=game.story_system.effects.get(id,{})
	if spec.is_empty():return false
	var art:=Image.load_from_file(game.battle_asset_root.path_join(str(spec["texture"]).trim_prefix("res://")))
	if art==null:return false
	art.generate_mipmaps();texture=ImageTexture.create_from_image(art)
	regions=spec["frame_regions"];fps=float(spec["fps"]);duration=seconds
	region_enabled=true;region_rect=Rect2(regions[0][0],regions[0][1],regions[0][2],regions[0][3])
	scale=Vector2.ONE*width/float(regions[0][2]);texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	z_index=20
	return true

func _process(delta: float) -> void:
	if regions.is_empty():return
	elapsed+=delta
	var index:=mini(regions.size()-1,int(elapsed*fps))
	var r: Array=regions[index];region_rect=Rect2(r[0],r[1],r[2],r[3])
	modulate.a=clampf((duration-elapsed)/.15,0,1)
	if elapsed>=duration:completed.emit();queue_free()
