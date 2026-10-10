extends Control

const GREETINGS: Array[String]=["你好呀！今天过得怎么样？","嗨，见到你很高兴！","你好！有空一起聊聊天吧。","早上好，祝你今天心情愉快！","嗨！在校园里逛得开心。"]
const HERO_REPLIES: Array[String]=["你好！见到你也很高兴。","嗨，祝你今天过得愉快！","你好呀，有空再一起聊聊。","谢谢，也祝你心情愉快！"]
const SPEAKING_COLOR:=Color.WHITE
const LISTENING_COLOR:=Color(.38,.42,.38,1)
var game: Node2D
var frame: TextureRect
var portrait: TextureRect
var left_portrait: TextureRect
var right_portrait: TextureRect
var turn_hint: Label
var active_speaker:="npc"
var current_turn:=0
var hero_reply:=""
var name_label: Label
var speech: Label
var confirm: Button
var cancel: Button
var speaker_name: String
var last_greeting:=""
var rng:=RandomNumberGenerator.new()
signal script_finished(accepted: bool)
var script_lines: Array=[]
var script_mode:=false
var script_mandatory:=false
var script_index:=0
var script_callback:=Callable()

func button_style(color: Color) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.border_color=Color("789064")
	style.set_border_width_all(2);style.set_corner_radius_all(9)
	style.shadow_color=Color(0.12,.22,.1,.18);style.shadow_size=2
	style.content_margin_left=18;style.content_margin_right=18
	return style

func _ready() -> void:
	rng.randomize()
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color=Color(0,.015,.01,.22);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	left_portrait=make_portrait(0.0,1.0/3.0)
	right_portrait=make_portrait(2.0/3.0,1.0)
	portrait=right_portrait
	var panel:=Control.new()
	panel.z_index=100
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left=-550;panel.offset_right=550;panel.offset_top=-390;panel.offset_bottom=-20
	add_child(panel)
	frame=TextureRect.new()
	frame.z_index=0
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	name_label=game.label("",23);name_label.position=Vector2(120,53)
	name_label.z_index=10
	name_label.add_theme_color_override("font_color",Color("355236"))
	panel.add_child(name_label)
	speech=game.label("",24);speech.position=Vector2(190,122);speech.size=Vector2(810,85)
	speech.z_index=10
	speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	speech.add_theme_color_override("font_color",Color("344a32"));panel.add_child(speech)
	turn_hint=game.label("",16);turn_hint.position=Vector2(190,258)
	turn_hint.z_index=10
	turn_hint.add_theme_color_override("font_color",Color("59714a"));panel.add_child(turn_hint)
	var mobile: bool=OS.has_feature("android") or "--mobile-controls" in OS.get_cmdline_user_args()
	var row:=HBoxContainer.new();row.position=Vector2(690,246);row.size=Vector2(325,64 if mobile else 45)
	row.z_index=20
	row.add_theme_constant_override("separation",20);panel.add_child(row)
	for key: String in ["确认","取消"]:
		var option:=Button.new()
		option.text="◇ "+key;option.custom_minimum_size=Vector2(150,64 if mobile else 44)
		option.add_theme_font_override("font",game.ui_font);option.add_theme_font_size_override("font_size",20)
		for state: String in ["normal","focus"]:option.add_theme_stylebox_override(state,button_style(Color("e1eccd")))
		option.add_theme_stylebox_override("hover",button_style(Color("f0f5de")))
		option.add_theme_stylebox_override("pressed",button_style(Color("c4d4ae")))
		for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:option.add_theme_color_override(state,Color("395434"))
		if key=="确认":confirm=option;option.pressed.connect(accept)
		else:cancel=option;option.pressed.connect(close)
		row.add_child(option)
	hide()

func make_portrait(left: float, right: float) -> TextureRect:
	var image:=TextureRect.new()
	image.z_index=0
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.anchor_left=left;image.anchor_right=right
	image.anchor_top=.03;image.anchor_bottom=.96
	image.offset_left=16;image.offset_right=-16
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(image)
	return image

func greet(record: Dictionary) -> void:
	var image:=Image.load_from_file(game.resolve_path(game.dialogue_path))
	if image==null:game.show_notice("对话框素材缺失");return
	image.generate_mipmaps();frame.texture=ImageTexture.create_from_image(image)
	var hero: Image=game.npc_catalog.frame("zhao_mugei",0)
	var other: Image=game.npc_catalog.dialogue_portrait(record["character"])
	if hero==null or other==null:frame.texture=null;game.show_notice("对话人物素材缺失");return
	hero.generate_mipmaps();left_portrait.texture=ImageTexture.create_from_image(hero)
	other.generate_mipmaps();right_portrait.texture=ImageTexture.create_from_image(other)
	speaker_name=record["name"]
	var options:=GREETINGS.duplicate()
	var replies:=HERO_REPLIES.duplicate()
	var role: String=record.get("role","")
	var profile: Dictionary=game.office_plan.data.get("dialogue_profiles",{}).get(role,{})
	if not profile.is_empty():options.assign(profile["greetings"]);replies.assign(profile["replies"])
	# Neutral greetings apply to all five time periods.
	options.erase("早上好，祝你今天心情愉快！")
	if profile.is_empty() and game.day_clock.display_text()=="上午":options.append("早上好，祝你今天心情愉快！")
	if not last_greeting.is_empty():options.erase(last_greeting)
	last_greeting=options[rng.randi_range(0,options.size()-1)]
	hero_reply=replies[rng.randi_range(0,replies.size()-1)]
	set_turn(0)
	game.player.path.clear();game.player.velocity=Vector2.ZERO
	game.pending_npc_talk=""
	game.gameplay_hud.hide()
	show();game.refresh_player_freeze()

