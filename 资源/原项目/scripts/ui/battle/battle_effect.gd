## 独立像素块战斗特效；仅演出反馈，不判定命中、闪避或战斗结果。
extends Control

signal finished
const Style = preload("res://scripts/ui/ui_style.gd")
@export_enum("hit", "dodge_success", "dodge_failure", "auto_battle") var effect_kind: String = "hit"
@export_range(0.1, 10.0) var duration: float = 0.55
@export var autoplay: bool = true
## 挂机对白为可编辑文本，确保游戏内中文和大小写准确。
@export var dialogue: String = "woc我忘吃饭了"
var elapsed: float = 0.0
var playing: bool = false
var text_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.theme(18)
	text_label = Style.label("", 18)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(text_label)
	resized.connect(_sync_text)
	_sync_text()
	if autoplay:
		play()
	else:
		hide()

func play() -> void:
	elapsed = 0.0
	playing = true
	show()
	queue_redraw()

## 可供编辑器演出工具定位某一时刻；暂停时不会自动消失。
func seek(seconds: float) -> void:
	elapsed = clampf(seconds, 0.0, duration)
	playing = false
	show()
	queue_redraw()

func stop() -> void:
	playing = false
	hide()

func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	if elapsed >= duration:
		playing = false
		hide()
		finished.emit()
	queue_redraw()

func _sync_text() -> void:
	if not is_instance_valid(text_label):
		return
	if effect_kind == "auto_battle":
		text_label.text = dialogue
		text_label.position = Vector2(8, 5)
		text_label.size = Vector2(size.x - 16, size.y - 18)
	else:
		text_label.text = "闪避成功" if effect_kind == "dodge_success" else ("闪避失败" if effect_kind == "dodge_failure" else "")
		text_label.position = Vector2(0, 0)
		text_label.size = Vector2(size.x, 30)
		text_label.add_theme_color_override("font_color", Color("#c4ded4") if effect_kind == "dodge_success" else Color("#e6a8a5"))

func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	if effect_kind == "auto_battle":
		_draw_dialogue(progress)
		return
	var unit := minf(size.x / 240.0, size.y / 200.0)
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.56), 0.0, Vector2(unit, unit))
	var alpha := 1.0 - smoothstep(0.50, 1.0, progress)
	match effect_kind:
		"hit":
			_draw_impact(progress, Color(0.98, 0.84, 0.46, alpha), Color(1, 1, 0.91, alpha))
		"dodge_success":
			for trail in range(3):
				for segment in range(10):
					var angle := -1.4 + float(segment) * 0.18
					var radius := 42.0 + float(trail) * 13.0 + progress * 28.0
					var point := Vector2(cos(angle) * radius - 35, sin(angle) * radius)
					draw_rect(Rect2(point.snapped(Vector2(4, 4)), Vector2(8, 8)), Color(0.67, 0.88, 0.81, alpha * (1.0 - float(trail) * 0.22)))
			for line in range(3):
				draw_rect(Rect2(-70 - progress * 20, -25 + line * 24, 35 + line * 8, 4), Color(0.9, 1, 0.97, alpha))
		"dodge_failure":
			_draw_impact(progress, Color(0.85, 0.30, 0.28, alpha), Color(1, 0.84, 0.80, alpha))
			for point in range(-5, 6):
				draw_rect(Rect2(Vector2(point * 7, point * 7), Vector2(9, 9)), Color(0.95, 0.50, 0.46, alpha))
				draw_rect(Rect2(Vector2(point * 7, -point * 7), Vector2(9, 9)), Color(0.95, 0.50, 0.46, alpha))

func _draw_impact(progress: float, outer: Color, inner: Color) -> void:
	var radius := 25.0 + sin(progress * PI) * 28.0
	var star := PackedVector2Array()
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var length := radius if i % 2 == 0 else radius * 0.36
		star.append((Vector2(cos(angle), sin(angle)) * length).snapped(Vector2(4, 4)))
	draw_colored_polygon(star, outer)
	draw_rect(Rect2(-8, -8, 16, 16), inner)
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var point := (Vector2(cos(angle), sin(angle)) * (44 + progress * 40)).snapped(Vector2(4, 4))
		draw_rect(Rect2(point, Vector2(6, 6)), outer)

func _draw_dialogue(progress: float) -> void:
	var alpha := 1.0 - smoothstep(0.88, 1.0, progress)
	var box := Rect2(3, 3, size.x - 6, size.y - 14)
	draw_rect(box, Color(0.06, 0.09, 0.11, 0.89 * alpha))
	draw_rect(box, Color(0.81, 0.85, 0.83, alpha), false, 2.0)
	# 台阶状尾巴指向主角头顶，保留像素风格。
	var x := floorf(size.x * 0.5)
	for step in range(3):
		draw_rect(Rect2(x - 6 + step * 2, size.y - 13 + step * 3, 12 - step * 4, 3), Color(0.81, 0.85, 0.83, alpha))
	if is_instance_valid(text_label):
		text_label.modulate.a = alpha
