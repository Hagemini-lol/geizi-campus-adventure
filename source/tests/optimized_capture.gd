extends "res://tests/facade_capture.gd"

func capture() -> void:
	game=(load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	if not game.load_error.is_empty(): quit(1); return
	game.player.set_physics_process(false)
	out=game.package_root.get_base_dir().path_join("地图重绘预览/修复与优化预览")
	DirAccess.make_dir_recursive_absolute(out)
	await shot(Vector2(527,1343),1.25,Vector2.ZERO,"南门.png")
	await shot(Vector2(245,68),1.25,Vector2.ZERO,"北门.png")
	await shot(Vector2(395,1283),1.25,Vector2(0,-2),"户外屏幕.png")
	await shot(Vector2(925,185),.58,Vector2(0,-8),"体育馆全景.png")
	await shot(Vector2(925,185),1.25,Vector2(0,-2),"体育馆近景.png")
	await shot(Vector2(925,185),.58,Vector2(0,-8),"体育馆碰撞.png",true)
	await shot(Vector2(527,1120),1.25,Vector2(0,-4.5),"合成楼体窗户.png")
	print("OPTIMIZED_CAPTURES ",out)
	quit()
