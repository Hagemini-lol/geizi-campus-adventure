## 回合制战斗界面框架：中上部双方立绘，下部操作类别和独立子菜单，不处理战斗规则。
extends Control

## 打开操作类别的通知。
signal category_opened(category_id: StringName)
## 返回类别选择状态的通知。
signal categories_restored
## 提交具体条目的 UI 选择；未来由战斗系统处理。
signal action_selected(category_id: StringName, command_id: StringName, payload: Dictionary)

const Style = preload("res://scripts/ui/ui_style.gd")
## 六个类别和空招式列表的配置文件；可以扩充类别并替换按钮或子菜单场景。
@export_file("*.json") var catalog_path: String = "res://data/battle_ui_library.json"
## UI 显示的回合数，未来由战斗系统提供。
@export var round_number: int = 1
## UI 显示的当前阶段，未来由战斗系统提供。
@export var phase_text: String = "我方行动"
## 是否允许选择操作；敌方回合可关闭输入。
@export var input_enabled: bool = true
## 共用战场背景；编辑器可指定素材，也可在运行时用 set_battle_background 切换。
@export var battle_background: Texture2D
var ally_slot: Control
var enemy_slot: Control
var category_buttons: Dictionary = {}
var submenus: Dictionary = {}
var selected_category: StringName = &""
var turn_label: Label
var stage: Control
var dock: VBoxContainer
var category_grid: GridContainer
var submenu_host: PanelContainer
var idle_label: Label
var button_group: ButtonGroup
## 仅负责姿势与特效，未来战斗规则可直接调用其播放接口。
var action_presenter: Node

func _ready() -> void:
	theme = Style.theme(18)
	turn_label = Style.label("", 16)
	turn_label.anchor_left = 0.30
	turn_label.anchor_right = 0.70
	turn_label.anchor_top = 0.015
	turn_label.offset_bottom = 28
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(turn_label)
	stage = preload("res://scenes/ui/battle/components/battle_stage.tscn").instantiate()
	stage.name = "UISharedBattleStage"
	stage.background_texture = battle_background
	stage.anchor_left = 0.03
	stage.anchor_right = 0.97
	stage.anchor_top = 0.07
	stage.anchor_bottom = 0.62
	add_child(stage)
	ally_slot = stage.ally_slot
	enemy_slot = stage.enemy_slot
	dock = VBoxContainer.new()
	dock.anchor_left = 0.03
	dock.anchor_right = 0.97
	dock.anchor_top = 0.66
	dock.anchor_bottom = 0.97
	dock.add_theme_constant_override("separation", 8)
	add_child(dock)
	category_grid = GridContainer.new()
	category_grid.columns = 6
	category_grid.add_theme_constant_override("h_separation", 8)
	category_grid.add_theme_constant_override("v_separation", 6)
	dock.add_child(category_grid)
	button_group = ButtonGroup.new()
	button_group.allow_unpress = true
	submenu_host = PanelContainer.new()
	submenu_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	submenu_host.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	dock.add_child(submenu_host)
	idle_label = Style.label("请选择操作", 16)
	idle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	idle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	idle_label.modulate.a = 0.65
	submenu_host.add_child(idle_label)
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if catalog is Dictionary:
		for definition in catalog.get("categories", []):
			if not definition is Dictionary:
				continue
			var id := StringName(str(definition.get("id", "")))
			var button_scene = load(str(definition.get("button_scene", "")))
			var submenu_scene = load(str(definition.get("submenu_scene", "")))
			if button_scene is PackedScene and submenu_scene is PackedScene:
				add_category(id, str(definition.get("label", "")), button_scene, submenu_scene)
				var configured_entries: Array[Dictionary] = []
				for entry in definition.get("commands", []):
					if entry is Dictionary:
						configured_entries.append(entry)
				set_category_entries(id, configured_entries)
	_sync_layout()
	resized.connect(_sync_layout)
	set_turn_state(round_number, phase_text, input_enabled)
	action_presenter = preload("res://scenes/ui/battle/effects/action_presenter.tscn").instantiate()
	action_presenter.stage = stage
	add_child(action_presenter)
	category_opened.connect(_on_category_presentation)

