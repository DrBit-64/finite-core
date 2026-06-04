extends Node

const InventoryScript := preload("res://Scripts/economy/inventory.gd")
const ProcessorScene := preload("res://Scenes/buildings/processor.tscn")

func _ready() -> void:
	var inventory := InventoryScript.new()
	var processor := ProcessorScene.instantiate()
	add_child(processor)
	var recipes: Array[RecipeDef] = []
	processor.call("setup_processor", recipes, inventory)
	processor.set("output_cache", {&"iron_plate": 23})
	processor.call("_process", 0.1)

	_expect(inventory.get_amount(&"iron_plate") == 23, "加工厂输出缓存应被抽象物流转入主库存")
	_expect((processor.get("output_cache") as Dictionary).is_empty(), "转入主库存后加工厂输出缓存应清空")

	print("PROCESSOR_OUTPUT_LOGISTICS_OK")
	get_tree().quit()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
