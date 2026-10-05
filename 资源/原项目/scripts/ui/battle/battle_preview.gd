## 独立战斗素材预览：提供中性背景，不接入当前校园场景或实际战斗。
extends Control

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("#4d6059")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var battle = preload("res://scenes/ui/battle/battle_interface.tscn").instantiate()
	battle.name = "BattleInterface"
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(battle)
