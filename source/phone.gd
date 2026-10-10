extends Control

var game: Node2D
var launcher: TextureButton
var panel: Control
var body: VBoxContainer
var heading: Label
var page:="home"
var messages: Dictionary={"wechat":[],"qq":[]}
var matches:=0
var last_score:=0
var match_round:=0
var match_score:=0
var inputs: Dictionary={}
var previous:="home"
var initiating:=false
var keypad: Dictionary={}
var keypad_text: Label
var keypad_fresh:=true
var editor_target:=""
var editor_offset:=0
const WARNING:="从世界之外，我们获得修改世界的力量，少年，你确定要这样做么？"
const GROUPS:={"wechat":"我也要玩瓦洛兰特","qq":"唠嗑组"}
const LABELS:={"hp":"生命上限","hp_current":"当前生命","mp":"魔力上限","mp_current":"当前魔力","energy":"精力上限","energy_current":"当前精力","san":"SAN上限","san_current":"当前SAN","attack":"攻击力","defense":"防御","magic_resistance":"魔法抗性","penetration":"穿透","physical_reduction":"物理减伤","magic_reduction":"魔法减伤","level":"等级","experience":"经验","SAN":"剧情理智百分比","RP_H":"凡人路线点","RP_W":"魔女路线点","RP_D":"世家路线点","GOU_UNDERSTAND":"对勾尬的理解","BETRAY_COUNT":"背弃次数","STATE":"守印阶段","rune_mistakes":"符文失误次数"}

func art(id: String) -> Texture2D:
	var image:=Image.load_from_file(game.package_root.path_join("资源/手机UI/v1.5/"+id+".png"))
	return ImageTexture.create_from_image(image) if image!=null else null

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP;theme=game.menu_view.shared_theme
	var shade:=ColorRect.new();shade.color=Color(0.02,.035,.045,.62);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	panel=Control.new();panel.size=Vector2(420,760);add_child(panel)
	var background:=TextureRect.new();background.texture=art("phone_screen_base");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(background)
	var column:=VBoxContainer.new();column.position=Vector2(30,80);column.size=Vector2(360,600);column.add_theme_constant_override("separation",12);panel.add_child(column)
	heading=game.label("赵慕gei的手机",22);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(heading)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",10);scroll.add_child(body)
	var nav:=HBoxContainer.new();column.add_child(nav)
	var back:=Button.new();back.text="返回";back.custom_minimum_size=Vector2(130,64);back.pressed.connect(back_page);nav.add_child(back)
	var close_button:=Button.new();close_button.text="关闭手机";close_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;close_button.custom_minimum_size.y=64;close_button.pressed.connect(close);nav.add_child(close_button)
	resized.connect(sync_layout);sync_layout();hide()
	launcher=TextureButton.new();launcher.texture_normal=art("phone_launcher");launcher.ignore_texture_size=true;launcher.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	launcher.anchor_left=1;launcher.anchor_right=1;launcher.offset_left=-96;launcher.offset_right=-20;launcher.offset_top=18;launcher.offset_bottom=94;launcher.tooltip_text="手机 · 群聊 / 游戏 / 禁忌力量"
	get_parent().add_child.call_deferred(launcher);launcher.pressed.connect(open)

func sync_layout() -> void:
	if panel==null:return
	var ratio:=minf(1,minf((size.y-28)/760,(size.x-28)/420));panel.scale=Vector2.ONE*ratio
	panel.position=Vector2(size.x-420*ratio-16,(size.y-760*ratio)/2)

func _process(_delta: float) -> void:
	if launcher!=null:launcher.visible=game.game_started and not visible and not game.battle_view.visible and not game.story_system.running and not game.front_end.visible and not game.menu_view.visible and not game.map_view.visible and not game.transition_busy

func open() -> void:
	if game.transition_busy or game.story_system.running or game.dialogue_view.visible or game.battle_view.visible or game.lesson_blocked() or not game.game_started:return
	game.close_menu();game.player.path.clear();game.player.velocity=Vector2.ZERO;show();home()
	game.refresh_player_freeze();game.mobile_controls.hide()

func close() -> void:
	hide();match_round=0;game.refresh_player_freeze();game.mobile_controls.refresh_availability();game.interaction_delay=.4

func clear(title: String, route: String) -> void:
	page=route;heading.text=title;inputs.clear()
	(body.get_parent() as ScrollContainer).scroll_vertical=0
	for child: Node in body.get_children():body.remove_child(child);child.queue_free()

func paragraph(text: String) -> void:
	var label: Label=game.label(text,18);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(label)

