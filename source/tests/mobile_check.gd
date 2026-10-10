extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
var auto_intro:=false
func _process(_delta: float) -> bool:
	if auto_intro and game!=null and game.dialogue_view.visible:game.dialogue_view.accept()
	return false
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames(count: int=3) -> void:
	for i: int in range(count):await process_frame
func touch(index: int, at: Vector2, pressed: bool) -> void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=at;event.pressed=pressed
	root.push_input(event,true)
func drag(index: int, at: Vector2, relative: Vector2=Vector2(60,0)) -> void:
	var event:=InputEventScreenDrag.new();event.index=index;event.position=at;event.relative=relative
	root.push_input(event,true)
func tap(index: int, at: Vector2) -> void:
	touch(index,at,true);await frames();touch(index,at,false);await frames()
func wait_transition() -> void:
	var end:=Time.get_ticks_msec()+60000
	while game.transition_busy and Time.get_ticks_msec()<end:await process_frame
	check(not game.transition_busy,"mobile scene transition completes")
	await frames()
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await frames(10)
	var wide: bool="--wide-mobile" in OS.get_cmdline_user_args()
	if wide:DisplayServer.window_set_size(Vector2i(1600,900));await frames(8)
	check(game.load_error.is_empty(),"mobile bundle loads all startup assets")
	check(game.package_root=="res://package","resources use bundled mobile root")
	check(game.mobile_controls.active,"mobile input enabled")
	check(game.mobile_controls.base_art!=null and game.mobile_controls.knob_art!=null and game.mobile_controls.button_art!=null,"library joystick and button textures load")
	check(not game.mobile_controls.visible,"controls hidden on cover")
	await tap(0,game.front_end.title_buttons["start"].get_global_rect().get_center());await wait_transition()
	check(game.game_started and game.mobile_controls.visible,"touch starts game from cover")
	game.story_system.stage=6;game.story_system.reward_given=true
	var controls: Control=game.mobile_controls
	var start: Vector2=game.player.position
	touch(0,controls.stick_rect.get_center(),true)
	drag(0,controls.stick_rect.get_center()+Vector2(controls.stick_rect.size.x*.35,0));await frames(20)
	check(controls.stick_index==0 and controls.direction.x>.9,"first finger drives joystick")
	check(game.player.position.x>start.x+3,"joystick moves actual protagonist")
	check(game.player.path.is_empty(),"stick does not create a click-to-move path")
	touch(1,controls.run_rect.get_center(),true);await frames()
	check(controls.running and controls.stick_index==0,"second finger sprints without releasing stick")
	check(game.player.velocity.length()>190,"touch sprint uses double speed")
	touch(1,controls.run_rect.get_center(),false);await frames()
	check(not controls.running and controls.direction.x>.9,"sprint release retains joystick movement")
	touch(2,controls.y_rect.get_center(),true);await frames();touch(2,controls.y_rect.get_center(),false)
	check(game.menu_view.visible,"Y opens menu while another finger holds stick")
	check(controls.direction.is_zero_approx() and game.player.frozen,"opening menu stops joystick")
	touch(0,Vector2.ZERO,false);await frames()
	await tap(1,game.menu_view.tabs["items"].get_global_rect().get_center())
	await tap(1,game.menu_view.shop_button.get_global_rect().get_center())
	var scroll: ScrollContainer=game.menu_view.page_scroll
	check(scroll.get_v_scroll_bar().max_value>scroll.size.y,"shop has scrollable content")
	var scroll_point:=scroll.get_global_rect().position+Vector2(24,scroll.size.y*.65)
	touch(1,scroll_point,true);await frames()
	drag(1,scroll_point-Vector2(0,120),Vector2(0,-120));await frames()
	touch(1,scroll_point-Vector2(0,120),false);await frames()
	check(scroll.scroll_vertical>20,"finger swipes scroll menu lists")
	await tap(1,game.menu_view.close_button.get_global_rect().get_center())
	check(not game.menu_view.visible and not game.player.frozen,"large menu close button releases player")
	await frames()
	game.teleport_outdoor(game.spawn);await wait_transition()
	game.player.camera.reset_smoothing();await frames(5)
	game.player.path.clear()
	# Choose a short, walkable point away from the on-screen controls.
	var target: Vector2=game.player.position
	for vector: Vector2 in [Vector2.UP,Vector2.LEFT,Vector2.DOWN,Vector2.RIGHT]:
		var candidate: Vector2=game.player.position+vector*80
		if not game.navigation.route(game.player.position,candidate).is_empty():target=candidate;break
	check(target!=game.player.position,"navigation fixture chooses a reachable point")
	var before_click: Vector2=game.player.position
	var screen: Vector2=root.get_canvas_transform()*target
	touch(0,screen,true)
	var click_route: bool=not game.player.path.is_empty()
	check(click_route and game.player.path[-1].distance_to(target)<24,"screen coordinates map to intended world destination")
	await frames();touch(0,screen,false);await frames()
	print("TOUCH_NAV ",before_click," -> ",target," at ",screen," notice ",game.notice," end ",game.player.position)
	check(click_route,"screen tap reaches existing click-to-move navigation")
	game.player.path.clear()
	game.change_interior({"kind":"classroom","building":"B01","floor":3,"room":0});await wait_transition()
	game.day_clock.current_period=4;game.sync_classroom_period();await frames()
	var people: Node2D=game.terrain.current_scene.npcs
	var items: Array[Dictionary]=people.interactions()
	check(not items.is_empty(),"interior NPCs load on mobile")
	people.set_process(false)
	var approach: PackedVector2Array=game.approach_interaction(items[0]["at"])
	check(not approach.is_empty(),"touch interaction target reachable around furniture")
	if not approach.is_empty():game.player.position=approach[-1]
	game.player.path.clear();game.player.camera.reset_smoothing()
	await create_timer(.4).timeout;await frames(5)
	check(not game.nearby.is_empty(),"nearby interaction discovered before pressing X")
	await tap(0,controls.x_rect.get_center())
	check(game.dialogue_view.visible or is_instance_valid(game.campaign.panel),"X interacts with nearby NPC")
	check(not controls.visible,"movement controls hidden under dialogue")
	if is_instance_valid(game.campaign.panel):
		var talk: Button=null
		for button: Button in game.campaign.panel.find_children("*","Button",true,false):
			if button.get_meta("campaign_option","") in ["chat","talk"]:talk=button
		check(talk!=null,"named NPC service offers conversation")
		if talk!=null:await tap(0,talk.get_global_rect().get_center())
		check(game.dialogue_view.visible,"touching campaign option starts actual conversation")
	var confirm: Button=game.dialogue_view.confirm
	var dialogue_step: int=game.dialogue_view.script_index if game.dialogue_view.script_mode else game.dialogue_view.current_turn
	if confirm!=null:await tap(0,confirm.get_global_rect().get_center())
	var next_step: int=game.dialogue_view.script_index if game.dialogue_view.script_mode else game.dialogue_view.current_turn
	check(not game.dialogue_view.visible or next_step>dialogue_step,"screen tap advances dialogue turn")
	for step: int in range(8):
		if not game.dialogue_view.visible:break
		await tap(0,confirm.get_global_rect().get_center())
	check(not game.dialogue_view.visible,"dialogue option responds to screen tap")
	if game.menu_view.visible:await tap(0,game.menu_view.close_button.get_global_rect().get_center())
	await frames()
	touch(0,controls.stick_rect.get_center(),true);drag(0,controls.stick_rect.get_center()+Vector2(0,controls.stick_rect.size.x*.35));await frames()
	touch(0,Vector2(-100,-100),false);await frames()
	check(controls.direction.is_zero_approx(),"release outside stick prevents stuck movement")
	game.combat_rules.reset_hero();game.story_system.stage=6
	var saved: Dictionary=game.save_game_slot(1)
	check(saved.get("ok",false),"mobile save written to private/test storage")
	check(game.load_game_slot(1).get("ok",false),"mobile save reloads")
	await wait_transition()
	await frames(8)
	var phone: Control=game.phone
	await tap(0,phone.launcher.get_global_rect().get_center())
	check(phone.visible and game.player.frozen,"touch opens top-right phone and freezes world")
	await tap(0,phone.body.get_child(1).get_global_rect().get_center())
	check(phone.page=="wechat" and phone.heading.text=="我也要玩瓦洛兰特","touch opens requested WeChat group")
	phone.home();await frames()
	await tap(0,phone.body.get_child(2).get_global_rect().get_center())
	check(phone.page=="qq" and phone.heading.text=="唠嗑组","touch opens requested QQ group")
	phone.home();await frames()
	await tap(0,phone.body.get_child(4).get_global_rect().get_center())
	check(phone.page=="warning","touch opens forbidden warning")
	await tap(0,phone.body.get_child(2).get_global_rect().get_center())
	check(phone.page=="home" and not game.world_editor.unlocked,"touch cancel leaves powers locked")
	await tap(0,phone.body.get_child(4).get_global_rect().get_center())
	auto_intro=true;await tap(0,phone.body.get_child(1).get_global_rect().get_center())
	var deadline:=Time.get_ticks_msec()+30000
	while phone.initiating and Time.get_ticks_msec()<deadline:await process_frame
	auto_intro=false
	check(not phone.initiating and phone.visible and phone.page=="editor","exported first-use animation completes into modifier")
	check(int(game.event_state.get("forbidden/transfer_visual",0))==1,"exported transfer beams play exactly once")
	await frames();await tap(0,phone.body.get_child(2).get_global_rect().get_center())
	check(phone.page=="editor/money","touch opens secondary money editor")
	var numeric: Dictionary=phone.inputs.values()[0]
	await tap(0,numeric["button"].get_global_rect().get_center())
	for digit: String in ["2","4","6","8","0"]:phone.keypad_press(digit)
	await tap(0,phone.body.get_child(phone.body.get_child_count()-1).get_global_rect().get_center())
	check(game.economy.money==24680,"touch applies numeric edit in exported UI")
	phone.close();phone.open();phone.forbidden()
	check(phone.page=="editor" and int(game.event_state.get("forbidden/inherited",0))==1,"exported subsequent entry skips animation")
	phone.close();await frames()
	game.battle_view.start({"monster":{"uid":"touch-ui","id":"ink_slime","level":1,"hp":100000}},"probe");await frames(8)
	var battle: Control=game.battle_view.interface
	await tap(0,battle.category_buttons["magic"].get_global_rect().get_center())
	check(battle.selected_category==&"magic" and battle.submenus["magic"].visible,"touch switches new battle command category")
	await tap(0,battle.category_buttons["attack"].get_global_rect().get_center())
	var turn: int=game.battle_view.turn
	await tap(0,battle.submenus["attack"].command_buttons["physical"].get_global_rect().get_center())
	while game.battle_view.busy:await process_frame
	check(game.battle_view.turn>turn or game.battle_view.result=="victory","touch executes actual new battle attack")
	game.battle_view.finish("escape");game.battle_view.close();await frames()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/Godot/校园自由漫游/runtime/安卓触屏"+("宽屏" if wide else "")+"预览.png")
	var report: Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"test":"actual ScreenTouch/ScreenDrag dispatch with simultaneous fingers"}
	var file:=FileAccess.open("D:/Godot/校园自由漫游/runtime/mobile_checks"+("_wide" if wide else "")+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("MOBILE_CHECKS ",checks," FAILURES ",failures.size());quit(0 if failures.is_empty() else 1)
