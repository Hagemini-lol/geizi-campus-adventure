extends Node2D

const Space = preload("res://map_space.gd")
const Region = preload("res://map_region.tscn")
var map_texture: Texture2D
var active: Dictionary = {}
var current := Vector2i(-1, -1)
var transition_count := 0

func update_position(at: Vector2) -> void:
	var destination := Space.region_at(at)
	if current == destination: return
	current = destination
	transition_count += 1
	var needed: Array[Vector2i] = []
	for x: int in range(maxi(0, current.x - 1), mini(3, current.x + 1) + 1):
		for y: int in range(maxi(0, current.y - 1), mini(3, current.y + 1) + 1):
			needed.append(Vector2i(x, y))
	for id: Vector2i in active.keys():
		if not needed.has(id):
			remove_child(active[id])
			active[id].queue_free()
			active.erase(id)
	for id: Vector2i in needed:
		if not active.has(id):
			var region := Region.instantiate()
			region.index = id
			region.map_texture = map_texture
			add_child(region)
			active[id] = region
