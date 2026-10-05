## [素材用途] 独立角色人像组件：可替换贴图；默认取现有主角图集的正面区域，不改写原始图片。
extends PanelContainer

const Style = preload("res://scripts/ui/ui_style.gd")
## 角色贴图或图集区域；留空使用现有主角正面。
@export var portrait: Texture2D
## 人像面板标题，默认角色。
@export var title: String = "角色"
var portrait_view: TextureRect

func _ready() -> void:
	theme = Style.theme(20)
	add_theme_stylebox_override("panel", Style.panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	column.add_child(Style.label(title, 20))
	portrait_view = TextureRect.new()
	portrait_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait_view)
	if portrait == null:
		var atlas := AtlasTexture.new()
		atlas.atlas = preload("res://assets/characters/hero/zhao_mugei.png")
		var front_cell := atlas.atlas.get_image().get_region(Rect2i(Vector2i.ZERO, Vector2i(atlas.atlas.get_size() * 0.5)))
		atlas.region = Rect2(_portrait_bounds(front_cell))
		portrait = atlas
	portrait_view.texture = portrait

## 替换人物贴图，可传入单张人像或 AtlasTexture。
func set_portrait(texture: Texture2D) -> void:
	portrait = texture
	if is_instance_valid(portrait_view):
		portrait_view.texture = texture

## 忽略低透明度杂点，找到正面角色范围以便按面板尺寸显示。
func _portrait_bounds(image: Image) -> Rect2i:
	var first := image.get_size()
	var last := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a >= 0.5:
				first.x = mini(first.x, x)
				first.y = mini(first.y, y)
				last.x = maxi(last.x, x)
				last.y = maxi(last.y, y)
	if last.x < 0:
		return Rect2i(Vector2i.ZERO, image.get_size())
	return Rect2i(first - Vector2i.ONE, last - first + Vector2i(3, 3)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
