extends RefCounted

func run(game: Node2D) -> void:
	if game.world_editor.unlocked:return
	var story: Node2D=game.story_system
	story.begin_sequence();game.music.story_tone="heroic"
	var origin: Vector2=game.player.position
	var nav: RefCounted=game.motion_navigation()
	var teacher: Sprite2D=story.make_actor("english_teacher",landing(game,nav,origin+Vector2(-28,-5)),40.8)
	var gou: Sprite2D=story.make_actor("gou_ga",landing(game,nav,origin+Vector2(28,-5)),40.8)
	teacher.modulate=Color(.65,.85,1,.8);gou.modulate=Color(.85,.65,1,.8)
	await game.campaign.dialog([{"actor":"system","text":"手机屏幕变成一面没有倒影的窗。老美子与勾尬的魔力影像从窗口两侧显现。"+("她们留在这个世界的魔力记录仍在，但已经死去的人没有回来。" if not game.relationships.alive("english_teacher") or not game.relationships.alive("gou_ga") else "两人隔着光幕看向 gei 子，仿佛早已听见他按下确认的声音。")},{"actor":"english_teacher","text":"少年，语言能描述世界。现在，来自世界之外的力量，允许你改写其中的数字。但你做过的选择，不会因此变成没发生过。"},{"actor":"gou_ga","text":"拿去吧，gei 子。别再说你不知道自己在改什么。力量交到你手里，怎么用，就是你的选择。"}])
	await story.play_effect("world_magic_circle",origin-Vector2(0,7),110,.8)
	await story.play_effect("light_medium",teacher.position-Vector2(0,20),90,.5)
	await story.play_effect("lightning_high",gou.position-Vector2(0,20),105,.55)
	await transfer(game,teacher,gou,origin-Vector2(0,18))
	var old_color: Color=game.player.modulate
	var pulse:=game.create_tween();pulse.tween_property(game.player,"modulate",Color(1.5,1.7,2),.22);pulse.tween_property(game.player,"modulate",old_color,.35);await pulse.finished
	await game.campaign.dialog([{"actor":"zhao_mugei","text":"每一条魔力回路都亮起来了……这不是我练会的法术，是直接把整个世界的刻度交到了我手上。"},{"actor":"system","text":"庞大的力量涌入 gei 子。手机上的数字一行行浮现，教室与天空像被同一只手轻轻翻动。"}])
	game.world_editor.unlocked=true
	var hero: Dictionary=game.combat_rules.hero
	for field: String in ["attack","hp","mp","energy"]:
		game.world_editor.edit("hero","",field,mini(1000000000,int(hero[field])*(3 if field=="attack" else 2)+(500 if field in ["attack","hp"] else 200)))
	game.combat_rules.refill_hero()
	game.campaign.change_san(100)
	var offset: Vector2=game.player.camera.offset
	# One timeline and one completion signal: low FPS cannot lose a second signal.
	var finale:=game.create_tween().set_parallel(true)
	if bool(game.preferences.values["camera_shake"]):
		for i: int in range(5):
			var x: float=[2.0,-2.0,1.5,-1.5,0.0][i]
			finale.tween_property(game.player.camera,"offset",offset+Vector2(x,0),.08).set_delay(i*.08)
	var old_fade: Color=game.fade.color;game.fade.color=Color.WHITE;game.fade.modulate.a=0
	var strength:=.12 if bool(game.preferences.values["reduce_flash"]) else .45
	finale.tween_property(game.fade,"modulate:a",strength,.14)
	finale.tween_property(game.fade,"modulate:a",0,.22).set_delay(.14)
	finale.tween_interval(.4)
	await finale.finished
	game.player.camera.offset=offset;game.fade.color=old_fade;game.fade.modulate.a=0
	story.clear_actors();game.player.modulate=old_color
	game.record_game_event("forbidden/inherited");story.end_sequence()

func transfer(game: Node2D, teacher: Sprite2D, gou: Sprite2D, target: Vector2) -> void:
	# Two short beams and eight moving sparks; no particle emitter or texture allocation.
	var light:=Node2D.new();light.name="ForbiddenTransfer";light.z_index=90;game.add_child(light)
	var animation:=game.create_tween().set_parallel(true)
	for i: int in range(2):
		var start: Vector2=(teacher.position if i==0 else gou.position)-Vector2(0,18)
		var tint:=Color(.55,.85,1) if i==0 else Color(.85,.55,1)
		var beam:=Line2D.new();beam.points=PackedVector2Array([start,target]);beam.width=.5;beam.default_color=tint;beam.modulate.a=0;light.add_child(beam)
		animation.tween_property(beam,"width",3.0,.35)
		animation.tween_property(beam,"modulate:a",.85,.25)
		animation.tween_property(beam,"modulate:a",0,.3).set_delay(.9)
		for j: int in range(4):
			var spark:=Polygon2D.new();spark.polygon=PackedVector2Array([Vector2(0,-2),Vector2(2,0),Vector2(0,2),Vector2(-2,0)]);spark.color=tint;spark.position=start;spark.modulate.a=0;light.add_child(spark)
			animation.tween_property(spark,"modulate:a",1,.1).set_delay(j*.14)
			animation.tween_property(spark,"position",target,.6).set_delay(j*.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			animation.tween_property(spark,"modulate:a",0,.12).set_delay(j*.14+.6)
	game.sounds.play("light")
	await animation.finished
	game.record_game_event("forbidden/transfer_visual")
	light.queue_free()

func landing(game: Node2D, nav: RefCounted, preferred: Vector2) -> Vector2:
	return game.safe_outdoor(preferred) if game.interior_state.is_empty() else nav.safe_landing(preferred)
