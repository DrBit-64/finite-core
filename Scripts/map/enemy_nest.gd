extends "res://Scripts/buildings/base_building.gd"
class_name EnemyNest

signal guard_spawn_requested(nest: Node, guard_type: StringName)
signal nest_destroyed(nest: Node)

var nest_id: StringName = &""
var nest_type: StringName = &""
var guard_unit_type: StringName = &""
var initial_guard_count: int = 6
var max_guard_count: int = 6
var guard_replenish_seconds: float = 30.0
var guard_replenish_count: int = 1
var shared_aggro_radius: float = 520.0
var shared_aggro_seconds: float = 8.0
var reward: Dictionary = {}
var time_alive_seconds: float = 0.0
var replenish_seconds_remaining: float = 30.0
var guard_roster: Array[StringName] = []
var full_roster_replenish: bool = false
var invulnerable: bool = false
var combat_target_enabled: bool = true
var mainline_objective: bool = true

var _guards: Array[Node] = []
var _guard_slots: Dictionary = {}
var _reserved_guard_slots: Dictionary = {}
var _shared_alert_target: Node2D = null
var _shared_alert_until_msec: int = 0

func setup_nest(id: StringName, type_id: StringName, config: Dictionary, origin: Vector2i, next_cell_size: int) -> void:
	nest_id = id
	nest_type = type_id
	guard_unit_type = StringName(str(config.get("guard_unit_type", "scavenger_hound")))
	initial_guard_count = maxi(0, int(config.get("initial_guard_count", 6)))
	max_guard_count = maxi(0, int(config.get("max_guard_count", 6)))
	guard_replenish_seconds = maxf(0.1, float(config.get("guard_replenish_seconds", 30.0)))
	guard_replenish_count = maxi(1, int(config.get("guard_replenish_count", 1)))
	shared_aggro_radius = maxf(0.0, float(config.get("shared_aggro_radius", 520.0)))
	shared_aggro_seconds = maxf(0.0, float(config.get("shared_aggro_seconds", 8.0)))
	guard_roster = _string_name_array(config.get("guard_roster", []))
	full_roster_replenish = bool(config.get("full_roster_replenish", false))
	invulnerable = bool(config.get("invulnerable", false))
	combat_target_enabled = bool(config.get("combat_target_enabled", true))
	mainline_objective = bool(config.get("mainline_objective", true))
	replenish_seconds_remaining = guard_replenish_seconds
	reward = config.get("reward", {}).duplicate(true)
	time_alive_seconds = 0.0
	_clear_shared_alert()
	team = "Team_B"
	armor_type = StringName(str(config.get("armor_type", "structure")))

	var def := BuildingDef.new()
	def.id = type_id
	def.display_name = str(config.get("display_name", "敌巢"))
	def.icon_path = str(config.get("icon_path", "res://Resources/art/enemies/enemy_nest.svg"))
	def.grid_size = _vector2i(config.get("grid_size", [2, 2]), Vector2i(2, 2))
	def.max_hp = maxi(1, int(config.get("max_hp", 180)))
	setup(def, origin, next_cell_size)
	if not combat_target_enabled:
		remove_from_group("combat_target")
		_unregister_combat_target()

func spawn_initial_guards() -> void:
	for index in range(initial_guard_count):
		guard_spawn_requested.emit(self, _get_guard_type_for_slot(index))

func register_guard(guard: Node) -> void:
	register_guard_at_slot(guard, -1)

func register_guard_at_slot(guard: Node, slot_index: int = -1) -> void:
	if guard == null or _guards.has(guard):
		return
	var selected_slot := slot_index
	if selected_slot < 0:
		selected_slot = _find_guard_slot_for_node(guard)
	selected_slot = clampi(selected_slot, 0, maxi(0, max_guard_count - 1))
	_guards.append(guard)
	_guard_slots[int(guard.get_instance_id())] = selected_slot
	_reserved_guard_slots.erase(selected_slot)
	guard.set_meta("guard_slot_index", selected_slot)
	if guard is Node2D:
		var home_position := get_spawn_position(selected_slot)
		(guard as Node2D).global_position = home_position
		if guard.has_method("set"):
			guard.set("guard_home_position", home_position)

func unregister_guard(guard: Node) -> void:
	if guard != null:
		_guard_slots.erase(int(guard.get_instance_id()))
	_guards.erase(guard)

func get_guard_count() -> int:
	_prune_guards()
	return _guards.size()

func notify_guard_engaged(target: Node2D) -> void:
	if not is_alive() or target == null or not is_instance_valid(target):
		return
	if target.has_method("is_alive") and not bool(target.call("is_alive")):
		return
	_shared_alert_target = target
	_shared_alert_until_msec = Time.get_ticks_msec() + roundi(shared_aggro_seconds * 1000.0)

func get_shared_alert_target() -> Node2D:
	if _shared_alert_target == null or not is_instance_valid(_shared_alert_target):
		_clear_shared_alert()
		return null
	if Time.get_ticks_msec() > _shared_alert_until_msec:
		_clear_shared_alert()
		return null
	if _shared_alert_target.has_method("is_alive") and not bool(_shared_alert_target.call("is_alive")):
		_clear_shared_alert()
		return null
	if shared_aggro_radius > 0.0:
		var distance := get_target_position().distance_to(_shared_alert_target.global_position)
		if distance > shared_aggro_radius:
			_clear_shared_alert()
			return null
	return _shared_alert_target

