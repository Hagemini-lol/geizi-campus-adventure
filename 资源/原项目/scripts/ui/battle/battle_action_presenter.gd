## 战斗动作演出组件：切换透明差分并播放独立特效，不计算伤害或成功率。
extends Node

signal presentation_finished
@export_file("*.json") var catalog_path: String = "res://data/battle_action_library.json"
## 挂到 UI 前指定共用战场；演出层放在外层 UI，避免头顶对白被战场裁切。
var stage: Control
var effect_layer: Control
var active_effects: Array[Control] = []
var pose_textures: Dictionary = {}
var motion: Tween
var busy: bool = false
var _origins: Dictionary = {}
const EFFECT_SCENES := {
	"hit": preload("res://scenes/ui/battle/effects/hit_effect.tscn"),
	"dodge_success": preload("res://scenes/ui/battle/effects/dodge_success_effect.tscn"),
	"dodge_failure": preload("res://scenes/ui/battle/effects/dodge_failure_effect.tscn"),
	"auto_battle": preload("res://scenes/ui/battle/effects/auto_battle_effect.tscn")
}

func _ready() -> void:
	effect_layer = Control.new()
	effect_layer.name = "UIBattleActionEffects"
	effect_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_layer.z_index = 20
	get_parent().add_child.call_deferred(effect_layer)
	if is_instance_valid(stage):
		stage.resized.connect(_on_stage_resized)
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if catalog is Dictionary:
		for entry in catalog.get("poses", []):
			if entry is Dictionary:
				pose_textures[str(entry.get("id", ""))] = load(str(entry.get("texture", "")))

## 任意新演出都会取消上一段并恢复姿势/位置，不遗留对白或命中闪光。
func stop() -> void:
	if motion != null and motion.is_valid():
		motion.kill()
	busy = false
	for effect in active_effects:
		if is_instance_valid(effect):
			effect.stop()
			effect.queue_free()
	active_effects.clear()
	if is_instance_valid(stage):
		for actor in [stage.ally_slot, stage.enemy_slot]:
			if _origins.has(actor):
				actor.position = _origins[actor]
			actor.restore_pose()
			actor.portrait_view.modulate = Color.WHITE
	_origins.clear()

func _begin() -> bool:
	stop()
	if not is_instance_valid(stage) or not effect_layer.is_inside_tree():
		return false
	_origins[stage.ally_slot] = stage.ally_slot.position
	_origins[stage.enemy_slot] = stage.enemy_slot.position
	busy = true
	return true

## 拳击演出：出拳差分、小幅前冲、敌方位置命中闪光、恢复基础姿势。
func play_punch() -> bool:
	if not pose_textures.get("punch") is Texture2D or not _begin():
		return false
	stage.ally_slot.set_pose(pose_textures["punch"])
	motion = create_tween()
	motion.tween_property(stage.ally_slot, "position", stage.ally_slot.position + Vector2(22, -5), 0.10)
	motion.tween_callback(_spawn_effect.bind("hit", stage.enemy_slot))
	motion.tween_interval(0.45)
	motion.tween_callback(_complete)
	return true

## 闪避结果由调用者提供；成功显示清色拖线，失败显示红色冲击与短暂受击染色。
func play_dodge(success: bool) -> bool:
	if not pose_textures.get("dodge") is Texture2D or not _begin():
		return false
	stage.ally_slot.set_pose(pose_textures["dodge"])
	motion = create_tween()
	motion.tween_property(stage.ally_slot, "position", stage.ally_slot.position + Vector2(-28, 5), 0.13)
	motion.tween_callback(_dodge_feedback.bind(success))
	motion.tween_interval(0.68)
	motion.tween_callback(_complete)
	return true

func _dodge_feedback(success: bool) -> void:
	_spawn_effect("dodge_success" if success else "dodge_failure", stage.ally_slot)
	if not success:
		stage.ally_slot.portrait_view.modulate = Color(1.0, 0.62, 0.62)

