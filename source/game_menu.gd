extends Control

var game: Node2D
var assets: Dictionary={}
var pages: Dictionary={}
var tabs: Dictionary={}
var actions: Dictionary={}
var selected_tab:="status"
var location: Label
var close_button: Button
var textures: Array[Texture2D]=[]
var asset_paths: Array[String]=[]
var shared_theme: Theme
var attribute_labels: Dictionary={}
var status_label: Label
var task_label: Label
var page_scroll: ScrollContainer
var portrait: TextureRect
var money_label: Label
var supply_rows: VBoxContainer
var quantity_row: HBoxContainer
var trade_quantity: SpinBox
var shop_button: Button
var bag_button: Button
var action_feedback: Label
var supply_mode:="bag"
var buy_buttons: Dictionary={}
var sell_buttons: Dictionary={}
var use_buttons: Dictionary={}
var service_actor:=""
var equipment_rows: VBoxContainer
var skill_rows: VBoxContainer

func texture(path: String, crop: Rect2i=Rect2i()) -> Texture2D:
	asset_paths.append(path)
	var image:=Image.load_from_file(path)
	if image==null:return null
	if crop.has_area():image=image.get_region(crop)
	image.generate_mipmaps()
	var result:=ImageTexture.create_from_image(image)
	textures.append(result)
	return result

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shade:=ColorRect.new()
	shade.color=Color(0.02,.035,.04,.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var frame:=Control.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.anchor_left=.055;frame.anchor_right=.945
	frame.anchor_top=.075;frame.anchor_bottom=.90
	add_child(frame)
	var columns:=HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation",14)
	frame.add_child(columns)
	portrait=TextureRect.new()
	portrait.texture=texture(game.resolve_path(assets["menu"]),Rect2i(154,74,386,794))
	portrait.custom_minimum_size=Vector2(clampf(get_viewport_rect().size.x*.23,140,290),0)
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	columns.add_child(portrait)
	var right:=VBoxContainer.new()
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",10)
	columns.add_child(right)
	var panel_texture:=texture(game.resolve_path(assets["panel"]))
	var panel_style:=StyleBoxTexture.new()
	panel_style.texture=panel_texture
	panel_style.set_texture_margin_all(4)
	panel_style.content_margin_left=18;panel_style.content_margin_right=18
	panel_style.content_margin_top=14;panel_style.content_margin_bottom=14
	var normal:=button_style(texture(game.resolve_path(assets["button_normal"])))
	var hover:=button_style(texture(game.resolve_path(assets["button_hover"])))
	var selected:=button_style(texture(game.resolve_path(assets["button_selected"])))
	var menu_theme:=Theme.new()
	menu_theme.default_font=game.ui_font
	menu_theme.default_font_size=19
	menu_theme.set_stylebox("normal","Button",normal)
	menu_theme.set_stylebox("hover","Button",hover)
	menu_theme.set_stylebox("pressed","Button",selected)
	menu_theme.set_stylebox("hover_pressed","Button",selected)
	menu_theme.set_stylebox("panel","PanelContainer",panel_style)
	frame.theme=menu_theme
	shared_theme=menu_theme
	var information:=PanelContainer.new()
	right.add_child(information)
	var details:=VBoxContainer.new()
	details.add_theme_constant_override("separation",12)
	information.add_child(details)
	var heading:=HBoxContainer.new()
	details.add_child(heading)
	var title: Label=game.label("gei子的冒险 · 角色菜单",25)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	close_button=Button.new()
	close_button.text="×"
	close_button.custom_minimum_size=Vector2(44,38)
	close_button.pressed.connect(game.close_menu)
	heading.add_child(close_button)
	location=game.label("",18)
	details.add_child(location)
	action_feedback=game.label("",17);action_feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.add_child(action_feedback);action_feedback.hide()
	var attributes:=GridContainer.new();attributes.columns=2
	attributes.add_theme_constant_override("h_separation",24)
	attributes.add_theme_constant_override("v_separation",6)
	details.add_child(attributes)
	for entry: Array in [["HP  —","e36b6b"],["MP  —","629edb"],["精力  —","e0c564"],["SAN  —","78bd82"]]:
		var attribute: Label=game.label(entry[0],20)
		attribute.modulate=Color(entry[1])
		attributes.add_child(attribute)
		attribute_labels[str(entry[0]).split(" ")[0]]=attribute
	var tab_row:=HBoxContainer.new()
	tab_row.add_theme_constant_override("separation",4)
	right.add_child(tab_row)
	var body:=PanelContainer.new()
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	right.add_child(body)
	page_scroll=ScrollContainer.new();page_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;page_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(page_scroll)
	var stack:=VBoxContainer.new();stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL;page_scroll.add_child(stack)
	var group:=ButtonGroup.new()
	for entry: Array in [["status","状态"],["equipment","装备"],["items","物品"],["skills","技能"],["saves","存读档"],["settings","设置"]]:
		var id: String=entry[0]
		var tab:=Button.new()
		tab.text=entry[1]
		tab.toggle_mode=true;tab.button_group=group
		tab.custom_minimum_size.y=46
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tab.pressed.connect(func():select_tab(id))
		tab_row.add_child(tab)
		tabs[id]=tab
		var page:=VBoxContainer.new()
		page.add_theme_constant_override("separation",15)
		stack.add_child(page)
		pages[id]=page
	pages["status"].add_child(game.label("当前状态",24))
	status_label=game.label("",20);pages["status"].add_child(status_label)
	pages["status"].add_child(game.label("当前任务",23))
	task_label=game.label("",19);task_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	task_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;pages["status"].add_child(task_label)
	var journal_button:=Button.new();journal_button.text="剧情手册 · 证据 / 图鉴 / 伙伴";journal_button.custom_minimum_size.y=46
	journal_button.pressed.connect(func():game.campaign.open_journal());pages["status"].add_child(journal_button)
	pages["status"].add_child(game.label("常态移动  4.2 米/秒\nShift 奔跑  8.4 米/秒\n点击寻路  21 米/秒",19))
	pages["status"].add_child(game.label("WASD 移动 · E 门 / 楼梯 / 告示牌\nM 校园全图 · 滚轮缩放 · F3 碰撞显示",18))
	pages["equipment"].add_child(game.label("装备与委托",24))
	equipment_rows=VBoxContainer.new();equipment_rows.add_theme_constant_override("separation",12);pages["equipment"].add_child(equipment_rows)
	pages["skills"].add_child(game.label("法术与战斗专精",24))
	skill_rows=VBoxContainer.new();skill_rows.add_theme_constant_override("separation",12);pages["skills"].add_child(skill_rows)
	pages["items"].add_child(game.label("物资与交易",24))
	money_label=game.label("",21);pages["items"].add_child(money_label)
	var modes:=HBoxContainer.new();modes.add_theme_constant_override("separation",12);pages["items"].add_child(modes)
	var mode_group:=ButtonGroup.new()
	for entry: Array in [["bag","背包"],["shop","校园商店"]]:
		var mode: String=entry[0];var button:=Button.new();button.text=entry[1];button.toggle_mode=true;button.button_group=mode_group
		button.custom_minimum_size=Vector2(150,44);button.pressed.connect(func():supply_mode=mode;refresh_supplies());modes.add_child(button)
		if mode=="bag":bag_button=button
		else:shop_button=button
	quantity_row=HBoxContainer.new();pages["items"].add_child(quantity_row);quantity_row.add_child(game.label("交易数量",18))
	trade_quantity=SpinBox.new();trade_quantity.min_value=1;trade_quantity.max_value=99;trade_quantity.step=1;trade_quantity.value=1
	trade_quantity.custom_minimum_size=Vector2(140,40);trade_quantity.value_changed.connect(func(_value: float):refresh_supplies());quantity_row.add_child(trade_quantity)
	supply_rows=VBoxContainer.new();supply_rows.add_theme_constant_override("separation",16);pages["items"].add_child(supply_rows)
	pages["saves"].add_child(game.label("存档与读档",24))
	pages["saves"].add_child(game.label("五个独立槽位，记录当前位置和时间段",18))
	for entry: Array in [["save","保存游戏"],["load","加载存档"]]:
		var id: String=entry[0]
		var button:=Button.new()
		button.text=entry[1];button.custom_minimum_size.y=48
		button.pressed.connect(func():game.menu_action(id))
		pages["saves"].add_child(button)
		actions[id]=button
	var settings_grid:=GridContainer.new()
	settings_grid.columns=2
	settings_grid.add_theme_constant_override("h_separation",12)
	settings_grid.add_theme_constant_override("v_separation",15)
	pages["settings"].add_child(settings_grid)
	for entry: Array in [["resume","继续漫游"],["map","校园全图"],["preferences","游戏设置"],["journal","剧情手册 / 证据 / 伙伴"],["south","回到南门"],["fullscreen","切换全屏"],["title","返回封面"],["exit","退出游戏"]]:
		var id: String=entry[0]
		var button:=Button.new()
		button.text=entry[1]
		button.custom_minimum_size.y=45
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.pressed.connect(func():game.menu_action(id))
		settings_grid.add_child(button)
		actions[id]=button
	var hint: Label=game.label("鼠标右键 / Esc 关闭菜单",17)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left=-150;hint.offset_right=150
	hint.offset_top=-54;hint.offset_bottom=-26
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	select_tab("status")
	game.task_system.changed.connect(refresh_tasks)
	game.economy.changed.connect(on_economy_changed)
	resized.connect(func():portrait.custom_minimum_size.x=clampf(get_viewport_rect().size.x*.23,140,290))
	refresh_tasks()
	refresh_supplies()
	hide()

func button_style(value: Texture2D) -> StyleBoxTexture:
	var style:=StyleBoxTexture.new()
	style.texture=value
	style.set_texture_margin_all(4)
	style.content_margin_top=7;style.content_margin_bottom=7
	style.content_margin_left=12;style.content_margin_right=12
	return style

func open_menu() -> void:
	refresh_status()
	refresh_tasks();refresh_supplies()
	refresh_progression()
	show()

func refresh_status() -> void:
	var hero: Dictionary=game.combat_rules.hero
	for pair: Array in [["HP","hp"],["MP","mp"],["精力","energy"],["SAN","san"]]:
		var stat: String=pair[1]
		attribute_labels[pair[0]].text="%s %d/%d" % [pair[0],hero[stat+"_current"],hero[stat]]
	status_label.text="等级 %d    攻击 %d    防御 %d\n法术抗性 %d    攻击穿透 %d" % [hero["level"],hero["attack"],hero["defense"],hero["magic_resistance"],hero["penetration"]]
	status_label.text+="\n经验 %d%s" % [hero["experience"],"（已满级）" if int(hero["level"])>=game.combat_rules.maximum_level() else " / "+str(game.combat_rules.experience_required(int(hero["level"])))]
	location.text="当前位置："+(game.terrain.current_scene.title if not game.interior_state.is_empty() else str(game.model["regions"][game.terrain.current_id]["name"]))+"    资金 %dg" % game.economy.money

func refresh_tasks() -> void:
	if task_label!=null:task_label.text=game.task_system.display_text()+ ("\n\n"+game.campaign.objective_text() if game.campaign!=null and game.campaign.active() else "")

func on_economy_changed() -> void:
	refresh_supplies()
	if visible and game.game_started and game.terrain.current_scene!=null:refresh_status()

func feedback(result: Dictionary) -> void:
	action_feedback.text=result["message"];action_feedback.show()

func refresh_supplies() -> void:
	if supply_rows==null:return
	money_label.text="持有资金  %dg  ·  每天生活费  %dg" % [game.economy.money,int(game.economy.data.get("daily_allowance",50))]
	bag_button.button_pressed=supply_mode=="bag";shop_button.button_pressed=supply_mode=="shop";quantity_row.visible=supply_mode=="shop"
	for child: Node in supply_rows.get_children():supply_rows.remove_child(child);child.queue_free()
	buy_buttons={};sell_buttons={};use_buttons={}
	var count:=int(trade_quantity.value)
	for id: String in game.economy.catalog:
		var spec: Dictionary=game.economy.catalog[id];var owned: int=game.economy.quantity(id)
		if spec.get("plot_item",false):continue
		var row:=VBoxContainer.new();row.add_theme_constant_override("separation",5);supply_rows.add_child(row)
		var description: Label=game.label("%s ×%d  ·  %s" % [spec["name"],owned,spec.get("description","")],18)
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;row.add_child(description)
		var controls:=HBoxContainer.new();controls.add_theme_constant_override("separation",12);row.add_child(controls)
		if supply_mode=="bag":
			if not spec.get("restore",{}).is_empty():
				var button:=Button.new();button.text="使用";button.custom_minimum_size=Vector2(110,38)
				button.disabled=not game.economy.can_use(id,game.combat_rules.hero);button.pressed.connect(func():feedback(game.use_supply(id)))
				controls.add_child(button);use_buttons[id]=button
			else:controls.add_child(game.label("可在校园商店出售",17))
		else:
			var buy_price:=int(spec.get("buy_price",-1));var sell_price:=int(spec.get("sell_price",0))
			var prices: Label=game.label(("买入 %dg" % buy_price if buy_price>=0 else "只可出售")+" / 出售 %dg" % sell_price,17)
			prices.size_flags_horizontal=Control.SIZE_EXPAND_FILL;controls.add_child(prices)
			for buying: bool in [true,false]:
				var button:=Button.new();button.text="买入" if buying else "出售";button.custom_minimum_size=Vector2(100,38)
				button.disabled=(buy_price<0 or game.economy.money<buy_price*count or owned+count>game.economy.STACK_CAP) if buying else (sell_price<=0 or owned<count)
				button.pressed.connect(func():feedback(game.trade_supply(id,int(trade_quantity.value),buying)));controls.add_child(button)
				if buying:buy_buttons[id]=button
				else:sell_buttons[id]=button

func select_tab(id: String) -> void:
	selected_tab=id
	if page_scroll!=null:page_scroll.scroll_vertical=0
	for key: String in tabs:
		tabs[key].button_pressed=key==id
		pages[key].visible=key==id

func open_service(actor: String) -> void:
	service_actor=actor;game.paused=false;game.overlay.hide()
	game.gameplay_hud.hide()
	open_menu();select_tab("skills" if actor=="fei_yan" else "equipment")
	game.refresh_player_freeze()

func clear_rows(parent: VBoxContainer) -> void:
	for child: Node in parent.get_children():parent.remove_child(child);child.queue_free()

func progression_feedback(value: Dictionary) -> void:
	feedback(value);refresh_progression();refresh_status()

func refresh_progression() -> void:
	if equipment_rows==null:return
	clear_rows(equipment_rows);clear_rows(skill_rows)
	var rules: RefCounted=game.combat_rules
	var hero: Dictionary=rules.hero
	var info: Label=game.label("与牢李交谈可委托制作；与牢硕交谈可购买装备。",17)
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;equipment_rows.add_child(info)
	for id: String in rules.data.get("equipment",{}):
		var spec: Dictionary=rules.data["equipment"][id]
		var owned: bool=game.economy.quantity(id)>0
		var item: Dictionary=game.economy.catalog[id]
		var merchant: String=item.get("merchant","")
		if not owned and (merchant.is_empty() or merchant!=service_actor):continue
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);equipment_rows.add_child(row)
		var caption: Label=game.label(spec["name"]+" · "+item["description"],18)
		caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(caption)
		var button:=Button.new();button.custom_minimum_size=Vector2(140,40);row.add_child(button)
		if owned:
			var equipped: bool=hero.get("equipment",{}).get(spec["slot"],"")==id
			button.text="已装备" if equipped else "装备";button.disabled=equipped
			button.pressed.connect(func():rules.equip(id);refresh_progression();refresh_status())
		else:
			button.text=("委托 " if merchant=="lao_li" else "购买 ")+str(game.equipment_price(id))+"g"
			button.disabled=game.economy.money<game.equipment_price(id) or (id=="tech_amulet" and game.economy.quantity("ink_fragment")<2)
			button.pressed.connect(func():progression_feedback(game.purchase_equipment(id,service_actor)))
	if game.economy.quantity("basic_magic_book")>0:equipment_rows.add_child(game.label("基础魔法书 · 已习得四系低级法术",18))
	if hero.get("equipment",{}).is_empty():equipment_rows.add_child(game.label("暂无装备。按主线任务继续探索。",19))
	var explanation: Label=game.label("向费眼学习法术和辅助技能；向牢硕学习战斗专精。\n中级 / 高级 / 超级法术分别在 5 / 15 / 35 级开放。\n双倍施法：先支付双倍 MP，承受一回合敌方行动，下回合释放双倍伤害。",17)
	explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;skill_rows.add_child(explanation)
	for id: String in rules.data.get("skills",{}):
		var skill: Dictionary=rules.data["skills"][id]
		var learned: bool=id in hero.get("skills",[])
		if not learned and skill.get("teacher","")!=service_actor:continue
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);skill_rows.add_child(row)
		var description: String=skill.get("description","")
		if skill["kind"]=="magic":
			var tier: Dictionary=rules.data["magic_tiers"][skill["tier"]]
			description="MP %d · 攻击倍率 ×%s" % [rules.spell_cost(skill["tier"]),str(tier["multiplier"])]
		var caption: Label=game.label(skill["name"]+" · "+description,18);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(caption)
		var button:=Button.new();button.custom_minimum_size=Vector2(140,40);row.add_child(button)
		button.text="已习得" if learned else ("需 %d 级" % int(skill["level"]) if int(hero["level"])<int(skill["level"]) else "学习 %dg" % int(skill["price"]))
		button.disabled=learned or not game.story_system.reward_given or int(hero["level"])<int(skill["level"]) or game.economy.money<int(skill["price"])
		button.pressed.connect(func():progression_feedback(game.learn_skill(id,service_actor)))
	if hero.get("skills",[]).is_empty():skill_rows.add_child(game.label("尚未觉醒魔力。按主线任务继续探索。",19))
