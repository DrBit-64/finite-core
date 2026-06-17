extends "res://Scripts/buildings/base_building.gd"
class_name ForwardSupplyPointBuilding

signal supply_inventory_changed

const InventoryScript := preload("res://Scripts/economy/inventory.gd")

@export var storage_capacity: int = 240

var inventory := InventoryScript.new()
var status_text: String = "待命"

func _ready() -> void:
	super._ready()
	add_to_group("frontline_supply")
	if not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)

func add_resource(resource_id: StringName, amount: int, reason: String = "") -> int:
	if amount <= 0:
		return 0
	var accepted := mini(amount, get_free_capacity())
	if accepted <= 0:
		status_text = "库存已满"
		return 0
	inventory.add_resource(resource_id, accepted, reason)
	status_text = "中继缓存"
	return accepted

func remove_resource(resource_id: StringName, amount: int, reason: String = "") -> int:
	if amount <= 0:
		return 0
	var removed := mini(amount, inventory.get_amount(resource_id))
	if removed <= 0:
		return 0
	if inventory.spend_resources({resource_id: removed}, reason):
		status_text = "中继发货"
		return removed
	return 0

func get_amount(resource_id: StringName) -> int:
	return inventory.get_amount(resource_id)

func get_all_resources() -> Dictionary:
	return inventory.get_all()

func get_used_capacity() -> int:
	var total := 0
	for resource_id in inventory.get_all().keys():
		total += maxi(0, int(inventory.get_amount(resource_id)))
	return total

func get_free_capacity() -> int:
	return maxi(0, storage_capacity - get_used_capacity())

func get_inspector_lines() -> Array[String]:
	var lines := super.get_inspector_lines()
	lines.append("状态：%s" % status_text)
	lines.append("库存：%s / %s" % [get_used_capacity(), storage_capacity])
	lines.append("物资：%s" % JSON.stringify(inventory.get_all()))
	return lines

func _on_inventory_changed(_resource_id: StringName, _amount: int, _delta: int, _reason: String) -> void:
	supply_inventory_changed.emit()
