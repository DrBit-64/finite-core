extends Node
class_name IdProviderService

var _next_values: Dictionary = {}

func next_id(prefix: StringName) -> String:
	var key := String(prefix)
	var next_value := int(_next_values.get(key, 1))
	_next_values[key] = next_value + 1
	return "%s_%06d" % [key, next_value]

func reset(prefix: StringName = &"") -> void:
	if String(prefix).is_empty():
		_next_values.clear()
		return
	_next_values.erase(String(prefix))

func peek_next(prefix: StringName) -> int:
	return int(_next_values.get(String(prefix), 1))
