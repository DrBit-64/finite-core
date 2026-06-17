extends RefCounted
class_name Inventory

signal inventory_changed(resource_id: StringName, amount: int, delta: int, reason: String)

var _amounts: Dictionary = {}

func add_resource(resource_id: StringName, amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	var next_amount := get_amount(resource_id) + amount
	_amounts[resource_id] = next_amount
	inventory_changed.emit(resource_id, next_amount, amount, reason)

func spend_resources(cost: Dictionary, reason: String = "") -> bool:
	if not can_afford(cost):
		return false
	for resource_id in cost.keys():
		var amount := int(cost[resource_id])
		if amount <= 0:
			continue
		var next_amount := get_amount(resource_id) - amount
		_amounts[resource_id] = next_amount
		inventory_changed.emit(resource_id, next_amount, -amount, reason)
	return true

func can_afford(cost: Dictionary) -> bool:
	for resource_id in cost.keys():
		if get_amount(resource_id) < int(cost[resource_id]):
			return false
	return true

func get_amount(resource_id: StringName) -> int:
	return int(_amounts.get(resource_id, 0))

func get_missing(cost: Dictionary) -> Dictionary:
	var missing := {}
	for resource_id in cost.keys():
		var needed := int(cost[resource_id])
		var current := get_amount(resource_id)
		if current < needed:
			missing[resource_id] = needed - current
	return missing

func get_all() -> Dictionary:
	return _amounts.duplicate(true)

func set_all(amounts: Dictionary, reason: String = "set_inventory") -> void:
	_amounts.clear()
	for resource_id in amounts.keys():
		var amount := int(amounts[resource_id])
		if amount <= 0:
			continue
		var key := StringName(str(resource_id))
		_amounts[key] = amount
		inventory_changed.emit(key, amount, amount, reason)
