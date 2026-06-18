extends CharacterBody2D
class_name RobotUnit

signal robot_lost(robot: Node, reason: StringName)

const CombatTargetRegistryScript := preload("res://Scripts/map/combat_target_registry.gd")
const TacticalTemplateCompilerScript := preload("res://Scripts/ai/tactical_template_compiler.gd")
const ACTION_ICON_RALLY := preload("res://Resources/art/ui/state_rally.svg")
const ACTION_ICON_WAIT := preload("res://Resources/art/ui/state_wait.svg")
const ACTION_ICON_DEFAULT_BRAIN := preload("res://Resources/art/ui/state_default_brain.svg")

@export var display_name: String = "基础步枪机器人"
@export var max_hp: int = 60
@export var speed: float = 90.0
@export_enum("Team_A", "Team_B") var team: String = "Team_A"
@export var tags: Array[String] = []
@export var lifespan_seconds: float = 120.0
@export var pool_name: String = "robot_basic"
@export var fire_range: float = 140.0
@export var target_lock_seconds: float = 1.5
@export var bullet_damage: int = 8
@export var fire_cooldown_seconds: float = 0.8
@export var damage_type: StringName = &"kinetic"
@export var armor_type: StringName = &"light"
@export var heat_capacity: float = 0.0
@export var heat_per_shot: float = 0.0
@export var heat_cooling_per_second: float = 0.0
@export var overheat_threshold: float = 0.0
@export var overheated_resume_threshold: float = 0.0
@export var minimum_overheat_lock_seconds: float = 1.0
@export var weapon_enabled: bool = true
@export_enum("default_combat", "path_patrol", "melee_hound", "logistics", "idle") var brain_mode: String = "default_combat"
@export var default_brain_enabled: bool = true
@export var preferred_range_ratio: float = 0.85
@export var range_dead_zone: float = 12.0
@export var visual_size: Vector2 = Vector2(42, 42)
@export var muzzle_distance: float = 24.0
@export var turn_speed_radians: float = 12.0
@export var fire_arc_radians: float = 0.16
@export_file("*.svg") var icon_path: String = "res://Resources/art/blueprints/basic_rifle_robot.svg"
@export var melee_damage: int = 0
@export var melee_range: float = 32.0
@export var melee_cooldown_seconds: float = 1.0
@export var guard_aggro_radius: float = 0.0
@export var hound_follow_up_radius: float = 180.0
@export var separation_radius: float = 34.0
@export var separation_strength: float = 28.0
@export var separation_max_step: float = 8.0
@export var melee_target_lateral_offset: float = 14.0
@export var navigation_repath_interval_seconds: float = 0.35
@export var navigation_target_move_threshold: float = 40.0
@export var navigation_waypoint_tolerance: float = 20.0

var hp: int = 60
var blueprint_id: StringName = &""
var blueprint_version: int = 0
var blueprint_snapshot_id: StringName = &""
var chassis_id: StringName = &""
var weapon_audio_id: StringName = &"rifle_module"
var active_upgrade_ids: Array[StringName] = []
var rally_point_position: Vector2 = Vector2.ZERO
var has_rally_point: bool = false
var producer_forge_name: String = ""
var cargo_capacity: int = 0
var cargo_inventory: Dictionary = {}
var logistics_status_text: String = "无物流能力"
var current_logistics_task: Dictionary = {}

var current_target: Node2D = null
var current_action: String = "闲置"
var current_fire_state: String = "无目标"
var current_distance_to_target: float = -1.0
var patrol_points: Array[Vector2] = []
var patrol_loop: bool = true
var source_nest: Node = null
var guard_home_position: Vector2 = Vector2.ZERO

var _is_dead: bool = false
var _selected: bool = false
var _patrol_index: int = 0
var _loaded_icon_path: String = ""
var _facing_angle: float = 0.0
var _brain_trigger_history: Array[String] = []
var _last_brain_trigger_key: StringName = &""
var _last_brain_trigger_msec: int = 0
var _current_rule_bubble_text: String = ""
var _current_rule_bubble_until_msec: int = 0
var _last_melee_attack_seconds: float = -9999.0
var _locked_target: Node2D = null
var _target_lock_until_msec: int = 0
var _hound_has_engaged: bool = false
var _combat_target_registry: Node = null
var _last_damage_source_payload: Dictionary = {}
var _damage_flash_until_msec: int = 0
var _rallied_at_msec: int = 0
var current_heat: float = 0.0
var is_overheated: bool = false
var overheat_locked_until_msec: int = 0
var _active_heat_hold: bool = false
var _death_tween: Tween = null
var _module_icon_path: String = ""
var _loaded_module_icon_path: String = ""
var _chainsaw_swing_until_msec: int = 0
var _chainsaw_hit_center: Vector2 = Vector2.ZERO
var _navigation_path: PackedVector2Array = PackedVector2Array()
var _navigation_path_index: int = 0
var _navigation_target_position: Vector2 = Vector2.INF
var _navigation_target_instance_id: int = 0
var _navigation_target_cell: Vector2i = Vector2i(-1, -1)
var _navigation_next_repath_msec: int = 0
var _navigation_path_resolved: bool = false
var action_icon: Sprite2D = null
var module_sprite: Sprite2D = null
var _next_separation_update_msec: int = 0
var _separation_accumulated_delta: float = 0.0
var _chainsaw_visual_was_active: bool = false

@onready var unit_sprite: Sprite2D = get_node_or_null("UnitSprite")
@onready var hp_bar: ProgressBar = get_node_or_null("HPBar")
@onready var heat_bar: ProgressBar = get_node_or_null("HeatBar")
@onready var action_label: Label = get_node_or_null("ActionLabel")
@onready var muzzle: Marker2D = get_node_or_null("Muzzle")
@onready var lifespan_component = get_node_or_null("LifespanComponent")
@onready var health_component = get_node_or_null("HealthComponent")
@onready var movement_component = get_node_or_null("MovementComponent")
@onready var weapon_component = get_node_or_null("WeaponComponent")
@onready var enemy_sensor = get_node_or_null("EnemySensor")
@onready var state_flags = get_node_or_null("UnitStateFlags")
@onready var default_brain = get_node_or_null("DefaultBrain")
@onready var path_follow_brain = get_node_or_null("PathFollowBrain")
@onready var ai_controller = get_node_or_null("AIController")

func _ready() -> void:
	_connect_components()
	_ensure_action_icon()
	reset_state()

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_update_heat(delta)

	match brain_mode:
		"path_patrol":
			if path_follow_brain:
				path_follow_brain.tick(self)
			else:
				current_action = "路径脑干缺失"
				if movement_component:
					movement_component.stop(&"idle")
		"default_combat":
			if default_brain_enabled:
				var rule_handled := false
				if ai_controller and ai_controller.has_method("evaluate_logic"):
					rule_handled = bool(ai_controller.call("evaluate_logic"))
				if rule_handled:
					pass
				elif default_brain:
					default_brain.tick(self)
				else:
					current_action = "默认脑干缺失"
					if movement_component:
						movement_component.stop(&"idle")
		"melee_hound":
			_tick_melee_hound()
		"logistics":
			pass
		_:
			current_action = "闲置"
			if movement_component:
				movement_component.stop(&"idle")

	if movement_component:
		movement_component.apply_to(self)
	_apply_separation_micro_offset(delta)
	_update_facing(delta)
	_update_unit_visuals()

