extends Node
class_name MovementComponent

@export var max_speed: float = 90.0
@export var arrival_tolerance: float = 8.0

var desired_velocity: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var movement_intent: StringName = &"idle"

func setup(next_speed: float) -> void:
	max_speed = maxf(0.0, next_speed)
	stop(&"idle")

func move_towards(origin: Vector2, target: Vector2, speed_scale: float = 1.0) -> void:
	target_position = target
	var offset := target - origin
	if offset.length() <= arrival_tolerance:
		stop(&"arrived")
		return
	desired_velocity = offset.normalized() * max_speed * clampf(speed_scale, 0.0, 1.0)
	movement_intent = &"approach"

func move_away_from(origin: Vector2, threat: Vector2, speed_scale: float = 1.0) -> void:
	target_position = threat
	var offset := origin - threat
	if offset.length() <= 0.001:
		offset = Vector2.RIGHT
	desired_velocity = offset.normalized() * max_speed * clampf(speed_scale, 0.0, 1.0)
	movement_intent = &"retreat"

func stop(next_intent: StringName = &"hold") -> void:
	desired_velocity = Vector2.ZERO
	movement_intent = next_intent

func apply_to(body: CharacterBody2D) -> void:
	body.velocity = desired_velocity
	body.move_and_slide()
