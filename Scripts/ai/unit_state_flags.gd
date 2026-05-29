extends Node
class_name UnitStateFlags

signal flag_changed(flag_id: StringName, old_value: bool, new_value: bool)

var _flags: Dictionary = {}

func setup(defaults: Dictionary) -> void:
	_flags.clear()
	for key in defaults.keys():
		_flags[StringName(str(key))] = bool(defaults[key])

func get_flag(flag_id: StringName) -> bool:
	return bool(_flags.get(flag_id, false))

func set_flag(flag_id: StringName, value: bool) -> void:
	var old_value := get_flag(flag_id)
	if old_value == value:
		return
	_flags[flag_id] = value
	flag_changed.emit(flag_id, old_value, value)

func clear_flag(flag_id: StringName) -> void:
	set_flag(flag_id, false)

func get_all() -> Dictionary:
	return _flags.duplicate()

func format_lines() -> Array[String]:
	var lines: Array[String] = []
	for flag_id in _flags.keys():
		lines.append("%s：%s" % [String(flag_id), "是" if bool(_flags[flag_id]) else "否"])
	return lines
