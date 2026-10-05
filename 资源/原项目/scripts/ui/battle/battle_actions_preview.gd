## 专用动作素材预览；按钮展示演出，不往六类空招式菜单写入条目。
extends Control

const Style = preload("res://scripts/ui/ui_style.gd")
var battle: Control
var presenter: Node

func _ready() -> void:
	theme = Style.theme(18)
	var background := ColorRect.new()
	background.color = Color("#4d6059")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	battle = preload("res://scenes/ui/battle/battle_interface.tscn").instantiate()
	battle.name = "BattleInterface"
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(battle)
	presenter = battle.action_presenter
	battle.turn_label.text = "动作素材预览"
	battle.idle_label.hide()
	var samples := GridContainer.new()
	samples.name = "UIActionPreviewControls"
	samples.anchor_left = 0.04
	samples.anchor_right = 0.96
	samples.anchor_top = 0.78
	samples.anchor_bottom = 0.95
	samples.columns = 6
	samples.add_theme_constant_override("h_separation", 8)
	add_child(samples)
	var names := ["拳击", "闪避成功", "闪避失败", "命中我方", "挂机对白", "恢复"]
	for i in range(names.size()):
		var button: Button = preload("res://scenes/ui/components/option_button.tscn").instantiate()
		button.option_text = names[i]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 50
		samples.add_child(button)
		button.pressed.connect(_select_sample.bind(i))

func _select_sample(index: int) -> void:
	battle.return_to_categories()
	battle.idle_label.hide()
	match index:
		0: presenter.play_punch()
		1: presenter.play_dodge(true)
		2: presenter.play_dodge(false)
		3: presenter.play_hit(&"ally")
		4: presenter.play_auto_battle()
		5: presenter.stop()