func _on_category_presentation(category_id: StringName) -> void:
	if category_id == &"auto_battle":
		action_presenter.play_auto_battle()

## 可以新增独立类别；不提供场景时复用通用按钮与通用空子菜单。
func add_category(category_id: StringName, label: String, button_scene: PackedScene = null, submenu_scene: PackedScene = null) -> bool:
	if category_id == &"" or category_buttons.has(category_id) or label.strip_edges().is_empty():
		return false
	var button_source: PackedScene = button_scene if button_scene != null else preload("res://scenes/ui/components/option_button.tscn")
	var submenu_source: PackedScene = submenu_scene if submenu_scene != null else preload("res://scenes/ui/battle/components/submenu.tscn")
	var button: Button = button_source.instantiate()
	button.option_text = label
	button.option_id = category_id
	button.font_size = 20
	button.toggle_mode = true
	button.button_group = button_group
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not input_enabled
	category_grid.add_child(button)
	button.pressed.connect(open_category.bind(category_id))
	category_buttons[category_id] = button
	var submenu: PanelContainer = submenu_source.instantiate()
	submenu.category_id = category_id
	submenu.category_title = label
	submenu_host.add_child(submenu)
	submenu.hide()
	submenu.back_requested.connect(return_to_categories)
	submenu.command_requested.connect(_on_command_requested)
	submenus[category_id] = submenu
	return true

## 打开指定子菜单；选中状态与显示同步，任何时候仅显示一页。
func open_category(category_id: StringName) -> bool:
	if not input_enabled or not submenus.has(category_id):
		return false
	selected_category = category_id
	idle_label.hide()
	for id in submenus:
		submenus[id].visible = id == category_id
		category_buttons[id].button_pressed = id == category_id
	category_opened.emit(category_id)
	return true

## 返回类别选择；主类别按钮始终保留，当前子菜单隐藏。
func return_to_categories() -> void:
	selected_category = &""
	idle_label.show()
	for id in submenus:
		submenus[id].hide()
		category_buttons[id].button_pressed = false
	categories_restored.emit()

## 数据接口：以后为任意类别加入条目；当前六份配置均为空。
func set_category_entries(category_id: StringName, entries: Array[Dictionary]) -> bool:
	if not submenus.has(category_id):
		return false
	return submenus[category_id].set_entries(entries)

## 替换战场环境，人物与菜单保持当前状态；null 恢复默认占位背景。
func set_battle_background(texture: Texture2D) -> void:
	battle_background = texture
	if is_instance_valid(stage):
		stage.set_background(texture)

## 敌方回合或结算时可禁止 UI 输入；不会自动改变战斗状态。
func set_input_enabled(allowed: bool) -> void:
	input_enabled = allowed
	for button in category_buttons.values():
		button.disabled = not allowed
	if not allowed:
		return_to_categories()

## 更新回合/阶段文字与可输入状态，由未来的战斗控制器调用。
func set_turn_state(turn: int, phase: String, allowed: bool) -> void:
	round_number = maxi(turn, 1)
	phase_text = phase
	if is_instance_valid(turn_label):
		turn_label.text = "第%d回合 · %s" % [round_number, phase_text]
	set_input_enabled(allowed)

func _on_command_requested(category_id: StringName, command_id: StringName, payload: Dictionary) -> void:
	if input_enabled and selected_category == category_id:
		action_selected.emit(category_id, command_id, payload.duplicate(true))

func _sync_layout() -> void:
	if not is_instance_valid(dock):
		return
	var compact := size.x < 900
	category_grid.columns = 3 if compact else 6
	stage.anchor_bottom = 0.51 if compact else 0.62
	dock.anchor_top = 0.56 if compact else 0.66
