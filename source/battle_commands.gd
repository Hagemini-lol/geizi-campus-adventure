extends PanelContainer

signal command_requested(category_id: StringName, command_id: StringName, payload: Dictionary)
signal back_requested
var category_id: StringName
var command_buttons: Dictionary={}
var entries: Array[Dictionary]=[]
var scroll: ScrollContainer
var grid: GridContainer
var empty_label: Label
var signature:=""
var allowed:=true

func _ready() -> void:
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	grid=GridContainer.new();grid.columns=1;grid.size_flags_horizontal=SIZE_EXPAND_FILL
	grid.add_theme_constant_override("v_separation",8);grid.add_theme_constant_override("h_separation",8);scroll.add_child(grid)
	empty_label=Label.new();empty_label.text="当前没有可用选项";grid.add_child(empty_label)

func set_entries(value: Array[Dictionary]) -> bool:
	var seen: Dictionary={}
	for entry: Dictionary in value:
		if str(entry.get("id","")).is_empty() or seen.has(entry["id"]):return false
		seen[entry["id"]]=true
	var stamp:=JSON.stringify(value)
	if stamp==signature:return true
	signature=stamp;entries.assign(value.duplicate(true))
	for child: Node in grid.get_children():grid.remove_child(child);child.queue_free()
	command_buttons.clear()
	if entries.is_empty():
		empty_label=Label.new();empty_label.text="当前没有可用选项";grid.add_child(empty_label)
	for entry: Dictionary in entries:
		var button:=Button.new();button.custom_minimum_size=Vector2(0,66)
		button.size_flags_horizontal=SIZE_EXPAND_FILL;button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var caption: String=str(entry["label"])
		var detail: String=str(entry.get("description",""))
		if not detail.is_empty() and not caption.contains("\n"):caption+="\n"+detail
		button.text=caption;button.tooltip_text=detail
		button.add_theme_font_size_override("font_size",16)
		button.disabled=not allowed or not entry.get("enabled",true)
		button.pressed.connect(func():command_requested.emit(category_id,StringName(str(entry["id"])),entry.get("payload",{})))
		grid.add_child(button);command_buttons[StringName(str(entry["id"]))]=button
	return true

func set_allowed(value: bool) -> void:
	allowed=value
	for entry: Dictionary in entries:
		command_buttons[StringName(str(entry["id"]))].disabled=not allowed or not entry.get("enabled",true)