func setup_from_blueprint(blueprint: UnitBlueprint, next_rally_point: Vector2 = Vector2.ZERO, next_has_rally_point: bool = false) -> void:
	if blueprint == null:
		return
	blueprint_id = blueprint.id
	blueprint_version = blueprint.version
	blueprint_snapshot_id = StringName(blueprint.get_snapshot_key())
	chassis_id = blueprint.chassis_id
	weapon_audio_id = _get_primary_weapon_audio_id(blueprint)
	_module_icon_path = _get_primary_module_icon_path(blueprint)
	active_upgrade_ids = blueprint.upgrade_ids.duplicate()
	display_name = blueprint.display_name
	if not blueprint.icon_path.is_empty():
		icon_path = blueprint.icon_path
	if blueprint.stats:
		max_hp = blueprint.stats.max_hp
		speed = blueprint.stats.speed
		lifespan_seconds = blueprint.stats.lifespan_seconds
		target_lock_seconds = blueprint.stats.target_lock_seconds
		fire_range = blueprint.stats.fire_range
		bullet_damage = blueprint.stats.damage
		fire_cooldown_seconds = blueprint.stats.fire_cooldown_seconds
		damage_type = blueprint.stats.damage_type
		armor_type = blueprint.stats.armor_type
		heat_capacity = blueprint.stats.heat_capacity
		heat_per_shot = blueprint.stats.heat_per_shot
		heat_cooling_per_second = blueprint.stats.heat_cooling_per_second
		overheat_threshold = blueprint.stats.overheat_threshold
		overheated_resume_threshold = blueprint.stats.overheated_resume_threshold
	melee_damage = bullet_damage
	melee_range = fire_range
	melee_cooldown_seconds = fire_cooldown_seconds
	cargo_capacity = blueprint.stats.cargo_capacity if blueprint.stats and blueprint.stats.cargo_capacity > 0 else _get_blueprint_cargo_capacity(blueprint)
	if cargo_capacity > 0:
		tags = ["cargo", "logistics"]
		brain_mode = "logistics"
		weapon_enabled = false
		logistics_status_text = "待命"
		current_logistics_task = {
			"task_id": "",
			"type": "idle",
			"status": "等待物流任务",
		}
	else:
		tags = []
		cargo_inventory.clear()
		logistics_status_text = "无物流能力"
		current_logistics_task.clear()
		brain_mode = "default_combat"
		weapon_enabled = bullet_damage > 0 and fire_range > 0.0
	default_brain_enabled = blueprint.default_brain_enabled
	var state_flag_defaults := blueprint.state_flag_defaults
	var logic_rules := blueprint.embedded_rules
	if not blueprint.tactical_templates.is_empty():
		var compiled: Dictionary = TacticalTemplateCompilerScript.compile_templates(blueprint.tactical_templates)
		state_flag_defaults = compiled.get("state_flag_defaults", {})
		logic_rules = compiled.get("rules", [])
	if state_flags:
		state_flags.setup(state_flag_defaults)
	if ai_controller and ai_controller.has_method("set_logic_rules"):
		ai_controller.call("set_logic_rules", logic_rules)
	rally_point_position = next_rally_point
	has_rally_point = next_has_rally_point
	reset_state()

func apply_campaign_upgrades(upgrade_ids: Array[StringName]) -> void:
	active_upgrade_ids = upgrade_ids.duplicate()
	if chassis_id == &"light_chassis":
		if active_upgrade_ids.has(&"light_chassis_hp_1"):
			max_hp += 20
		if active_upgrade_ids.has(&"light_chassis_speed_1"):
			speed *= 1.15
	_configure_components()
	_update_unit_visuals()

func setup_debug_enemy(next_name: String, path_points: Array[Vector2], loop_path: bool = true, config: Dictionary = {}) -> void:
	display_name = next_name if not next_name.is_empty() else str(config.get("display_name", "调试靶机"))
	team = "Team_B"
	brain_mode = "path_patrol"
	blueprint_snapshot_id = &""
	default_brain_enabled = false
	weapon_enabled = false
	max_hp = int(config.get("max_hp", 420))
	speed = float(config.get("speed", 54.0))
	lifespan_seconds = float(config.get("lifespan_seconds", 0.0))
	pool_name = "debug_enemy_unit"
	icon_path = str(config.get("icon_path", "res://Resources/art/units/debug_enemy_unit.svg"))
	set_patrol_path(path_points, loop_path)
	reset_state()

func setup_scavenger_hound(config: Dictionary, nest: Node = null) -> void:
	display_name = str(config.get("display_name", "拾荒猎犬"))
	team = "Team_B"
	brain_mode = "melee_hound"
	blueprint_snapshot_id = &""
	default_brain_enabled = false
	weapon_enabled = false
	max_hp = int(config.get("max_hp", 90))
	speed = float(config.get("speed", 135.0))
	armor_type = StringName(str(config.get("armor_type", "light")))
	damage_type = StringName(str(config.get("damage_type", "melee")))
	lifespan_seconds = 0.0
	pool_name = str(config.get("pool_name", config.get("id", "scavenger_hound")))
	icon_path = str(config.get("icon_path", "res://Resources/art/enemies/scavenger_hound.svg"))
	visual_size = _vector2_from_config(config.get("visual_size", [32.0, 32.0]), Vector2(32.0, 32.0))
	melee_damage = int(config.get("melee_damage", 16))
	melee_range = float(config.get("melee_range", 32.0))
	melee_cooldown_seconds = float(config.get("melee_cooldown_seconds", 1.0))
	guard_aggro_radius = maxf(0.0, float(config.get("guard_aggro_radius", 320.0)))
	hound_follow_up_radius = maxf(0.0, float(config.get("hound_follow_up_radius", 180.0)))
	reset_state()
	source_nest = nest if nest != null and is_instance_valid(nest) else null
	guard_home_position = global_position

