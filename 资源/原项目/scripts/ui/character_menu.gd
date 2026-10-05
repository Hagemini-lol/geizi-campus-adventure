## [素材用途] 可扩展角色菜单：人像与信息固定，五个页签切换共享内容区；允许新增或替换内容页。
extends Control

## 页签切换通知，参数为页签逻辑标识。
signal tab_changed(tab_id: String)
## 设置操作接口：save / load / exit / unstuck；接游戏逻辑后才执行对应行为。
signal settings_action_requested(action: StringName)
## 请求关闭菜单；由上层控制菜单显示状态。
signal close_requested

const Style = preload("res://scripts/ui/ui_style.gd")
const TabScenes := {
	"status": preload("res://scenes/ui/options/status_button.tscn"),
	"equipment": preload("res://scenes/ui/options/equipment_button.tscn"),
	"items": preload("res://scenes/ui/options/items_button.tscn"),
	"skills": preload("res://scenes/ui/options/skills_button.tscn"),
	"settings": preload("res://scenes/ui/options/settings_button.tscn")
}
const PageScenes := {
	"status": preload("res://scenes/ui/pages/status_page.tscn"),
	"equipment": preload("res://scenes/ui/pages/equipment_page.tscn"),
	"items": preload("res://scenes/ui/pages/items_page.tscn"),
	"skills": preload("res://scenes/ui/pages/skills_page.tscn"),
	"settings": preload("res://scenes/ui/pages/settings_page.tscn")
}
var information: PanelContainer
var portrait_panel: PanelContainer
var tabs: Dictionary = {}
var pages: Dictionary = {}
var selected_tab: String = "status"
var tab_row: HBoxContainer
var content_panel: PanelContainer
var button_group: ButtonGroup

func _ready() -> void:
	theme = Style.theme(18)
	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.anchor_left = 0.06
	columns.anchor_top = 0.08
	columns.anchor_right = 0.94
	columns.anchor_bottom = 0.92
	columns.add_theme_constant_override("separation", 12)
	add_child(columns)
	portrait_panel = preload("res://scenes/ui/components/portrait_panel.tscn").instantiate()
	portrait_panel.custom_minimum_size = Vector2(240, 0)
	columns.add_child(portrait_panel)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)
	information = preload("res://scenes/ui/components/information_panel.tscn").instantiate()
	information.font_size = 20
	information.bar_height = 12
	information.show_date = false
	right.add_child(information)
	tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	right.add_child(tab_row)
	button_group = ButtonGroup.new()
	content_panel = PanelContainer.new()
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_stylebox_override("panel", Style.panel())
	right.add_child(content_panel)
	for id in TabScenes:
		var page = PageScenes[id].instantiate()
		var title: String = {"status": "状态", "equipment": "装备", "items": "物品", "skills": "技能", "settings": "设置"}[id]
		add_tab(id, title, page, TabScenes[id])
	pages["settings"].action_requested.connect(func(action): settings_action_requested.emit(action))
	select_tab("status")
	var close_button = preload("res://scenes/ui/components/option_button.tscn").instantiate()
	close_button.option_text = "×"
	close_button.option_id = &"close"
	close_button.custom_minimum_size = Vector2(42, 36)
	close_button.anchor_left = 0.94
	close_button.anchor_right = 0.94
	close_button.anchor_top = 0.02
	close_button.anchor_bottom = 0.02
	close_button.offset_left = -42
	close_button.offset_right = 0
	close_button.offset_bottom = 36
	add_child(close_button)
	close_button.custom_minimum_size = Vector2(42, 36)
	close_button.pressed.connect(func(): close_requested.emit())

## 新增独立页签；可传入自定义内容面板与按钮场景。
func add_tab(tab_id: String, title: String, page: Control = null, button_scene: PackedScene = null) -> void:
	if tabs.has(tab_id):
		return
	var button = (button_scene if button_scene != null else preload("res://scenes/ui/components/option_button.tscn")).instantiate()
	button.option_text = title
	button.option_id = StringName(tab_id)
	button.toggle_mode = true
	button.button_group = button_group
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_child(button)
	button.pressed.connect(func(): select_tab(tab_id))
	tabs[tab_id] = button
	if page == null:
		page = VBoxContainer.new()
		page.add_child(Style.label(title, 20))
	content_panel.add_child(page)
	page.visible = false
	pages[tab_id] = page

## 仅显示目标内容页，并同步页签选中状态。
func select_tab(tab_id: String) -> void:
	if not tabs.has(tab_id):
		return
	selected_tab = tab_id
	for id in tabs:
		tabs[id].button_pressed = id == tab_id
		pages[id].visible = id == tab_id
	tab_changed.emit(tab_id)

## 更新支持列表的内容页；lines 应为 Array[String]。
func set_page_items(tab_id: String, lines: Array[String]) -> void:
	if pages.has(tab_id) and pages[tab_id].has_method("set_items"):
		pages[tab_id].set_items(lines)

## 替换已有内容页，保留同一页签入口。
func set_page_content(tab_id: String, content: Control) -> void:
	if not pages.has(tab_id):
		return
	var old_page: Control = pages[tab_id]
	content_panel.remove_child(old_page)
	old_page.queue_free()
	content_panel.add_child(content)
	content.visible = selected_tab == tab_id
	pages[tab_id] = content
