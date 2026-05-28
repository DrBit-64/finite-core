extends CharacterBody2D
class_name RobotUnit

signal robot_lost(robot: Node, reason: StringName)

@export var display_name: String = "基础步枪机器人"
@export var max_hp: int = 60
@export var speed: float = 90.0
@export_enum("Team_A", "Team_B") var team: String = "Team_A"
@export var tags: Array[String] = []
@export var lifespan_seconds: float = 120.0
@export var pool_name: String = "robot_basic"
@export var fire_range: float = 140.0
@export var bullet_damage: int = 8
@export var fire_cooldown_seconds: float = 0.8
@export var weapon_enabled: bool = true
@export_enum("default_combat", "path_patrol", "idle") var brain_mode: String = "default_combat"
@export var default_brain_enabled: bool = true
@export var preferred_range_ratio: float = 0.85
@export var range_dead_zone: float = 12.0
@export var visual_size: Vector2 = Vector2(42, 42)
@export var muzzle_distance: float = 24.0
@export var turn_speed_radians: float = 12.0
@export var fire_arc_radians: float = 0.16
@export_file("*.svg") var icon_path: String = "res://Resources/art/blueprints/basic_rifle_robot.svg"

var hp: int = 60
var blueprint_id: StringName = &""
var blueprint_version: int = 0
var rally_point_position: Vector2 = Vector2.ZERO
var has_rally_point: bool = false

var current_target: Node2D = null
var current_action: String = "闲置"
var current_fire_state: String = "无目标"
var current_distance_to_target: float = -1.0
var patrol_points: Array[Vector2] = []
var patrol_loop: bool = true

var _is_dead: bool = false
var _selected: bool = false
var _patrol_index: int = 0
var _loaded_icon_path: String = ""
var _facing_angle: float = 0.0
var _brain_trigger_history: Array[String] = []
var _last_brain_trigger_key: StringName = &""
var _last_brain_trigger_msec: int = 0

@onready var unit_sprite: Sprite2D = get_node_or_null("UnitSprite")
@onready var hp_bar: ProgressBar = get_node_or_null("HPBar")
@onready var action_label: Label = get_node_or_null("ActionLabel")
@onready var muzzle: Marker2D = get_node_or_null("Muzzle")
@onready var lifespan_component = get_node_or_null("LifespanComponent")
@onready var health_component = get_node_or_null("HealthComponent")
@onready var movement_component = get_node_or_null("MovementComponent")
@onready var weapon_component = get_node_or_null("WeaponComponent")
@onready var enemy_sensor = get_node_or_null("VisibleEnemySensor")
@onready var default_brain = get_node_or_null("DefaultBrain")
@onready var path_follow_brain = get_node_or_null("PathFollowBrain")

func _ready() -> void:
	_connect_components()
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
				if default_brain:
					default_brain.tick(self)
				else:
					current_action = "默认脑干缺失"
					if movement_component:
						movement_component.stop(&"idle")
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
	display_name = blueprint.display_name
	if not blueprint.icon_path.is_empty():
		icon_path = blueprint.icon_path
	if blueprint.stats:
		max_hp = blueprint.stats.max_hp
		speed = blueprint.stats.speed
		lifespan_seconds = blueprint.stats.lifespan_seconds
		fire_range = blueprint.stats.fire_range
		bullet_damage = blueprint.stats.damage
		fire_cooldown_seconds = blueprint.stats.fire_cooldown_seconds
	default_brain_enabled = blueprint.default_brain_enabled
	rally_point_position = next_rally_point
	has_rally_point = next_has_rally_point
	reset_state()

func setup_debug_enemy(next_name: String, path_points: Array[Vector2], loop_path: bool = true) -> void:
	display_name = next_name
	team = "Team_B"
	brain_mode = "path_patrol"
	default_brain_enabled = false
	weapon_enabled = false
	max_hp = 420
	speed = 54.0
	lifespan_seconds = 0.0
	pool_name = "debug_enemy_unit"
	icon_path = "res://Resources/art/units/debug_enemy_unit.svg"
	set_patrol_path(path_points, loop_path)
	reset_state()

func set_patrol_path(path_points: Array[Vector2], loop_path: bool = true) -> void:
	patrol_points = path_points.duplicate()
	patrol_loop = loop_path
	_patrol_index = 0
	if path_follow_brain:
		path_follow_brain.set_path(path_points, loop_path)

