extends Node
class_name WeaponComponent

@export var enabled: bool = true
@export var fire_range: float = 140.0
@export var damage: int = 8
@export var cooldown_seconds: float = 0.8
@export var bullet_scene: PackedScene = preload("res://Scenes/bullet.tscn")
@export var bullet_pool_name: String = "bullet_basic"

var fire_state: StringName = &"ready"
var _last_fire_time: float = -9999.0

func setup(next_range: float, next_damage: int, next_cooldown: float) -> void:
	fire_range = maxf(0.0, next_range)
	damage = maxi(0, next_damage)
	cooldown_seconds = maxf(0.0, next_cooldown)
	reset()

func reset() -> void:
	fire_state = &"ready"
	_last_fire_time = -9999.0

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

func _make_source_payload(owner_team: String) -> Dictionary:
	var source_unit := get_parent()
	if source_unit == null:
		return {"team": owner_team}
	return {
		"team": owner_team,
		"robot_id": str(source_unit.name),
		"weapon_id": String(source_unit.get("weapon_audio_id")) if source_unit.get("weapon_audio_id") != null else "default",
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