func _vector2_from_config(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback

func set_patrol_path(path_points: Array[Vector2], loop_path: bool = true) -> void:
	patrol_points = path_points.duplicate()
	patrol_loop = loop_path
	_patrol_index = 0
	if path_follow_brain:
		path_follow_brain.set_path(path_points, loop_path)

func reset_state() -> void:
	if _death_tween:
		_death_tween.kill()
		_death_tween = null
	_is_dead = false
	current_target = null
	current_action = "闲置"
	current_fire_state = "无目标"
	current_distance_to_target = -1.0
	_facing_angle = 0.0
	_brain_trigger_history.clear()
	_last_brain_trigger_key = &""
	_last_brain_trigger_msec = 0
	_current_rule_bubble_text = ""
	_current_rule_bubble_until_msec = 0
	if action_icon:
		action_icon.visible = false
	_last_melee_attack_seconds = -9999.0
	_locked_target = null
	_target_lock_until_msec = 0
	_hound_has_engaged = false
	current_heat = 0.0
	is_overheated = false
	overheat_locked_until_msec = 0
	_active_heat_hold = false
	_next_separation_update_msec = 0
	_separation_accumulated_delta = 0.0
	source_nest = null
	_last_damage_source_payload.clear()
	_damage_flash_until_msec = 0
	_rallied_at_msec = 0
	_clear_navigation_path()
	_sync_runtime_groups()
	_configure_team_collision()
	_configure_components()
	_update_unit_visuals()

func is_alive() -> bool:
	return not _is_dead and (health_component == null or health_component.is_alive())

func get_display_name() -> String:
	return display_name

func _get_primary_weapon_audio_id(blueprint: UnitBlueprint) -> StringName:
	for module_id in blueprint.module_ids:
		var module_text := String(module_id)
		if module_text.contains("rifle"):
			return module_id
		if module_text.contains("chainsaw"):
			return module_id
	return blueprint.module_ids[0] if not blueprint.module_ids.is_empty() else &"default"

func _get_primary_module_icon_path(blueprint: UnitBlueprint) -> String:
	if blueprint == null or blueprint.module_icon_paths.is_empty():
		return ""
	for i in range(blueprint.module_ids.size()):
		var module_text := String(blueprint.module_ids[i])
		if module_text.contains("chainsaw") and i < blueprint.module_icon_paths.size():
			return blueprint.module_icon_paths[i]
	return blueprint.module_icon_paths[0]

func get_inspector_lines() -> Array[String]:
	var target_name := "无"
	if current_target:
		if current_target.has_method("get_display_name"):
			target_name = str(current_target.call("get_display_name"))
		else:
			target_name = str(current_target.name)
	var distance_text := "-" if current_distance_to_target < 0.0 else "%.1f / %.1f" % [current_distance_to_target, fire_range]
	var hp_text := "%s / %s" % [hp, max_hp]
	if health_component:
		hp_text = "%s / %s" % [health_component.hp, health_component.max_hp]
	var lines: Array[String] = [
		"类型：单位",
		"队伍：%s" % _format_team_name(),
		"生命：%s" % hp_text,
		"脑干：%s" % _format_brain_mode(),
		"目标：%s" % target_name,
		"动作：%s" % current_action,
		"移动：%s" % _format_movement_intent(),
		"开火：%s" % _format_fire_state(),
		"距离/射程：%s" % distance_text,
	]
	if lifespan_seconds > 0.0 and lifespan_component:
		lines.append("剩余寿命：%.1fs" % lifespan_component.get_time_left())
	else:
		lines.append("剩余寿命：无限")
	if not String(blueprint_id).is_empty():
		lines.append("蓝图：%s v%s" % [String(blueprint_id), blueprint_version])
	if not String(blueprint_snapshot_id).is_empty():
		lines.append("蓝图快照：%s" % String(blueprint_snapshot_id))
	if state_flags:
		var flag_lines: Array[String] = state_flags.format_lines()
		if not flag_lines.is_empty():
			lines.append("战术标记：")
			for flag_line in flag_lines:
				lines.append("  %s" % flag_line)
	if not active_upgrade_ids.is_empty():
		lines.append("Tech upgrades: %s" % ", ".join(_string_name_list(active_upgrade_ids)))
	if is_cargo_robot():
		lines.append("物流状态：%s" % logistics_status_text)
		lines.append("货舱：%s / %s" % [get_cargo_used_capacity(), cargo_capacity])
		lines.append_array(get_logistics_task_summary_lines())
	lines.append("Stats: HP %s / Speed %.1f" % [max_hp, speed])
	lines.append("Combat: armor %s / damage %s" % [String(armor_type), String(damage_type)])
	if heat_capacity > 0.0:
		lines.append("热量：%.1f / %.1f" % [current_heat, heat_capacity])
		lines.append("热控：每次结算 +%.1f / 每秒散热 %.1f" % [heat_per_shot, heat_cooling_per_second])
		lines.append("满热锁定：%.1fs" % get_overheat_lock_remaining() if is_overheated else "满热时强制关闭武器")
	if has_rally_point:
		lines.append("集结点：%.0f, %.0f" % [rally_point_position.x, rally_point_position.y])
	if brain_mode == "path_patrol":
		var path_index: int = path_follow_brain.patrol_index if path_follow_brain else _patrol_index
		var path_count: int = path_follow_brain.patrol_points.size() if path_follow_brain else patrol_points.size()
		lines.append("路径点：%s / %s" % [path_index + 1, path_count])
	lines.append("索敌：地图全局敌方列表")
	lines.append("目标锁定：%s" % ("已锁定" if _is_valid_enemy_target(_locked_target) else "无"))
	if not _brain_trigger_history.is_empty():
		lines.append("最近脑干触发：")
		for entry in _brain_trigger_history:
			lines.append("  %s" % entry)
	if ai_controller and ai_controller.has_method("get_rule_debug_lines"):
		for rule_line in ai_controller.call("get_rule_debug_lines"):
			lines.append(rule_line)
	return lines

func set_selected(value: bool) -> void:
	_selected = value
	queue_redraw()

func has_enemy_in_range() -> bool:
	return get_current_enemy() != null

func get_current_enemy() -> Node2D:
	if brain_mode == "melee_hound":
		return _get_hound_target()
	return _get_locked_or_nearest_enemy()

func get_lowest_hp_enemy() -> Node2D:
	var enemies := _get_sensed_enemies()
	if enemies.is_empty():
		return null
	var target := enemies[0]
	var lowest_ratio: float = float(target.call("hp_ratio")) if target.has_method("hp_ratio") else 1.0
	for candidate in enemies:
		if not candidate.has_method("hp_ratio"):
			continue
		var ratio: float = float(candidate.call("hp_ratio"))
		if ratio < lowest_ratio:
			target = candidate
			lowest_ratio = ratio
	return _lock_target(target, target_lock_seconds)

func get_radar_targets() -> Array[Node2D]:
	return _get_sensed_enemies()

func get_target_position(target: Node2D = self) -> Vector2:
	var base_position := global_position
	if target and target != self and target.has_method("get_target_position"):
		base_position = target.call("get_target_position")
	elif target:
		base_position = target.global_position
	return base_position

func is_current_enemy_in_fire_range() -> bool:
	var enemy := get_current_enemy()
	if enemy == null:
		return false
	return global_position.distance_to(get_target_position(enemy)) <= fire_range

func _apply_separation_micro_offset(delta: float) -> void:
	if delta <= 0.0 or separation_radius <= 0.0 or separation_strength <= 0.0:
		return
	_separation_accumulated_delta += delta
	var now := Time.get_ticks_msec()
	if _next_separation_update_msec <= 0:
		_next_separation_update_msec = now + int(get_instance_id() % 83)
	if now < _next_separation_update_msec:
		return
	_next_separation_update_msec = now + 100
	delta = minf(_separation_accumulated_delta, 0.2)
	_separation_accumulated_delta = 0.0
	var effective_radius := separation_radius
	var effective_strength := separation_strength
	if _is_actively_pursuing_melee_target():
		effective_radius = minf(effective_radius, 20.0)
		effective_strength *= 0.15
	var group_name: String = "team_a" if team == "Team_A" else "team_b"
	var push: Vector2 = Vector2.ZERO
	var neighbor_count: int = 0
	for unit in get_tree().get_nodes_in_group(group_name):
		if unit == self or not (unit is RobotUnit):
			continue
		var other := unit as RobotUnit
		if not other.is_inside_tree() or not other.is_alive():
			continue
		var offset: Vector2 = global_position - other.global_position
		var distance: float = offset.length()
		if distance <= 0.001 or distance >= effective_radius:
			continue
		var weight: float = 1.0 - distance / effective_radius
		push += offset.normalized() * weight
		neighbor_count += 1
	if neighbor_count <= 0 or push.length() <= 0.001:
		return
	var step: Vector2 = push.normalized() * minf(
		separation_max_step,
		effective_strength * delta * minf(1.0, push.length())
	)
	var proposed_position := global_position + step
	var path_provider := _get_path_provider()
	if path_provider == null \
			or not path_provider.has_method("is_navigation_world_position_walkable") \
			or bool(path_provider.call("is_navigation_world_position_walkable", proposed_position)):
		global_position = proposed_position

func _is_actively_pursuing_melee_target() -> bool:
	if current_target == null or not is_instance_valid(current_target):
		return false
	return brain_mode == "melee_hound" or _uses_chainsaw_weapon()

func hp_ratio() -> float:
	if health_component:
		return health_component.hp_ratio()
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)

