extends Control

var game: Node2D
var title_visible:=false
var cover: TextureRect
var title_buttons: Dictionary={}
var title_actions: PanelContainer
var modal: PanelContainer
var veil: ColorRect
var content: VBoxContainer
var message: Label
var back_button: Button
var slot_buttons: Dictionary={}
var slot_mode:="load"
var settings_controls: Dictionary={}
var overwrite: ConfirmationDialog
var pending_slot:=0
var draft: Dictionary={}
var settings_open:=false
var backdrop: ColorRect
var cover_heading: PanelContainer

func button(text: String, callback: Callable) -> Button:
	var result:=Button.new()
	result.text=text
	result.custom_minimum_size.y=42
	result.pressed.connect(func():game.play_ui_click();callback.call())
	return result

func _ready() -> void:
	theme=game.menu_view.shared_theme
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter=Control.MOUSE_FILTER_STOP
	var black:=ColorRect.new()
	backdrop=black
	black.color=Color("101d25")
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(black)
	cover=TextureRect.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	# Overlay the old raster title without changing the original cover asset.
	cover_heading=PanelContainer.new()
	cover_heading.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	cover_heading.anchor_bottom=.32
	cover_heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var heading_style:=StyleBoxFlat.new()
	heading_style.bg_color=Color("102e32")
	heading_style.border_color=Color("d6c580")
	heading_style.border_width_bottom=3
	cover_heading.add_theme_stylebox_override("panel",heading_style)
	add_child(cover_heading)
	var heading:=VBoxContainer.new()
	heading.alignment=BoxContainer.ALIGNMENT_CENTER
	heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cover_heading.add_child(heading)
	var game_name: Label=game.label("gei子的冒险",68)
	game_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	game_name.add_theme_color_override("font_color",Color("fff1b5"))
	game_name.mouse_filter=Control.MOUSE_FILTER_IGNORE
	heading.add_child(game_name)
	var edition: Label=game.label("离线版 · "+str(ProjectSettings.get_setting("application/config/version","")),17)
	edition.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	edition.modulate=Color("b8d4cf")
	edition.mouse_filter=Control.MOUSE_FILTER_IGNORE
	heading.add_child(edition)
	title_actions=PanelContainer.new()
	title_actions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	title_actions.offset_left=-465;title_actions.offset_right=465
	title_actions.offset_top=-84;title_actions.offset_bottom=-16
	add_child(title_actions)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	title_actions.add_child(row)
	for entry: Array in [["start","开始游戏"],["load","加载存档"],["exit","退出游戏"],["settings","设置"]]:
		var id: String=entry[0]
		var action:=button(entry[1],func():title_action(id))
		action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(action)
		title_buttons[id]=action
	veil=ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color=Color(0.02,.04,.05,.91)
	veil.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(veil)
	modal=PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.anchor_left=.20;modal.anchor_right=.80
	modal.anchor_top=.085;modal.anchor_bottom=.915
	add_child(modal)
	content=VBoxContainer.new()
	content.add_theme_constant_override("separation",12)
	modal.add_child(content)
	overwrite=ConfirmationDialog.new()
	overwrite.title="覆盖存档"
	overwrite.ok_button_text="覆盖并保存"
	overwrite.cancel_button_text="取消"
	overwrite.confirmed.connect(func():write_slot(pending_slot))
	add_child(overwrite)
	veil.hide();modal.hide();cover.hide();cover_heading.hide();title_actions.hide()
	hide()

func title_action(id: String) -> void:
	match id:
		"start":game.start_new_game()
		"load":open_slots("load")
		"exit":game.get_tree().quit()
		"settings":open_settings()

func show_title() -> void:
	title_visible=true
	backdrop.show()
	if cover.texture==null:
		var image:=Image.load_from_file(game.resolve_path(game.cover_path))
		if image!=null:
			image.generate_mipmaps()
			cover.texture=ImageTexture.create_from_image(image)
	cover.show();cover_heading.show();title_actions.show();modal.hide();veil.hide()
	show()
	game.refresh_player_freeze()

func hide_title() -> void:
	title_visible=false
	backdrop.hide()
	cover.hide();cover_heading.hide();title_actions.hide()
	cover.texture=null
	close_modal()
	hide()

func has_modal() -> bool:return modal.visible

func reset_modal(title: String) -> void:
	for child: Node in content.get_children():content.remove_child(child);child.queue_free()
	slot_buttons={};settings_controls={}
	content.add_child(game.label(title,27))
	message=game.label("",17)
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	modal.show();veil.show();title_actions.hide();show()
	game.refresh_player_freeze()

func add_footer(callback: Callable=Callable()) -> void:
	content.add_child(message)
	back_button=button("返回",close_modal if callback.is_null() else callback)
	content.add_child(back_button)

