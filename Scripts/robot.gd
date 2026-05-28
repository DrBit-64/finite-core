extends CharacterBody2D
class_name RobotUnit

signal robot_lost(robot: Node, reason: StringName)

@export var max_hp: int = 100
@export var speed: float = 80.0
@export_enum("Team_A", "Team_B") var team: String = "Team_A"
@export var tags: Array[String] = []
@export var lifespan_seconds: float = 5.0
@export var pool_name: String = "robot_basic"
@export var radar_radius: float = 1000.0
@export var fire_range: float = 140.0
@export var bullet_scene: PackedScene = preload("res://Scenes/bullet.tscn")
@export var bullet_pool_name: String = "bullet_basic"
@export var bullet_damage: int = 15
@export var fire_cooldown_seconds: float = 0.8

var hp: int
var blueprint_id: StringName = &""
var blueprint_version: int = 0
var rally_point_position: Vector2 = Vector2.ZERO
var has_rally_point: bool = false
var _is_dead: bool = false
var enemies_in_range: Array[CharacterBody2D] = []
var _last_fire_time: float = -9999.0

@onready var lifespan_timer: Timer = $LifespanTimer
@onready var radar: Area2D = $Radar
@onready var radar_shape: CollisionShape2D = $Radar/CollisionShape2D
@onready var body_color: ColorRect = $ColorRect
@onready var muzzle: Marker2D = $Muzzle

func _ready() -> void:
	_sync_runtime_groups()
	reset_state()

func _sync_runtime_groups() -> void:
	if team == "Team_A":
		add_to_group("team_a")
		remove_from_group("team_b")
	else:
		add_to_group("team_b")
		remove_from_group("team_a")
	for tag in tags:
		if not tag.is_empty():
			add_to_group(tag)

func _physics_process(_delta: float) -> void:
	if _is_dead:
		return
	move_and_slide()

func reset_state() -> void:
	hp = max_hp
	_is_dead = false
	velocity = Vector2.ZERO
	enemies_in_range.clear()
	_last_fire_time = -9999.0
	_sync_runtime_groups()
	_configure_team_collision()
	_configure_radar()
	if lifespan_timer:
		lifespan_timer.stop()
		lifespan_timer.wait_time = lifespan_seconds
		lifespan_timer.one_shot = true
		lifespan_timer.start()

func setup_from_blueprint(blueprint: UnitBlueprint, next_rally_point: Vector2 = Vector2.ZERO, next_has_rally_point: bool = false) -> void:
	if blueprint == null:
		return
	blueprint_id = blueprint.id
	blueprint_version = blueprint.version
	if blueprint.stats:
		max_hp = blueprint.stats.max_hp
		speed = blueprint.stats.speed
		lifespan_seconds = blueprint.stats.lifespan_seconds
		radar_radius = blueprint.stats.radar_radius
		fire_range = blueprint.stats.fire_range
		bullet_damage = blueprint.stats.damage
		fire_cooldown_seconds = blueprint.stats.fire_cooldown_seconds
	rally_point_position = next_rally_point
	has_rally_point = next_has_rally_point
	reset_state()

func is_alive() -> bool:
	return not _is_dead

func _configure_team_collision() -> void:
	if team == "Team_A":
		collision_layer = 1
		if body_color:
			body_color.color = Color(0.203922, 0.537255, 0.921569, 1.0)
	else:
		collision_layer = 2
		if body_color:
			body_color.color = Color(0.839216, 0.203922, 0.203922, 1.0)
	collision_mask = 0

func _configure_radar() -> void:
	if radar_shape and radar_shape.shape is CircleShape2D:
		(radar_shape.shape as CircleShape2D).radius = radar_radius

	if radar:
		radar.collision_layer = 0
		if team == "Team_A":
			radar.collision_mask = 2
		else:
			radar.collision_mask = 1

func _is_enemy_candidate(body: Node2D) -> bool:
	if body == null or body == self:
		return false
	if not (body is CharacterBody2D):
		return false
	if body.get("team") == null:
		return false
	return body.get("team") != team

func _cleanup_enemy_list() -> void:
	for i in range(enemies_in_range.size() - 1, -1, -1):
		var enemy := enemies_in_range[i]
		if enemy == null or not is_instance_valid(enemy):
			enemies_in_range.remove_at(i)

