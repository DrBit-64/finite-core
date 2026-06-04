extends "res://Scripts/buildings/base_building.gd"
class_name MainBase

signal inventory_changed

const InventoryScript := preload("res://Scripts/economy/inventory.gd")

@export var construction_mass_per_minute: int = 45
@export var service_radius_cells: int = 8

var inventory := InventoryScript.new()
var _construction_mass_accumulator: float = 0.0

func _ready() -> void:
	super._ready()
	inventory.inventory_changed.connect(_on_inventory_changed)

func seed_inventory(starting_amounts: Dictionary) -> void:
	for resource_id in starting_amounts.keys():
		inventory.add_resource(resource_id, int(starting_amounts[resource_id]), "初始库存")

func _process(delta: float) -> void:
	var amount_per_second := float(construction_mass_per_minute) / 60.0
	_construction_mass_accumulator += amount_per_second * delta
	var whole_amount := floori(_construction_mass_accumulator)
	if whole_amount <= 0:
		return
	_construction_mass_accumulator -= whole_amount
	inventory.add_resource(MvpDataDefaults.RES_CONSTRUCTION_MASS, whole_amount, "主基地被动生产")

func get_inspector_lines() -> Array[String]:
	var lines := super.get_inspector_lines()
	lines.append("服务半径：%s 格" % service_radius_cells)
	lines.append("建设质料产出：%s / 分钟" % construction_mass_per_minute)
	lines.append("库存：%s" % JSON.stringify(inventory.get_all()))
	return lines

func _draw() -> void:
	var radius := float(service_radius_cells * cell_size)
	var center := Vector2(grid_size.x * cell_size, grid_size.y * cell_size) * 0.5
	draw_arc(center, radius, 0.0, TAU, 96, Color(0.24, 0.76, 0.92, 0.42), 2.0)

func _on_inventory_changed(_resource_id: StringName, _amount: int, _delta: int, _reason: String) -> void:
	inventory_changed.emit()
