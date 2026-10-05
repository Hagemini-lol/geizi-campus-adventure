## 文档截图工具：实际渲染空战斗框架，不注入任何具体招式。
extends SceneTree

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	var preview = load("res://scenes/ui/battle/battle_preview.tscn").instantiate()
	root.add_child(preview)
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/battle-ui/battle-framework-preview.png")
	var battle = preview.get_node("BattleInterface")
	battle.open_category(&"attack")
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/battle-ui/battle-submenu-preview.png")
	print("Rendered battle framework and empty submenu previews.")
	quit()
