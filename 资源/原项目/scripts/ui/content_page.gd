## [素材用途] 状态、装备、物品、技能内容页的共用结构：标题与条目列表可独立更新或整页替换。
extends VBoxContainer

const Style = preload("res://scripts/ui/ui_style.gd")
## 独立内容页标题。
@export var page_title: String = "当前状态"
## 列表为空时显示的提示。
@export var empty_text: String = "无特殊状态"
var body: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 16)
	add_child(Style.label(page_title, 20))
	var divider := HSeparator.new()
	add_child(divider)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	add_child(body)
	set_items([])

func set_items(lines: Array[String]) -> void:
	if not is_instance_valid(body):
		return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if lines.is_empty():
		body.add_child(Style.label(empty_text, 16))
	else:
		for line in lines:
			body.add_child(Style.label(line, 16))
