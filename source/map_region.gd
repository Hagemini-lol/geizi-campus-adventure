extends Node2D

const Space = preload("res://map_space.gd")
var index := Vector2i.ZERO
var map_texture: Texture2D

func _ready() -> void:
	name = "Region_%d_%d" % [index.x + 1, index.y + 1]
	var region := Rect2(Vector2(index.x * 80, index.y * 90) * Space.PIXELS_PER_METER, Vector2(80, 90) * Space.PIXELS_PER_METER)
	# Each region uses shared texture slices. Piecewise scale preserves the stated
	# campus / track / football dimensions without creating or copying PNG files.
	for x: int in range(Space.SOURCE_X.size() - 1):
		for y: int in range(Space.SOURCE_Y.size() - 1):
			var source := Rect2(Vector2(Space.SOURCE_X[x], Space.SOURCE_Y[y]), Vector2(Space.SOURCE_X[x + 1] - Space.SOURCE_X[x], Space.SOURCE_Y[y + 1] - Space.SOURCE_Y[y]))
			var world := Space.box_to_world(source)
			if not world.intersects(region): continue
			var clipped := world.intersection(region)
			var source_clip := Rect2(Space.unproject(clipped.position), Space.unproject(clipped.end) - Space.unproject(clipped.position))
			var texture := AtlasTexture.new()
			texture.atlas = map_texture
			texture.region = source_clip
			texture.filter_clip = true
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = false
			sprite.position = clipped.position
			sprite.scale = clipped.size / source_clip.size
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(sprite)
