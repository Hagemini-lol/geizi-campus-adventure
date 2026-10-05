extends RefCounted

const PPM := 24.0
var astar := AStarGrid2D.new()
var model: Dictionary
var regions: Array
var gate_pairs: Dictionary = {}

func configure(value: Dictionary) -> void:
	model = value
	regions = model["regions"]
	astar.region = Rect2i(0,0,320,360)
	astar.cell_size = Vector2.ONE * PPM
	astar.offset = Vector2.ONE * PPM * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	var mask: String = model["blocked"]
	for y: int in range(360):
		for x: int in range(320):
			if mask[y*320+x] == "1": astar.set_point_solid(Vector2i(x,y))
	for gate: Array in model["gates"]:
		var a := int(gate[0])
		var b := int(gate[1])
		var key := Vector2i(mini(a,b),maxi(a,b))
		if not gate_pairs.has(key): gate_pairs[key] = []
		gate_pairs[key].append(Vector2(gate[2],gate[3])*PPM)

func region_at(at: Vector2) -> int:
	var meters := at / PPM
	for index: int in range(regions.size()):
		for values: Array in regions[index]["world_areas"]:
			if Rect2(values[0],values[1],values[2],values[3]).has_point(meters): return index
	return -1

func can_cross(from_id: int, to_id: int, at: Vector2) -> bool:
	var cell:=Vector2i((at/PPM).floor())
	if not astar.is_in_boundsv(cell) or astar.is_point_solid(cell) or model["roads"][cell.y*320+cell.x]!="1" or not walkable(at): return false
	var key := Vector2i(mini(from_id,to_id),maxi(from_id,to_id))
	for gate: Vector2 in gate_pairs.get(key,[]):
		if at.distance_to(gate) < .85*PPM: return true
	return false

func walkable(at: Vector2, radius: float=.3) -> bool:
	var p:=at/PPM
	if p.x<radius or p.y<radius or p.x>320-radius or p.y>360-radius: return false
	for a: Array in model["solids"]:
		if Rect2(a[0],a[1],a[2],a[3]).grow(radius).has_point(p): return false
	for a: Array in model.get("ellipses",[]):
		var center:=Vector2(a[0]+a[2]/2,a[1]+a[3]/2)
		var ratio: Vector2=(p-center)/(Vector2(a[2],a[3])/2+Vector2.ONE*radius)
		if ratio.length_squared()<=1: return false
	for tree: Array in model["trees"]:
		if p.distance_to(Vector2(tree[0],tree[1]))<.175+radius: return false
	return true

func segment_clear(from: Vector2, to: Vector2) -> bool:
	var samples:=maxi(1,int(ceil(from.distance_to(to)/(.15*PPM))))
	for i: int in range(samples+1):
		if not walkable(from.lerp(to,float(i)/samples)): return false
	return true

func closest_cell(at: Vector2) -> Vector2i:
	var cell := Vector2i((at / PPM).floor())
	if not astar.is_in_boundsv(cell): return Vector2i(-1,-1)
	var best := Vector2i(-1,-1)
	var distance := INF
	for y: int in range(-2,3):
		for x: int in range(-2,3):
			var candidate := cell+Vector2i(x,y)
			if astar.is_in_boundsv(candidate) and not astar.is_point_solid(candidate) and segment_clear(at,astar.get_point_position(candidate)):
				var actual := astar.get_point_position(candidate).distance_to(at)
				if actual < distance:
					distance=actual
					best=candidate
	return best

func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	if region_at(to) < 0 or not walkable(to): return PackedVector2Array()
	var start := closest_cell(from)
	var finish := closest_cell(to)
	if start.x < 0 or finish.x < 0: return PackedVector2Array()
	var path := astar.get_point_path(start,finish)
	if not path.is_empty() and not astar.is_point_solid(Vector2i((to/PPM).floor())):
		path.append(to)
	return path
