extends Control

const TEXT_SECONDS:=2.0
var game: Node2D
var panel: PanelContainer
var black_text: Label
var confirm: Button
var cancel: Button
var description: Label
var running:=false
var completed:=0
var held_seconds:=0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new();shade.color=Color(0,0,0,.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(shade)
	panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left=-310;panel.offset_right=310;panel.offset_top=-125;panel.offset_bottom=125
	panel.add_theme_stylebox_override("panel",game.dialogue_view.button_style(Color("e1eccd")));add_child(panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",18);panel.add_child(column)
	var title: Label=game.label("上课",26);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_color_override("font_color",Color("395434"));column.add_child(title)
	description=game.label("",22);description.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color",Color("395434"));description.custom_minimum_size=Vector2(570,70);column.add_child(description)
	var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",24);column.add_child(row)
	for name: String in ["确认","取消"]:
		var button:=Button.new();button.text="◇ "+name;button.custom_minimum_size=Vector2(160,46)
		button.add_theme_font_override("font",game.ui_font);button.add_theme_font_size_override("font_size",21)
		for state: String in ["normal","focus"]:button.add_theme_stylebox_override(state,game.dialogue_view.button_style(Color("e1eccd")))
		button.add_theme_stylebox_override("hover",game.dialogue_view.button_style(Color("f0f5de")))
		button.add_theme_stylebox_override("pressed",game.dialogue_view.button_style(Color("c4d4ae")))
		for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,Color("395434"))
		row.add_child(button)
		if name=="确认":confirm=button;button.pressed.connect(start_lesson)
		else:cancel=button;button.pressed.connect(close)
	black_text=game.label("",27);black_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black_text.offset_left=90;black_text.offset_right=-90;black_text.offset_top=70;black_text.offset_bottom=-70
	black_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;black_text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	black_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;black_text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game.fade.add_child(black_text);black_text.hide();hide()

func available(scene: Node2D=null) -> bool:
	if scene==null:scene=game.terrain.current_scene
	return scene!=null and scene.get("is_ten_class")==true and not scene.is_office and scene.state["building"]!="B02" and game.day_clock.current_period in [1,2]

func open() -> void:
	if running or not available():return
	var next: String="下午" if game.day_clock.current_period==1 else "晚上"
	description.text="坐在自己的座位上，参加"+game.day_clock.display_text()+"课程？\n结束后进入"+next+"。"
	game.player.path.clear();game.player.velocity=Vector2.ZERO
	show();game.refresh_player_freeze()

func close() -> void:
	if running:return
	hide();game.refresh_player_freeze();game.interaction_delay=maxf(game.interaction_delay,.25)

func start_lesson() -> void:
	if running or not visible or not available() or game.transition_busy:return
	if game.campaign!=null and game.campaign.active() and game.campaign.current().get("id","")=="yang_awakened" and game.story_system.chapter_room():
		hide();game.campaign.run_event();return
	running=true;hide();game.transition_busy=true;game.time_skip_busy=true;game.refresh_player_freeze()
	game.player.path.clear();game.player.velocity=Vector2.ZERO;game.pending_npc_talk="";game.pending_monster=""
	game.update_time_display()
	var morning: bool=game.day_clock.current_period==1
	var cover:=game.create_tween();cover.tween_property(game.fade,"modulate:a",1.0,.18);await cover.finished
	black_text.text="上午 · 上课\n\n赵慕gei坐在靠窗倒数第二排的座位上。\n班主任在讲台旁讲课，同学们安静地听讲。" if morning else "下午 · 上课\n\n赵慕gei坐在自己的座位上。\n英语老师在讲台旁授课，大家完成了课堂练习。"
	black_text.show()
	var begin:=Time.get_ticks_msec()
	await get_tree().create_timer(TEXT_SECONDS).timeout
	held_seconds=float(Time.get_ticks_msec()-begin)/1000.0
	# Advance while the world remains hidden; seating/teacher state follows the period.
	game.day_clock.next_period();game.monster_world.advance(game.interior_state);game.sync_monsters()
	game.sync_classroom_period();game.apply_time_lighting();game.update_time_display()
	game.record_game_event("classes_attended")
	completed+=1;black_text.hide()
	var reveal:=game.create_tween();reveal.tween_property(game.fade,"modulate:a",0.0,.22);await reveal.finished
	running=false;game.time_skip_busy=false;game.transition_busy=false
	game.refresh_player_freeze();game.interaction_delay=maxf(game.interaction_delay,.35);game.update_time_display()
	game.show_notice("下课了，现在是"+game.day_clock.display_text())
