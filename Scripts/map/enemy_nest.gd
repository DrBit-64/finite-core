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
var reward: Dictionary = {}
var time_alive_seconds: float = 0.0
var replenish_seconds_remaining: float = 30.0

var _guards: Array[Node] = []
var _guard_slots: Dictionary = {}
var _reserved_guard_slots: Dictionary = {}

func setup_nest(id: StringName, type_id: StringName, config: Dictionary, origin: Vector2i, next_cell_size: int) -> void:
	nest_id = id
	nest_type = type_id
	guard_unit_type = StringName(str(config.get("guard_unit_type", "scavenger_hound")))
	initial_guard_count = maxi(0, int(config.get("initial_guard_count", 6)))
	max_guard_count = maxi(0, int(config.get("max_guard_count", 6)))
	guard_replenish_seconds = maxf(0.1, float(config.get("guard_replenish_seconds", 30.0)))
	replenish_seconds_remaining = guard_replenish_seconds
	reward = config.get("reward", {}).duplicate(true)
	time_alive_seconds = 0.0
	team = "Team_B"
	armor_type = StringName(str(config.get("armor_type", "structure")))

	var def := BuildingDef.new()
	def.id = type_id
	def.display_name = str(config.get("display_name", "敌巢"))
	def.icon_path = str(config.get("icon_path", "res://Resources/art/enemies/enemy_nest.svg"))
	def.grid_size = _vector2i(config.get("grid_size", [2, 2]), Vector2i(2, 2))
	def.max_hp = maxi(1, int(config.get("max_hp", 180)))
	setup(def, origin, next_cell_size)

func spawn_initial_guards() -> void:
	for _index in range(initial_guard_count):
		guard_spawn_requested.emit(self, guard_unit_type)

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
	guard_spawn_requested.emit(self, guard_unit_type)

func _on_building_destroyed(_reason: StringName) -> void:
	nest_destroyed.emit(self)

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
