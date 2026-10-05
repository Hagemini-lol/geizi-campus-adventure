## 同一画面内的战场：斜后方观察构图，背景、近景我方和远景敌方分层。
extends Control

## 在编辑器直接指定其它背景素材；留空时显示中性的透视地面。
@export var background_texture: Texture2D
@export var fallback_color: Color = Color("#454e4e")
## 人物脚底在战场内的归一化坐标，调整其它背景时可同步修改。
@export var ally_foot: Vector2 = Vector2(0.25, 0.90)
@export var enemy_foot: Vector2 = Vector2(0.73, 0.60)
## 近大远小的立绘高度，比例相对于战场高度。
@export_range(0.1, 1.5) var ally_height_ratio: float = 0.91
@export_range(0.1, 1.5) var enemy_height_ratio: float = 0.42
var background_view: TextureRect
var ally_slot: Control
var enemy_slot: Control

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_view = TextureRect.new()
	background_view.name = "UIBattleBackground"
	background_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_view)
	# 远处敌方先绘制；我方位于同一战场前景。
	enemy_slot = preload("res://scenes/ui/battle/components/combatant_sprite.tscn").instantiate()
	enemy_slot.name = "UIEnemyCombatant"
	enemy_slot.side_title = "敌方"
	add_child(enemy_slot)
	ally_slot = preload("res://scenes/ui/battle/components/combatant_sprite.tscn").instantiate()
	ally_slot.name = "UIAllyCombatant"
	ally_slot.side_title = "我方"
	ally_slot.combatant_name = "赵慕gei"
	ally_slot.use_project_hero = true
	add_child(ally_slot)
	set_background(background_texture)
	resized.connect(_sync_composition)
	_sync_composition()

## 即时切换背景，仅影响环境层；null 恢复中性占位环境。
func set_background(texture: Texture2D) -> void:
	background_texture = texture
	if is_instance_valid(background_view):
		background_view.texture = texture
		background_view.visible = texture != null
	queue_redraw()

## 适配其它背景的角色脚底位置和大小，不改变立绘或 UI 菜单。
func set_composition(near_foot: Vector2, far_foot: Vector2, near_height: float = 0.91, far_height: float = 0.42) -> void:
	ally_foot = near_foot.clamp(Vector2.ZERO, Vector2.ONE)
	enemy_foot = far_foot.clamp(Vector2.ZERO, Vector2.ONE)
	ally_height_ratio = clampf(near_height, 0.1, 1.5)
	enemy_height_ratio = clampf(far_height, 0.1, 1.5)
	_sync_composition()

func _sync_composition() -> void:
	if not is_instance_valid(ally_slot):
		return
	_place_actor(ally_slot, ally_foot, ally_height_ratio)
	_place_actor(enemy_slot, enemy_foot, enemy_height_ratio)
	queue_redraw()

func _place_actor(actor: Control, foot: Vector2, height_ratio: float) -> void:
	var height := size.y * height_ratio
	actor.size = Vector2(height * 0.73, height)
	actor.position = size * foot - Vector2(actor.size.x * 0.5, height - 26)

func _draw() -> void:
	if background_texture != null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), fallback_color)
	var horizon := size.y * 0.33
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), Color(0.30, 0.34, 0.33))
	var vanishing := Vector2(size.x * 0.73, horizon)
	# 低对比度透视线提示景深；替换背景后自动隐藏。
	for fraction in [-0.6, -0.1, 0.4, 0.9, 1.4, 1.9]:
		draw_line(vanishing, Vector2(size.x * fraction, size.y), Color(0.72, 0.76, 0.74, 0.08), 1.0)
	for fraction in [0.43, 0.60, 0.84]:
		draw_line(Vector2(0, size.y * fraction), Vector2(size.x, size.y * fraction), Color(0.72, 0.76, 0.74, 0.06), 1.0)
