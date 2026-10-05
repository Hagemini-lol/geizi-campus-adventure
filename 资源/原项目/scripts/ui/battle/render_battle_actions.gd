## 实际渲染定格演出素材，复用可播放的差分和特效。
extends SceneTree

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	var preview = load("res://scenes/ui/battle/battle_actions_preview.tscn").instantiate()
	root.add_child(preview)
	for frame in range(8):
		await process_frame
	for sample in ["punch", "dodge_success", "dodge_failure", "hit", "auto_battle"]:
		preview.presenter.show_sample(sample)
		for frame in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/battle-ui/actions/" + sample + "-preview.png")
	print("Rendered five battle action/effect previews.")
	quit()
