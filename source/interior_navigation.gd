extends RefCounted

var astar := AStarGrid2D.new()
var obstacles: Array[Rect2] = []
var floor_polygon := PackedVector2Array()
var extent := Vector2.ZERO
const RADIUS := 7.2
const CLEARANCE := RADIUS + 0.1 # CharacterBody's 0.08 physics recovery margin.
var cell_size := 3.6

func configure(dimensions: Vector2, polygon: PackedVector2Array, boxes: Array[Rect2], step: float=3.6) -> void:
	cell_size=step
	extent=dimensions
	floor_polygon=polygon
	obstacles=boxes
	astar.region=Rect2i(Vector2i.ZERO,Vector2i((dimensions/cell_size).ceil()))
	astar.cell_size=Vector2.ONE*cell_size
	astar.offset=Vector2.ONE*cell_size*.5
	astar.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y: int in range(astar.region.size.y):
		for x: int in range(astar.region.size.x):
			var cell:=Vector2i(x,y)
			astar.set_point_solid(cell,not walkable(astar.get_point_position(cell)))

func region_at(at: Vector2) -> int:
	return 0 if Rect2(Vector2.ZERO,extent).has_point(at) else -1

func walkable(at: Vector2, radius: float=CLEARANCE) -> bool:
	if not Geometry2D.is_point_in_polygon(at,floor_polygon): return false
	for i: int in range(floor_polygon.size()):
		var nearest:=Geometry2D.get_closest_point_to_segment(at,floor_polygon[i],floor_polygon[(i+1)%floor_polygon.size()])
		if nearest.distance_to(at)<radius: return false
	for box: Rect2 in obstacles:
		if box.grow(radius).has_point(at): return false
	return true

func segment_clear(from: Vector2, to: Vector2) -> bool:
	if not walkable(from) or not walkable(to):return false
	# These floor polygons are convex; their inset keeps the complete segment
	# inside when both endpoints are clear. Test furniture analytically so a
	# narrow corner crossing cannot fall between discrete path samples.
	var delta:=to-from
	for obstacle: Rect2 in obstacles:
		var box:=obstacle.grow(CLEARANCE)
		var enter:=0.0
		var leave:=1.0
		var separated:=false
		for axis: int in range(2):
			if absf(delta[axis])<.00001:
				if from[axis]<box.position[axis] or from[axis]>box.end[axis]:separated=true;break
			else:
				var a: float=(box.position[axis]-from[axis])/delta[axis]
				var b: float=(box.end[axis]-from[axis])/delta[axis]
				enter=maxf(enter,minf(a,b))
				leave=minf(leave,maxf(a,b))
				if enter>leave:separated=true;break
		if not separated:return false
	return true

func closest_cell(at: Vector2) -> Vector2i:
	var center:=Vector2i((at/cell_size).floor())
	var best:=Vector2i(-1,-1)
	var distance:=INF
	for y: int in range(-3,4):
		for x: int in range(-3,4):
			var cell:=center+Vector2i(x,y)
			if not astar.is_in_boundsv(cell) or astar.is_point_solid(cell): continue
			var p:=astar.get_point_position(cell)
			if p.distance_to(at)<distance and segment_clear(at,p):
				best=cell
				distance=p.distance_to(at)
	return best

func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not walkable(to): return PackedVector2Array()
	var start:=closest_cell(from)
	var finish:=closest_cell(to)
	if start.x<0 or finish.x<0: return PackedVector2Array()
	var result:=astar.get_point_path(start,finish)
	if not result.is_empty(): result.append(to)
	if result.is_empty():return result
	# Remove unnecessary grid waypoints so the 5x speed is attainable indoors.
	var smooth:=PackedVector2Array()
	var previous:=from
	var cursor:=0
	while cursor<result.size():
		var finish_index:=cursor
		while finish_index+1<result.size() and segment_clear(previous,result[finish_index+1]): finish_index+=1
		smooth.append(result[finish_index])
		previous=result[finish_index]
		cursor=finish_index+1
	return smooth
