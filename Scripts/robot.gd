extends CharacterBody2D
class_name RobotUnit

signal robot_lost(robot: Node, reason: StringName)

const CombatTargetRegistryScript := preload("res://Scripts/map/combat_target_registry.gd")
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
@export var weapon_enabled: bool = true
@export_enum("default_combat", "path_patrol", "melee_hound", "idle") var brain_mode: String = "default_combat"
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

var hp: int = 60
var blueprint_id: StringName = &""
var blueprint_version: int = 0
var blueprint_snapshot_id: StringName = &""
var rally_point_position: Vector2 = Vector2.ZERO
var has_rally_point: bool = false

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
var _death_tween: Tween = null
var action_icon: Sprite2D = null

@onready var unit_sprite: Sprite2D = get_node_or_null("UnitSprite")
@onready var hp_bar: ProgressBar = get_node_or_null("HPBar")
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
		_:
			current_action = "闲置"
			if movement_component:
				movement_component.stop(&"idle")

	if movement_component:
		movement_component.apply_to(self)
	_update_facing(delta)
	_update_unit_visuals()

func setup_from_blueprint(blueprint: UnitBlueprint, next_rally_point: Vector2 = Vector2.ZERO, next_has_rally_point: bool = false) -> void:
	if blueprint == null:
		return
	blueprint_id = blueprint.id
	blueprint_version = blueprint.version
	blueprint_snapshot_id = StringName(blueprint.get_snapshot_key())
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
	default_brain_enabled = blueprint.default_brain_enabled
	if state_flags:
		state_flags.setup(blueprint.state_flag_defaults)
	if ai_controller and ai_controller.has_method("set_logic_rules"):
		ai_controller.call("set_logic_rules", blueprint.embedded_rules)
	rally_point_position = next_rally_point
	has_rally_point = next_has_rally_point
	reset_state()

func setup_debug_enemy(next_name: String, path_points: Array[Vector2], loop_path: bool = true) -> void:
	display_name = next_name
	team = "Team_B"
	brain_mode = "path_patrol"
	blueprint_snapshot_id = &""
	default_brain_enabled = false
	weapon_enabled = false
	max_hp = 420
	speed = 54.0
	lifespan_seconds = 0.0
	pool_name = "debug_enemy_unit"
	icon_path = "res://Resources/art/units/debug_enemy_unit.svg"
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
	lifespan_seconds = 0.0
	pool_name = "scavenger_hound"
	icon_path = str(config.get("icon_path", "res://Resources/art/enemies/scavenger_hound.svg"))
	melee_damage = int(config.get("melee_damage", 16))
	melee_range = float(config.get("melee_range", 32.0))
	melee_cooldown_seconds = float(config.get("melee_cooldown_seconds", 1.0))
	guard_aggro_radius = maxf(0.0, float(config.get("guard_aggro_radius", 320.0)))
	hound_follow_up_radius = maxf(0.0, float(config.get("hound_follow_up_radius", 180.0)))
	source_nest = nest
	guard_home_position = global_position
	reset_state()

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
	_last_damage_source_payload.clear()
	_damage_flash_until_msec = 0
	_sync_runtime_groups()
	_configure_team_collision()
	_configure_components()
	_update_unit_visuals()

func is_alive() -> bool:
	return not _is_dead and (health_component == null or health_component.is_alive())

func get_display_name() -> String:
	return display_name

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
	if target and target != self and target.has_method("get_target_position"):
		return target.call("get_target_position")
	if target:
		return target.global_position
	return global_position

func is_current_enemy_in_fire_range() -> bool:
	var enemy := get_current_enemy()
	if enemy == null:
		return false
	return global_position.distance_to(get_target_position(enemy)) <= fire_range

func hp_ratio() -> float:
	if health_component:
		return health_component.hp_ratio()
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)

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
	move_towards(get_target_position(enemy))

func move_towards(target_pos: Vector2) -> void:
	if movement_component == null:
		return
	movement_component.move_towards(global_position, target_pos)
	current_action = "接近目标"

func flee_from(target_pos: Vector2) -> void:
	if movement_component == null:
		return
	movement_component.move_away_from(global_position, target_pos)
	current_action = "远离目标"

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

func get_state_flag(flag_id: StringName) -> bool:
	if state_flags == null:
		return false
	return bool(state_flags.call("get_flag", flag_id))

func set_state_flag(flag_id: StringName, value: bool, reason: String = "") -> void:
	if state_flags == null:
		return
	state_flags.call("set_flag", flag_id, value)
	if not reason.is_empty():
		record_brain_trigger(StringName("flag_%s_%s" % [String(flag_id), value]), reason)

func uses_physics_ai_tick() -> bool:
	return true

func get_blueprint_snapshot_key() -> String:
	return String(blueprint_snapshot_id)

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
	if weapon_component == null:
		return
	if target:
		var target_position := get_target_position(target)
		_turn_towards(target_position, get_physics_process_delta_time())
		if not _is_facing_position(target_position):
			current_fire_state = "转向中"
			return
	var spawn_parent := _get_projectile_parent()
	weapon_component.try_fire(team, muzzle, target, spawn_parent)
	current_fire_state = _format_fire_state()

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	if health_component:
		health_component.take_damage(amount)

func take_damage_from(amount: int, source_payload: Dictionary = {}) -> void:
	_last_damage_source_payload = source_payload.duplicate(true)
	take_damage(amount)

func get_last_damage_source_payload() -> Dictionary:
	return _last_damage_source_payload.duplicate(true)

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
		weapon_component.setup(fire_range, bullet_damage, fire_cooldown_seconds)
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
		enemies = enemy_sensor.get_initial_targets(self, team, source_nest, guard_aggro_radius)
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
				unit_sprite.scale = Vector2(visual_size.x / texture_size.x, visual_size.y / texture_size.y)
		unit_sprite.rotation = _facing_angle
		unit_sprite.modulate = Color(1.0, 0.48, 0.38, 1.0) if Time.get_ticks_msec() < _damage_flash_until_msec else Color.WHITE
	if muzzle:
		muzzle.position = Vector2.RIGHT.rotated(_facing_angle) * muzzle_distance
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		hp_bar.visible = hp < max_hp
	if action_label:
		var bubble_text := ""
		if Time.get_ticks_msec() <= _current_rule_bubble_until_msec and not _current_rule_bubble_text.is_empty():
			bubble_text = _current_rule_bubble_text
		elif not current_action.is_empty() and current_action != "闲置":
			bubble_text = current_action
		action_label.visible = is_alive() and not bubble_text.is_empty()
		action_label.text = bubble_text
		_update_action_icon(bubble_text, action_label.visible)
	queue_redraw()

func _update_facing(delta: float) -> void:
	if _should_face_attack_target():
		_turn_towards(get_target_position(current_target), delta)
		return
	if movement_component and movement_component.desired_velocity.length() > 0.001:
		_turn_angle_towards(movement_component.desired_velocity.angle(), delta)

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
			movement_component.move_towards(global_position, guard_home_position)
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
		if movement_component:
			movement_component.move_towards(global_position, target_position)
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
	if not _selected:
		return
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
		&"fired":
			return "开火"
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
		action_icon.position = Vector2(-64.0, -44.0)
		add_child(action_icon)
	action_icon.visible = false
	action_icon.scale = Vector2(0.82, 0.82)

func _update_action_icon(bubble_text: String, should_show: bool) -> void:
	_ensure_action_icon()
	if action_icon == null:
		return
	var icon_texture := _get_action_icon_texture(bubble_text)
	action_icon.texture = icon_texture
	action_icon.visible = should_show and icon_texture != null

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
