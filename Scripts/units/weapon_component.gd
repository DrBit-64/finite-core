extends Node
class_name WeaponComponent

const LaserBeamEffectScript := preload("res://Scripts/effects/laser_beam_effect.gd")

@export var enabled: bool = true
@export var fire_range: float = 140.0
@export var damage: int = 8
@export var cooldown_seconds: float = 0.8
@export var bullet_scene: PackedScene = preload("res://Scenes/bullet.tscn")
@export var bullet_pool_name: String = "bullet_basic"
@export_enum("projectile", "laser") var fire_mode: String = "projectile"
@export var laser_tick_interval: float = 0.12

var fire_state: StringName = &"ready"
var _last_fire_time: float = -9999.0
var _last_laser_tick_time: float = -9999.0
var _active_laser_beam: Node2D = null

func setup(next_range: float, next_damage: int, next_cooldown: float, next_fire_mode: String = "projectile") -> void:
	fire_range = maxf(0.0, next_range)
	damage = maxi(0, next_damage)
	cooldown_seconds = maxf(0.0, next_cooldown)
	fire_mode = next_fire_mode
	reset()

func reset() -> void:
	fire_state = &"ready"
	_last_fire_time = -9999.0
	_last_laser_tick_time = -9999.0
	_clear_active_laser_beam()

func is_target_in_range(origin: Vector2, target: Node2D) -> bool:
	return target != null and origin.distance_to(_get_target_position(target)) <= fire_range

func get_cooldown_remaining() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	return maxf(0.0, cooldown_seconds - (now - _last_fire_time))

func try_fire(owner_team: String, muzzle: Node2D, target: Node2D, spawn_parent: Node) -> bool:
	if not enabled:
		fire_state = &"disabled"
		return false
	if target == null or not is_instance_valid(target):
		fire_state = &"no_target"
		return false

	var origin := Vector2.ZERO
	if muzzle:
		origin = muzzle.global_position
	elif get_parent() is Node2D:
		origin = (get_parent() as Node2D).global_position
	var target_position := _get_target_position(target)
	if origin.distance_to(target_position) > fire_range:
		fire_state = &"out_of_range"
		return false

	if fire_mode == "laser":
		return _fire_laser(owner_team, origin, target_position, target, spawn_parent)

	if get_cooldown_remaining() > 0.0:
		fire_state = &"cooldown"
		return false

	var bullet := ObjectPool.get_instance(bullet_scene, spawn_parent, bullet_pool_name) as Node2D
	if bullet == null:
		fire_state = &"spawn_failed"
		return false

	bullet.global_position = origin
	var shot_dir := (target_position - origin).normalized()
	if bullet.has_method("setup"):
		bullet.call("setup", owner_team, damage, shot_dir, _make_source_payload(owner_team))
	_last_fire_time = Time.get_ticks_msec() / 1000.0
	fire_state = &"fired"
	return true

func _fire_laser(owner_team: String, origin: Vector2, target_position: Vector2, target: Node2D, spawn_parent: Node) -> bool:
	var payload := _make_source_payload(owner_team)
	_refresh_laser_beam(origin, target_position, spawn_parent)

	var now := Time.get_ticks_msec() / 1000.0
	var tick_interval := maxf(0.04, laser_tick_interval)
	if now - _last_laser_tick_time < tick_interval:
		fire_state = &"channeling"
		return false

	if target.has_method("take_damage_from"):
		target.call("take_damage_from", damage, payload)
	elif target.has_method("take_damage"):
		target.call("take_damage", damage)
	_last_laser_tick_time = now
	_last_fire_time = now
	fire_state = &"fired"
	return true

func _refresh_laser_beam(origin: Vector2, target_position: Vector2, spawn_parent: Node) -> void:
	if _active_laser_beam == null or not is_instance_valid(_active_laser_beam):
		_active_laser_beam = LaserBeamEffectScript.new()
		(spawn_parent if spawn_parent != null else get_parent()).add_child(_active_laser_beam)
	if _active_laser_beam.has_method("setup"):
		_active_laser_beam.call("setup", origin, target_position)

func _clear_active_laser_beam() -> void:
	if _active_laser_beam != null and is_instance_valid(_active_laser_beam):
		_active_laser_beam.queue_free()
	_active_laser_beam = null

func _make_source_payload(owner_team: String) -> Dictionary:
	var source_unit := get_parent()
	if source_unit == null:
		return {"team": owner_team}
	return {
		"team": owner_team,
		"robot_id": str(source_unit.name),
		"weapon_id": String(source_unit.get("weapon_audio_id")) if source_unit.get("weapon_audio_id") != null else "default",
		"damage_type": String(source_unit.get("damage_type")) if source_unit.get("damage_type") != null else "kinetic",
		"blueprint_id": String(source_unit.get("blueprint_id")) if source_unit.get("blueprint_id") != null else "",
		"blueprint_version": int(source_unit.get("blueprint_version")) if source_unit.get("blueprint_version") != null else 0,
		"blueprint_snapshot_id": String(source_unit.get("blueprint_snapshot_id")) if source_unit.get("blueprint_snapshot_id") != null else "",
		"blueprint_name": str(source_unit.get("display_name")) if source_unit.get("display_name") != null else "",
	}

func _get_target_position(target: Node2D) -> Vector2:
	if target and target.has_method("get_target_position"):
		return target.call("get_target_position")
	if target:
		return target.global_position
	return Vector2.ZERO
