extends Node2D
var game: Node2D

func _ready() -> void:
	z_index=100

func _draw() -> void:
	if game == null or game.terrain == null or game.terrain.current_scene == null: return
	for body: Node in game.terrain.current_scene.get_children():
		if not body is StaticBody2D: continue
		for child: Node in body.get_children():
			if not child is CollisionShape2D or child.disabled: continue
			var color := Color(1,.25,.15,.25)
			var at: Vector2 = child.global_position
			if child.shape is RectangleShape2D:
				var half: Vector2=child.shape.size/2
				var outline:=PackedVector2Array()
				for corner: Vector2 in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)]: outline.append(child.to_global(corner))
				draw_colored_polygon(outline,color)
				outline.append(outline[0])
				draw_polyline(outline,Color(1,.3,.2),1.5,true)
			elif child.shape is CircleShape2D:
				draw_circle(at,child.shape.radius,Color(1,.55,.05,.7))
				draw_arc(at,child.shape.radius,0,TAU,24,Color(1,.8,.1),1.5,true)
			elif child.shape is ConvexPolygonShape2D:
				var points: PackedVector2Array=child.shape.points
				for i: int in range(points.size()): points[i]=child.to_global(points[i])
				draw_colored_polygon(points,color)
				points.append(points[0])
				draw_polyline(points,Color(1,.3,.2),1.5,true)
	if game.player != null and game.player.visible:
		draw_arc(game.player.position,game.player.RADIUS,0,TAU,32,Color.YELLOW,1.5,true)
		draw_line(game.player.position-Vector2(10,0),game.player.position+Vector2(10,0),Color.YELLOW,1)
		draw_line(game.player.position-Vector2(0,10),game.player.position+Vector2(0,10),Color.YELLOW,1)
