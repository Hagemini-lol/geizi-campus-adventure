## 战斗立绘槽：只负责展示我方或敌方，可替换人物名称与 Texture2D/AtlasTexture。
extends PanelContainer

const Style = preload("res://scripts/ui/ui_style.gd")
## 我方/敌方的显示标题。
@export var side_title: String = "我方"
## 角色名称；留空时显示未指定角色。
@export var combatant_name: String = ""
## 单张立绘或图集区域；不会自动生成敌方角色。
@export var portrait: Texture2D
## 我方示例可引用项目现有主角，敌方示例保持空位。
@export var use_project_hero: bool = false
var name_label: Label
var portrait_view: TextureRect
var placeholder: Label

func _ready() -> void:
	theme = Style.theme(18)
	var panel_style := Style.panel(0.20)
	panel_style.border_color.a = 0.32
	add_theme_stylebox_override("panel", panel_style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var side_label := Style.label(side_title, 18)
	side_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(side_label)
	name_label = Style.label("", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var portrait_area := Control.new()
	portrait_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait_area)
	portrait_view = TextureRect.new()
	portrait_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_area.add_child(portrait_view)
	placeholder = Style.label("立绘占位", 18)
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.modulate.a = 0.55
	portrait_area.add_child(placeholder)
	if portrait == null and use_project_hero:
		portrait = _hero_front()
	set_combatant(combatant_name, portrait)

## 名称和立绘可在战斗进入时更新；texture 留空时保留独立占位。
func set_combatant(display_name: String, texture: Texture2D) -> void:
	combatant_name = display_name
	portrait = texture
	if not is_instance_valid(portrait_view):
		return
	name_label.text = combatant_name if not combatant_name.is_empty() else "未指定角色"
	portrait_view.texture = portrait
	portrait_view.visible = portrait != null
	placeholder.visible = portrait == null

func _hero_front() -> AtlasTexture:
	var source := preload("res://assets/characters/hero/zhao_mugei.png")
	var cell := source.get_image().get_region(Rect2i(Vector2i.ZERO, Vector2i(source.get_size() * 0.5)))
	var first := cell.get_size()
	var last := Vector2i(-1, -1)
	for y in range(cell.get_height()):
		for x in range(cell.get_width()):
			if cell.get_pixel(x, y).a >= 0.5:
				first.x = mini(first.x, x)
				first.y = mini(first.y, y)
				last.x = maxi(last.x, x)
				last.y = maxi(last.y, y)
	var region := Rect2i(Vector2i.ZERO, cell.get_size())
	if last.x >= 0:
		region = Rect2i(first - Vector2i.ONE, last - first + Vector2i(3, 3)).intersection(region)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(region)
	return atlas