## 通用命中特效支持我方或敌方位置；不会改动血量或推进回合。
func play_hit(target_side: StringName = &"enemy") -> bool:
	if target_side not in [&"ally", &"enemy"] or not _begin():
		return false
	var actor: Control = stage.ally_slot if target_side == &"ally" else stage.enemy_slot
	_spawn_effect("hit", actor)
	motion = create_tween()
	motion.tween_property(actor, "position", actor.position + Vector2(6, 0), 0.05)
	motion.tween_property(actor, "position", _origins[actor] - Vector2(5, 0), 0.05)
	motion.tween_property(actor, "position", _origins[actor], 0.05)
	motion.tween_interval(0.42)
	motion.tween_callback(_complete)
	return true

## 挂机专属头顶对白；只显示演出，自动选择招式由以后战斗系统负责。
func play_auto_battle() -> bool:
	if not _begin():
		return false
	_spawn_effect("auto_battle", stage.ally_slot)
	motion = create_tween()
	motion.tween_interval(2.8)
	motion.tween_callback(_complete)
	return true

func _complete() -> void:
	stop()
	presentation_finished.emit()

func _spawn_effect(kind: String, actor: Control, sample_time: float = -1.0) -> void:
	var effect: Control = EFFECT_SCENES[kind].instantiate()
	effect.autoplay = sample_time < 0
	if kind == "auto_battle":
		effect.size = Vector2(240, 64)
	else:
		var extent := clampf(actor.size.y * 0.78, 130.0, 250.0)
		effect.size = Vector2(extent * 1.2, extent)
	effect_layer.add_child(effect)
	var actor_origin := actor.global_position - effect_layer.global_position
	if kind == "auto_battle":
		# 以实际可见立绘的头顶定位对白，同时留在屏幕范围内。
		var x := actor_origin.x + actor.size.x * 0.5 - effect.size.x * 0.5
		effect.position = Vector2(clampf(x, 4, maxf(4, effect_layer.size.x - effect.size.x - 4)), maxf(4, actor_origin.y - 66))
	else:
		effect.position = actor_origin + Vector2(actor.size.x * 0.5, (actor.size.y - 26) * 0.46) - effect.size * 0.5
		if kind.begins_with("dodge_"):
			effect.text_label.position.y = maxf(4, actor_origin.y - 28) - effect.position.y
	active_effects.append(effect)
	effect.finished.connect(effect.queue_free)
	if sample_time >= 0:
		effect.seek(sample_time)

## 定格素材样片，供预览/导出使用；与播放逻辑共用差分和特效场景。
func show_sample(sample: String) -> bool:
	if sample not in ["punch", "dodge_success", "dodge_failure", "hit", "auto_battle"]:
		return false
	if not _begin():
		return false
	busy = false
	if sample == "punch":
		stage.ally_slot.set_pose(pose_textures["punch"])
		_spawn_effect("hit", stage.enemy_slot, 0.18)
	elif sample.begins_with("dodge_"):
		stage.ally_slot.set_pose(pose_textures["dodge"])
		stage.ally_slot.position.x -= 28
		_dodge_sample(sample)
	else:
		_spawn_effect(sample, stage.ally_slot, 0.18)
	return true

func _dodge_sample(sample: String) -> void:
	_spawn_effect(sample, stage.ally_slot, 0.22)
	if sample == "dodge_failure":
		stage.ally_slot.portrait_view.modulate = Color(1.0, 0.62, 0.62)

func _on_stage_resized() -> void:
	stop()
	# 旧像素坐标不能恢复到新尺寸上，交由战场归一化构图重新定位。
	stage.call_deferred("_sync_composition")

func _exit_tree() -> void:
	if motion != null and motion.is_valid():
		motion.kill()
	if is_instance_valid(effect_layer):
		effect_layer.queue_free()
