extends Node

const InventoryScript := preload("res://Scripts/economy/inventory.gd")
const ProcessorScene := preload("res://Scenes/buildings/processor.tscn")

func _ready() -> void:
	_check_recipe_responsibilities()
	_check_pause_preserves_progress()
	print("PROCESSOR_CONTROLS_OK")
	get_tree().quit()

func _check_recipe_responsibilities() -> void:
	var manager := MvpGameManager.new()
	manager.recipe_defs = [
		_make_recipe(&"process_iron_plate", &"iron_plate"),
		_make_recipe(&"process_copper_wire", &"copper_wire"),
		_make_recipe(&"process_reinforced_steel_plate", &"reinforced_steel_plate"),
		_make_recipe(&"process_optical_lens", &"optical_lens"),
		_make_recipe(&"process_high_capacity_battery", &"high_capacity_battery"),
	]
	var basic_def := BuildingDef.new()
	basic_def.id = MvpDataDefaults.BUILDING_PROCESSOR
	var advanced_def := BuildingDef.new()
	advanced_def.id = MvpDataDefaults.BUILDING_ADVANCED_PROCESSOR

	var basic_ids := _recipe_ids(manager.call("_get_resource_recipes_for_processor", basic_def))
	var advanced_ids := _recipe_ids(manager.call("_get_resource_recipes_for_processor", advanced_def))
	_expect(basic_ids == [&"process_iron_plate", &"process_copper_wire"], "基础加工厂只应提供铁板和铜线配方")
	_expect(advanced_ids == [
		&"process_reinforced_steel_plate",
		&"process_optical_lens",
		&"process_high_capacity_battery",
	], "高级加工厂只应提供阶段 16 复合材料配方")
	manager.free()

func _check_pause_preserves_progress() -> void:
	var inventory := InventoryScript.new()
	inventory.add_resource(&"iron_ore", 2)
	var recipe := _make_recipe(&"process_iron_plate", &"iron_plate")
	recipe.duration_seconds = 1.0
	recipe.inputs = {&"iron_ore": 2}
	recipe.outputs = {&"iron_plate": 1}

	var processor := ProcessorScene.instantiate() as ProcessorBuilding
	add_child(processor)
	processor.setup_processor([recipe], inventory)
	processor.set_recipe(recipe.id)
	processor._process(0.4)
	var paused_progress := processor.progress_seconds
	processor.set_paused(true)
	processor._process(2.0)

	_expect(is_equal_approx(processor.progress_seconds, paused_progress), "暂停时加工进度不应增长")
	_expect(processor.state_id == ProcessorBuilding.STATE_PAUSED, "暂停时应进入暂停状态")
	_expect(inventory.get_amount(&"iron_plate") == 0, "暂停期间不应完成产出")

	processor.set_paused(false)
	processor._process(0.6)
	_expect(inventory.get_amount(&"iron_plate") == 1, "继续加工后应从原进度完成产出")
	processor._process(0.0)
	_expect(processor.state_id == ProcessorBuilding.STATE_WAITING_INPUTS, "原料不足时应进入缺货状态")
	processor.queue_free()

func _make_recipe(recipe_id: StringName, target_id: StringName) -> RecipeDef:
	var recipe := RecipeDef.new()
	recipe.id = recipe_id
	recipe.display_name = String(recipe_id)
	recipe.recipe_type = &"resource"
	recipe.target_id = target_id
	return recipe

func _recipe_ids(recipes: Array[RecipeDef]) -> Array[StringName]:
	var result: Array[StringName] = []
	for recipe in recipes:
		result.append(recipe.id)
	return result

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)

