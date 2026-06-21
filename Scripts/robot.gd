extends CharacterBody2D
class_name RobotUnit

signal robot_lost(robot: Node, reason: StringName)

const CombatTargetRegistryScript := preload("res://Scripts/map/combat_target_registry.gd")
const TacticalTemplateCompilerScript := preload("res://Scripts/ai/tactical_template_compiler.gd")
const ACTION_ICON_RALLY := preload("res://Resources/art/ui/state_rally.svg")
const ACTION_ICON_WAIT := preload("res://Resources/art/ui/state_wait.svg")
const ACTION_ICON_DEFAULT_BRAIN := preload("res://Resources/art/ui/state_default_brain.svg")
const TARGET_LOCK_OVERLAY_TEXTURE := preload("res://Resources/art/map/target_lock_overlay.svg")
const BOSS_MACHINE_GUN_TURRET_TEXTURE := preload("res://Resources/art/enemies/wreckage_titan_machine_gun_turret.svg")
const BOSS_LASER_TURRET_TEXTURE := preload("res://Resources/art/enemies/wreckage_titan_laser_turret.svg")
const BOSS_SPELL_CORE_TEXTURE := preload("res://Resources/art/enemies/wreckage_titan_spell_core.svg")
const BOSS_EMP_PROJECTILE_TEXTURE := preload("res://Resources/art/effects/emp_projectile.svg")
const BOSS_GUARD_DRONE_SCENE_PATH := "res://Scenes/units/scavenger_hound.tscn"
const RALLY_CANDIDATE_CACHE_MSEC := 120
const SEPARATION_ACTIVE_INTERVAL_MSEC := 140
const SEPARATION_WAITING_INTERVAL_MSEC := 360
const SEPARATION_MAX_NEIGHBORS := 8
const MISSILE_LOCK_META := &"missile_lock_until_msec"
const MISSILE_LOCK_SOURCE_META := &"missile_lock_source"
const TARGET_LOCKER_UNIT_TYPE := "target_locker_robot"
const CRUISE_MISSILE_UNIT_TYPE := "cruise_missile_robot"
const MISSILE_FORMATION_CELL_SIZE := 64.0
const MISSILE_FORMATION_CHECK_MSEC := 700

static var _shared_rally_candidate_cache: Dictionary = {}
static var _shared_rally_cache_prune_msec: int = 0

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
@export_enum("default_combat", "path_patrol", "melee_hound", "ranged_hound", "logistics", "target_locker", "cruise_missile", "wreckage_titan_boss", "idle") var brain_mode: String = "default_combat"
@export var default_brain_enabled: bool = true
@export var preferred_range_ratio: float = 0.85
@export var range_dead_zone: float = 12.0
@export var visual_size: Vector2 = Vector2(42, 42)
@export var projectile_tint: Color = Color.WHITE
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
var target_lock_overlay_sprite: Sprite2D = null
var _next_separation_update_msec: int = 0
var _separation_accumulated_delta: float = 0.0
var _chainsaw_visual_was_active: bool = false
var _runtime_tag_groups: Array[String] = []
var _emp_disabled_until_msec: int = 0
var _lock_channel_target: Node2D = null
var _lock_channel_complete_msec: int = 0
var _last_lock_scan_msec: int = 0
var _missile_cached_target: Node2D = null
var _last_missile_scan_msec: int = 0
var _missile_last_fire_seconds: float = -9999.0
var _missile_formation_target_position: Vector2 = Vector2.INF
var _missile_formation_target_cell: Vector2i = Vector2i(-999999, -999999)
var _missile_next_formation_check_msec: int = 0
var _missile_visuals: Array[Dictionary] = []
var _boss_machine_gun_a: Sprite2D = null
var _boss_machine_gun_b: Sprite2D = null
var _boss_laser_turret: Sprite2D = null
var _boss_spell_core: Sprite2D = null
var _boss_mg_a_target: Node2D = null
var _boss_mg_b_target: Node2D = null
var _boss_laser_target: Node2D = null
var _boss_last_mg_a_seconds: float = -9999.0
var _boss_last_mg_b_seconds: float = -9999.0
var _boss_last_laser_seconds: float = -9999.0
var _boss_last_emp_seconds: float = -9999.0
var _boss_last_summon_seconds: float = -9999.0
var _boss_laser_beam_until_msec: int = 0
var _boss_laser_beam_start: Vector2 = Vector2.ZERO
var _boss_laser_beam_end: Vector2 = Vector2.ZERO
var _boss_laser_visual_target: Node2D = null
var _boss_mg_traces: Array[Dictionary] = []
var _boss_cannon_shells: Array[Dictionary] = []
var _boss_splash_rings: Array[Dictionary] = []
var _boss_emp_shells: Array[Dictionary] = []
var _boss_emp_pulses: Array[Dictionary] = []

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
	_tick_pending_cruise_missile_impacts()
	_tick_pending_boss_projectile_impacts()
	if _is_emp_disabled():
		if movement_component:
			movement_component.stop(&"emp_disabled")
			movement_component.apply_to(self)
		current_action = "EMP disabled"
		current_fire_state = "EMP %.1fs" % get_emp_disabled_remaining_seconds()
		_update_unit_visuals()
		return

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
		"ranged_hound":
			_tick_ranged_hound()
		"logistics":
			pass
		"target_locker":
			_clear_invalid_lock_channel()
			if not _evaluate_special_brain_rules():
				_tick_target_locker(delta)
		"cruise_missile":
			if not _evaluate_special_brain_rules():
				_tick_cruise_missile(delta)
		"wreckage_titan_boss":
			_tick_wreckage_titan_boss(delta)
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
		if String(blueprint.unit_type_id).contains("salvage") or String(blueprint.id).contains("salvage"):
			tags.append("salvage")
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
		var unit_type_text := String(blueprint.unit_type_id)
		if unit_type_text == TARGET_LOCKER_UNIT_TYPE or String(blueprint.id).contains("target_locker"):
			tags = ["combat", "scout", "locker", "ranged"]
			brain_mode = "target_locker"
			weapon_enabled = false
			damage_type = &"none"
			fire_range = maxf(fire_range, 320.0)
			target_lock_seconds = maxf(target_lock_seconds, 2.0)
		elif unit_type_text == CRUISE_MISSILE_UNIT_TYPE or String(blueprint.id).contains("cruise_missile"):
			tags = ["combat", "ranged", "missile", "long_range"]
			brain_mode = "cruise_missile"
			weapon_enabled = true
			damage_type = &"missile"
			fire_range = maxf(fire_range, 99999.0)
			fire_cooldown_seconds = maxf(fire_cooldown_seconds, 8.0)
			projectile_tint = Color(1.0, 0.58, 0.18, 1.0)
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
	var attack_mode := str(config.get("attack_mode", "melee"))
	brain_mode = "ranged_hound" if attack_mode == "ranged" else "melee_hound"
	if attack_mode == "boss":
		brain_mode = "wreckage_titan_boss"
	blueprint_snapshot_id = &""
	default_brain_enabled = false
	weapon_enabled = attack_mode == "ranged"
	max_hp = int(config.get("max_hp", 90))
	speed = float(config.get("speed", 135.0))
	armor_type = StringName(str(config.get("armor_type", "light")))
	damage_type = StringName(str(config.get("damage_type", "melee")))
	tags = _string_array_from_variant(config.get("tags", []))
	lifespan_seconds = 0.0
	pool_name = str(config.get("pool_name", config.get("id", "scavenger_hound")))
	icon_path = str(config.get("icon_path", "res://Resources/art/enemies/scavenger_hound.svg"))
	visual_size = _vector2_from_config(config.get("visual_size", [32.0, 32.0]), Vector2(32.0, 32.0))
	melee_damage = int(config.get("melee_damage", 16))
	melee_range = float(config.get("melee_range", 32.0))
	melee_cooldown_seconds = float(config.get("melee_cooldown_seconds", 1.0))
	fire_range = float(config.get("fire_range", melee_range))
	bullet_damage = int(config.get("damage", melee_damage))
	fire_cooldown_seconds = float(config.get("fire_cooldown_seconds", melee_cooldown_seconds))
	projectile_tint = _color_from_config(config.get("projectile_tint", [1.0, 0.42, 0.18, 1.0]), Color(1.0, 0.42, 0.18, 1.0))
	weapon_audio_id = StringName(str(config.get("weapon_audio_id", "enemy_melee")))
	guard_aggro_radius = maxf(0.0, float(config.get("guard_aggro_radius", 320.0)))
	hound_follow_up_radius = maxf(0.0, float(config.get("hound_follow_up_radius", 180.0)))
	if brain_mode == "wreckage_titan_boss":
		weapon_enabled = false
		lifespan_seconds = 0.0
		separation_radius = 96.0
		muzzle_distance = 64.0
		turn_speed_radians = 4.0
	reset_state()
	source_nest = nest if nest != null and is_instance_valid(nest) else null
	guard_home_position = global_position