func reset_state() -> void:
	_is_dead = false
	current_target = null
	current_action = "闲置"
	current_fire_state = "无目标"
	current_distance_to_target = -1.0
	_facing_angle = 0.0
	_brain_trigger_history.clear()
	_last_brain_trigger_key = &""
	_last_brain_trigger_msec = 0
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
		target_name = str(current_target.call("get_display_name")) if current_target.has_method("get_display_name") else current_target.name
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
	if has_rally_point:
		lines.append("集结点：%.0f, %.0f" % [rally_point_position.x, rally_point_position.y])
	if brain_mode == "path_patrol":
		var path_index: int = path_follow_brain.patrol_index if path_follow_brain else _patrol_index
		var path_count: int = path_follow_brain.patrol_points.size() if path_follow_brain else patrol_points.size()
		lines.append("路径点：%s / %s" % [path_index + 1, path_count])
	lines.append("索敌：当前可见地图内敌军")
	if not _brain_trigger_history.is_empty():
		lines.append("最近脑干触发：")
		for entry in _brain_trigger_history:
			lines.append("  %s" % entry)
	return lines

func set_selected(value: bool) -> void:
	_selected = value
	queue_redraw()

func has_enemy_in_range() -> bool:
	return get_current_enemy() != null

func get_current_enemy() -> CharacterBody2D:
	var enemies := _get_visible_enemies()
	if enemies.is_empty() or not (enemies[0] is CharacterBody2D):
		return null
	return enemies[0] as CharacterBody2D

func get_lowest_hp_enemy() -> CharacterBody2D:
	var enemies := _get_visible_enemies()
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
	return target as CharacterBody2D

func get_radar_targets() -> Array[Node2D]:
	return _get_visible_enemies()

func is_current_enemy_in_fire_range() -> bool:
	var enemy := get_current_enemy()
	if enemy == null:
		return false
	return global_position.distance_to(enemy.global_position) <= fire_range

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
	flee_from(enemy.global_position)

func move_towards_nearest_enemy() -> void:
	var enemy := get_current_enemy()
	if enemy == null:
		stop_and_idle()
		return
	move_towards(enemy.global_position)

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

func fire_weapon(target: Node2D) -> void:
	if weapon_component == null:
		return
	if target:
		_turn_towards(target.global_position, get_physics_process_delta_time())
		if not _is_facing_position(target.global_position):
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
	add_to_group("combat_unit")
	if team == "Team_A":
		add_to_group("team_a")
		remove_from_group("team_b")
	else:
		add_to_group("team_b")
		remove_from_group("team_a")
	for tag in tags:
		if not tag.is_empty():
			add_to_group(tag)

func _configure_team_collision() -> void:
	collision_layer = 1 if team == "Team_A" else 2
	collision_mask = 0

func _get_visible_enemies() -> Array[Node2D]:
	if enemy_sensor:
		return enemy_sensor.get_visible_enemies(self, team)
	return []

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
		unit_sprite.modulate = Color.WHITE
	if muzzle:
		muzzle.position = Vector2.RIGHT.rotated(_facing_angle) * muzzle_distance
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		hp_bar.visible = hp < max_hp
	if action_label:
		var should_show_action := is_alive() and not current_action.is_empty() and current_action != "闲置"
		action_label.visible = should_show_action
		action_label.text = current_action if should_show_action else ""
	queue_redraw()

func _update_facing(delta: float) -> void:
	if _should_face_attack_target():
		_turn_towards(current_target.global_position, delta)
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

func _on_health_changed(current_hp: int, current_max_hp: int, _delta: int) -> void:
	hp = current_hp
	max_hp = current_max_hp
	_update_unit_visuals()

func _on_health_died(reason: StringName) -> void:
	_finish_death(reason)

func _finish_death(reason: StringName) -> void:
	if _is_dead:
		return
	_is_dead = true
	current_action = "报废"
	if movement_component:
		movement_component.stop(&"dead")
	if lifespan_component:
		lifespan_component.stop()
	robot_lost.emit(self, reason)
	ObjectPool.return_instance(self, pool_name)

func _on_lifespan_expired() -> void:
	die(&"lifespan_expired")

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
