extends Node
class_name CombatEventLogService

signal event_recorded(event: Dictionary)
signal events_cleared

@export var retention_seconds: float = 600.0

var _events: Array[Dictionary] = []

func record(event_type: StringName, payload: Dictionary = {}) -> Dictionary:
	var event := {
		"time": Time.get_ticks_msec() / 1000.0,
		"clock": Time.get_time_string_from_system(),
		"type": String(event_type),
		"payload": payload.duplicate(true),
	}
	_events.append(event)
	_prune_old_events()
	event_recorded.emit(event)
	return event

func get_recent_events(window_seconds: float = 0.0, event_type: String = "") -> Array[Dictionary]:
	_prune_old_events()
	var now := Time.get_ticks_msec() / 1000.0
	var result: Array[Dictionary] = []
	for event in _events:
		if window_seconds > 0.0 and now - float(event.get("time", 0.0)) > window_seconds:
			continue
		if not event_type.is_empty() and str(event.get("type", "")) != event_type:
			continue
		result.append(event.duplicate(true))
	return result

func count_events(event_type: String = "", window_seconds: float = 0.0) -> int:
	return get_recent_events(window_seconds, event_type).size()

func clear() -> void:
	_events.clear()
	events_cleared.emit()

func _prune_old_events() -> void:
	if retention_seconds <= 0.0:
		return
	var cutoff := Time.get_ticks_msec() / 1000.0 - retention_seconds
	while not _events.is_empty() and float(_events[0].get("time", 0.0)) < cutoff:
		_events.pop_front()
