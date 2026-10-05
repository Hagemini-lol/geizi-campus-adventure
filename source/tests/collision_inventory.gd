extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node2D=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await physics_frame
	for index: int in range(20):
		game.load_district(index)
		await physics_frame
		var shapes: Array=[]
		for body: Node in game.terrain.current_scene.get_children():
			if not body is StaticBody2D: continue
			var collision: CollisionShape2D=body.get_child(0)
			if collision.shape is RectangleShape2D:
				shapes.append([body.position.x/24,body.position.y/24,collision.shape.size.x/24,collision.shape.size.y/24])
		print("SHAPES ",game.model["regions"][index]["id"]," ",JSON.stringify(shapes))
	quit()