func button(text: String, action: Callable, icon: String="") -> Button:
	var value:=Button.new();value.text=text;value.custom_minimum_size.y=64;value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;value.add_theme_font_size_override("font_size",18)
	if not icon.is_empty():value.icon=art(icon);value.expand_icon=true;value.add_theme_constant_override("icon_max_width",38)
	value.pressed.connect(func():game.play_ui_click();action.call());body.add_child(value);return value

func home() -> void:
	clear("赵慕gei的手机 · "+game.day_clock.display_text(),"home")
	paragraph("放下课本后的片刻。"+("\n当前存档已使用禁忌力量。" if game.world_editor.used else ""))
	button("微信 · 特殊小队",func():chat("wechat"),"app_wechat")
	button("QQ · 班级群",func():chat("qq"),"app_qq")
	button("王者荣耀 · 消磨时间",king_home,"app_honor_of_kings")
	button("禁忌力量",forbidden,"app_browser")

func back_page() -> void:
	if page=="home":close()
	elif page=="keypad":editor(str(keypad["scope"]),str(keypad["target"]),int(keypad["offset"]))
	elif page.begins_with("editor/"):editor_home()
	else:home()

func roster(group: String) -> Array[String]:
	var result: Array[String]=game.relationships.COMPANIONS.duplicate()
	if group=="qq":result.append_array(["gou_ga","homeroom_teacher","english_teacher"])
	elif game.campaign.index>=14:result.append("gou_ga")
	return result.filter(func(id: String):return game.relationships.alive(id))

func chat(group: String) -> void:
	clear(GROUPS[group],group)
	var members: Array[String]=[]
	for id: String in roster(group):members.append(str(game.npc_catalog.characters[id]["display_name"]))
	paragraph(("特殊小队交流群" if group=="wechat" else "十班班级群 · 普通同学与老师也在群中")+"\n目前在线："+"、".join(members))
	if messages[group].is_empty():paragraph("系统：群聊已建立。成员只会留下自己还在时说过的话。")
	for message: Dictionary in messages[group]:
		var actor: String=message["actor"]
		paragraph(("gei子" if actor=="hero" else str(game.npc_catalog.characters.get(actor,{}).get("display_name",actor)))+" · 第%d天\n" % (int(message["day"])+1)+str(message["text"])+( "\n〔生前留言〕" if actor!="hero" and not game.relationships.alive(actor) else ""))
	button("发消息：现在大家在哪？",func():send(group,"location"))
	button("发消息：问问大家的近况",func():send(group,"care"))
	button("发消息：商量下一步行动",func():send(group,"plan"))

func send(group: String, kind: String) -> void:
	var text: String={"location":"大家现在在哪儿？我一会儿过去。","care":"今天还好吗？有事可以说，不用一个人扛。","plan":"下一步我们先做什么？"}[kind]
	messages[group].append({"actor":"hero","text":text,"day":game.economy.day_serial})
	var members:=roster(group)
	for i: int in range(mini(3,members.size())):
		var actor: String=members[(game.economy.day_serial+i)%members.size()]
		var reply:=""
		if game.relationships.bond(actor)<0:reply="你做过的事大家都记得。先别在群里装作什么也没发生，我现在不想跟你组队。"
		elif kind=="location":reply="我在"+game.campaign.location_name(game.campaign.scheduled_location(actor))+"。"+("先吃饭，下午再碰头。" if game.day_clock.current_period==5 else "过来前说一声。")
		elif kind=="plan":reply="先把眼前的调查做完。"+game.story_system.objective_text()
		else:reply=str(game.relationships.reaction({"character":actor,"uid":"phone/"+actor},"phone")[1]["text"]);game.relationships.once(actor,"phone_care",1)
		messages[group].append({"actor":actor,"text":reply,"day":game.economy.day_serial})
	while messages[group].size()>80:messages[group].pop_front()
	game.record_game_event("phone/"+group+"/"+kind);chat(group)

func king_home() -> void:
	clear("王者荣耀","king")
	paragraph("离线短局 · 对线 / 视野 / 撤退\n一局三个决策，结算推进一个时段。不会获得g或真实账号奖励。\n已完成%d局，上一局%d/3。" % [matches,last_score])
	button("开始一局：消磨一个时段",func():match_round=1;match_score=0;king_round())

