extends SceneTree

var game: Node2D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames() -> void:await process_frame;await process_frame
func transition() -> void:
	var deadline:=Time.get_ticks_msec()+20000
	while game.transition_busy and Time.get_ticks_msec()<deadline:await process_frame
	check(not game.transition_busy,"time/scene transition completes");await physics_frame;await frames()
func click(control: Control) -> void:
	await frames();var at:=control.get_global_rect().get_center()
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at;event.pressed=true
	root.push_input(event,true);await frames();event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func right_click() -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.position=Vector2(900,600);event.pressed=true
	root.push_input(event,true);await frames();event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var folder: String=game.package_root.path_join("runtime/物资与交易预览");DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate();root.add_child(game);await frames()
	game.start_new_game();await transition()
	var economy: RefCounted=game.economy;var rules: RefCounted=game.combat_rules
	check(economy.money==50 and economy.quantity("water")==2 and economy.quantity("bread")==1,"first day allowance and starting supplies")
	check(economy.claim_allowance()==0 and economy.money==50,"same day allowance cannot be claimed twice")
	await create_timer(.3).timeout;check(economy.money==50 and economy.day_serial==0,"waiting never advances days or pays money")
	check(game.trade_supply("water",2,true)["ok"] and economy.money==30 and economy.quantity("water")==4,"buy supplies atomically")
	check(game.trade_supply("water",1,false)["ok"] and economy.money==35 and economy.quantity("water")==3,"sell owned supplies atomically")
	var unchanged: Dictionary=economy.snapshot()
	check(not game.trade_supply("first_aid",2,true)["ok"] and economy.snapshot()==unchanged,"insufficient funds leave state untouched")
	for count: int in [-1,0,10000]:check(not game.trade_supply("water",count,true)["ok"] and economy.snapshot()==unchanged,"invalid quantity rejected without mutation")
	check(not game.trade_supply("ink_fragment",1,true)["ok"] and not game.trade_supply("first_aid",1,false)["ok"] and economy.snapshot()==unchanged,"unsellable/unowned trades rejected")
	rules.hero["hp_current"]=900;rules.hero["energy_current"]=160
	check(game.use_supply("bread")["ok"] and rules.hero["hp_current"]==1000 and rules.hero["energy_current"]==200 and economy.quantity("bread")==0,"bread restores both stats and clamps maximum")
	unchanged=economy.snapshot();check(not game.use_supply("water")["ok"] and economy.snapshot()==unchanged,"full-state supplies not wasted")
	rules.hero["energy_current"]=100;check(game.use_supply("water")["ok"] and rules.hero["energy_current"]==170 and economy.quantity("water")==2,"water consumes one and restores flat plus proportional energy")
	check(game.event_state.get("items_bought/water")==2 and game.event_state.get("item_used/water")==1,"trading and use publish future task events")
	for rarity: String in ["normal","elite","boss"]:
		var count: int=economy.quantity("ink_fragment");var loot: Dictionary=economy.award_loot(rarity)
		check(loot["ink_fragment"]=={"normal":1,"elite":2,"boss":5}[rarity] and economy.quantity("ink_fragment")==count+loot["ink_fragment"],"rarity-configured tradable loot")
	var money: int=economy.money;check(game.trade_supply("ink_fragment",8,false)["ok"] and economy.money==money+80,"monster materials can actually be sold")
	economy.inventory["water"]=9999;unchanged=economy.snapshot()
	check(not game.trade_supply("water",1,true)["ok"] and economy.snapshot()==unchanged,"inventory stack cap enforced")
	economy.inventory["water"]=2;rules.refill_hero()
	game.task_system.definitions["test_trade"]={"id":"test_trade","type":"side","steps":[{"hint":"测试交易事件","event":"trade_completed","count":1}]}
	game.task_system.start("test_trade")
	await right_click();check(game.menu_view.visible and game.player.frozen,"right-click opens material menu")
	await click(game.menu_view.tabs["items"]);check(game.menu_view.selected_tab=="items" and game.menu_view.money_label.text.contains("每天生活费  50g"),"inventory page displays money and allowance")
	await shot("物品页_背包")
	await click(game.menu_view.shop_button);check(game.menu_view.supply_mode=="shop" and game.menu_view.buy_buttons.has("water"),"shop mode presents buy and sell controls")
	money=economy.money;var owned: int=economy.quantity("water")
	await click(game.menu_view.buy_buttons["water"])
	check(economy.money==money-10 and economy.quantity("water")==owned+1 and game.menu_view.action_feedback.text.contains("购入"),"actual UI purchase updates gold, inventory and feedback")
	check(game.task_system.entries["test_trade"]["status"]=="completed","actual purchase completes event-bound task")
	await click(game.menu_view.sell_buttons["water"])
	check(economy.money==money-5 and economy.quantity("water")==owned,"actual UI sale updates both sides")
	game.menu_view.trade_quantity.value=2;await frames();await click(game.menu_view.buy_buttons["water"])
	check(economy.money==money-25 and economy.quantity("water")==owned+2,"quantity selector applies to real trade")
	await shot("物品页_校园商店")
	await click(game.menu_view.bag_button);rules.hero["energy_current"]=100;game.menu_view.refresh_supplies();await frames()
	owned=economy.quantity("water");await click(game.menu_view.use_buttons["water"])
	check(rules.hero["energy_current"]==170 and economy.quantity("water")==owned-1 and game.menu_view.attribute_labels["精力"].text.contains("170/200"),"actual UI consumption refreshes hero status")
	game.close_menu();money=economy.money
	for i: int in range(5):game.advance_time_period();await transition()
	check(game.day_clock.current_period==1 and economy.day_serial==1 and economy.money==money+50,"one five-period cycle pays exactly one daily allowance")
	check(game.event_state.get("allowance_received")==50 and economy.last_allowance_day==1,"daily receipt tracking recorded")
	check(game.save_game_slot(3)["ok"],"gold, items and allowance tracking save")
	var saved: Dictionary=economy.snapshot()
	game.load_game_slot(3);await transition();check(economy.snapshot()==saved,"loading does not award another daily allowance")
	check(economy.claim_allowance()==0 and economy.snapshot()==saved,"repeated manual claim after load remains idempotent")
	game.trade_supply("water",1,true);game.load_game_slot(3);await transition()
	check(economy.snapshot()==saved,"read restores spent gold and inventory quantities")
	for i: int in range(5):game.advance_time_period();await transition()
	check(economy.money==int(saved["money"])+50 and economy.day_serial==2,"next actual day still receives allowance after loading")
	var bad: Dictionary=economy.snapshot();bad["money"]=-1;check(not economy.valid_snapshot(bad),"negative funds save rejected")
	bad=economy.snapshot();bad["last_allowance_day"]=0;check(not economy.valid_snapshot(bad),"inconsistent allowance save rejected")
	bad=economy.snapshot();bad["inventory"]["water"]=10000;check(not economy.valid_snapshot(bad),"invalid material stack save rejected")
	var state: Dictionary=game.save_store.read_slot(3)["state"];state.erase("economy")
	check(game.queue_restore(state,"旧存档物资迁移")["ok"],"old saves without economy accepted");await transition()
	check(economy.money==50 and economy.day_serial==0 and economy.quantity("water")==2,"old save gets first-day baseline once before its next manual save")
	game.start_new_game();await transition();check(economy.money==50 and economy.day_serial==0 and economy.quantity("bread")==1,"new game resets independent economy")
	var report: Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"daily_allowance_g":50,"income_boundary":"深夜 → 凌晨","time_remains_period_only":true,"currency":"g","item_types":economy.catalog.size(),"buy_sell_and_use":true,"economy_saved":true,"no_duplicate_allowance_after_load":true,"legacy_save_compatible":true,"original_assets_edited":false}
	var file:=FileAccess.open(game.package_root.path_join("runtime/economy_checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("ECONOMY_CHECK ",checks," FAILURES ",failures.size());game.queue_free();await frames();quit(0 if failures.is_empty() else 1)