func _vector2_from_config(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback

func _color_from_config(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Color(
			float(value[0]),
			float(value[1]),
			float(value[2]),
			float(value[3]) if value.size() >= 4 else 1.0
		)
	return fallback

func _string_array_from_variant(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		var text := str(item)
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result

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
	_emp_disabled_until_msec = 0
	_lock_channel_target = null
	_lock_channel_complete_msec = 0
	_last_lock_scan_msec = 0
	_missile_cached_target = null
	_last_missile_scan_msec = 0
	_missile_last_fire_seconds = -9999.0
	_missile_formation_target_position = Vector2.INF
	_missile_formation_target_cell = Vector2i(-999999, -999999)
	_missile_next_formation_check_msec = 0
	_missile_visuals.clear()
	_boss_mg_a_target = null
	_boss_mg_b_target = null
	_boss_laser_target = null
	_boss_last_mg_a_seconds = -9999.0
	_boss_last_mg_b_seconds = -9999.0
	_boss_last_laser_seconds = -9999.0
	_boss_last_emp_seconds = -9999.0
	_boss_last_summon_seconds = -9999.0
	_boss_laser_beam_until_msec = 0
	_boss_laser_visual_target = null
	_boss_mg_traces.clear()
	_boss_cannon_shells.clear()
	_boss_splash_rings.clear()
	_boss_emp_shells.clear()
	_boss_emp_pulses.clear()
	_clear_navigation_path()
	_sync_runtime_groups()
	_configure_team_collision()
	_configure_components()
	_update_unit_visuals()

func is_alive() -> bool:
	return not _is_dead and (health_component == null or health_component.is_alive())

func get_display_name() -> String:
	return display_name

func uses_melee_default_combat() -> bool:
	return _uses_chainsaw_weapon() or damage_type == &"melee"

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
	if not tags.is_empty():
		lines.append("Tags: %s" % ", ".join(tags))
	if is_cargo_robot():
		lines.append("物流状态：%s" % logistics_status_text)
		lines.append("货舱：%s / %s" % [get_cargo_used_capacity(), cargo_capacity])
		lines.append_array(get_logistics_task_summary_lines())
	lines.append("Stats: HP %s / Speed %.1f" % [max_hp, speed])
	lines.append("Combat: armor %s / damage %s" % [String(armor_type), String(damage_type)])
	lines.append("攻击：%s" % _format_attack_profile())
	if brain_mode == "wreckage_titan_boss":
		lines.append("Boss技能CD：EMP %.1fs / 召唤 %.1fs" % [_get_boss_emp_cooldown_remaining(), _get_boss_summon_cooldown_remaining()])
		lines.append("Boss主武器：热能激光 8/0.10s；双机炮 36/0.85s 溅射")
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
	if brain_mode == "melee_hound" or brain_mode == "ranged_hound":
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

func prioritize_tagged_target_near_current(radius: float = 180.0, tag: StringName = &"backline") -> bool:
	return switch_to_backline_near_current_target(radius, tag)

func switch_to_backline_near_current_target(radius: float = 180.0, tag: StringName = &"backline") -> bool:
	var anchor := current_target
	if not _is_valid_enemy_target(anchor):
		anchor = _locked_target
	if not _is_valid_enemy_target(anchor):
		return false
	var candidate := find_tagged_enemy_near_target(anchor, tag, radius)
	if candidate == null:
		return false
	if candidate == anchor:
		return false
	_lock_target(candidate, target_lock_seconds)
	current_target = candidate
	current_distance_to_target = global_position.distance_to(get_target_position(candidate))
	record_brain_trigger(&"prioritize_tagged_target", "优先 %s 目标：%s" % [String(tag), candidate.name])
	return true

func find_tagged_enemy_near_target(anchor: Node2D, tag: StringName = &"backline", radius: float = 180.0) -> Node2D:
	if not _is_valid_enemy_target(anchor) or enemy_sensor == null:
		return null
	var center := get_target_position(anchor)
	var candidates: Array[Node2D] = []
	if enemy_sensor.has_method("get_enemies_in_radius"):
		candidates = enemy_sensor.call("get_enemies_in_radius", self, team, center, radius)
	else:
		candidates = _get_sensed_enemies()
	var best: Node2D = null
	var best_distance := INF
	for candidate in candidates:
		if not _is_valid_enemy_target(candidate):
			continue
		if not candidate.is_in_group(String(tag)):
			continue
		var distance := center.distance_squared_to(get_target_position(candidate))
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best

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
	if brain_mode == "cruise_missile":
		return
	if delta <= 0.0 or separation_radius <= 0.0 or separation_strength <= 0.0:
		return
	_separation_accumulated_delta += delta
	var now := Time.get_ticks_msec()
	if _next_separation_update_msec <= 0:
		_next_separation_update_msec = now + int(get_instance_id() % 83)
	if now < _next_separation_update_msec:
		return
	var separation_interval := SEPARATION_WAITING_INTERVAL_MSEC if _should_throttle_separation() else SEPARATION_ACTIVE_INTERVAL_MSEC
	_next_separation_update_msec = now + separation_interval
	delta = minf(_separation_accumulated_delta, 0.2)
	_separation_accumulated_delta = 0.0
	var effective_radius := separation_radius
	var effective_strength := separation_strength
	if _should_throttle_separation():
		effective_strength *= 0.45
	if _is_actively_pursuing_melee_target():
		effective_radius = minf(effective_radius, 20.0)
		effective_strength *= 0.15
	var effective_radius_squared := effective_radius * effective_radius
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
		var distance_squared := offset.length_squared()
		if distance_squared <= 0.000001 or distance_squared >= effective_radius_squared:
			continue
		var distance: float = sqrt(distance_squared)
		if distance <= 0.001 or distance >= effective_radius:
			continue
		var weight: float = 1.0 - distance / effective_radius
		push += offset.normalized() * weight
		neighbor_count += 1
		if neighbor_count >= SEPARATION_MAX_NEIGHBORS:
			break
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

func _should_throttle_separation() -> bool:
	if movement_component != null:
		var intent := StringName(str(movement_component.get("movement_intent")))
		if intent == &"idle" or intent == &"hold" or intent == &"arrived":
			return true
	if current_action == "等待队友" or current_action == "闲置" or current_action == "巢穴周围警戒":
		return true
	return false

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
	_shared_rally_candidate_cache.clear()

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
	var now := Time.get_ticks_msec()
	var cached: Dictionary = _shared_rally_candidate_cache.get(ready_key, {})
	if not cached.is_empty() and now - int(cached.get("time", 0)) <= RALLY_CANDIDATE_CACHE_MSEC:
		var cached_candidates: Array = cached.get("candidates", [])
		var valid_cached := _filter_cached_rally_release_candidates(cached_candidates, radius, ready_key)
		if valid_cached.size() == cached_candidates.size():
			return valid_cached
	var release_radius := radius + 24.0
	for unit in get_tree().get_nodes_in_group("combat_unit"):
		if unit == null or not is_instance_valid(unit) or not (unit is RobotUnit):
			continue
		var other := unit as RobotUnit
		if _is_rally_release_candidate_for_key(other, radius, release_radius, ready_key):
			candidates.append(other)
	_sort_rally_release_candidates(candidates)
	_shared_rally_candidate_cache[ready_key] = {
		"time": now,
		"candidates": candidates.duplicate(),
	}
	_prune_shared_rally_candidate_cache(now)
	return candidates

func _filter_cached_rally_release_candidates(cached_candidates: Array, radius: float, ready_key: String) -> Array[RobotUnit]:
	var result: Array[RobotUnit] = []
	var release_radius := radius + 24.0
	for candidate_value in cached_candidates:
		if candidate_value == null or not is_instance_valid(candidate_value) or not (candidate_value is RobotUnit):
			continue
		var other := candidate_value as RobotUnit
		if _is_rally_release_candidate_for_key(other, radius, release_radius, ready_key):
			result.append(other)
	return result

func _is_rally_release_candidate_for_key(other: RobotUnit, radius: float, release_radius: float, ready_key: String) -> bool:
	if other == null or not other.is_inside_tree() or not other.is_alive():
		return false
	if other.get_state_flag(&"squad_ready"):
		return false
	if not other.has_rally_point or other.team != team:
		return false
	if other._get_rally_ready_key(radius) != ready_key:
		return false
	var distance := other.distance_to_rally_point()
	if distance > release_radius:
		return false
	if distance > radius and not other.get_state_flag(&"rallied"):
		return false
	return true

func _sort_rally_release_candidates(candidates: Array[RobotUnit]) -> void:
	candidates.sort_custom(func(a: RobotUnit, b: RobotUnit) -> bool:
		var a_time := a._rallied_at_msec if a._rallied_at_msec > 0 else 0x7FFFFFFF
		var b_time := b._rallied_at_msec if b._rallied_at_msec > 0 else 0x7FFFFFFF
		if a_time == b_time:
			return int(a.get_instance_id()) < int(b.get_instance_id())
		return a_time < b_time
	)

func _prune_shared_rally_candidate_cache(now_msec: int) -> void:
	if _shared_rally_candidate_cache.size() <= 64 and now_msec - _shared_rally_cache_prune_msec < 1000:
		return
	_shared_rally_cache_prune_msec = now_msec
	var ttl := RALLY_CANDIDATE_CACHE_MSEC * 4
	for key in _shared_rally_candidate_cache.keys():
		var cached: Dictionary = _shared_rally_candidate_cache.get(key, {})
		if cached.is_empty() or now_msec - int(cached.get("time", 0)) > ttl:
			_shared_rally_candidate_cache.erase(key)

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
	if flag_id == &"rallied" or flag_id == &"squad_ready":
		clear_shared_rally_readiness()
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
		"projectile_tint": projectile_tint,
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
	if _is_dead:
		return
	_last_damage_source_payload = source_payload.duplicate(true)
	var multiplier := _damage_multiplier_for_profile(source_payload)
	var final_damage := maxi(1, roundi(float(amount) * multiplier))
	take_damage(final_damage)
	_play_damage_impact_audio(source_payload, multiplier)

func get_last_damage_source_payload() -> Dictionary:
	return _last_damage_source_payload.duplicate(true)

func heat_ratio() -> float:
	if heat_capacity <= 0.0:
		return 0.0
	return clampf(current_heat / heat_capacity, 0.0, 1.0)

func has_heat_weapon() -> bool:
	return heat_capacity > 0.0 and heat_per_shot > 0.0

func apply_emp_disabled(duration_seconds: float) -> void:
	if duration_seconds <= 0.0:
		return
	_emp_disabled_until_msec = maxi(_emp_disabled_until_msec, Time.get_ticks_msec() + roundi(duration_seconds * 1000.0))
	if movement_component:
		movement_component.stop(&"emp_disabled")
	current_action = "EMP disabled"
	current_fire_state = "EMP %.1fs" % get_emp_disabled_remaining_seconds()
	record_brain_trigger(&"emp_disabled", "EMP disabled %.1fs" % duration_seconds)

func get_emp_disabled_remaining_seconds() -> float:
	return maxf(0.0, float(_emp_disabled_until_msec - Time.get_ticks_msec()) / 1000.0)

func _is_emp_disabled() -> bool:
	return Time.get_ticks_msec() < _emp_disabled_until_msec

func apply_missile_target_lock(locker: Node = null, duration_seconds: float = 10.0) -> void:
	var lock_until := Time.get_ticks_msec() + roundi(maxf(0.25, duration_seconds) * 1000.0)
	set_meta(MISSILE_LOCK_META, lock_until)
	set_meta(MISSILE_LOCK_SOURCE_META, str(locker.name) if locker != null and is_instance_valid(locker) else "")
	queue_redraw()

func get_missile_target_lock_remaining_seconds() -> float:
	if not has_meta(MISSILE_LOCK_META):
		return 0.0
	return maxf(0.0, float(int(get_meta(MISSILE_LOCK_META)) - Time.get_ticks_msec()) / 1000.0)

func is_missile_locked() -> bool:
	return get_missile_target_lock_remaining_seconds() > 0.0

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
	return maxi(1, roundi(float(amount) * _damage_multiplier_for_profile(source_payload)))

func _damage_multiplier_for_profile(source_payload: Dictionary) -> float:
	var source_damage_type := StringName(str(source_payload.get("damage_type", "kinetic")))
	var source_team := str(source_payload.get("team", ""))
	var multiplier := 1.0
	if armor_type == &"heavy_armor":
		if source_team == "Team_B":
			match source_damage_type:
				&"melee", &"enemy_melee":
					multiplier = 0.75
				&"kinetic", &"ranged", &"enemy_ranged":
					multiplier = 0.50
	elif armor_type == &"armored":
		match source_damage_type:
			&"kinetic":
				multiplier = 0.55
			&"thermal":
				multiplier = 1.35
			&"missile":
				multiplier = 1.20
			&"melee":
				multiplier = 0.80
	elif armor_type == &"structure_armor":
		match source_damage_type:
			&"kinetic":
				multiplier = 0.75
			&"thermal":
				multiplier = 1.25
			&"missile":
				multiplier = 1.35
	elif armor_type == &"boss_armor":
		match source_damage_type:
			&"kinetic":
				multiplier = 0.45
			&"thermal":
				multiplier = 0.85
			&"missile":
				multiplier = 1.45
			&"melee":
				multiplier = 0.65
	return multiplier

func _damage_effectiveness_from_multiplier(multiplier: float) -> StringName:
	if multiplier <= 0.80:
		return &"weak"
	if multiplier >= 1.20:
		return &"strong"
	return &"normal"

func _play_damage_impact_audio(source_payload: Dictionary, multiplier: float) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager == null or not audio_manager.has_method("play_damage_impact_cue"):
		return
	audio_manager.call(
		"play_damage_impact_cue",
		_damage_effectiveness_from_multiplier(multiplier),
		StringName(str(source_payload.get("weapon_id", "default")))
	)

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
	for old_tag in _runtime_tag_groups:
		if not tags.has(old_tag):
			remove_from_group(old_tag)
	_runtime_tag_groups.clear()
	for tag in tags:
		if not tag.is_empty():
			add_to_group(tag)
			_runtime_tag_groups.append(tag)
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
	var valid_source_nest := _get_valid_source_nest()
	if _is_valid_enemy_target(_locked_target):
		if valid_source_nest != null and valid_source_nest.has_method("notify_guard_engaged"):
			valid_source_nest.call("notify_guard_engaged", _locked_target)
		return _locked_target
	_clear_locked_target()
	if enemy_sensor == null:
		return null

	var enemies: Array[Node2D] = []
	if _hound_has_engaged and enemy_sensor.has_method("get_follow_up_targets"):
		enemies = enemy_sensor.get_follow_up_targets(self, team, hound_follow_up_radius)
	if enemies.is_empty() and valid_source_nest != null and valid_source_nest.has_method("get_shared_alert_target"):
		var shared_target: Variant = valid_source_nest.call("get_shared_alert_target")
		if _is_valid_enemy_target(shared_target):
			enemies.append(shared_target as Node2D)
	if enemies.is_empty() and enemy_sensor.has_method("get_initial_targets"):
		enemies = enemy_sensor.get_initial_targets(self, team, valid_source_nest, guard_aggro_radius)
	if enemies.is_empty():
		_hound_has_engaged = false
		return null

	_hound_has_engaged = true
	var target := _lock_target(enemies[0], 0.0)
	if target != null and valid_source_nest != null and valid_source_nest.has_method("notify_guard_engaged"):
		valid_source_nest.call("notify_guard_engaged", target)
	return target

func _get_valid_source_nest() -> Node:
	if source_nest != null and is_instance_valid(source_nest):
		return source_nest
	source_nest = null
	return null

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

func _is_valid_enemy_target(target: Variant) -> bool:
	if enemy_sensor == null or target == null or not is_instance_valid(target) or not (target is Node2D):
		return false
	return bool(enemy_sensor.is_valid_enemy(self, team, target as Node2D))

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
		var next_rotation := 0.0 if _uses_fixed_icon_orientation() else _facing_angle + _get_icon_rotation_offset()
		if not is_equal_approx(unit_sprite.rotation, next_rotation):
			unit_sprite.rotation = next_rotation
		var next_modulate := Color(1.0, 0.48, 0.38, 1.0) if Time.get_ticks_msec() < _damage_flash_until_msec else Color.WHITE
		if unit_sprite.modulate != next_modulate:
			unit_sprite.modulate = next_modulate
	_update_module_visuals()
	_update_target_lock_overlay_visuals()
	if brain_mode == "wreckage_titan_boss":
		_ensure_boss_turrets()
		_update_boss_turret_visuals(get_physics_process_delta_time())
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
	if _has_active_projectile_visuals():
		queue_redraw()

func _update_module_visuals() -> void:
	if module_sprite:
		module_sprite.visible = false

func _update_target_lock_overlay_visuals() -> void:
	if target_lock_overlay_sprite == null:
		target_lock_overlay_sprite = Sprite2D.new()
		target_lock_overlay_sprite.name = "TargetLockOverlay"
		target_lock_overlay_sprite.texture = TARGET_LOCK_OVERLAY_TEXTURE
		target_lock_overlay_sprite.z_index = 12
		target_lock_overlay_sprite.visible = false
		add_child(target_lock_overlay_sprite)
	var lock_remaining := get_missile_target_lock_remaining_seconds()
	var should_show := lock_remaining > 0.0 and is_alive()
	target_lock_overlay_sprite.visible = should_show
	if not should_show:
		return
	var texture := target_lock_overlay_sprite.texture
	if texture != null:
		var texture_size := texture.get_size()
		var size := maxf(34.0, maxf(visual_size.x, visual_size.y) * 0.95)
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			target_lock_overlay_sprite.scale = Vector2(size / texture_size.x, size / texture_size.y)
	target_lock_overlay_sprite.rotation = -float(Time.get_ticks_msec() % 1600) / 1600.0 * TAU

func _has_active_projectile_visuals() -> bool:
	var now := Time.get_ticks_msec()
	return now <= _boss_laser_beam_until_msec \
		or not _missile_visuals.is_empty() \
		or not _boss_mg_traces.is_empty() \
		or not _boss_cannon_shells.is_empty() \
		or not _boss_splash_rings.is_empty() \
		or not _boss_emp_shells.is_empty() \
		or not _boss_emp_pulses.is_empty()

func _update_facing(delta: float) -> void:
	if _should_face_attack_target():
		_turn_towards(get_target_position(current_target), delta)
		return
	if movement_component and movement_component.desired_velocity.length() > 0.001:
		_turn_angle_towards(movement_component.desired_velocity.angle(), delta)

func _ensure_boss_turrets() -> void:
	if brain_mode != "wreckage_titan_boss":
		return
	if _boss_machine_gun_a != null and is_instance_valid(_boss_machine_gun_a):
		return
	_boss_machine_gun_a = _make_boss_turret("MachineGunTurretA", BOSS_MACHINE_GUN_TURRET_TEXTURE, Vector2(34, -24), Vector2(36, 36))
	_boss_machine_gun_b = _make_boss_turret("MachineGunTurretB", BOSS_MACHINE_GUN_TURRET_TEXTURE, Vector2(34, 24), Vector2(36, 36))
	_boss_laser_turret = _make_boss_turret("LaserTurret", BOSS_LASER_TURRET_TEXTURE, Vector2(-32, 0), Vector2(48, 48))
	_boss_spell_core = _make_boss_turret("SpellCore", BOSS_SPELL_CORE_TEXTURE, Vector2(0, 0), Vector2(50, 50))

func _make_boss_turret(node_name: String, texture: Texture2D, local_position: Vector2, target_size: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.position = local_position
	sprite.z_index = 4
	if texture != null:
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			sprite.scale = Vector2(target_size.x / texture_size.x, target_size.y / texture_size.y)
	add_child(sprite)
	return sprite

func _update_boss_turret_visuals(delta: float) -> void:
	_rotate_turret_towards(_boss_machine_gun_a, _boss_mg_a_target, delta)
	_rotate_turret_towards(_boss_machine_gun_b, _boss_mg_b_target, delta)
	_rotate_turret_towards(_boss_laser_turret, _boss_laser_target, delta)
	if _boss_spell_core != null and is_instance_valid(_boss_spell_core):
		_boss_spell_core.rotation += delta * 0.9

func _rotate_turret_towards(sprite: Sprite2D, target: Node2D, delta: float) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	if not _is_valid_enemy_target(target):
		return
	var direction := get_target_position(target) - sprite.global_position
	if direction.length() <= 0.001:
		return
	sprite.global_rotation = rotate_toward(sprite.global_rotation, direction.angle(), maxf(0.0, delta) * 8.0)

func _hide_boss_turrets() -> void:
	for sprite in [_boss_machine_gun_a, _boss_machine_gun_b, _boss_laser_turret, _boss_spell_core]:
		if sprite != null and is_instance_valid(sprite):
			sprite.visible = false

func _uses_fixed_icon_orientation() -> bool:
	return brain_mode == "logistics" or brain_mode == "cruise_missile" or brain_mode == "wreckage_titan_boss" or tags.has("cargo") or tags.has("logistics")

func _get_icon_rotation_offset() -> float:
	if brain_mode == "target_locker":
		return PI * 0.5
	return 0.0

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

func _evaluate_special_brain_rules() -> bool:
	if ai_controller and ai_controller.has_method("evaluate_logic"):
		return bool(ai_controller.call("evaluate_logic"))
	return false

func _clear_invalid_lock_channel() -> void:
	if _lock_channel_target != null and not _is_valid_enemy_target(_lock_channel_target):
		_lock_channel_target = null
		_lock_channel_complete_msec = 0
		queue_redraw()

func _tick_target_locker(delta: float) -> void:
	var enemy := _get_lock_channel_target()
	if enemy == null:
		enemy = _select_target_for_locking()
	current_target = enemy
	if enemy == null:
		current_action = "扫描锁定目标"
		current_fire_state = "无可锁定目标"
		current_distance_to_target = -1.0
		if movement_component:
			movement_component.stop(&"idle")
		return
	var target_position := get_target_position(enemy)
	current_distance_to_target = global_position.distance_to(target_position)
	if current_distance_to_target > fire_range:
		_lock_channel_target = null
		_lock_channel_complete_msec = 0
		move_towards(target_position, enemy)
		current_action = "接近锁定距离"
		current_fire_state = "目标超出锁定距离"
		return
	if movement_component:
		movement_component.stop(&"target_lock")
	_turn_towards(target_position, delta)
	var now := Time.get_ticks_msec()
	if _lock_channel_target != enemy:
		_lock_channel_target = enemy
		_lock_channel_complete_msec = now + roundi(target_lock_seconds * 1000.0)
	current_action = "目标锁定"
	var remaining := maxf(0.0, float(_lock_channel_complete_msec - now) / 1000.0)
	current_fire_state = "锁定 %.1fs" % remaining
	queue_redraw()
	if now >= _lock_channel_complete_msec:
		_apply_target_lock_to(enemy, 12.0)
		_lock_channel_complete_msec = now + roundi(target_lock_seconds * 1000.0)
		record_brain_trigger(&"target_locked", "目标已锁定：%s" % enemy.name)

func _get_lock_channel_target() -> Node2D:
	if _is_valid_enemy_target(_lock_channel_target):
		return _lock_channel_target
	if _lock_channel_target != null:
		queue_redraw()
	_lock_channel_target = null
	_lock_channel_complete_msec = 0
	return null

func _select_target_for_locking() -> Node2D:
	var now := Time.get_ticks_msec()
	if now - _last_lock_scan_msec < 180 and _is_valid_enemy_target(current_target):
		return current_target
	_last_lock_scan_msec = now
	var best: Node2D = null
	var best_score := -INF
	for candidate in _get_all_valid_enemy_targets():
		var score := _score_lock_target(candidate)
		if score > best_score:
			best = candidate
			best_score = score
	return best

func _score_lock_target(candidate: Node2D) -> float:
	if candidate == null:
		return -INF
	var score := 0.0
	var remaining := _get_target_lock_remaining_seconds(candidate)
	score -= remaining * 12.0
	if remaining >= 8.0:
		score -= 100.0
	var distance := global_position.distance_to(get_target_position(candidate))
	score += maxf(0.0, 520.0 - distance) * 0.12
	score -= distance * 0.04
	if _target_has_tag(candidate, &"boss"):
		score += 90.0
	if _target_has_tag(candidate, &"high_value"):
		score += 55.0
	if _target_has_tag(candidate, &"jammer"):
		score += 45.0
	if _target_has_tag(candidate, &"backline"):
		score += 20.0
	return score

func _apply_target_lock_to(target: Node2D, duration_seconds: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("apply_missile_target_lock"):
		target.call("apply_missile_target_lock", self, duration_seconds)
	else:
		target.set_meta(MISSILE_LOCK_META, Time.get_ticks_msec() + roundi(duration_seconds * 1000.0))
		target.set_meta(MISSILE_LOCK_SOURCE_META, str(name))

func _tick_cruise_missile(delta: float) -> void:
	var formation_target := _get_cruise_missile_formation_target()
	var moving_to_formation := false
	if formation_target != Vector2.INF and global_position.distance_to(formation_target) > 14.0:
		moving_to_formation = move_towards(formation_target, null, 0.72)
		if moving_to_formation:
			current_action = "导弹阵地展开"
	var enemy := _select_locked_missile_target()
	current_target = enemy
	if enemy == null:
		if not moving_to_formation:
			current_action = "等待锁定目标"
		current_fire_state = "无锁定目标"
		current_distance_to_target = -1.0
		if movement_component and not moving_to_formation:
			movement_component.stop(&"missile_wait")
		return
	if movement_component and not moving_to_formation:
		movement_component.stop(&"missile_fire")
	var target_position := get_target_position(enemy)
	_turn_towards(target_position, delta)
	current_distance_to_target = global_position.distance_to(target_position)
	if not moving_to_formation:
		current_action = "远程导弹打击"
	var now_seconds := Time.get_ticks_msec() / 1000.0
	var cooldown := maxf(1.0, fire_cooldown_seconds)
	if now_seconds - _missile_last_fire_seconds < cooldown:
		current_fire_state = "导弹装填 %.1fs" % maxf(0.0, cooldown - (now_seconds - _missile_last_fire_seconds))
		return
	_missile_last_fire_seconds = now_seconds
	_fire_cruise_missile(enemy)

func _select_locked_missile_target() -> Node2D:
	var now := Time.get_ticks_msec()
	if now - _last_missile_scan_msec < 250 and _is_valid_enemy_target(_missile_cached_target) and _is_target_missile_locked(_missile_cached_target):
		return _missile_cached_target
	_last_missile_scan_msec = now
	var best: Node2D = null
	var best_score := -INF
	for candidate in _get_all_valid_enemy_targets():
		if not _is_target_missile_locked(candidate):
			continue
		var score := _score_missile_target(candidate)
		if score > best_score:
			best = candidate
			best_score = score
	_missile_cached_target = best
	return best

func _get_cruise_missile_formation_target() -> Vector2:
	var now := Time.get_ticks_msec()
	if now < _missile_next_formation_check_msec:
		return _missile_formation_target_position
	_missile_next_formation_check_msec = now + MISSILE_FORMATION_CHECK_MSEC + int(get_instance_id() % 173)
	_missile_formation_target_position = Vector2.INF
	_missile_formation_target_cell = Vector2i(-999999, -999999)
	var path_provider := _get_path_provider()
	if path_provider == null:
		return Vector2.INF
	var self_cell := _get_navigation_cell(path_provider, global_position)
	if self_cell.x <= -999999:
		return Vector2.INF
	var cluster := _collect_nearby_cruise_missiles(path_provider, self_cell)
	if cluster.size() <= 1:
		return Vector2.INF
	cluster.sort_custom(func(a: RobotUnit, b: RobotUnit) -> bool:
		return int(a.get_instance_id()) < int(b.get_instance_id())
	)
	var index := cluster.find(self)
	if index < 0:
		return Vector2.INF
	var anchor := _get_missile_cluster_anchor_cell(path_provider, cluster)
	var target_cell := _find_available_missile_formation_cell(path_provider, anchor, index, cluster)
	if target_cell == self_cell and global_position.distance_to(_missile_cell_to_world(target_cell)) <= 14.0:
		return Vector2.INF
	_missile_formation_target_cell = target_cell
	_missile_formation_target_position = _missile_cell_to_world(target_cell)
	return _missile_formation_target_position

func _collect_nearby_cruise_missiles(path_provider: Node, self_cell: Vector2i) -> Array[RobotUnit]:
	var result: Array[RobotUnit] = []
	if get_tree() == null:
		return result
	for unit in get_tree().get_nodes_in_group("missile"):
		if unit == null or not is_instance_valid(unit) or not (unit is RobotUnit):
			continue
		var other := unit as RobotUnit
		if other.team != team or not other.is_alive() or other.brain_mode != "cruise_missile":
			continue
		var cell := _get_navigation_cell(path_provider, other.global_position)
		var same_cell := cell == self_cell
		var close_enough := global_position.distance_to(other.global_position) <= MISSILE_FORMATION_CELL_SIZE * 0.72
		if same_cell or close_enough:
			result.append(other)
	return result

func _get_missile_cluster_anchor_cell(path_provider: Node, cluster: Array[RobotUnit]) -> Vector2i:
	var min_cell := Vector2i(999999, 999999)
	for unit in cluster:
		var cell := _get_navigation_cell(path_provider, unit.global_position)
		if cell.x < min_cell.x or (cell.x == min_cell.x and cell.y < min_cell.y):
			min_cell = cell
	return min_cell

func _find_available_missile_formation_cell(path_provider: Node, anchor: Vector2i, preferred_index: int, cluster: Array[RobotUnit]) -> Vector2i:
	var offsets := _get_square_formation_offsets(maxi(4, cluster.size() + 4))
	var occupied_by_other_missiles := {}
	for unit in cluster:
		if unit == self:
			continue
		var existing_target: Vector2i = unit._missile_formation_target_cell
		if existing_target.x > -999999:
			occupied_by_other_missiles[existing_target] = true
	for pass_index in range(2):
		for offset_index in range(offsets.size()):
			var index := (preferred_index + offset_index) % offsets.size()
			var candidate := anchor + offsets[index]
			if occupied_by_other_missiles.has(candidate):
				continue
			if _is_missile_formation_cell_usable(path_provider, candidate):
				return candidate
	return anchor

func _get_square_formation_offsets(min_count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var side := ceili(sqrt(float(maxi(1, min_count))))
	var half := floori(float(side) / 2.0)
	for y in range(side):
		for x in range(side):
			result.append(Vector2i(x - half, y - half))
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = absi(a.x) + absi(a.y)
		var db: int = absi(b.x) + absi(b.y)
		if da == db:
			if a.y == b.y:
				return a.x < b.x
			return a.y < b.y
		return da < db
	)
	return result

func _is_missile_formation_cell_usable(path_provider: Node, cell: Vector2i) -> bool:
	var world_position := _missile_cell_to_world(cell)
	if path_provider != null and path_provider.has_method("is_navigation_world_position_walkable"):
		return bool(path_provider.call("is_navigation_world_position_walkable", world_position))
	return true

func _missile_cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(float(cell.x) + 0.5) * MISSILE_FORMATION_CELL_SIZE,
		(float(cell.y) + 0.5) * MISSILE_FORMATION_CELL_SIZE
	)

func _score_missile_target(candidate: Node2D) -> float:
	var score := _get_target_lock_remaining_seconds(candidate) * 2.0
	if _target_has_tag(candidate, &"boss"):
		score += 120.0
	if _target_has_tag(candidate, &"high_value"):
		score += 70.0
	if _target_has_tag(candidate, &"backline"):
		score += 25.0
	score += maxf(0.0, 1000.0 - global_position.distance_to(get_target_position(candidate))) * 0.01
	return score

func _fire_cruise_missile(target: Node2D) -> void:
	var payload := _make_weapon_source_payload()
	payload["weapon_id"] = "cruise_missile_launcher"
	payload["damage_type"] = "missile"
	var center := get_target_position(target)
	var direct_damage := maxi(1, bullet_damage)
	var now := Time.get_ticks_msec()
	_missile_visuals.append({
		"start": global_position,
		"end": center,
		"target": target,
		"payload": payload,
		"direct_damage": direct_damage,
		"splash_radius": 92.0,
		"start_msec": now,
		"end_msec": now + 720,
		"impacted": false,
		"impact_msec": 0,
	})
	if _missile_visuals.size() > 8:
		_missile_visuals.pop_front()
	current_fire_state = "导弹发射"
	record_brain_trigger(&"cruise_missile_fire", "巡航导弹发射：%s" % target.name)
	queue_redraw()

func _tick_pending_cruise_missile_impacts() -> void:
	if _missile_visuals.is_empty():
		return
	var now := Time.get_ticks_msec()
	for index in range(_missile_visuals.size() - 1, -1, -1):
		var visual: Dictionary = _missile_visuals[index]
		if bool(visual.get("impacted", false)):
			continue
		if now < int(visual.get("end_msec", 0)):
			continue
		_apply_cruise_missile_impact(visual)
		visual["impacted"] = true
		visual["impact_msec"] = now
		_missile_visuals[index] = visual
		current_fire_state = "导弹命中"
		queue_redraw()

func _apply_cruise_missile_impact(visual: Dictionary) -> void:
	var center: Vector2 = visual.get("end", global_position)
	var target: Node2D = visual.get("target", null)
	var payload: Dictionary = visual.get("payload", _make_weapon_source_payload())
	var direct_damage := maxi(1, int(visual.get("direct_damage", bullet_damage)))
	var splash_radius := maxf(1.0, float(visual.get("splash_radius", 92.0)))
	var direct_applied := false
	if _is_valid_enemy_target(target):
		var target_distance := center.distance_to(get_target_position(target))
		if target_distance <= splash_radius:
			if target.has_method("take_damage_from"):
				target.call("take_damage_from", direct_damage, payload)
			elif target.has_method("take_damage"):
				target.call("take_damage", direct_damage)
			direct_applied = true
	for enemy in _get_all_valid_enemy_targets():
		if direct_applied and enemy == target:
			continue
		var distance := center.distance_to(get_target_position(enemy))
		if distance > splash_radius:
			continue
		var splash_damage := maxi(1, roundi(float(direct_damage) * (1.0 - distance / splash_radius) * 0.55))
		if enemy.has_method("take_damage_from"):
			enemy.call("take_damage_from", splash_damage, payload)
		elif enemy.has_method("take_damage"):
			enemy.call("take_damage", splash_damage)
	record_brain_trigger(&"cruise_missile_impact", "巡航导弹命中")

func _tick_wreckage_titan_boss(delta: float) -> void:
	_ensure_boss_turrets()
	if movement_component:
		if guard_home_position != Vector2.ZERO and global_position.distance_to(guard_home_position) > 96.0:
			move_towards(guard_home_position, null, 0.35)
			current_action = "回到干扰核心"
		else:
			movement_component.stop(&"boss_hold")
			current_action = "压制战场"
	var targets := _get_all_valid_enemy_targets()
	if targets.is_empty():
		current_target = null
		current_distance_to_target = -1.0
		current_fire_state = "等待入侵者"
		_clear_boss_laser_visual()
		_update_boss_turret_visuals(delta)
		return
	_boss_mg_a_target = _select_boss_target(targets, global_position + Vector2(34, -24), 290.0, false)
	_boss_mg_b_target = _select_boss_target(targets, global_position + Vector2(34, 24), 290.0, false)
	_boss_laser_target = _select_boss_target(targets, global_position + Vector2(-36, 0), 380.0, true)
	if _boss_laser_target == null:
		_clear_boss_laser_visual()
	current_target = _boss_laser_target if _boss_laser_target != null else _boss_mg_a_target
	current_distance_to_target = global_position.distance_to(get_target_position(current_target)) if current_target != null else -1.0
	var now_seconds := Time.get_ticks_msec() / 1000.0
	_boss_try_fire_machine_gun(_boss_mg_a_target, "mg_a", now_seconds, global_position + Vector2(34, -24))
	_boss_try_fire_machine_gun(_boss_mg_b_target, "mg_b", now_seconds, global_position + Vector2(34, 24))
	_boss_try_fire_laser(_boss_laser_target, now_seconds, global_position + Vector2(-36, 0))
	_boss_try_launch_emp_shell(targets, now_seconds)
	_boss_try_summon_guards(now_seconds)
	_update_boss_turret_visuals(delta)

func _select_boss_target(targets: Array[Node2D], origin: Vector2, range: float, prefer_heavy: bool) -> Node2D:
	var best: Node2D = null
	var best_score := -INF
	for target in targets:
		var distance := origin.distance_to(get_target_position(target))
		if distance > range:
			continue
		var score := maxf(0.0, range - distance)
		if prefer_heavy and (target.is_in_group("heavy_armor") or target.is_in_group("missile")):
			score += 120.0
		if target.is_in_group("missile"):
			score += 80.0
		if target.is_in_group("locker"):
			score += 60.0
		if target.has_method("hp_ratio"):
			score += (1.0 - float(target.call("hp_ratio"))) * 30.0
		if score > best_score:
			best = target
			best_score = score
	return best

func _boss_try_fire_machine_gun(target: Node2D, slot: String, now_seconds: float, origin: Vector2) -> void:
	if not _is_valid_enemy_target(target):
		return
	var last_fire := _boss_last_mg_a_seconds if slot == "mg_a" else _boss_last_mg_b_seconds
	var cooldown := 0.85
	if now_seconds - last_fire < cooldown:
		return
	if slot == "mg_a":
		_boss_last_mg_a_seconds = now_seconds
	else:
		_boss_last_mg_b_seconds = now_seconds
	_boss_fire_cannon_shell(target, origin)
	current_fire_state = "机炮轰击"

func _boss_fire_cannon_shell(target: Node2D, origin: Vector2) -> void:
	if not _is_valid_enemy_target(target):
		return
	var impact := get_target_position(target)
	var radius := 72.0
	var payload := _make_weapon_source_payload()
	payload["weapon_id"] = "boss_cannon"
	payload["damage_type"] = "enemy_ranged"
	var now := Time.get_ticks_msec()
	_boss_cannon_shells.append({
		"start": origin,
		"end": impact,
		"target": target,
		"payload": payload,
		"direct_damage": 36,
		"splash_radius": radius,
		"start_msec": now,
		"end_msec": now + 360,
		"impacted": false,
	})
	if _boss_cannon_shells.size() > 10:
		_boss_cannon_shells.pop_front()
	queue_redraw()

func _tick_pending_boss_projectile_impacts() -> void:
	if _boss_cannon_shells.is_empty() and _boss_emp_shells.is_empty():
		return
	var now := Time.get_ticks_msec()
	for index in range(_boss_cannon_shells.size() - 1, -1, -1):
		var shell: Dictionary = _boss_cannon_shells[index]
		if bool(shell.get("impacted", false)):
			continue
		if now < int(shell.get("end_msec", 0)):
			continue
		_apply_boss_cannon_impact(shell)
		shell["impacted"] = true
		shell["impact_msec"] = now
		_boss_cannon_shells[index] = shell
		queue_redraw()
	for index in range(_boss_emp_shells.size() - 1, -1, -1):
		var shell: Dictionary = _boss_emp_shells[index]
		if bool(shell.get("impacted", false)):
			continue
		if now < int(shell.get("end_msec", 0)):
			continue
		_apply_boss_emp_impact(shell)
		shell["impacted"] = true
		shell["impact_msec"] = now
		_boss_emp_shells[index] = shell
		queue_redraw()

func _apply_boss_cannon_impact(shell: Dictionary) -> void:
	var impact: Vector2 = shell.get("end", global_position)
	var target: Node2D = shell.get("target", null)
	var radius := maxf(1.0, float(shell.get("splash_radius", 72.0)))
	var direct_damage := maxi(1, int(shell.get("direct_damage", 36)))
	var payload: Dictionary = shell.get("payload", _make_weapon_source_payload())
	for enemy in _get_all_valid_enemy_targets():
		var distance := impact.distance_to(get_target_position(enemy))
		if distance > radius:
			continue
		var damage := direct_damage
		if enemy != target:
			damage = maxi(8, roundi(float(direct_damage) * (1.0 - distance / radius) * 0.70))
		if enemy.has_method("take_damage_from"):
			enemy.call("take_damage_from", damage, payload)
		elif enemy.has_method("take_damage"):
			enemy.call("take_damage", damage)
	var now := Time.get_ticks_msec()
	_boss_splash_rings.append({
		"center": impact,
		"radius": radius,
		"start_msec": now,
		"end_msec": now + 420,
	})
	if _boss_splash_rings.size() > 10:
		_boss_splash_rings.pop_front()
	record_brain_trigger(&"boss_cannon_impact", "Boss cannon impact")

func _boss_try_fire_laser(target: Node2D, now_seconds: float, origin: Vector2) -> void:
	if not _is_valid_enemy_target(target):
		_clear_boss_laser_visual()
		return
	if now_seconds - _boss_last_laser_seconds < 0.10:
		return
	_boss_last_laser_seconds = now_seconds
	_boss_deal_damage(target, 8, &"thermal", "boss_laser")
	_boss_laser_beam_start = origin
	_boss_laser_beam_end = get_target_position(target)
	_boss_laser_visual_target = target
	_boss_laser_beam_until_msec = Time.get_ticks_msec() + 150
	current_fire_state = "后部激光炮"
	queue_redraw()

func _clear_boss_laser_visual() -> void:
	if _boss_laser_beam_until_msec <= 0 and _boss_laser_visual_target == null:
		return
	_boss_laser_beam_until_msec = 0
	_boss_laser_visual_target = null
	_boss_laser_beam_start = Vector2.ZERO
	_boss_laser_beam_end = Vector2.ZERO
	queue_redraw()

func _boss_try_launch_emp_shell(targets: Array[Node2D], now_seconds: float) -> void:
	if now_seconds - _boss_last_emp_seconds < 14.0:
		return
	var center_target := _select_boss_target(targets, global_position, 360.0, true)
	if center_target == null:
		return
	_boss_last_emp_seconds = now_seconds
	var center := get_target_position(center_target)
	var origin := global_position
	if _boss_spell_core != null and is_instance_valid(_boss_spell_core):
		origin = _boss_spell_core.global_position
	var payload := _make_weapon_source_payload()
	payload["weapon_id"] = "boss_emp"
	payload["damage_type"] = "emp"
	var now := Time.get_ticks_msec()
	_boss_emp_shells.append({
		"start": origin,
		"end": center,
		"target": center_target,
		"payload": payload,
		"damage": 70,
		"radius": 150.0,
		"emp_duration": 3.25,
		"start_msec": now,
		"end_msec": now + 620,
		"impacted": false,
	})
	if _boss_emp_shells.size() > 6:
		_boss_emp_shells.pop_front()
	current_fire_state = "EMP 炮弹发射"
	record_brain_trigger(&"boss_emp_launch", "Boss EMP launch")
	queue_redraw()

func _apply_boss_emp_impact(shell: Dictionary) -> void:
	var center: Vector2 = shell.get("end", global_position)
	var radius := maxf(1.0, float(shell.get("radius", 150.0)))
	var damage := maxi(0, int(shell.get("damage", 70)))
	var duration := maxf(0.0, float(shell.get("emp_duration", 3.25)))
	var payload: Dictionary = shell.get("payload", _make_weapon_source_payload())
	var affected := 0
	for target in _get_all_valid_enemy_targets():
		if center.distance_to(get_target_position(target)) > radius:
			continue
		if target.has_method("apply_emp_disabled"):
			target.call("apply_emp_disabled", duration)
		if damage > 0:
			if target.has_method("take_damage_from"):
				target.call("take_damage_from", damage, payload)
			elif target.has_method("take_damage"):
				target.call("take_damage", damage)
		affected += 1
	var now := Time.get_ticks_msec()
	_boss_emp_pulses.append({
		"center": center,
		"radius": radius,
		"start_msec": now,
		"end_msec": now + 720,
	})
	if _boss_emp_pulses.size() > 6:
		_boss_emp_pulses.pop_front()
	current_fire_state = "EMP 冲击"
	record_brain_trigger(&"boss_emp", "Boss EMP hit %d targets" % affected)

func _boss_try_cast_emp(targets: Array[Node2D], now_seconds: float) -> void:
	if now_seconds - _boss_last_emp_seconds < 14.0:
		return
	var center_target := _select_boss_target(targets, global_position, 360.0, true)
	if center_target == null:
		return
	_boss_last_emp_seconds = now_seconds
	var center := get_target_position(center_target)
	var affected := 0
	for target in targets:
		if center.distance_to(get_target_position(target)) > 150.0:
			continue
		if target.has_method("apply_emp_disabled"):
			target.call("apply_emp_disabled", 3.25)
		_boss_deal_damage(target, 70, &"emp", "boss_emp")
		affected += 1
	record_brain_trigger(&"boss_emp", "Boss EMP 命中 %d 个目标" % affected)

func _boss_try_summon_guards(now_seconds: float) -> void:
	if now_seconds - _boss_last_summon_seconds < 18.0:
		return
	var current_guards := _count_nearby_boss_guards()
	if current_guards >= 4:
		return
	_boss_last_summon_seconds = now_seconds
	var offsets := [Vector2(-64, -64), Vector2(-64, 64), Vector2(64, -64), Vector2(64, 64)]
	var spawned := 0
	for offset in offsets:
		if current_guards + spawned >= 4:
			break
		_spawn_boss_guard(global_position + offset)
		spawned += 1
	record_brain_trigger(&"boss_summon", "Boss 召唤护卫 x%d" % spawned)

func _get_boss_emp_cooldown_remaining() -> float:
	var elapsed := Time.get_ticks_msec() / 1000.0 - _boss_last_emp_seconds
	return maxf(0.0, 14.0 - elapsed)

func _get_boss_summon_cooldown_remaining() -> float:
	var elapsed := Time.get_ticks_msec() / 1000.0 - _boss_last_summon_seconds
	return maxf(0.0, 18.0 - elapsed)

func _spawn_boss_guard(world_position: Vector2) -> void:
	var parent := get_parent()
	var guard_scene := load(BOSS_GUARD_DRONE_SCENE_PATH) as PackedScene
	if guard_scene == null:
		return
	var guard := ObjectPool.get_instance(guard_scene, parent if parent else self, "boss_guard_drone") as RobotUnit
	if guard == null:
		return
	guard.name = "boss_guard_drone_%s" % Time.get_ticks_msec()
	guard.global_position = world_position
	var config := {
		"display_name": "Boss 护卫无人机",
		"id": "boss_guard_drone",
		"pool_name": "boss_guard_drone",
		"icon_path": "res://Resources/art/enemies/boss_guard_drone.svg",
		"max_hp": 150,
		"speed": 128.0,
		"tags": ["frontline", "summoned"],
		"visual_size": [38, 38],
		"armor_type": "armored",
		"damage_type": "melee",
		"melee_damage": 18,
		"melee_range": 34.0,
		"melee_cooldown_seconds": 1.05,
		"guard_aggro_radius": 420.0,
		"hound_follow_up_radius": 260.0,
	}
	guard.call("setup_scavenger_hound", config, null)
	guard.set("guard_home_position", world_position)

func _count_nearby_boss_guards() -> int:
	var count := 0
	if get_tree() == null:
		return count
	for unit in get_tree().get_nodes_in_group("summoned"):
		if unit == null or not is_instance_valid(unit) or not (unit is Node2D):
			continue
		if (unit as Node2D).global_position.distance_to(global_position) <= 520.0:
			count += 1
	return count

func _boss_deal_damage(target: Node2D, amount: int, next_damage_type: StringName, weapon_id: String) -> void:
	var payload := _make_weapon_source_payload()
	payload["weapon_id"] = weapon_id
	payload["damage_type"] = String(next_damage_type)
	payload["team"] = team
	if target.has_method("take_damage_from"):
		target.call("take_damage_from", amount, payload)
	elif target.has_method("take_damage"):
		target.call("take_damage", amount)

func _get_all_valid_enemy_targets() -> Array[Node2D]:
	var result: Array[Node2D] = []
	if get_tree() == null:
		return result
	for candidate in get_tree().get_nodes_in_group("combat_target"):
		if candidate == self or candidate == null or not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		var target := candidate as Node2D
		if _is_valid_enemy_target(target):
			result.append(target)
	return result

func _is_target_missile_locked(target: Node2D) -> bool:
	return _get_target_lock_remaining_seconds(target) > 0.0

func _get_target_lock_remaining_seconds(target: Node2D) -> float:
	if target == null or not is_instance_valid(target):
		return 0.0
	if target.has_method("get_missile_target_lock_remaining_seconds"):
		return float(target.call("get_missile_target_lock_remaining_seconds"))
	if not target.has_meta(MISSILE_LOCK_META):
		return 0.0
	return maxf(0.0, float(int(target.get_meta(MISSILE_LOCK_META)) - Time.get_ticks_msec()) / 1000.0)

func _target_has_tag(target: Node2D, tag: StringName) -> bool:
	return target != null and is_instance_valid(target) and target.is_in_group(String(tag))

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
	if enemy.has_method("take_damage_from"):
		enemy.call("take_damage_from", melee_damage, _make_weapon_source_payload())
	elif enemy.has_method("take_damage"):
		enemy.call("take_damage", melee_damage)
	record_brain_trigger(&"hound_melee_attack", "撕咬目标")

func _tick_ranged_hound() -> void:
	var enemy := get_current_enemy()
	current_target = enemy
	if enemy == null:
		if movement_component and global_position.distance_to(guard_home_position) > movement_component.arrival_tolerance:
			move_towards(guard_home_position)
			current_action = "返回守卫位置"
			return
		current_action = "巢穴周围警戒"
		current_fire_state = "无目标"
		current_distance_to_target = -1.0
		if movement_component:
			movement_component.stop(&"idle")
		return

	var target_position := get_target_position(enemy)
	current_distance_to_target = global_position.distance_to(target_position)
	if current_distance_to_target > fire_range:
		move_towards(target_position, enemy)
		current_action = "接近射击位置"
		current_fire_state = "目标超出射程"
		return

	if movement_component:
		movement_component.stop(&"hold_range")
	current_action = "远程射击"
	fire_weapon(enemy)
	record_brain_trigger(&"hound_ranged_attack", "远程射击")

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
	if target_lock_overlay_sprite:
		target_lock_overlay_sprite.visible = false
	_hide_boss_turrets()
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
	_draw_target_lock_channel_visual()
	_draw_missile_visuals()
	_draw_boss_machine_gun_traces()
	_draw_boss_cannon_visuals()
	_draw_boss_emp_visuals()
	_draw_boss_laser_visual()
	if _selected:
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 64, Color(1.0, 0.86, 0.12, 0.95), 2.5)

func _draw_target_lock_channel_visual() -> void:
	if brain_mode != "target_locker":
		return
	if not _is_valid_enemy_target(_lock_channel_target):
		return
	if _lock_channel_complete_msec <= 0 or target_lock_seconds <= 0.0:
		return
	var now := Time.get_ticks_msec()
	var total_msec := maxf(1.0, target_lock_seconds * 1000.0)
	var remaining_msec := maxf(0.0, float(_lock_channel_complete_msec - now))
	var progress := clampf(1.0 - remaining_msec / total_msec, 0.0, 1.0)
	var start := Vector2.RIGHT.rotated(_facing_angle) * maxf(18.0, visual_size.x * 0.42)
	var end := to_local(get_target_position(_lock_channel_target))
	var width := lerpf(1.0, 4.0, progress)
	var pulse := 0.65 + 0.35 * sin(float(now) * 0.018)
	draw_line(start, end, Color(1.0, 0.08, 0.04, 0.32 + 0.36 * progress), width + 2.0)
	draw_line(start, end, Color(1.0, 0.18, 0.12, 0.78 * pulse), width)
	draw_circle(end, lerpf(4.0, 9.0, progress), Color(1.0, 0.10, 0.05, 0.16 + 0.18 * progress))

func _draw_missile_visuals() -> void:
	var now := Time.get_ticks_msec()
	for index in range(_missile_visuals.size() - 1, -1, -1):
		var visual: Dictionary = _missile_visuals[index]
		var end_msec := int(visual.get("end_msec", 0))
		if bool(visual.get("impacted", false)):
			var impact_msec := int(visual.get("impact_msec", end_msec))
			if now > impact_msec + 240:
				_missile_visuals.remove_at(index)
				continue
			var impact_t := clampf(float(now - impact_msec) / 240.0, 0.0, 1.0)
			var center: Vector2 = visual.get("end", global_position)
			var radius := float(visual.get("splash_radius", 92.0))
			var alpha := 1.0 - impact_t
			draw_circle(to_local(center), radius * (0.16 + 0.34 * impact_t), Color(1.0, 0.72, 0.20, 0.16 * alpha))
			draw_arc(to_local(center), radius * (0.18 + 0.32 * impact_t), 0.0, TAU, 40, Color(1.0, 0.86, 0.24, 0.82 * alpha), 3.0)
			continue
		if now > end_msec:
			continue
		var start_msec := int(visual.get("start_msec", now))
		var duration := maxf(1.0, float(end_msec - start_msec))
		var t := clampf(float(now - start_msec) / duration, 0.0, 1.0)
		var start: Vector2 = visual.get("start", global_position)
		var end: Vector2 = visual.get("end", global_position)
		var position := start.lerp(end, t)
		var direction := (end - start).normalized()
		if direction.length() <= 0.001:
			direction = Vector2.RIGHT
		var local_position := to_local(position)
		var local_tail := to_local(position - direction * 34.0)
		draw_line(local_tail, local_position, Color(1.0, 0.70, 0.18, 0.82), 5.0)
		draw_circle(local_position, 5.5, Color(1.0, 0.92, 0.36, 0.95))

func _draw_boss_machine_gun_traces() -> void:
	var now := Time.get_ticks_msec()
	for index in range(_boss_mg_traces.size() - 1, -1, -1):
		var trace: Dictionary = _boss_mg_traces[index]
		if now > int(trace.get("end_msec", 0)):
			_boss_mg_traces.remove_at(index)
			continue
		draw_line(to_local(trace.get("start", global_position)), to_local(trace.get("end", global_position)), Color(1.0, 0.42, 0.16, 0.92), 3.0)

func _draw_boss_cannon_visuals() -> void:
	var now := Time.get_ticks_msec()
	for index in range(_boss_cannon_shells.size() - 1, -1, -1):
		var shell: Dictionary = _boss_cannon_shells[index]
		var end_msec := int(shell.get("end_msec", 0))
		if now > end_msec:
			if bool(shell.get("impacted", false)):
				_boss_cannon_shells.remove_at(index)
			continue
		var start_msec := int(shell.get("start_msec", now))
		var duration := maxf(1.0, float(end_msec - start_msec))
		var t := clampf(float(now - start_msec) / duration, 0.0, 1.0)
		var start: Vector2 = shell.get("start", global_position)
		var end: Vector2 = shell.get("end", global_position)
		var position := start.lerp(end, t)
		var direction := (end - start).normalized()
		if direction.length() <= 0.001:
			direction = Vector2.RIGHT
		var local_position := to_local(position)
		draw_line(to_local(position - direction * 22.0), local_position, Color(1.0, 0.54, 0.20, 0.82), 6.0)
		draw_circle(local_position, 8.5, Color(1.0, 0.76, 0.30, 0.96))
		draw_circle(local_position, 4.5, Color(0.30, 0.18, 0.12, 0.98))
	for index in range(_boss_splash_rings.size() - 1, -1, -1):
		var ring: Dictionary = _boss_splash_rings[index]
		var end_msec := int(ring.get("end_msec", 0))
		if now > end_msec:
			_boss_splash_rings.remove_at(index)
			continue
		var start_msec := int(ring.get("start_msec", now))
		var duration := maxf(1.0, float(end_msec - start_msec))
		var t := clampf(float(now - start_msec) / duration, 0.0, 1.0)
		var center: Vector2 = ring.get("center", global_position)
		var radius := float(ring.get("radius", 72.0))
		var alpha := 1.0 - t
		draw_circle(to_local(center), radius * (0.25 + 0.75 * t), Color(1.0, 0.42, 0.14, 0.12 * alpha))
		draw_arc(to_local(center), radius * (0.25 + 0.75 * t), 0.0, TAU, 48, Color(1.0, 0.60, 0.20, 0.82 * alpha), 3.0)

func _draw_boss_emp_visuals() -> void:
	var now := Time.get_ticks_msec()
	for index in range(_boss_emp_shells.size() - 1, -1, -1):
		var shell: Dictionary = _boss_emp_shells[index]
		var end_msec := int(shell.get("end_msec", 0))
		if now > end_msec:
			if bool(shell.get("impacted", false)):
				_boss_emp_shells.remove_at(index)
			continue
		var start_msec := int(shell.get("start_msec", now))
		var duration := maxf(1.0, float(end_msec - start_msec))
		var t := clampf(float(now - start_msec) / duration, 0.0, 1.0)
		var start: Vector2 = shell.get("start", global_position)
		var end: Vector2 = shell.get("end", global_position)
		var position := start.lerp(end, t)
		var direction := (end - start).normalized()
		if direction.length() <= 0.001:
			direction = Vector2.RIGHT
		var local_position := to_local(position)
		var local_tail := to_local(position - direction * 24.0)
		draw_line(local_tail, local_position, Color(0.48, 0.92, 1.0, 0.72), 5.0)
		var texture := BOSS_EMP_PROJECTILE_TEXTURE
		if texture != null:
			var size := Vector2(24, 24)
			var rect := Rect2(local_position - size * 0.5, size)
			draw_texture_rect(texture, rect, false, Color(0.90, 1.0, 1.0, 0.96))
		else:
			draw_circle(local_position, 8.0, Color(0.66, 1.0, 1.0, 0.96))
	for index in range(_boss_emp_pulses.size() - 1, -1, -1):
		var pulse: Dictionary = _boss_emp_pulses[index]
		var end_msec := int(pulse.get("end_msec", 0))
		if now > end_msec:
			_boss_emp_pulses.remove_at(index)
			continue
		var start_msec := int(pulse.get("start_msec", now))
		var duration := maxf(1.0, float(end_msec - start_msec))
		var t := clampf(float(now - start_msec) / duration, 0.0, 1.0)
		var center: Vector2 = pulse.get("center", global_position)
		var radius := float(pulse.get("radius", 150.0))
		var alpha := 1.0 - t
		var local_center := to_local(center)
		draw_circle(local_center, radius * (0.18 + 0.82 * t), Color(0.45, 0.92, 1.0, 0.10 * alpha))
		draw_arc(local_center, radius * (0.24 + 0.76 * t), 0.0, TAU, 64, Color(0.70, 1.0, 1.0, 0.86 * alpha), 3.0)
		draw_arc(local_center, radius * (0.42 + 0.58 * t), 0.0, TAU, 64, Color(0.72, 0.52, 1.0, 0.54 * alpha), 2.0)

func _draw_boss_laser_visual() -> void:
	if Time.get_ticks_msec() > _boss_laser_beam_until_msec:
		_clear_boss_laser_visual()
		return
	if _boss_laser_visual_target != null and (not is_instance_valid(_boss_laser_visual_target) or not _is_valid_enemy_target(_boss_laser_visual_target)):
		_clear_boss_laser_visual()
		return
	if _boss_laser_visual_target == null:
		return
	var end := get_target_position(_boss_laser_visual_target) if _boss_laser_visual_target != null else _boss_laser_beam_end
	draw_line(to_local(_boss_laser_beam_start), to_local(end), Color(0.72, 1.0, 1.0, 0.95), 5.0)
	draw_line(to_local(_boss_laser_beam_start), to_local(end), Color(0.15, 0.72, 1.0, 0.48), 11.0)

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
		"ranged_hound":
			return "敌军远程脑干"
		"logistics":
			return "物流调度脑干"
		_:
			return "闲置"

func _format_attack_profile() -> String:
	if brain_mode == "target_locker":
		return "目标锁定 / 引导 %.1fs / 锁定 12s / 范围 %.0f" % [target_lock_seconds, fire_range]
	if brain_mode == "cruise_missile":
		return "巡航导弹 / 攻击力 %d / 间隔 %.2fs / 仅攻击锁定目标" % [bullet_damage, fire_cooldown_seconds]
	if brain_mode == "wreckage_titan_boss":
		return "Boss多炮台 / 连续激光8每0.10s / 双机炮36每0.85s溅射 / EMP / 召唤"
	if not weapon_enabled and brain_mode != "melee_hound":
		return "无武器"
	var attack_mode := "远程弹体"
	var range_value := fire_range
	var damage_value := bullet_damage
	var cooldown_value := fire_cooldown_seconds
	if damage_type == &"thermal":
		attack_mode = "热能激光"
	elif _uses_chainsaw_weapon():
		attack_mode = "链锯近战"
	elif brain_mode == "melee_hound":
		attack_mode = "近战"
		range_value = melee_range
		damage_value = melee_damage
		cooldown_value = melee_cooldown_seconds
	elif brain_mode == "ranged_hound":
		attack_mode = "敌军远程弹体"
	var attacks_per_second := 0.0 if cooldown_value <= 0.0 else 1.0 / cooldown_value
	return "%s / 攻击力 %d / 间隔 %.2fs / 攻速 %.2f/s / 射程 %.0f" % [
		attack_mode,
		damage_value,
		cooldown_value,
		attacks_per_second,
		range_value,
	]

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
		"salvage_return":
			return "战场回收"
		"recover_cargo":
			return "回收残余货物"
		"dropoff":
			return "投递"
		"return":
			return "返航"
	return task_type if not task_type.is_empty() else "未指定"