func king_round() -> void:
	clear("王者荣耀 · 第%d回合" % match_round,"king_round")
	paragraph(["兵线进塔，敌方打野在另一条路出现。","河道视野全黑，对面中单消失了。","队友已撤离，敌方多人越塔准备强开。"][match_round-1])
	for entry: Array in [["farm","稳住补兵"],["ward","布置视野"],["retreat","撤退回城"]]:
		var id: String=entry[0];button(entry[1],func():king_action(id))

func king_action(answer: String) -> void:
	if page!="king_round":return
	if answer==["farm","ward","retreat"][match_round-1]:match_score+=1
	match_round+=1
	if match_round<=3:king_round();return
	matches+=1;last_score=match_score;match_round=0
	game.advance_world_period();game.combat_rules.hero["energy_current"]=mini(int(game.combat_rules.hero["energy"]),int(game.combat_rules.hero["energy_current"])+8)
	king_home();paragraph("一局结束。"+("配合很稳，心情也轻松了一点。" if last_score==3 else "输赢都有，先放下手机看看身边的事。"))

func forbidden() -> void:
	if game.world_editor.unlocked:editor_home();return
	clear("禁忌力量","warning");paragraph(WARNING)
	button("确认",initiate);button("算了",home)

func initiate() -> void:
	if initiating or game.story_system.running:return
	initiating=true;close()
	var intro:=preload("res://forbidden_intro.gd").new()
	await intro.run(game);initiating=false
	open();editor_home()

func editor_home() -> void:
	if not game.world_editor.unlocked:return
	clear("禁忌力量 · 修改器","editor")
	paragraph("修改随当前存档保存。可随时改回数值；正常剧情条件仍按任务记录判断。")
	for entry: Array in [["hero","主角属性 / 等级 / SAN"],["money","金钱"],["affinity","角色好感度"],["item","背包物资数量"],["campaign","剧情数值"],["monster","怪物属性"]]:
		var scope: String=entry[0];button(entry[1],func():editor(scope))

func numeric(scope: String, id: String, field: String, title: String, value: float, limits: Vector2) -> void:
	if game.preferences.mobile_mode():
		var edit:=button(title+"："+str(snappedf(value,.01)),func():number_pad(scope,id,field,title,value,limits))
		inputs[scope+"/"+id+"/"+field]={"button":edit}
		return
	var row:=VBoxContainer.new();row.add_theme_constant_override("separation",4);body.add_child(row)
	var label: Label=game.label(title,17);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;row.add_child(label)
	var controls:=HBoxContainer.new();row.add_child(controls)
	var input:=SpinBox.new();input.min_value=limits.x;input.max_value=limits.y;input.step=.01 if field.ends_with("reduction") else 1;input.value=value;input.custom_minimum_size=Vector2(195,44);input.size_flags_horizontal=Control.SIZE_EXPAND_FILL;controls.add_child(input)
	var apply:=Button.new();apply.text="修改";apply.custom_minimum_size=Vector2(90,44);controls.add_child(apply)
	apply.pressed.connect(func():
		if game.world_editor.edit(scope,id,field,input.value):game.show_notice("已修改："+title);game.play_ui_click()
	)
	inputs[scope+"/"+id+"/"+field]={"input":input,"button":apply}

