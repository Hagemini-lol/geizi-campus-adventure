## [素材用途] 文档预览导出工具：用 Godot 实际渲染 HUD、菜单和设置页截图，不参与游戏运行。
extends SceneTree

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	var preview = load("res://scenes/ui/modular_ui_preview.tscn").instantiate()
	root.add_child(preview)
	for index in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/ui-components/gameplay-preview.png")
	preview.show_menu()
	for index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/ui-components/menu-preview.png")
	preview.menu.select_tab("settings")
	for index in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/ui-components/settings-preview.png")
	print("Rendered reusable HUD, menu and settings previews.")
	quit()
