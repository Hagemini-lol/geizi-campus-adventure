## 独立战斗子菜单：默认没有招式；未来数据驱动按钮，界面只发送选择信号。
extends PanelContainer

## 招式选择接口，不执行伤害、消耗、道具或战斗结算。
signal command_requested(category_id: StringName, command_id: StringName, payload: Dictionary)
## 返回操作类别，清除本次子菜单选中。
signal back_requested

const Style = preload("res://scripts/ui/ui_style.gd")
## 所属类别的稳定 ID，与显示文字分离。
@export var category_id: StringName = &"attack"
## 子菜单标题，可独立修改。
@export var category_title: String = "攻击"
## 具体招式的独立按钮场景，可替换以改变单个条目结构。
@export var command_button_scene: PackedScene = preload("res://scenes/ui/battle/components/command_button.tscn")
## 每行条目数；更多招式通过滚动展示。
@export_range(1, 6) var columns: int = 3
var entries: Array[Dictionary] = []
var command_buttons: Dictionary = {}
var back_button: Button
var empty_label: Label
var scroll: ScrollContainer
var grid: GridContainer

func _ready() -> void:
	theme = Style.theme(18)
	add_theme_stylebox_override("panel", Style.panel(0.46))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Style.label(category_title, 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	back_button = preload("res://scenes/ui/components/option_button.tscn").instantiate()
	back_button.option_text = "返回"
	back_button.option_id = &"back"
	back_button.font_size = 14
	header.add_child(back_button)
	back_button.custom_minimum_size = Vector2(72, 30)
	back_button.pressed.connect(func(): back_requested.emit())
	empty_label = Style.label("暂无可用选项", 16)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(empty_label)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	_refresh_entries()

## 原子更新条目；空列表合法，重复 ID 或缺少显示名时返回 false 并保留旧列表。
## 字段：id、label；可选 enabled(bool)、description(String)、payload(Dictionary)。
func set_entries(new_entries: Array[Dictionary]) -> bool:
	var seen := {}
	for entry in new_entries:
		if not (entry.get("id") is String or entry.get("id") is StringName):
			return false
		var id: String = str(entry["id"]).strip_edges()
		if id.is_empty() or seen.has(id) or not entry.get("label") is String or str(entry["label"]).strip_edges().is_empty():
			return false
		if entry.has("enabled") and not entry["enabled"] is bool:
			return false
		if entry.has("payload") and not entry["payload"] is Dictionary:
			return false
		seen[id] = true
	entries.assign(new_entries.duplicate(true))
	if is_instance_valid(grid):
		_refresh_entries()
	return true

func _refresh_entries() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	command_buttons.clear()
	empty_label.visible = entries.is_empty()
	scroll.visible = not entries.is_empty()
	for entry in entries:
		var button: Button = command_button_scene.instantiate()
		var command_id := StringName(str(entry["id"]).strip_edges())
		button.option_text = str(entry["label"])
		button.option_id = command_id
		button.font_size = 16
		button.disabled = not bool(entry.get("enabled", true))
		button.tooltip_text = str(entry.get("description", ""))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
		button.pressed.connect(_request_command.bind(command_id, entry))
		command_buttons[command_id] = button

func _request_command(command_id: StringName, entry: Dictionary) -> void:
	if not bool(entry.get("enabled", true)):
		return
	var payload: Dictionary = entry.get("payload", {})
	command_requested.emit(category_id, command_id, payload.duplicate(true))