func close_modal() -> void:
	if settings_open:
		for key: String in ["master","music","sfx"]:game.preferences.preview_volume(key,float(game.preferences.values[key]))
	settings_open=false
	modal.hide();veil.hide();overwrite.hide()
	if title_visible:title_actions.show()
	else:hide()
	game.refresh_player_freeze()

func open_slots(mode: String) -> void:
	settings_open=false
	slot_mode=mode
	reset_modal("保存游戏" if mode=="save" else "加载存档")
	content.add_child(game.label("选择存档槽位 · 记录地点、人物位置与时间段",17))
	for slot: int in range(1,6):
		var record: Dictionary=game.save_store.read_slot(slot)
		var panel:=PanelContainer.new()
		content.add_child(panel)
		var row:=HBoxContainer.new()
		row.add_theme_constant_override("separation",16)
		panel.add_child(row)
		var details:=VBoxContainer.new()
		details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var location: String=record.get("location",record.get("error","空存档"))
		details.add_child(game.label("存档 %d · %s" % [slot,location],19))
		if record["ok"]:
			var state: Dictionary=record["state"]
			details.add_child(game.label("%s · %s%s" % [state.get("period",""),record["saved_at"]," · 备份" if record["backup"] else ""],14))
		var action:=button("保存" if mode=="save" else "读取",func():choose_slot(slot))
		action.custom_minimum_size.x=92
		action.disabled=mode=="load" and not record["ok"]
		row.add_child(action)
		slot_buttons[slot]=action
	add_footer()

func choose_slot(slot: int) -> void:
	if slot_mode=="load":
		var result: Dictionary=game.load_game_slot(slot)
		if not result["ok"]:message.text=result["error"]
		return
	var previous: Dictionary=game.save_store.read_slot(slot)
	if previous["ok"]:
		pending_slot=slot
		overwrite.dialog_text="覆盖存档 %d？\n%s\n%s" % [slot,previous["location"],previous["saved_at"]]
		overwrite.popup_centered(Vector2i(450,180))
	else:write_slot(slot)

func write_slot(slot: int) -> void:
	var result: Dictionary=game.save_game_slot(slot)
	if result["ok"]:
		open_slots("save")
		message.text="已保存到存档 %d" % slot
	else:message.text=result["error"]

func setting_row(title: String, control: Control) -> void:
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	var caption: Label=game.label(title,19)
	caption.custom_minimum_size.x=125
	row.add_child(caption)
	control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(control)
	content.add_child(row)

func open_settings() -> void:
	draft=game.preferences.values.duplicate()
	settings_open=true
	reset_modal("设置")
	var resolution:=OptionButton.new()
	for value: Vector2i in game.preferences.RESOLUTIONS:resolution.add_item("%d × %d" % [value.x,value.y])
	resolution.select(int(draft["resolution"]))
	resolution.item_selected.connect(func(index: int):draft["resolution"]=index)
	settings_controls["resolution"]=resolution
	setting_row("分辨率",resolution)
	for entry: Array in [["fullscreen","全屏显示"],["vsync","垂直同步"]]:
		var key: String=entry[0]
		var option:=CheckButton.new()
		option.button_pressed=bool(draft[key])
		option.toggled.connect(func(value: bool):draft[key]=value)
		settings_controls[key]=option
		setting_row(entry[1],option)
	var fps:=OptionButton.new()
	for value: int in game.preferences.FPS_VALUES:fps.add_item("不限" if value==0 else str(value)+" FPS")
	fps.select(game.preferences.FPS_VALUES.find(int(draft["fps"])))
	fps.item_selected.connect(func(index: int):draft["fps"]=game.preferences.FPS_VALUES[index])
	settings_controls["fps"]=fps
	setting_row("帧率上限",fps)
	for entry: Array in [["master","总音量"],["music","音乐音量"],["sfx","音效音量"]]:
		var key: String=entry[0]
		var line:=HBoxContainer.new()
		var slider:=HSlider.new()
		slider.min_value=0;slider.max_value=100;slider.step=1
		slider.value=float(draft[key]);slider.custom_minimum_size.x=230
		slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		line.add_child(slider)
		var amount: Label=game.label("%d%%" % int(slider.value),18)
		amount.custom_minimum_size.x=54
		line.add_child(amount)
		slider.value_changed.connect(func(value: float):draft[key]=value;amount.text="%d%%" % int(value);game.preferences.preview_volume(key,value))
		settings_controls[key]=slider
		setting_row(entry[1],line)
	var apply_button:=button("应用设置",apply_settings)
	settings_controls["apply"]=apply_button
	content.add_child(apply_button)
	add_footer()

func apply_settings() -> void:
	var success: bool=game.preferences.apply(draft)
	message.text="设置已保存" if success else "设置已生效，但文件保存失败"
	game.play_ui_click()