func editor(scope: String, target: String="", offset: int=0) -> void:
	editor_target=target;editor_offset=offset
	clear("修改器 · "+{"hero":"主角","money":"金钱","affinity":"好感度","item":"物资","campaign":"剧情","monster":"怪物"}.get(scope,scope),"editor/"+scope)
	if scope=="hero":
		for field: String in game.world_editor.HERO_FIELDS+["hp_current","mp_current","energy_current","san_current","level","experience"]:
			var limits: Vector2=Vector2(0,60) if field=="level" else Vector2(0,int(game.combat_rules.hero[field.trim_suffix("_current")])) if field.ends_with("_current") else game.world_editor.bounds(field)
			numeric(scope,"",field,LABELS.get(field,field),float(game.combat_rules.hero.get(field,0)),limits)
	elif scope=="money":numeric(scope,"","money","持有g",game.economy.money,Vector2(0,1000000000))
	elif scope=="affinity":
		for id: String in game.relationships.COMPANIONS+game.relationships.ADULTS+["gou_ga"]:numeric(scope,id,"bond",str(game.npc_catalog.characters[id]["display_name"]),game.relationships.bond(id),Vector2(-100,100))
		for id: String in game.relationships.affinity:
			if id.begins_with("local/"):numeric(scope,id,"bond","普通同学 · "+id.trim_prefix("local/"),game.relationships.bond(id),Vector2(-100,100))
	elif scope=="item":
		var items: Array=game.economy.catalog.keys()
		var limit: int=12 if game.preferences.mobile_mode() else items.size()
		for i: int in range(offset,mini(offset+limit,items.size())):
			var id: String=items[i];numeric(scope,id,"quantity",str(game.economy.catalog[id]["name"]),game.economy.quantity(id),Vector2(0,game.economy.STACK_CAP))
		if offset>0:button("上一页",func():editor(scope,target,maxi(0,offset-limit)))
		if offset+limit<items.size():button("下一页",func():editor(scope,target,offset+limit))
	elif scope=="campaign":
		for id: String in game.campaign.flags:
			if not game.campaign.flags[id] is bool and not game.campaign.flags[id] is String and not id.begins_with("BOND_"):numeric(scope,id,id,LABELS.get(id,"已记录的剧情计数"),game.campaign.flags[id],Vector2(0,5 if id=="GOU_UNDERSTAND" else 3 if id in ["STATE","rune_mistakes"] else 100))
	elif scope=="monster":
		if target.is_empty():
			for id: String in game.combat_rules.data["monsters"]:
				var monster_id: String=id;button(str(game.combat_rules.data["monsters"][id]["name"]),func():editor("monster",monster_id))
		else:
			var stats: Dictionary=game.combat_rules.monster_stats(target,maxi(1,int(game.combat_rules.hero["level"])))
			paragraph("更改之后生成的属性；不会中途改变已经开始的战斗。")
			for field: String in game.world_editor.MONSTER_FIELDS:numeric(scope,target,field,LABELS.get(field,field),stats.get(field,0),game.world_editor.bounds(field))

func number_pad(scope: String, id: String, field: String, title: String, value: float, limits: Vector2) -> void:
	keypad={"scope":scope,"id":id,"field":field,"title":title,"limits":limits,"target":editor_target,"offset":editor_offset}
	clear("修改 · "+title,"keypad");keypad_fresh=true
	paragraph("范围："+str(limits.x)+" 至 "+str(limits.y))
	keypad_text=game.label(str(snappedf(value,.01)),29);keypad_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;body.add_child(keypad_text)
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);body.add_child(grid)
	for key: String in ["7","8","9","4","5","6","1","2","3","−","0","删除"]:
		var digit:=Button.new();digit.text=key;digit.custom_minimum_size=Vector2(104,64);digit.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(digit);digit.pressed.connect(func():keypad_press(key))
	if field.ends_with("reduction"):button("小数点",func():keypad_press("."))
	button("确认修改",commit_number)

func keypad_press(key: String) -> void:
	var text: String=keypad_text.text
	if key=="删除":text="0" if keypad_fresh or text.length()<=1 else text.left(-1)
	elif key=="−":
		if keypad["limits"].x<0:text=text.trim_prefix("-") if text.begins_with("-") else "-"+text
	elif key==".":
		if keypad_fresh:text="0"
		if not text.contains("."):text+="."
	else:
		if keypad_fresh or text=="0":text=""
		if text.length()<14:text+=key
	keypad_fresh=false;keypad_text.text=text

func commit_number() -> void:
	var limits: Vector2=keypad["limits"]
	var amount:=clampf(float(keypad_text.text),limits.x,limits.y)
	if game.world_editor.edit(keypad["scope"],keypad["id"],keypad["field"],amount):
		game.show_notice("已修改："+str(keypad["title"])+" = "+str(amount));game.play_ui_click()
		editor(keypad["scope"],keypad["target"],keypad["offset"])

func snapshot() -> Dictionary:return {"version":1,"messages":messages.duplicate(true),"matches":matches,"last_score":last_score}
func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not value.get("messages") is Dictionary:return false
	for field: String in ["matches","last_score"]:
		var n: Variant=value.get(field)
		if not (n is int or n is float) or not is_finite(float(n)) or n!=floor(float(n)) or n<0 or n>(3 if field=="last_score" else 1000000):return false
	for group: String in GROUPS:
		if not value["messages"].get(group) is Array or value["messages"][group].size()>80:return false
		for row: Variant in value["messages"][group]:
			if not row is Dictionary or not row.get("actor") is String or not row.get("text") is String or row["text"].length()>1500:return false
			var n: Variant=row.get("day")
			if not (n is int or n is float) or not is_finite(float(n)) or n!=floor(float(n)) or n<0 or n>1000000:return false
	return true
func restore(value: Dictionary) -> void:
	messages=value.get("messages",{"wechat":[],"qq":[]}).duplicate(true);matches=int(value.get("matches",0));last_score=int(value.get("last_score",0));match_round=0;hide()