func _string_name_list(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

func move_away_from_current_enemy() -> void:
	var enemy := get_current_enemy()
	if enemy == null:
		stop_and_idle()
		return
	flee_from(get_target_position(enemy))

func move_towards_nearest_enemy() -> void:
	var enemy := get_current_enemy()
	if enemy == null:
		stop_and_idle()
		return
	move_towards(get_target_position(enemy), enemy)

func move_towards(target_pos: Vector2, target_node: Node = null, speed_scale: float = 1.0) -> bool:
	if movement_component == null:
		return false
	var next_target := _get_cached_navigation_waypoint(target_pos, target_node)
	if global_position.distance_to(next_target) <= 1.0 and global_position.distance_to(target_pos) > 18.0:
		movement_component.stop(&"blocked")
		current_action = "路径阻塞"
		return false
	movement_component.move_towards(global_position, next_target, speed_scale)
	current_action = "接近目标"
	return true

func flee_from(target_pos: Vector2, speed_scale: float = 1.0) -> void:
	if movement_component == null:
		return
	var away_direction := (global_position - target_pos).normalized()
	if away_direction.length() <= 0.001:
		away_direction = Vector2.RIGHT
	var retreat_distance := maxf(96.0, fire_range * 0.65)
	var retreat_target := global_position + away_direction * retreat_distance
	if move_towards(retreat_target, null, speed_scale):
		movement_component.movement_intent = &"retreat"
	current_action = "远离目标"

func _get_cached_navigation_waypoint(target_pos: Vector2, target_node: Node = null) -> Vector2:
	var path_provider := _get_path_provider()
	if path_provider == null:
		return target_pos
	var target_instance_id := target_node.get_instance_id() if target_node != null and is_instance_valid(target_node) else 0
	var now := Time.get_ticks_msec()
	var target_cell := _get_navigation_cell(path_provider, target_pos)
	var target_cell_changed := target_cell != _navigation_target_cell
	var target_moved := _navigation_target_position == Vector2.INF \
		or _navigation_target_position.distance_to(target_pos) >= navigation_target_move_threshold
	var target_changed := target_instance_id != _navigation_target_instance_id
	var path_exhausted := _navigation_path_resolved and _navigation_path_index >= _navigation_path.size()
	var waypoint_blocked := false
	if _navigation_path_index < _navigation_path.size() and path_provider.has_method("is_navigation_world_position_walkable"):
		waypoint_blocked = not bool(path_provider.call(
			"is_navigation_world_position_walkable",
			_navigation_path[_navigation_path_index]
		))
	var may_repath := now >= _navigation_next_repath_msec
	var failed_path_retry := _navigation_path_resolved and _navigation_path.is_empty() and may_repath
	var unfinished_path_retry := path_exhausted \
		and global_position.distance_to(target_pos) > navigation_waypoint_tolerance \
		and may_repath
	if not _navigation_path_resolved \
			or target_changed \
			or waypoint_blocked \
			or (target_cell_changed and may_repath) \
			or (target_moved and may_repath and target_node == null) \
			or failed_path_retry \
			or unfinished_path_retry:
		_rebuild_navigation_path(path_provider, target_pos, target_node, target_instance_id, target_cell, now)
	while _navigation_path_index < _navigation_path.size() \
		and global_position.distance_to(_navigation_path[_navigation_path_index]) <= navigation_waypoint_tolerance:
		_navigation_path_index += 1
	if _navigation_path_index >= _navigation_path.size():
		if target_node != null and target_cell == _navigation_target_cell:
			return target_pos
		if target_node != null and _navigation_target_position != Vector2.INF:
			return _navigation_target_position
		return target_pos if global_position.distance_to(target_pos) <= navigation_waypoint_tolerance else global_position
	return _navigation_path[_navigation_path_index]

func _rebuild_navigation_path(
	path_provider: Node,
	target_pos: Vector2,
	target_node: Node,
	target_instance_id: int,
	target_cell: Vector2i,
	now_msec: int
) -> void:
	_navigation_path = PackedVector2Array()
	if target_node != null and is_instance_valid(target_node) and path_provider.has_method("get_navigation_path_points_to_node"):
		_navigation_path = path_provider.call("get_navigation_path_points_to_node", global_position, target_node)
	elif path_provider.has_method("get_navigation_path_points"):
		_navigation_path = path_provider.call("get_navigation_path_points", global_position, target_pos)
	_navigation_path_resolved = true
	_navigation_path_index = 1 if _navigation_path.size() > 1 else 0
	_navigation_target_position = target_pos
	_navigation_target_instance_id = target_instance_id
	_navigation_target_cell = target_cell
	var stagger_msec := int(get_instance_id() % 113)
	var repath_seconds := navigation_repath_interval_seconds
	if target_node != null and _is_actively_pursuing_melee_target():
		repath_seconds = minf(repath_seconds, 0.12)
		stagger_msec = int(get_instance_id() % 37)
	_navigation_next_repath_msec = now_msec \
		+ roundi(maxf(0.05, repath_seconds) * 1000.0) \
		+ stagger_msec

func _get_navigation_cell(path_provider: Node, world_position: Vector2) -> Vector2i:
	if path_provider != null and path_provider.has_method("get_navigation_cell_for_world"):
		return path_provider.call("get_navigation_cell_for_world", world_position)
	return Vector2i(-1, -1)

func _clear_navigation_path() -> void:
	_navigation_path = PackedVector2Array()
	_navigation_path_index = 0
	_navigation_target_position = Vector2.INF
	_navigation_target_instance_id = 0
	_navigation_target_cell = Vector2i(-1, -1)
	_navigation_next_repath_msec = 0
	_navigation_path_resolved = false

func _get_path_provider() -> Node:
	return get_tree().get_first_node_in_group("stage_path_provider") if get_tree() else null

func stop_and_idle() -> void:
	if movement_component:
		movement_component.stop(&"idle")
	current_action = "闲置"

func move_to_rally_point() -> void:
	if not has_rally_point:
		stop_and_idle()
		current_action = "无集结点"
		return
	move_towards(rally_point_position)
	current_action = "前往集结点"

func distance_to_rally_point() -> float:
	if not has_rally_point:
		return INF
	return global_position.distance_to(rally_point_position)

func count_allies_near_rally_point(radius: float = 90.0) -> int:
	if not has_rally_point:
		return 0
	if _combat_target_registry != null and is_instance_valid(_combat_target_registry):
		if _combat_target_registry.has_method("count_units_near"):
			return int(_combat_target_registry.call("count_units_near", team, rally_point_position, radius))
	var count := 0
	for unit in get_tree().get_nodes_in_group("combat_unit"):
		if unit == null or not is_instance_valid(unit):
			continue
		if not (unit is Node2D):
			continue
		if unit.get("team") == null or String(unit.get("team")) != team:
			continue
		if unit.has_method("is_alive") and not bool(unit.call("is_alive")):
			continue
		if rally_point_position.distance_to((unit as Node2D).global_position) <= radius:
			count += 1
	return count

func is_rally_squad_ready(_radius: float = 90.0) -> bool:
	return has_rally_point and get_state_flag(&"squad_ready")

func mark_rally_squad_ready(radius: float = 90.0) -> void:
	try_mark_rally_squad_ready(radius, 1)

func try_mark_rally_squad_ready(radius: float = 90.0, required_allies: int = 1) -> bool:
	if not has_rally_point:
		return false
	if is_rally_squad_ready(radius):
		return true
	var required_count := maxi(1, required_allies)
	var candidates := _collect_rally_release_candidates(radius)
	if candidates.size() < required_count:
		return false
	for index in range(required_count):
		candidates[index]._set_squad_ready_flag()
	return is_rally_squad_ready(radius)

func sync_rally_squad_ready(radius: float = 90.0) -> void:
	if not is_rally_squad_ready(radius):
		return
	_set_squad_ready_flag()

func count_rally_release_candidates(radius: float = 90.0) -> int:
	return _collect_rally_release_candidates(radius).size()

static func clear_shared_rally_readiness() -> void:
	pass

func _get_rally_ready_key(radius: float) -> String:
	var cell := 24.0
	return "%s:%d:%d:%d" % [
		team,
		roundi(rally_point_position.x / cell),
		roundi(rally_point_position.y / cell),
		roundi(radius),
	]

func _collect_rally_release_candidates(radius: float) -> Array[RobotUnit]:
	var candidates: Array[RobotUnit] = []
	if get_tree() == null:
		return candidates
	var ready_key := _get_rally_ready_key(radius)
	var release_radius := radius + 24.0
	for unit in get_tree().get_nodes_in_group("combat_unit"):
		if unit == null or not is_instance_valid(unit) or not (unit is RobotUnit):
			continue
		var other := unit as RobotUnit
		if not other.is_inside_tree() or not other.is_alive():
			continue
		if other.get_state_flag(&"squad_ready"):
			continue
		if not other.has_rally_point or other.team != team:
			continue
		if other._get_rally_ready_key(radius) != ready_key:
			continue
		var distance := other.distance_to_rally_point()
		if distance > release_radius:
			continue
		if distance > radius and not other.get_state_flag(&"rallied"):
			continue
		candidates.append(other)
	candidates.sort_custom(func(a: RobotUnit, b: RobotUnit) -> bool:
		var a_time := a._rallied_at_msec if a._rallied_at_msec > 0 else 0x7FFFFFFF
		var b_time := b._rallied_at_msec if b._rallied_at_msec > 0 else 0x7FFFFFFF
		if a_time == b_time:
			return int(a.get_instance_id()) < int(b.get_instance_id())
		return a_time < b_time
	)
	return candidates

func _set_squad_ready_flag() -> void:
	if get_state_flag(&"squad_ready"):
		return
	set_state_flag(&"squad_ready", true, "Rally squad ready")

func get_state_flag(flag_id: StringName) -> bool:
	if state_flags == null:
		return false
	return bool(state_flags.call("get_flag", flag_id))

func set_state_flag(flag_id: StringName, value: bool, reason: String = "") -> void:
	if state_flags == null:
		return
	if flag_id == &"rallied":
		if value and not get_state_flag(flag_id):
			_rallied_at_msec = maxi(1, Time.get_ticks_msec())
		elif not value:
			_rallied_at_msec = 0
	state_flags.call("set_flag", flag_id, value)
	if not reason.is_empty():
		record_brain_trigger(StringName("flag_%s_%s" % [String(flag_id), value]), reason)

func uses_physics_ai_tick() -> bool:
	return true

func get_blueprint_snapshot_key() -> String:
	return String(blueprint_snapshot_id)

func is_cargo_robot() -> bool:
	return cargo_capacity > 0 or tags.has("cargo") or tags.has("logistics")

func setup_logistics_task(task: Dictionary) -> void:
	current_logistics_task = task.duplicate(true)
	logistics_status_text = str(current_logistics_task.get("status", "执行物流任务"))
	if logistics_status_text.is_empty():
		logistics_status_text = "执行物流任务"

func clear_logistics_task() -> void:
	current_logistics_task.clear()
	logistics_status_text = "待命" if is_cargo_robot() else "无物流能力"

func get_cargo_inventory() -> Dictionary:
	return cargo_inventory.duplicate(true)

func get_cargo_used_capacity() -> int:
	var total := 0
	for resource_id in cargo_inventory.keys():
		total += maxi(0, int(cargo_inventory[resource_id]))
	return total

func get_cargo_free_capacity() -> int:
	return maxi(0, cargo_capacity - get_cargo_used_capacity())

func add_cargo(resource_id: StringName, amount: int) -> int:
	if amount <= 0 or cargo_capacity <= 0:
		return 0
	var accepted := mini(amount, get_cargo_free_capacity())
	if accepted <= 0:
		return 0
	cargo_inventory[resource_id] = int(cargo_inventory.get(resource_id, 0)) + accepted
	return accepted

func remove_cargo(resource_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var current := int(cargo_inventory.get(resource_id, 0))
	var removed := mini(amount, current)
	if removed <= 0:
		return 0
	var next_amount := current - removed
	if next_amount <= 0:
		cargo_inventory.erase(resource_id)
	else:
		cargo_inventory[resource_id] = next_amount
	return removed

func get_logistics_task_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	if not is_cargo_robot():
		return lines
	if current_logistics_task.is_empty():
		lines.append("物流任务：无")
		return lines
	lines.append("物流任务：%s" % _format_logistics_task_type(str(current_logistics_task.get("type", "idle"))))
	lines.append("任务状态：%s" % str(current_logistics_task.get("status", logistics_status_text)))
	var cargo_item := str(current_logistics_task.get("resource_id", ""))
	if not cargo_item.is_empty():
		lines.append("目标物资：%s x%s" % [cargo_item, int(current_logistics_task.get("amount", 0))])
	var pickup := str(current_logistics_task.get("pickup", ""))
	var dropoff := str(current_logistics_task.get("dropoff", ""))
	if not pickup.is_empty() or not dropoff.is_empty():
		lines.append("路线：%s -> %s" % [pickup if not pickup.is_empty() else "-", dropoff if not dropoff.is_empty() else "-"])
	return lines

func fire_main_weapon() -> void:
	var enemy := get_current_enemy()
	if enemy == null:
		current_fire_state = "无目标"
		return
	fire_weapon(enemy)

func record_brain_trigger(key: StringName, description: String) -> void:
	var now := Time.get_ticks_msec()
	if key == _last_brain_trigger_key and now - _last_brain_trigger_msec < 1000:
		return
	_last_brain_trigger_key = key
	_last_brain_trigger_msec = now
	_brain_trigger_history.push_front(description)
	while _brain_trigger_history.size() > 5:
		_brain_trigger_history.pop_back()
	_current_rule_bubble_text = _format_rule_bubble_text(description)
	_current_rule_bubble_until_msec = now + 1800

func fire_weapon(target: Node2D) -> void:
	if _uses_chainsaw_weapon():
		_try_fire_chainsaw(target)
		return
	if weapon_component == null:
		return
	if _should_hold_fire_for_heat():
		current_fire_state = "过热停火"
		return
	if target:
		var target_position := get_target_position(target)
		_turn_towards(target_position, get_physics_process_delta_time())
		if not _is_facing_position(target_position):
			current_fire_state = "转向中"
			return
	var spawn_parent := _get_projectile_parent()
	var fired: bool = bool(weapon_component.try_fire(team, muzzle, target, spawn_parent))
	if fired:
		_add_weapon_heat()
	current_fire_state = _format_fire_state()

func _try_fire_chainsaw(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		current_fire_state = "无目标"
		return
	var target_position := get_target_position(target)
	_turn_towards(target_position, get_physics_process_delta_time())
	if not _is_facing_position(target_position):
		current_fire_state = "转向中"
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_melee_attack_seconds < fire_cooldown_seconds:
		current_fire_state = "冷却"
		return
	var hit_center := global_position + Vector2.RIGHT.rotated(_facing_angle) * minf(fire_range * 0.46, 42.0)
	var hit_radius := maxf(28.0, fire_range * 0.58)
	var hit_count := 0
	for enemy in _get_sensed_enemies():
		if enemy == null or not is_instance_valid(enemy):
			continue
		var enemy_position := get_target_position(enemy)
		if enemy_position.distance_to(hit_center) > hit_radius:
			continue
		if not _is_within_chainsaw_arc(enemy_position):
			continue
		if enemy.has_method("take_damage_from"):
			enemy.call("take_damage_from", bullet_damage, _make_weapon_source_payload())
		elif enemy.has_method("take_damage"):
			enemy.call("take_damage", bullet_damage)
		hit_count += 1
	_last_melee_attack_seconds = now
	_chainsaw_swing_until_msec = Time.get_ticks_msec() + 180
	_chainsaw_hit_center = to_local(hit_center)
	current_fire_state = "链锯命中 %d" % hit_count if hit_count > 0 else "链锯挥空"
	record_brain_trigger(&"chainsaw_sweep", current_fire_state)
	queue_redraw()

func _is_within_chainsaw_arc(world_position: Vector2) -> bool:
	var direction := world_position - global_position
	if direction.length() <= 0.001:
		return true
	return absf(angle_difference(_facing_angle, direction.angle())) <= 1.45

func _make_weapon_source_payload() -> Dictionary:
	return {
		"team": team,
		"robot_id": str(name),
		"weapon_id": String(weapon_audio_id),
		"damage_type": String(damage_type),
		"blueprint_id": String(blueprint_id),
		"blueprint_version": blueprint_version,
		"blueprint_snapshot_id": String(blueprint_snapshot_id),
		"blueprint_name": display_name,
	}

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	if health_component:
		health_component.take_damage(amount)

func take_damage_from(amount: int, source_payload: Dictionary = {}) -> void:
	_last_damage_source_payload = source_payload.duplicate(true)
	take_damage(_apply_damage_profile(amount, source_payload))

func get_last_damage_source_payload() -> Dictionary:
	return _last_damage_source_payload.duplicate(true)

func heat_ratio() -> float:
	if heat_capacity <= 0.0:
		return 0.0
	return clampf(current_heat / heat_capacity, 0.0, 1.0)

func has_heat_weapon() -> bool:
	return heat_capacity > 0.0 and heat_per_shot > 0.0

func hold_fire_for_heat() -> void:
	_active_heat_hold = true
	if movement_component:
		movement_component.stop(&"heat_hold")
	current_action = "散热等待"
	current_fire_state = "过热停火"

func _update_heat(delta: float) -> void:
	if heat_capacity <= 0.0:
		current_heat = 0.0
		is_overheated = false
		overheat_locked_until_msec = 0
		_active_heat_hold = false
		return
	if heat_cooling_per_second > 0.0 and current_heat > 0.0:
		current_heat = maxf(0.0, current_heat - heat_cooling_per_second * delta)
	if is_overheated and Time.get_ticks_msec() >= overheat_locked_until_msec:
		is_overheated = false
	if _active_heat_hold and not is_overheated and current_heat <= _get_resume_heat_threshold():
		_active_heat_hold = false

func _should_hold_fire_for_heat() -> bool:
	if heat_capacity <= 0.0:
		return false
	if is_overheated:
		return true
	if _active_heat_hold:
		if current_heat <= _get_resume_heat_threshold():
			_active_heat_hold = false
			return false
		return true
	return false

func _add_weapon_heat() -> void:
	if heat_capacity <= 0.0 or heat_per_shot <= 0.0:
		return
	current_heat = clampf(current_heat + heat_per_shot, 0.0, heat_capacity)
	if current_heat >= heat_capacity:
		is_overheated = true
		var full_dissipation_seconds := heat_capacity / maxf(heat_cooling_per_second, 0.001)
		var lock_seconds := maxf(minimum_overheat_lock_seconds, full_dissipation_seconds + 0.75)
		overheat_locked_until_msec = Time.get_ticks_msec() + roundi(lock_seconds * 1000.0)
		record_brain_trigger(&"forced_overheat", "武器满热：强制关闭 %.1f 秒" % lock_seconds)

func get_overheat_lock_remaining() -> float:
	if not is_overheated:
		return 0.0
	return maxf(0.0, float(overheat_locked_until_msec - Time.get_ticks_msec()) / 1000.0)

func _get_overheat_threshold() -> float:
	if overheat_threshold > 0.0:
		return minf(overheat_threshold, heat_capacity)
	return heat_capacity

func _get_resume_heat_threshold() -> float:
	if overheated_resume_threshold > 0.0:
		return minf(overheated_resume_threshold, _get_overheat_threshold())
	return _get_overheat_threshold() * 0.45

func _apply_damage_profile(amount: int, source_payload: Dictionary) -> int:
	var source_damage_type := StringName(str(source_payload.get("damage_type", "kinetic")))
	var multiplier := 1.0
	if armor_type == &"armored":
		match source_damage_type:
			&"kinetic":
				multiplier = 0.55
			&"thermal":
				multiplier = 1.35
			&"melee":
				multiplier = 0.80
	elif armor_type == &"structure_armor":
		match source_damage_type:
			&"kinetic":
				multiplier = 0.75
			&"thermal":
				multiplier = 1.25
	return maxi(1, roundi(float(amount) * multiplier))

func die(reason: StringName = &"destroyed") -> void:
	if _is_dead:
		return
	if health_component:
		health_component.kill(reason)
	else:
		_finish_death(reason)

func _connect_components() -> void:
	if health_component:
		if not health_component.health_changed.is_connected(_on_health_changed):
			health_component.health_changed.connect(_on_health_changed)
		if not health_component.died.is_connected(_on_health_died):
			health_component.died.connect(_on_health_died)
	if lifespan_component:
		if not lifespan_component.expired.is_connected(_on_lifespan_expired):
			lifespan_component.expired.connect(_on_lifespan_expired)

func _configure_components() -> void:
	if health_component:
		health_component.setup(max_hp)
	if movement_component:
		movement_component.setup(speed)
	if weapon_component:
		weapon_component.enabled = weapon_enabled
		weapon_component.setup(
			fire_range,
			bullet_damage,
			fire_cooldown_seconds,
			"laser" if damage_type == &"thermal" else "projectile"
		)
	if lifespan_component:
		lifespan_component.setup(lifespan_seconds)
	if default_brain:
		default_brain.setup(preferred_range_ratio, range_dead_zone)
	if path_follow_brain:
		path_follow_brain.set_path(patrol_points, patrol_loop)

func _sync_runtime_groups() -> void:
	_unregister_combat_target()
	add_to_group("combat_unit")
	add_to_group("combat_target")
	if team == "Team_A":
		add_to_group("team_a")
		remove_from_group("team_b")
	else:
		add_to_group("team_b")
		remove_from_group("team_a")
	for tag in tags:
		if not tag.is_empty():
			add_to_group(tag)
	_register_combat_target()

func _configure_team_collision() -> void:
	collision_layer = 1 if team == "Team_A" else 2
	collision_mask = 0

func _get_sensed_enemies() -> Array[Node2D]:
	if enemy_sensor == null:
		return []
	return enemy_sensor.get_enemies(self, team)

func _get_locked_or_nearest_enemy() -> Node2D:
	var now := Time.get_ticks_msec()
	if _is_valid_enemy_target(_locked_target) and now < _target_lock_until_msec:
		return _locked_target
	_clear_locked_target()
	var enemies := _get_sensed_enemies()
	if enemies.is_empty():
		return null
	return _lock_target(enemies[0], target_lock_seconds)

func _get_hound_target() -> Node2D:
	if _is_valid_enemy_target(_locked_target):
		return _locked_target
	_clear_locked_target()
	if enemy_sensor == null:
		return null

	var enemies: Array[Node2D] = []
	if _hound_has_engaged and enemy_sensor.has_method("get_follow_up_targets"):
		enemies = enemy_sensor.get_follow_up_targets(self, team, hound_follow_up_radius)
	if enemies.is_empty() and enemy_sensor.has_method("get_initial_targets"):
		var valid_source_nest: Node = null
		if source_nest != null and is_instance_valid(source_nest):
			valid_source_nest = source_nest
		else:
			source_nest = null
		enemies = enemy_sensor.get_initial_targets(self, team, valid_source_nest, guard_aggro_radius)
	if enemies.is_empty():
		_hound_has_engaged = false
		return null

	_hound_has_engaged = true
	return _lock_target(enemies[0], 0.0)

func _lock_target(target: Node2D, duration_seconds: float) -> Node2D:
	if not _is_valid_enemy_target(target):
		_clear_locked_target()
		return null
	_locked_target = target
	_target_lock_until_msec = Time.get_ticks_msec() + roundi(maxf(0.0, duration_seconds) * 1000.0)
	return _locked_target

func _clear_locked_target() -> void:
	_locked_target = null
	_target_lock_until_msec = 0

func _is_valid_enemy_target(target: Node2D) -> bool:
	if enemy_sensor == null or target == null or not is_instance_valid(target):
		return false
	return bool(enemy_sensor.is_valid_enemy(self, team, target))

func _get_projectile_parent() -> Node:
	var map := get_parent()
	while map != null and not map.has_method("get_layer"):
		map = map.get_parent()
	if map != null:
		var projectile_layer := map.call("get_layer", "ProjectileLayer") as Node
		if projectile_layer:
			return projectile_layer
	return get_tree().current_scene if get_tree().current_scene else get_parent()

func _update_unit_visuals() -> void:
	if unit_sprite:
		var texture := unit_sprite.texture
		if icon_path != _loaded_icon_path:
			_loaded_icon_path = icon_path
			if not icon_path.is_empty() and ResourceLoader.exists(icon_path, "Texture2D"):
				texture = load(icon_path) as Texture2D
				if texture:
					unit_sprite.texture = texture
		if texture:
			var texture_size := texture.get_size()
			if texture_size.x > 0.0 and texture_size.y > 0.0:
				var next_scale := Vector2(visual_size.x / texture_size.x, visual_size.y / texture_size.y)
				if not unit_sprite.scale.is_equal_approx(next_scale):
					unit_sprite.scale = next_scale
		var next_rotation := 0.0 if _uses_fixed_icon_orientation() else _facing_angle
		if not is_equal_approx(unit_sprite.rotation, next_rotation):
			unit_sprite.rotation = next_rotation
		var next_modulate := Color(1.0, 0.48, 0.38, 1.0) if Time.get_ticks_msec() < _damage_flash_until_msec else Color.WHITE
		if unit_sprite.modulate != next_modulate:
			unit_sprite.modulate = next_modulate
	_update_module_visuals()
	if muzzle:
		var next_muzzle_position := Vector2.RIGHT.rotated(_facing_angle) * muzzle_distance
		if not muzzle.position.is_equal_approx(next_muzzle_position):
			muzzle.position = next_muzzle_position
	if hp_bar:
		if not is_equal_approx(hp_bar.max_value, float(max_hp)):
			hp_bar.max_value = max_hp
		if not is_equal_approx(hp_bar.value, float(hp)):
			hp_bar.value = hp
		var hp_bar_visible := hp < max_hp
		if hp_bar.visible != hp_bar_visible:
			hp_bar.visible = hp_bar_visible
	if heat_bar:
		var next_heat_max := maxf(1.0, heat_capacity)
		if not is_equal_approx(heat_bar.max_value, next_heat_max):
			heat_bar.max_value = next_heat_max
		if not is_equal_approx(heat_bar.value, current_heat):
			heat_bar.value = current_heat
		var heat_bar_visible := has_heat_weapon() and is_alive()
		if heat_bar.visible != heat_bar_visible:
			heat_bar.visible = heat_bar_visible
		var heat_bar_modulate := Color(1.0, 0.30, 0.18, 1.0) if is_overheated else Color(1.0, 0.72, 0.18, 1.0)
		if heat_bar.modulate != heat_bar_modulate:
			heat_bar.modulate = heat_bar_modulate
	if action_label:
		var bubble_text := ""
		if Time.get_ticks_msec() <= _current_rule_bubble_until_msec and not _current_rule_bubble_text.is_empty():
			bubble_text = _current_rule_bubble_text
		elif not current_action.is_empty() and current_action != "闲置":
			bubble_text = current_action
		var action_visible := is_alive() and not bubble_text.is_empty()
		var action_layout_changed := action_label.visible != action_visible or action_label.text != bubble_text
		if action_label.visible != action_visible:
			action_label.visible = action_visible
		if action_label.text != bubble_text:
			action_label.text = bubble_text
		if action_layout_changed:
			_update_action_icon(bubble_text, action_label.visible)
			_layout_action_bubble(bubble_text, action_label.visible)
	var chainsaw_visual_active := _uses_chainsaw_weapon() and Time.get_ticks_msec() <= _chainsaw_swing_until_msec
	if chainsaw_visual_active or _chainsaw_visual_was_active:
		queue_redraw()
	_chainsaw_visual_was_active = chainsaw_visual_active

func _update_module_visuals() -> void:
	if module_sprite:
		module_sprite.visible = false

func _update_facing(delta: float) -> void:
	if _should_face_attack_target():
		_turn_towards(get_target_position(current_target), delta)
		return
	if movement_component and movement_component.desired_velocity.length() > 0.001:
		_turn_angle_towards(movement_component.desired_velocity.angle(), delta)

func _uses_fixed_icon_orientation() -> bool:
	return brain_mode == "logistics" or tags.has("cargo") or tags.has("logistics")

func _uses_chainsaw_weapon() -> bool:
	return String(weapon_audio_id).contains("chainsaw") or String(blueprint_id).contains("chainsaw")

func _turn_towards(world_position: Vector2, delta: float) -> void:
	var direction := world_position - global_position
	if direction.length() <= 0.001:
		return
	_turn_angle_towards(direction.angle(), delta)

func _turn_angle_towards(target_angle: float, delta: float) -> void:
	if delta < 0.0 or turn_speed_radians <= 0.0:
		_facing_angle = target_angle
	else:
		_facing_angle = rotate_toward(_facing_angle, target_angle, turn_speed_radians * delta)

func _is_facing_position(world_position: Vector2) -> bool:
	var direction := world_position - global_position
	if direction.length() <= 0.001:
		return true
	if _uses_chainsaw_weapon():
		return absf(angle_difference(_facing_angle, direction.angle())) <= 0.82
	return absf(angle_difference(_facing_angle, direction.angle())) <= fire_arc_radians

func _should_face_attack_target() -> bool:
	if not weapon_enabled:
		return false
	if current_target == null or not is_instance_valid(current_target):
		return false
	if current_distance_to_target < 0.0:
		return false
	return current_distance_to_target <= fire_range

func _tick_melee_hound() -> void:
	var enemy := get_current_enemy()
	current_target = enemy
	if enemy == null:
		if movement_component and global_position.distance_to(guard_home_position) > movement_component.arrival_tolerance:
			move_towards(guard_home_position)
			current_action = "返回守卫位置"
			return
		current_action = "巢穴周围警戒"
		current_distance_to_target = -1.0
		if movement_component:
			movement_component.stop(&"idle")
		return

	var target_position := get_target_position(enemy)
	current_distance_to_target = global_position.distance_to(target_position)
	if current_distance_to_target > melee_range:
		move_towards(target_position, enemy)
		current_action = "扑向目标"
		return

	if movement_component:
		movement_component.stop(&"hold_range")
	current_action = "撕咬目标"
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_melee_attack_seconds < melee_cooldown_seconds:
		return
	_last_melee_attack_seconds = now
	if enemy.has_method("take_damage"):
		enemy.call("take_damage", melee_damage)
	record_brain_trigger(&"hound_melee_attack", "撕咬目标")

func _on_health_changed(current_hp: int, current_max_hp: int, delta: int) -> void:
	hp = current_hp
	max_hp = current_max_hp
	if delta < 0:
		_damage_flash_until_msec = Time.get_ticks_msec() + 140
	_update_unit_visuals()

func _on_health_died(reason: StringName) -> void:
	_finish_death(reason)

func _finish_death(reason: StringName) -> void:
	if _is_dead:
		return
	_is_dead = true
	current_action = "报废"
	remove_from_group("combat_target")
	_unregister_combat_target()
	if movement_component:
		movement_component.stop(&"dead")
	if lifespan_component:
		lifespan_component.stop()
	_clear_locked_target()
	_hound_has_engaged = false
	if source_nest != null and is_instance_valid(source_nest) and source_nest.has_method("unregister_guard"):
		source_nest.call("unregister_guard", self)
	source_nest = null
	robot_lost.emit(self, reason)
	_play_death_fade_and_return()

func _play_death_fade_and_return() -> void:
	if hp_bar:
		hp_bar.visible = false
	if action_label:
		action_label.visible = false
	if action_icon:
		action_icon.visible = false
	if unit_sprite == null:
		ObjectPool.return_instance(self, pool_name)
		return
	if _death_tween:
		_death_tween.kill()
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	_death_tween.tween_property(unit_sprite, "modulate", Color(1.0, 0.28, 0.18, 0.0), 0.22)
	_death_tween.tween_property(unit_sprite, "scale", unit_sprite.scale * 0.72, 0.22)
	_death_tween.chain().tween_callback(func() -> void:
		_death_tween = null
		ObjectPool.return_instance(self, pool_name)
	)

func _on_lifespan_expired() -> void:
	die(&"lifespan_expired")

func _register_combat_target() -> void:
	_combat_target_registry = CombatTargetRegistryScript.find_for(self)
	if _combat_target_registry != null:
		_combat_target_registry.call("register_target", self)

func _unregister_combat_target() -> void:
	if _combat_target_registry != null and is_instance_valid(_combat_target_registry):
		_combat_target_registry.call("unregister_target", self)
	_combat_target_registry = null

func _draw() -> void:
	if _uses_chainsaw_weapon() and Time.get_ticks_msec() <= _chainsaw_swing_until_msec:
		var radius := maxf(24.0, fire_range * 0.34)
		var start_angle := _facing_angle - 1.15
		var end_angle := _facing_angle + 1.15
		draw_arc(_chainsaw_hit_center, radius, start_angle, end_angle, 28, Color(1.0, 0.76, 0.18, 0.9), 3.0)
		draw_arc(_chainsaw_hit_center, radius * 0.62, start_angle + 0.18, end_angle - 0.18, 22, Color(0.62, 0.95, 1.0, 0.55), 2.0)
	if _selected:
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 64, Color(1.0, 0.86, 0.12, 0.95), 2.5)

func _format_team_name() -> String:
	return "玩家" if team == "Team_A" else "调试敌军"

func _format_brain_mode() -> String:
	match brain_mode:
		"default_combat":
			return "默认战斗脑干"
		"path_patrol":
			return "路径移动脑干"
		"melee_hound":
			return "拾荒猎犬近战脑干"
		"logistics":
			return "物流调度脑干"
		_:
			return "闲置"

func _format_movement_intent() -> String:
	if movement_component == null:
		return "无"
	match movement_component.movement_intent:
		&"approach":
			return "接近"
		&"retreat":
			return "后退"
		&"hold_range":
			return "保持射程"
		&"arrived":
			return "到达"
		&"dead":
			return "停止"
		_:
			return "停止"

func _format_fire_state() -> String:
	if is_overheated:
		return "强制过热锁定 %.1fs" % get_overheat_lock_remaining()
	if current_fire_state == "过热停火":
		return "主动散热 %.0f%%" % (heat_ratio() * 100.0)
	if _uses_chainsaw_weapon():
		return current_fire_state
	if current_fire_state == "转向中":
		return current_fire_state
	if weapon_component == null:
		return "无武器"
	match weapon_component.fire_state:
		&"disabled":
			return "禁用"
		&"no_target":
			return "无目标"
		&"out_of_range":
			return "目标超出射程"
		&"cooldown":
			return "冷却中 %.1fs" % weapon_component.get_cooldown_remaining()
		&"spawn_failed":
			return "弹体生成失败"
		&"channeling":
			return "激光照射"
		&"fired":
			return "激光命中" if damage_type == &"thermal" else "开火"
		_:
			return "可开火"

func _format_rule_bubble_text(description: String) -> String:
	var text := description.strip_edges()
	if text.begins_with("规则："):
		text = text.trim_prefix("规则：")
	if text.begins_with("默认脑干："):
		text = text.trim_prefix("默认脑干：")
	if text.begins_with("路径脑干："):
		text = text.trim_prefix("路径脑干：")
	return text

func _ensure_action_icon() -> void:
	if action_icon != null:
		return
	action_icon = get_node_or_null("ActionIcon") as Sprite2D
	if action_icon == null:
		action_icon = Sprite2D.new()
		action_icon.name = "ActionIcon"
		action_icon.z_index = 24
		add_child(action_icon)
	action_icon.visible = false
	action_icon.scale = Vector2(0.82, 0.82)

func _ensure_module_sprite() -> void:
	if module_sprite != null:
		return
	module_sprite = get_node_or_null("ModuleSprite") as Sprite2D
	if module_sprite == null:
		module_sprite = Sprite2D.new()
		module_sprite.name = "ModuleSprite"
		module_sprite.z_index = 8
		add_child(module_sprite)
	module_sprite.visible = false

func _update_action_icon(bubble_text: String, should_show: bool) -> void:
	_ensure_action_icon()
	if action_icon == null:
		return
	var icon_texture := _get_action_icon_texture(bubble_text)
	action_icon.texture = icon_texture
	action_icon.visible = should_show and icon_texture != null

func _layout_action_bubble(bubble_text: String, should_show: bool) -> void:
	if action_label == null:
		return
	var text_width := _measure_action_label_text_width(bubble_text)
	var label_height := 20.0
	var icon_width := 0.0
	var icon_gap := 0.0
	if action_icon and action_icon.visible:
		icon_width = 12.0
		icon_gap = 5.0
	var total_width := text_width + icon_width + icon_gap
	var left := -total_width * 0.5
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	action_label.position = Vector2(left + icon_width + icon_gap, -54.0)
	action_label.size = Vector2(text_width, label_height)
	if action_icon:
		action_icon.position = Vector2(left + icon_width * 0.5, -44.0)
		action_icon.visible = should_show and action_icon.texture != null

func _measure_action_label_text_width(text: String) -> float:
	if text.is_empty() or action_label == null:
		return 0.0
	var font := action_label.get_theme_font("font")
	var font_size := action_label.get_theme_font_size("font_size")
	if font:
		return maxf(8.0, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	return maxf(8.0, float(text.length()) * 7.0)

func _get_action_icon_texture(bubble_text: String) -> Texture2D:
	if team != "Team_A":
		return null
	if bubble_text.contains("等待"):
		return ACTION_ICON_WAIT
	if bubble_text.contains("集结"):
		return ACTION_ICON_RALLY
	if bubble_text.contains("默认脑干") or brain_mode == "default_combat":
		return ACTION_ICON_DEFAULT_BRAIN
	return null

func _get_blueprint_cargo_capacity(blueprint: UnitBlueprint) -> int:
	if blueprint == null:
		return 0
	if blueprint.stats and blueprint.stats.cargo_capacity > 0:
		return blueprint.stats.cargo_capacity
	var capacity := 0
	var chassis_text := String(blueprint.chassis_id)
	if chassis_text.contains("cargo") or chassis_text.contains("hauler"):
		capacity += 8
	for module_id in blueprint.module_ids:
		var module_text := String(module_id)
		if module_text == "basic_cargo_pack":
			capacity += 8
		elif module_text == "expanded_cargo_pack":
			capacity += 16
		elif module_text.contains("cargo"):
			capacity += 8
	return capacity

func _format_logistics_task_type(task_type: String) -> String:
	match task_type:
		"idle":
			return "待命"
		"delivery":
			return "配送"
		"pickup":
			return "取货"
		"urgent_supply":
			return "紧急补货"
		"source_to_relay":
			return "运往前线补给点"
		"relay_to_base":
			return "补给点回运"
		"direct_to_base":
			return "远程直送主基地"
		"recover_cargo":
			return "回收残余货物"
		"dropoff":
			return "投递"
		"return":
			return "返航"
	return task_type if not task_type.is_empty() else "未指定"
