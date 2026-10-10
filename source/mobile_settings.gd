extends RefCounted

# Mobile uses in-scene controls: no desktop window modes or native popups.
var front: Control
var game: Node2D
var body: VBoxContainer
var tabs: Dictionary={}
var tab:="controls"

func build(owner: Control) -> void:
	front=owner;game=front.game
	front.reset_modal("手机设置与触屏引导")
	front.modal.anchor_left=.075;front.modal.anchor_right=.925
	var mobile_theme: Theme=front.theme.duplicate()
	var panel:=StyleBoxFlat.new();panel.bg_color=Color("14262d");panel.border_color=Color("638b92");panel.set_border_width_all(2);panel.set_corner_radius_all(12)
	panel.content_margin_left=22;panel.content_margin_right=22;panel.content_margin_top=18;panel.content_margin_bottom=18
	mobile_theme.set_stylebox("panel","PanelContainer",panel)
	for state: String in ["normal","hover","pressed","disabled"]:
		var style:=StyleBoxFlat.new();style.bg_color=Color("24424d") if state=="normal" else Color("365966") if state in ["hover","pressed"] else Color("163038")
		style.border_color=Color("6e9ba6") if state!="disabled" else Color("36515b");style.set_border_width_all(2);style.set_corner_radius_all(8)
		mobile_theme.set_stylebox(state,"Button",style)
	front.modal.theme=mobile_theme
	var navigation:=HBoxContainer.new();navigation.add_theme_constant_override("separation",12);front.content.add_child(navigation)
	for entry: Array in [["controls","操作"],["display","性能与画面"],["sound","声音"],["guide","触屏引导"]]:
		var id: String=entry[0]
		var button:=action(entry[1],func():show_tab(id))
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;navigation.add_child(button);tabs[id]=button
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;front.content.add_child(scroll)
	body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",14);scroll.add_child(body)
	front.message.custom_minimum_size.y=28;front.content.add_child(front.message)
	var footer:=HBoxContainer.new();footer.add_theme_constant_override("separation",16);front.content.add_child(footer)
	var apply:=action("保存设置",front.apply_settings);apply.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(apply);front.settings_controls["apply"]=apply
	front.back_button=action("返回游戏",front.close_modal);front.back_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(front.back_button)
	show_tab("controls")

func action(text: String, callback: Callable) -> Button:
	var result: Button=front.button(text,callback);result.custom_minimum_size=Vector2(110,64);return result

func paragraph(text: String) -> void:
	var label: Label=game.label(text,21);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(label)

func show_tab(id: String) -> void:
	tab=id
	for child: Node in body.get_children():body.remove_child(child);child.queue_free()
	for key: String in tabs:tabs[key].disabled=key==id
	match id:
		"controls":
			paragraph("大按钮与摇杆同时扩大触摸范围。手机、设置、对话打开时，场景操作会自动停用。")
			stepper("control_scale","摇杆与按钮大小",1.0,1.4,.05,"倍")
			stepper("control_margin","距屏幕边缘",28,76,4,"像素")
			stepper("control_opacity","操作控件不透明度",.45,1.0,.05,"%",100)
		"display":
			paragraph("横屏游玩。推荐60帧；发热或省电时选择30帧。场景画质保持一致，不切换手机显示模式。")
			var fps:=action("帧率上限：%d FPS" % int(front.draft["mobile_fps"]),func():
				front.draft["mobile_fps"]=30 if int(front.draft["mobile_fps"])==60 else 60
				show_tab("display")
			)
			body.add_child(fps);front.settings_controls["mobile_fps"]=fps
			toggle("reduce_flash","减弱剧情闪屏")
			toggle("camera_shake","允许轻微剧情震屏")
		"sound":
			paragraph("点击减号 / 加号调节。离开但未保存时恢复原音量。")
			for entry: Array in [["master","总音量"],["music","音乐音量"],["sfx","音效音量"]]:stepper(entry[0],entry[1],0,100,5,"%")
		"guide":
			paragraph("① 左下摇杆移动；左手保持移动，右手按住奔跑可加速。")
			paragraph("② X 与附近人物或物品交互，Y 打开游戏菜单；点击地面也可自动寻路。")
			paragraph("③ 右上手机打开群聊与软件。手机打开时，右侧场景按钮隐藏，不会挡住选项。")
			paragraph("④ 选项与对话抬手确认；轻微手抖不影响点击。列表上下滑动，滑动后即使滑回原处也不确认。修改器使用游戏内数字键盘。")
			paragraph("⑤ 游戏菜单 → 保存，主动保存进度。手机游戏消耗一个时段；普通设置、聊天、修改数值不推进时间。")
			paragraph("⑥ 若贴近系统手势区域，增加操作页的边缘距离；先保存设置，再返回游戏查看手感。")

func stepper(key: String, title: String, low: float, high: float, step: float, suffix: String, multiplier: float=1) -> void:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",14);body.add_child(row)
	var caption: Label=game.label(title,21);caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(caption)
	var amount: Label=game.label("",22);amount.custom_minimum_size.x=114;amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var display:=func():amount.text=(str(snappedf(float(front.draft[key])*multiplier,.01)) if suffix=="倍" else str(roundi(float(front.draft[key])*multiplier)))+suffix
	var minus:=action("−",func():change(key,low,high,-step);display.call());minus.custom_minimum_size.x=76
	var plus:=action("+",func():change(key,low,high,step);display.call());plus.custom_minimum_size.x=76
	row.add_child(minus);row.add_child(amount);row.add_child(plus);display.call()
	front.settings_controls[key]={"minus":minus,"plus":plus,"label":amount}

func change(key: String, low: float, high: float, delta: float) -> void:
	front.draft[key]=snappedf(clampf(float(front.draft[key])+delta,low,high),.01)
	if key in ["master","music","sfx"]:game.preferences.preview_volume(key,float(front.draft[key]))

func toggle(key: String, title: String) -> void:
	var control:=CheckButton.new();control.text=title;control.custom_minimum_size.y=64;control.button_pressed=bool(front.draft[key]);body.add_child(control)
	control.toggled.connect(func(value: bool):front.draft[key]=value)
	front.settings_controls[key]=control
