extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames() -> void:await process_frame;await process_frame
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await frames();game.start_new_game()
	while game.transition_busy:await process_frame
	game.story_system.stage=1;game.story_system.refresh_objective()
	var regions: RefCounted=game.story_regions;regions.game=game
	check(not game.story_system.objective.visible,"no story trigger text overlay")
	check(game.interactions().filter(func(item: Dictionary):return item["action"] in ["story_window","story_seat","campaign","side_quest"]).is_empty(),"story triggers absent from manual interaction HUD")
	game.player.position=game.story_system.rear_point+Vector2(0,-90);game.player.path.clear();game.player.velocity=Vector2.ZERO
	game.interaction_delay=0;game.paused=true;game.refresh_player_freeze()
	check(not regions.tick() and not game.story_system.running,"paused exploration does not trigger")
	game.paused=false;game.refresh_player_freeze();game.menu_view.show()
	check(not regions.tick() and not game.story_system.running,"menu blocks region trigger")
	game.menu_view.hide();game.refresh_player_freeze()
	var candidate: Dictionary=regions.candidates().filter(func(item: Dictionary):return item["action"]=="story_window")[0]
	check(regions.radius_for(candidate)>game.INTERACTION_RADIUS,"region larger than manual interaction reach")
	check(not game.within_interaction(candidate["at"]),"fixture lies beyond manual reach")
	game.transition_busy=true;check(not regions.tick(),"transition blocks trigger");game.transition_busy=false
	game.battle_view.show();check(not regions.tick(),"battle blocks trigger");game.battle_view.hide()
	game.dialogue_view.show();check(not regions.tick(),"dialogue blocks trigger");game.dialogue_view.hide()
	game.refresh_player_freeze();check(regions.tick(),"entering broad range automatically starts story")
	var deadline:=Time.get_ticks_msec()+5000
	while not game.dialogue_view.visible and Time.get_ticks_msec()<deadline:await process_frame
	check(game.story_system.running and game.dialogue_view.visible,"actual story dialogue starts without key or click")
	check(not regions.tick(),"running story cannot retrigger")
	check(game.player.path.is_empty() and game.player.velocity.is_zero_approx(),"story entry stops movement")
	var f:=FileAccess.open(game.package_root.path_join("runtime/story_region_checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures},"  "))
	print("STORY_REGION_CHECK ",checks," FAILURES ",failures.size());game.queue_free();game=null;await process_frame;quit(0 if failures.is_empty() else 1)
