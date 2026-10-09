extends Control

signal action_selected(category_id: StringName, command_id: StringName, payload: Dictionary)
const Assets=preload("res://external_battle_assets.gd")
var game: Node2D
var stage: Control
var ally_slot: Control
var enemy_slot: Control
var category_buttons: Dictionary={}
var submenus: Dictionary={}
var selected_category: StringName=&"attack"
var dock: VBoxContainer
var category_grid: GridContainer
var host: Control
var turn_label: Label
var hero_label: Label
var enemy_label: Label
var intent_label: Label
var log_label: Label
var charge_toggle: CheckButton
var close_button: Button
var hero_card: PanelContainer
var enemy_card: PanelContainer
var report_card: PanelContainer
var input_enabled:=true
var location_name:=""

static func box(color: Color, border: Color, padding: int=12) -> StyleBoxFlat:
	var value:=StyleBoxFlat.new();value.bg_color=color;value.border_color=border
	value.set_border_width_all(1);value.set_corner_radius_all(10)
	value.content_margin_left=padding;value.content_margin_right=padding
	value.content_margin_top=padding;value.content_margin_bottom=padding
	return value

func _ready() -> void:
	theme=Theme.new();theme.default_font=game.ui_font;theme.default_font_size=17
	theme.set_stylebox("normal","Button",box(Color("233f48"),Color("4a7278")))
	theme.set_stylebox("hover","Button",box(Color("325762"),Color("d7bb7b")))
	theme.set_stylebox("pressed","Button",box(Color("49616a"),Color("f6d28a")))
	theme.set_stylebox("focus","Button",box(Color(0,0,0,0),Color("ffe0a0")))
	theme.set_stylebox("disabled","Button",box(Color("202d33"),Color("35444c")))
	theme.set_color("font_disabled_color","Button",Color("8d9b9f"))
	hero_card=card();hero_label=text(17);hero_card.add_child(hero_label)
	enemy_card=card();enemy_label=text(17);enemy_card.add_child(enemy_label)
	turn_label=text(18);turn_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;add_child(turn_label)
	stage=Assets.fetch("res://scenes/ui/battle/components/battle_stage.tscn").instantiate();add_child(stage)
	ally_slot=stage.ally_slot;enemy_slot=stage.enemy_slot
	report_card=card();var reports:=VBoxContainer.new();report_card.add_child(reports)
	intent_label=text(16);intent_label.add_theme_color_override("font_color",Color("f4d294"));reports.add_child(intent_label)
	log_label=text(17);reports.add_child(log_label)
	dock=VBoxContainer.new();dock.add_theme_constant_override("separation",10);add_child(dock)
	category_grid=GridContainer.new();category_grid.columns=3
	category_grid.add_theme_constant_override("h_separation",8);category_grid.add_theme_constant_override("v_separation",8);dock.add_child(category_grid)
	var names: Dictionary={"attack":"攻击","magic":"法术","dodge":"防御","items":"物资","auto_battle":"自动","surrender":"撤离"}
	for id: String in names:
		var button:=Button.new();button.text=names[id];button.toggle_mode=true;button.custom_minimum_size=Vector2(0,46)
		button.size_flags_horizontal=SIZE_EXPAND_FILL;category_grid.add_child(button);category_buttons[id]=button
		button.pressed.connect(open_category.bind(StringName(id)))
	charge_toggle=CheckButton.new();charge_toggle.text="蓄力：双倍 MP，下一回合释放"
	charge_toggle.add_theme_font_size_override("font_size",15);dock.add_child(charge_toggle)
	host=Control.new();host.size_flags_vertical=SIZE_EXPAND_FILL;host.custom_minimum_size.y=80;dock.add_child(host)
	for id: String in names:
		var menu:=preload("res://battle_commands.gd").new();menu.category_id=StringName(id)
		menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);host.add_child(menu);submenus[id]=menu
		menu.command_requested.connect(func(category: StringName,command: StringName,payload: Dictionary):
			if input_enabled:action_selected.emit(category,command,payload))
		menu.back_requested.connect(return_to_categories)
	close_button=Button.new();close_button.text="返回地图";close_button.custom_minimum_size=Vector2(180,52);add_child(close_button);close_button.hide()
	resized.connect(sync_layout);sync_layout();open_category(&"attack")

func text(font_size: int) -> Label:
	var value:=Label.new();value.add_theme_font_size_override("font_size",font_size)
	value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;value.mouse_filter=MOUSE_FILTER_IGNORE
	return value

func card() -> PanelContainer:
	var value:=PanelContainer.new();value.add_theme_stylebox_override("panel",box(Color("172c34"),Color("49636c")))
	add_child(value);return value

func place(node: Control, rect: Rect2) -> void:
	node.position=rect.position*size;node.size=rect.size*size

func sync_layout() -> void:
	if dock==null:return
	var compact:=size.x<1050
	place(hero_card,Rect2(.018,.016,.48 if compact else .52,.18))
	place(enemy_card,Rect2(.51 if compact else .55,.016,.47 if compact else .43,.18))
	place(turn_label,Rect2(.02,.195,.96,.04))
	place(stage,Rect2(.018,.24,.964 if compact else .65,.24 if compact else .49))
	place(report_card,Rect2(.018,.49 if compact else .745,.964 if compact else .65,.19 if compact else .23))
	place(dock,Rect2(.018 if compact else .69,.69 if compact else .24,.964 if compact else .292,.29 if compact else .735))
	category_grid.columns=6 if compact else 3
	for menu: PanelContainer in submenus.values():menu.grid.columns=2 if compact else 1
	place(close_button,Rect2(.76,.9,.21,.07))

func open_category(id: StringName) -> bool:
	if not input_enabled or not submenus.has(id):return false
	selected_category=id
	for key: String in submenus:
		submenus[key].visible=key==str(id);category_buttons[key].button_pressed=key==str(id)
	charge_toggle.visible=id==&"magic"
	return true

func return_to_categories() -> void:open_category(&"attack")

func set_category_entries(id: StringName, entries: Array[Dictionary]) -> bool:
	return submenus[id].set_entries(entries) if submenus.has(id) else false

func set_turn_state(turn: int, phase: String, allowed: bool) -> void:
	turn_label.text="%s  ·  第 %d 回合  ·  %s" % [location_name,turn,phase]
	input_enabled=allowed
	for button: Button in category_buttons.values():button.disabled=not allowed
	for menu: PanelContainer in submenus.values():menu.set_allowed(allowed)

func set_battle_background(value: Texture2D) -> void:stage.set_background(value)
