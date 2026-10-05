## 共用战场内的独立人物层；透明立绘、地面影子和名称均不绑定背景。
extends Control

const Style = preload("res://scripts/ui/ui_style.gd")
@export var side_title: String = "敌方"
@export var combatant_name: String = ""
@export var portrait: Texture2D
## 我方示例默认使用斜后视角素材，正式战斗也可传入其它 Texture2D。
@export var use_project_hero: bool = false
var portrait_view: TextureRect
var placeholder: Label
var name_label: Label
## 姿势只覆盖显示层，portrait 始终保留进入战斗时的基础立绘。
var displayed_pose: Texture2D
var _trimmed_cache: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.theme(16)
	portrait_view = TextureRect.new()
	portrait_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_view.offset_bottom = -26
	portrait_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait_view)
	placeholder = Style.label("立绘占位", 14)
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	placeholder.offset_bottom = -26
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.modulate.a = 0.65
	add_child(placeholder)
	name_label = Style.label("", 16)
	name_label.anchor_top = 1.0
	name_label.anchor_bottom = 1.0
	name_label.anchor_right = 1.0
	name_label.offset_top = -24
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)
	if portrait == null and use_project_hero:
		portrait = load("res://assets/characters/hero/battle/zhao_mugei_rear_quarter.png")
	set_combatant(combatant_name, portrait)
	resized.connect(queue_redraw)

## 替换人物不会改变背景、布局或操作菜单；透明边缘在显示时自动裁紧。
func set_combatant(display_name: String, texture: Texture2D) -> void:
	combatant_name = display_name
	portrait = texture
	if not is_instance_valid(portrait_view):
		return
	name_label.text = side_title + (" · " + combatant_name if not combatant_name.is_empty() else "")
	set_pose(texture)
	queue_redraw()

## 用于攻击/闪避演出；缓存裁切区域，避免播放时反复扫描透明边缘。
func set_pose(texture: Texture2D) -> void:
	displayed_pose = texture
	if not is_instance_valid(portrait_view):
		return
	portrait_view.texture = _trim_display_texture(texture)
	portrait_view.visible = texture != null
	placeholder.visible = texture == null

func restore_pose() -> void:
	set_pose(portrait)

func _trim_display_texture(texture: Texture2D) -> Texture2D:
	if texture == null or texture is AtlasTexture:
		return texture
	if _trimmed_cache.has(texture):
		return _trimmed_cache[texture]
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	# 过滤生成图外围的极低透明度像素，避免立绘脚底浮在地面影子上方。
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
		return texture
	var region := Rect2i(first, last - first + Vector2i.ONE)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(region)
	_trimmed_cache[texture] = atlas
	return atlas

func _draw() -> void:
	# 影子随人物层缩放，明确近景与远景落脚位置。
	var foot := Vector2(size.x * 0.5, size.y - 27)
	var ellipse := PackedVector2Array()
	for i in range(40):
		var angle := TAU * float(i) / 40.0
		ellipse.append(foot + Vector2(cos(angle) * size.x * 0.26, sin(angle) * size.y * 0.026))
	draw_colored_polygon(ellipse, Color(0.02, 0.025, 0.03, 0.23))
	if displayed_pose == null:
		# 中性人形仅标记敌方位置，并非具体敌人素材。
		var center := size.x * 0.5
		draw_circle(Vector2(center, size.y * 0.18), size.y * 0.075, Color(0.68, 0.71, 0.70, 0.32))
		var body := PackedVector2Array([
			Vector2(center - size.x * 0.19, size.y * 0.30), Vector2(center + size.x * 0.19, size.y * 0.30),
			Vector2(center + size.x * 0.24, size.y * 0.56), Vector2(center + size.x * 0.12, size.y - 30),
			Vector2(center - size.x * 0.12, size.y - 30), Vector2(center - size.x * 0.24, size.y * 0.56)])
		draw_colored_polygon(body, Color(0.68, 0.71, 0.70, 0.24))
