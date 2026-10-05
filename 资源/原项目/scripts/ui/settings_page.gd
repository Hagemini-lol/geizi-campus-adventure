## [素材用途] 设置内容页：独立保存、加载、退出、脱离卡死按钮只发送操作信号，具体行为由游戏实现。
extends VBoxContainer

## 四个操作各自输出稳定标识；本页不直接写存档或退出游戏。
signal action_requested(action: StringName)
const Style = preload("res://scripts/ui/ui_style.gd")
const Options := {
	"save": preload("res://scenes/ui/options/save_button.tscn"),
	"load": preload("res://scenes/ui/options/load_button.tscn"),
	"exit": preload("res://scenes/ui/options/exit_button.tscn"),
	"unstuck": preload("res://scenes/ui/options/unstuck_button.tscn")
}
var buttons: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(Style.label("设置", 20))
	for id in Options:
		var button = Options[id].instantiate()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(button)
		button.pressed.connect(func(): action_requested.emit(StringName(id)))
		buttons[id] = button
