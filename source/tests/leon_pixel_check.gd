extends SceneTree
var game: Node2D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.game_started=true;game.front_end.hide_title();game.story_system.stage=6;game.story_system.reward_given=true;game.campaign.index=30;game.day_clock.current_period=4
	await game.change_interior({"building":"B01","floor":3,"kind":"classroom","room":0})
	await process_frame;await process_frame
	var record: Dictionary={}
	for row: Dictionary in game.terrain.current_scene.npcs.records:
		if row["character"]=="fei_yan":record=row;break
	check(not record.is_empty() and record.has("gait"),"Feiyan overworld uses live animated Leon sprite")
	if not record.is_empty() and record.has("gait"):
		var gait: RefCounted=record["gait"]
		check(gait.pixel_sheet!=null and gait.pixel_sheet.get_size()==Vector2(512,480),"single small 12-pose atlas")
		check(record["sprite"].texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"pixel sprite uses nearest sampling")
		for facing: int in range(4):
			gait.face(facing);gait.stop()
			check(record["sprite"].texture.region==Rect2(facing*128,0,128,160),"idle direction "+str(facing))
			for step: int in range(10):
				gait.advance(.13,1000)
				check(gait.rate<=4 and record["sprite"].texture.region.position.y in [160.0,320.0],"walking alternates two actual poses and caps fps")
			gait.stop();check(gait.rate==0,"standing stops animation")
	check(game.npc_catalog.dialogue_portrait("fei_yan").get_height()>1000,"original full-size Leon dialogue render remains separate")
	game.terrain.current_scene.npcs.set_process(false)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(game.package_root.path_join("runtime/v15-leon-world.png"))
	game.day_clock.current_period=1;game.sync_classroom_period();await process_frame
	check(game.terrain.current_scene.npcs.records.size()==32,"pixel replacement preserves seated class and collision occupants")
	var f:=FileAccess.open(game.package_root.path_join("runtime/leon_pixel_checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures},"  "))
	print("LEON_PIXEL_CHECKS ",checks," FAILURES ",failures.size());game.queue_free();game=null;await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
