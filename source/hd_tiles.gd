extends Node2D

class PreparedImage extends RefCounted:
	var path: String
	var density:=1
	var result: Image
	func run() -> void:
		result=Image.load_from_file(path)
		if result==null:return
		# Keep originals; three samples per world pixel suffice for 2..3x density.
		if density==3:result.resize(774,774,Image.INTERPOLATE_BILINEAR)
		result.generate_mipmaps()

const TILE_SIZE:=256.0
const MAX_JOBS:=2
const MAX_UPLOADS:=1
var manifest: Dictionary={}
var directory: String
var region_bounds:=Rect2()
var tiles: Dictionary={}
var active_bytes:=0
var peak_bytes:=0
var peak_jobs:=0
var lod:=0
var previous_rect:=Rect2()
var tile_rect:=Rect2i()
var pending: Dictionary={}
var wanted: Dictionary={}
var requests: Array[String]=[]
var viewport_rebuilds:=0
var idle_frames:=0

func _ready() -> void:
	z_index=-4
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _process(_delta: float) -> void:refresh()

func refresh() -> void:
	if manifest.is_empty():return
	var camera:=get_viewport().get_camera_2d()
	if camera==null:return
	var display_scale:=get_viewport().get_stretch_transform().get_scale().abs()
	var density:=camera.zoom.x*maxf(display_scale.x,display_scale.y)
	var next_lod:=clampi(ceili(density-.0001),1,4)
	var view_size:=get_viewport_rect().size/camera.zoom
	var view:=Rect2(camera.get_screen_center_position()-view_size*.5,view_size).grow(24).intersection(region_bounds)
	if not view.has_area():return
	var first:=Vector2i((view.position/TILE_SIZE).floor())
	var last:=Vector2i(((view.end-Vector2.ONE*.01)/TILE_SIZE).floor())
	var next_rect:=Rect2i(first,last-first+Vector2i.ONE)
	if next_rect!=tile_rect or next_lod!=lod:
		viewport_rebuilds+=1;tile_rect=next_rect;lod=next_lod;wanted={};requests=[]
		for y: int in range(first.y,last.y+1):
			for x: int in range(first.x,last.x+1):
				var key:=str(x)+"_"+str(y)
				if manifest["tiles"].has(key):wanted[key]=true
		# Free offscreen and obsolete-resolution textures before replacements.
		for key: String in tiles.keys():
			if not wanted.has(key) or int(tiles[key]["lod"])!=lod:
				active_bytes-=int(tiles[key]["bytes"]);tiles[key]["node"].free();tiles.erase(key)
		for key: String in wanted:
			if not tiles.has(key):requests.append(key)
		var center:=view.get_center()/TILE_SIZE
		requests.sort_custom(func(a: String,b: String) -> bool:
			return Vector2(float(a.get_slice("_",0))+.5,float(a.get_slice("_",1))+.5).distance_squared_to(center)<Vector2(float(b.get_slice("_",0))+.5,float(b.get_slice("_",1))+.5).distance_squared_to(center))
	elif pending.is_empty() and requests.is_empty():
		idle_frames+=1;return
	previous_rect=view
	var uploads:=0
	for job_key: String in pending.keys():
		var job: Dictionary=pending[job_key]
		if not WorkerThreadPool.is_task_completed(job["task"]):continue
		var key:=job_key.get_slice("@",0)
		var quality:=int(job_key.get_slice("@",1))
		var keep:=wanted.has(key) and quality==lod
		if keep and uploads>=MAX_UPLOADS:continue
		WorkerThreadPool.wait_for_task_completion(job["task"])
		var image: Image=job["worker"].result
		pending.erase(job_key)
		if not keep or image==null:continue
		var sprite:=Sprite2D.new();sprite.centered=false
		var atlas:=AtlasTexture.new();atlas.atlas=ImageTexture.create_from_image(image)
		atlas.region=Rect2(lod,lod,TILE_SIZE*lod,TILE_SIZE*lod);atlas.filter_clip=false
		sprite.texture=atlas
		var a: Array=manifest["tiles"][key]["world_pixels"]
		sprite.position=Vector2(a[0]+1,a[1]+1);sprite.scale=Vector2.ONE/float(lod)
		add_child(sprite)
		var byte_count:=image.get_data_size()
		tiles[key]={"node":sprite,"bytes":byte_count,"lod":lod}
		active_bytes+=byte_count;uploads+=1
	while pending.size()<MAX_JOBS and not requests.is_empty():
		var key: String=requests.pop_front()
		var job_key:=key+"@"+str(lod)
		if tiles.has(key) or pending.has(job_key):continue
		var worker:=PreparedImage.new();worker.density=lod
		worker.path=directory.path_join(manifest["tiles"][key]["images"][str(4 if lod==3 else lod)])
		pending[job_key]={"worker":worker,"task":WorkerThreadPool.add_task(worker.run)}
	peak_jobs=maxi(peak_jobs,pending.size());peak_bytes=maxi(peak_bytes,active_bytes)

func view_ready() -> bool:
	if wanted.is_empty():return false
	for key: String in wanted:
		if not tiles.has(key) or int(tiles[key]["lod"])!=lod:return false
	return true

func wait_for_view() -> void:
	var started:=Time.get_ticks_msec()
	while not view_ready() and Time.get_ticks_msec()-started<3000:
		refresh();await get_tree().process_frame

func _exit_tree() -> void:
	# Only two private decode jobs can remain after rapid camera movement.
	for job: Dictionary in pending.values():WorkerThreadPool.wait_for_task_completion(job["task"])
	pending.clear();requests.clear();wanted.clear();tiles.clear();active_bytes=0

