extends Node
class_name HealthComponent

signal health_changed(current_hp: int, max_hp: int, delta: int)
signal died(reason: StringName)

@export var max_hp: int = 100

var hp: int = 100
var _dead: bool = false

func setup(next_max_hp: int) -> void:
	max_hp = maxi(1, next_max_hp)
	reset()

func reset() -> void:
	hp = max_hp
	_dead = false
	health_changed.emit(hp, max_hp, 0)

func take_damage(amount: int) -> void:
	if _dead or amount <= 0:
		return
	var previous_hp := hp
	hp = maxi(0, hp - amount)
	health_changed.emit(hp, max_hp, hp - previous_hp)
	if hp <= 0:
		kill(&"destroyed")

func kill(reason: StringName = &"destroyed") -> void:
	if _dead:
		return
	_dead = true
	hp = 0
	health_changed.emit(hp, max_hp, 0)
	died.emit(reason)

func is_alive() -> bool:
	return not _dead

func hp_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)
