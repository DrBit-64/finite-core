extends Node
class_name LifespanComponent

signal expired

@export var lifespan_seconds: float = 0.0

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)

func setup(next_lifespan_seconds: float) -> void:
	lifespan_seconds = maxf(0.0, next_lifespan_seconds)
	reset()

func reset() -> void:
	stop()
	if lifespan_seconds > 0.0:
		_timer.wait_time = lifespan_seconds
		_timer.start()

func stop() -> void:
	if _timer:
		_timer.stop()

func get_time_left() -> float:
	if _timer == null or _timer.is_stopped():
		return 0.0
	return _timer.time_left

func _on_timeout() -> void:
	expired.emit()