func get_spawn_position(index: int = -1) -> Vector2:
	var offsets := [
		Vector2(0.0, -92.0),
		Vector2(80.0, -46.0),
		Vector2(80.0, 46.0),
		Vector2(0.0, 92.0),
		Vector2(-80.0, 46.0),
		Vector2(-80.0, -46.0),
		Vector2(64.0, -64.0),
		Vector2(64.0, 64.0),
		Vector2(-64.0, 64.0),
		Vector2(-64.0, -64.0),
	]
	var selected_index := _first_available_guard_slot(false) if index < 0 else index
	return get_target_position() + offsets[selected_index % offsets.size()]

func reserve_guard_slot() -> int:
	var slot_index := _first_available_guard_slot(true)
	_reserved_guard_slots[slot_index] = true
	return slot_index

func get_inspector_lines() -> Array[String]:
	var lines := super.get_inspector_lines()
	lines[0] = "类型：敌巢"
	lines.append("巢穴 ID：%s" % String(nest_id))
	lines.append("守军：%s / %s" % [get_guard_count(), max_guard_count])
	lines.append("补充倒计时：%.1fs" % replenish_seconds_remaining)
	lines.append("奖励：%s" % _format_reward_text())
	return lines

func _process(delta: float) -> void:
	if not is_alive():
		return
	time_alive_seconds += delta
	if get_guard_count() >= max_guard_count:
		replenish_seconds_remaining = guard_replenish_seconds
		return
	replenish_seconds_remaining -= delta
	if replenish_seconds_remaining > 0.0:
		return
	replenish_seconds_remaining = guard_replenish_seconds
	if full_roster_replenish:
		var occupied := _get_occupied_guard_slots()
		for slot_index in range(max_guard_count):
			if occupied.has(slot_index):
				continue
			guard_spawn_requested.emit(self, _get_guard_type_for_slot(slot_index))
	else:
		for _i in range(guard_replenish_count):
			if get_guard_count() >= max_guard_count:
				break
			var slot_index := _first_available_guard_slot(true)
			guard_spawn_requested.emit(self, _get_guard_type_for_slot(slot_index))

func _on_building_destroyed(_reason: StringName) -> void:
	_clear_shared_alert()
	nest_destroyed.emit(self)

func take_damage(_amount: int) -> void:
	if invulnerable:
		return
	super.take_damage(_amount)

func take_damage_from(amount: int, source_payload: Dictionary = {}) -> void:
	if invulnerable:
		return
	super.take_damage_from(amount, source_payload)

func is_mainline_objective() -> bool:
	return mainline_objective

func _prune_guards() -> void:
	for index in range(_guards.size() - 1, -1, -1):
		var guard := _guards[index]
		if guard == null or not is_instance_valid(guard):
			_guards.remove_at(index)
		elif guard.has_method("is_alive") and not bool(guard.call("is_alive")):
			_guard_slots.erase(int(guard.get_instance_id()))
			_guards.remove_at(index)
		elif guard is CanvasItem and not (guard as CanvasItem).visible:
			_guard_slots.erase(int(guard.get_instance_id()))
			_guards.remove_at(index)
	_rebuild_guard_slot_table()

func _first_available_guard_slot(include_reserved: bool) -> int:
	_prune_guards()
	var occupied := {}
	for slot_value in _guard_slots.values():
		occupied[int(slot_value)] = true
	if include_reserved:
		for slot_value in _reserved_guard_slots.keys():
			occupied[int(slot_value)] = true
	var slot_count := maxi(1, max_guard_count)
	for slot_index in range(slot_count):
		if not occupied.has(slot_index):
			return slot_index
	return get_guard_count() % slot_count

func _find_guard_slot_for_node(guard: Node) -> int:
	if guard != null and guard.has_meta("guard_slot_index"):
		return int(guard.get_meta("guard_slot_index"))
	if guard is Node2D:
		return _nearest_available_guard_slot((guard as Node2D).global_position)
	return _first_available_guard_slot(true)

func _nearest_available_guard_slot(position: Vector2) -> int:
	_prune_guards()
	var occupied := {}
	for slot_value in _guard_slots.values():
		occupied[int(slot_value)] = true
	var best_slot := _first_available_guard_slot(true)
	var best_distance := INF
	for slot_index in range(maxi(1, max_guard_count)):
		if occupied.has(slot_index):
			continue
		var distance := position.distance_squared_to(get_spawn_position(slot_index))
		if distance < best_distance:
			best_distance = distance
			best_slot = slot_index
	return best_slot

func _rebuild_guard_slot_table() -> void:
	var next_slots := {}
	for guard in _guards:
		if guard == null or not is_instance_valid(guard):
			continue
		var guard_key := int(guard.get_instance_id())
		if _guard_slots.has(guard_key):
			next_slots[guard_key] = int(_guard_slots[guard_key])
	_guard_slots = next_slots

func _get_occupied_guard_slots() -> Dictionary:
	_prune_guards()
	var occupied := {}
	for slot_value in _guard_slots.values():
		occupied[int(slot_value)] = true
	for slot_value in _reserved_guard_slots.keys():
		occupied[int(slot_value)] = true
	return occupied

func _get_guard_type_for_slot(slot_index: int) -> StringName:
	if guard_roster.is_empty():
		return guard_unit_type
	return guard_roster[clampi(slot_index, 0, guard_roster.size() - 1)]

func _clear_shared_alert() -> void:
	_shared_alert_target = null
	_shared_alert_until_msec = 0

func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(StringName(str(item)))
	return result

func _vector2i(value: Variant, fallback: Vector2i) -> Vector2i:
	if typeof(value) != TYPE_ARRAY or value.size() < 2:
		return fallback
	return Vector2i(int(value[0]), int(value[1]))

func _format_reward_text() -> String:
	if reward.is_empty():
		return "无"
	if reward.has("technology_item"):
		return "科技物品：%s" % str(reward.get("technology_item", "未知"))
	return JSON.stringify(reward)
