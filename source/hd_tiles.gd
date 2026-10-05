extends Node2D

class PreparedImage extends RefCounted:
	var path: String
	var result: Image
	func run() -> void:
		result=Image.load_from_file(path)
		if result!=null:result.generate_mipmaps()

var manifest: Dictionary={}
var directory: String
var region_bounds:=Rect2()
var tiles: Dictionary={}
var active_bytes:=0
var peak_bytes:=0
var lod:=0
var previous_rect:=Rect2()
var pending: Dictionary={}
var wanted: Dictionary={}
const TILE_SIZE:=256.0

func _ready() -> void:
	z_index=-4
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _process(_delta: float) -> void: refresh()

func refresh() -> void:
	if manifest.is_empty():return
	var camera:=get_viewport().get_camera_2d()
	if camera==null:return
	var display_scale:=get_viewport().get_stretch_transform().get_scale().abs()
	var density:=camera.zoom.x*maxf(display_scale.x,display_scale.y)
	var next_lod:=1 if density<=1 else (2 if density<=2 else 4)
	var view_size:=get_viewport_rect().size/camera.zoom
	var view:=Rect2(camera.get_screen_center_position()-view_size*.5,view_size).grow(40)
	view=view.intersection(region_bounds)
	if not view.has_area():return
	wanted={}
	var first:=Vector2i((view.position/TILE_SIZE).floor())
	var last:=Vector2i(((view.end-Vector2.ONE*.01)/TILE_SIZE).floor())
	for y: int in range(first.y,last.y+1):
		for x: int in range(first.x,last.x+1):
			var key:=str(x)+"_"+str(y)
			if manifest["tiles"].has(key):wanted[key]=true
	# Release old tiles before creating replacements, including a LOD change.
	for key: String in tiles.keys():
		if not wanted.has(key):
			active_bytes-=int(tiles[key]["bytes"])
			tiles[key]["node"].free()
			tiles.erase(key)
	lod=next_lod
	var uploads:=0
	for key: String in wanted:
		if tiles.has(key) and int(tiles[key]["lod"])==lod:continue
		var entry: Dictionary=manifest["tiles"][key]
		var job_key:=key+"@"+str(lod)
		if not pending.has(job_key):
			var worker:=PreparedImage.new()
			worker.path=directory.path_join(entry["images"][str(lod)])
			pending[job_key]={"worker":worker,"task":WorkerThreadPool.add_task(worker.run)}
		if uploads>=4 or not WorkerThreadPool.is_task_completed(pending[job_key]["task"]):continue
		WorkerThreadPool.wait_for_task_completion(pending[job_key]["task"])
		var image: Image=pending[job_key]["worker"].result
		pending.erase(job_key)
		if image==null:continue
		if tiles.has(key):
			active_bytes-=int(tiles[key]["bytes"])
			tiles[key]["node"].free()
			tiles.erase(key)
		var sprite:=Sprite2D.new()
		sprite.centered=false
		var atlas:=AtlasTexture.new()
		atlas.atlas=ImageTexture.create_from_image(image)
		atlas.region=Rect2(lod,lod,TILE_SIZE*lod,TILE_SIZE*lod)
		atlas.filter_clip=false
		sprite.texture=atlas
		var a: Array=entry["world_pixels"]
		sprite.position=Vector2(a[0]+1,a[1]+1)
		sprite.scale=Vector2.ONE/float(lod)
		add_child(sprite)
		var byte_count:=image.get_data_size()
		tiles[key]={"node":sprite,"bytes":byte_count,"lod":lod}
		active_bytes+=byte_count
		uploads+=1
	# Completed offscreen jobs are discarded; retain no global texture cache.
	for job_key: String in pending.keys():
		var key:=job_key.get_slice("@",0)
		var quality:=int(job_key.get_slice("@",1))
		if (not wanted.has(key) or quality!=lod) and WorkerThreadPool.is_task_completed(pending[job_key]["task"]):
			WorkerThreadPool.wait_for_task_completion(pending[job_key]["task"])
			pending.erase(job_key)
	peak_bytes=maxi(peak_bytes,active_bytes)
	previous_rect=view

func view_ready() -> bool:
	if wanted.is_empty():return false
	for key: String in wanted:
		if not tiles.has(key) or int(tiles[key]["lod"])!=lod:return false
	return true

func wait_for_view() -> void:
	var started:=Time.get_ticks_msec()
	while not view_ready() and Time.get_ticks_msec()-started<3000:
		refresh()
		await get_tree().process_frame

func _exit_tree() -> void:
	# Workers own only immutable file paths and private Image objects. Complete
	# them before releasing this scene so task bookkeeping cannot accumulate.
	for job: Dictionary in pending.values():WorkerThreadPool.wait_for_task_completion(job["task"])
	pending.clear()