func set_turn(turn: int) -> void:
	current_turn=turn
	active_speaker="npc" if turn==0 else "hero"
	name_label.text=speaker_name if turn==0 else "赵慕gei"
	speech.text=last_greeting if turn==0 else hero_reply
	left_portrait.modulate=LISTENING_COLOR if turn==0 else SPEAKING_COLOR
	right_portrait.modulate=SPEAKING_COLOR if turn==0 else LISTENING_COLOR
	turn_hint.text="确认：回应问候  ·  取消：结束对话" if turn==0 else "确认：结束对话"

func accept() -> void:
	game.play_ui_click()
	if script_mode:
		script_index+=1
		if script_index<script_lines.size():display_script_turn()
		else:finish_script(true)
		return
	if current_turn==0:set_turn(1)
	else:game.show_notice("你向"+speaker_name+"点头问好。");close(false)

func can_advance_at(at: Vector2) -> bool:
	if not visible:return false
	if is_instance_valid(game.campaign.panel) and game.campaign.panel.is_visible_in_tree():return false
	for node: Node in get_tree().root.find_children("*","Control",true,false):
		if not node.is_visible_in_tree():continue
		if node is BaseButton or node is Range or node is LineEdit or node is TextEdit or node is ScrollContainer:
			var local: Vector2=node.get_global_transform_with_canvas().affine_inverse()*at
			if Rect2(Vector2.ZERO,node.size).has_point(local):return false
	return true

func close(play_sound: bool=true) -> void:
	if script_mode:
		if script_mandatory:return
		finish_script(false);return
	if play_sound:game.play_ui_click()
	hide();frame.texture=null;left_portrait.texture=null;right_portrait.texture=null
	game.pending_npc_talk=""
	game.interaction_delay=maxf(game.interaction_delay,.3)
	if game.game_started and not game.menu_view.visible and not game.front_end.visible:game.gameplay_hud.show()
	game.refresh_player_freeze()

func begin_script(lines: Array, mandatory: bool=true, callback: Callable=Callable()) -> void:
	script_lines=game.relationships.adapt_lines(lines);script_index=0;script_mode=true;script_mandatory=mandatory;script_callback=callback
	var image:=Image.load_from_file(game.resolve_path(game.dialogue_path));image.generate_mipmaps()
	frame.texture=ImageTexture.create_from_image(image)
	var hero: Image=game.npc_catalog.frame("zhao_mugei",0);hero.generate_mipmaps();left_portrait.texture=ImageTexture.create_from_image(hero)
	right_portrait.texture=null
	for row: Dictionary in script_lines:
		var actor: String=row.get("actor","")
		if actor in ["system","zhao_mugei"] or not game.npc_catalog.characters.has(actor):continue
		var other: Image=game.npc_catalog.dialogue_portrait(actor);other.generate_mipmaps()
		right_portrait.texture=ImageTexture.create_from_image(other);break
	confirm.text="◇ 确认";cancel.disabled=mandatory
	game.player.path.clear();game.player.velocity=Vector2.ZERO;game.gameplay_hud.hide()
	display_script_turn();show();game.refresh_player_freeze()

func display_script_turn() -> void:
	var row: Dictionary=script_lines[script_index]
	var actor: String=row.get("actor","system")
	active_speaker="hero" if actor=="zhao_mugei" else "npc"
	if actor!="zhao_mugei" and actor!="system" and game.npc_catalog.characters.has(actor):
		var art: Image=game.npc_catalog.dialogue_portrait(actor)
		art.generate_mipmaps();right_portrait.texture=ImageTexture.create_from_image(art)
	name_label.text="提示" if actor=="system" else str(game.npc_catalog.characters.get(actor,{}).get("display_name","赵慕gei"))
	speech.text=str(row["text"])
	left_portrait.modulate=SPEAKING_COLOR if actor=="zhao_mugei" else LISTENING_COLOR
	right_portrait.modulate=SPEAKING_COLOR if actor!="zhao_mugei" and actor!="system" else LISTENING_COLOR
	turn_hint.text="点空白处 / 确认 / E：继续  ·  %d / %d" % [script_index+1,script_lines.size()]

func finish_script(accepted: bool) -> void:
	var callback:=script_callback
	script_mode=false;script_mandatory=false;script_callback=Callable();script_lines=[];cancel.disabled=false
	close(false);script_finished.emit(accepted)
	if callback.is_valid() and accepted:callback.call_deferred()
