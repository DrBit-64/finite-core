extends Area2D
class_name BulletProjectile

@export var speed: float = 560.0
@export var life_time: float = 2.0
@export var pool_name: String = "bullet_basic"

var team: String = "Team_A"
var damage: int = 10
var direction: Vector2 = Vector2.RIGHT
var source_payload: Dictionary = {}
var _alive: bool = true

@onready var life_timer: Timer = $LifeTimer

func _ready() -> void:
	reset_state()

func reset_state() -> void:
	_alive = true
	if life_timer:
		life_timer.stop()
		life_timer.wait_time = life_time
		life_timer.one_shot = true
		life_timer.start()

func setup(spawn_team: String, spawn_damage: int, dir: Vector2, next_source_payload: Dictionary = {}) -> void:
	team = spawn_team
	damage = spawn_damage
	source_payload = next_source_payload.duplicate(true)
	if dir.length() < 0.001:
		direction = Vector2.RIGHT
	else:
		direction = dir.normalized()
	_configure_collision_mask_by_team()

func _configure_collision_mask_by_team() -> void:
	collision_layer = 4
	if team == "Team_A":
		collision_mask = 2
	else:
		collision_mask = 1

func _physics_process(delta: float) -> void:
	if not _alive:
		return
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if not _alive:
		return
	if body == null:
		return
	if body.get("team") == null:
		return
	if body.get("team") == team:
		return
	if body.has_method("take_damage_from"):
		body.call("take_damage_from", damage, source_payload)
	elif body.has_method("take_damage"):
		body.take_damage(damage)
	_return_to_pool()

func _on_life_timer_timeout() -> void:
	_return_to_pool()

func _return_to_pool() -> void:
	if not _alive:
		return
	_alive = false
	source_payload.clear()
	if life_timer:
		life_timer.stop()
	ObjectPool.return_instance(self, pool_name)