func has_enemy_in_range() -> bool:
	_cleanup_enemy_list()
	return not enemies_in_range.is_empty()

# TODO: 这个函数被频繁调用，可能需要性能优化
func get_current_enemy() -> CharacterBody2D:
	_cleanup_enemy_list()
	if enemies_in_range.is_empty():
		return null
	var nearest: CharacterBody2D = enemies_in_range[0]
	var nearest_dist_sq := global_position.distance_squared_to(nearest.global_position)
	for i in range(1, enemies_in_range.size()):
		var candidate := enemies_in_range[i]
		if candidate == null or not is_instance_valid(candidate):
			continue
		var dist_sq := global_position.distance_squared_to(candidate.global_position)
		if dist_sq < nearest_dist_sq:
			nearest = candidate
			nearest_dist_sq = dist_sq
	return nearest

func get_lowest_hp_enemy() -> CharacterBody2D:
	_cleanup_enemy_list()
	if enemies_in_range.is_empty():
		return null
	var target := enemies_in_range[0]
	var lowest_ratio: float = target.hp_ratio() if target.has_method("hp_ratio") else 1.0
	for i in range(1, enemies_in_range.size()):
		var candidate := enemies_in_range[i]
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not candidate.has_method("hp_ratio"):
			continue
		var ratio: float = candidate.hp_ratio()
		if ratio < lowest_ratio:
			target = candidate
			lowest_ratio = ratio
	return target

func get_radar_targets() -> Array[Node2D]:
	_cleanup_enemy_list()
	var targets: Array[Node2D] = []
	for enemy in enemies_in_range:
		targets.append(enemy)
	return targets

func is_current_enemy_in_fire_range() -> bool:
	var enemy := get_current_enemy()
	if enemy == null:
		return false
	return global_position.distance_to(enemy.global_position) <= fire_range

func hp_ratio() -> float:
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
	var dir := target_pos - global_position
	if dir.length() < 0.001:
		stop_and_idle()
		return
	velocity = dir.normalized() * speed

func flee_from(target_pos: Vector2) -> void:
	var dir := global_position - target_pos
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	velocity = dir.normalized() * speed

func stop_and_idle() -> void:
	velocity = Vector2.ZERO

func fire_main_weapon() -> void:
	var enemy := get_current_enemy()
	if enemy == null:
		return
	fire_weapon(enemy)

func fire_weapon(target: Node2D) -> void:
	if target == null:
		return
	if global_position.distance_to(target.global_position) > fire_range:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_fire_time < fire_cooldown_seconds:
		return
	_last_fire_time = now

	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_parent()
	if spawn_parent == null:
		return

	var bullet := ObjectPool.get_instance(bullet_scene, spawn_parent, bullet_pool_name) as Node2D
	if bullet == null:
		return
	bullet.global_position = muzzle.global_position if muzzle else global_position
	var shot_dir: Vector2 = (target.global_position - bullet.global_position).normalized()
	if bullet.has_method("setup"):
		bullet.setup(team, bullet_damage, shot_dir)

func _on_radar_body_entered(body: Node2D) -> void:
	if not _is_enemy_candidate(body):
		return
	var enemy := body as CharacterBody2D
	if enemies_in_range.has(enemy):
		return
	enemies_in_range.append(enemy)
	print("[", name, "] 发现敌人: ", enemy.name, " 当前敌人数=", enemies_in_range.size())

func _on_radar_body_exited(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	var enemy := body as CharacterBody2D
	if enemies_in_range.has(enemy):
		enemies_in_range.erase(enemy)
		print("[", name, "] 敌人离开: ", enemy.name, " 当前敌人数=", enemies_in_range.size())

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	hp -= amount
	if hp < 0:
		hp = 0
	if hp <= 0:
		die(&"destroyed")

func die(reason: StringName = &"destroyed") -> void:
	if _is_dead:
		return
	_is_dead = true
	enemies_in_range.clear()
	if lifespan_timer:
		lifespan_timer.stop()
	robot_lost.emit(self, reason)
	ObjectPool.return_instance(self, pool_name)

func _on_lifespan_timer_timeout() -> void:
	die(&"lifespan_expired")
