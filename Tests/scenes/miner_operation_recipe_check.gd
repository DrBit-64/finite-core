extends Node

const MinerScene := preload("res://Scenes/buildings/miner.tscn")
const InventoryScript := preload("res://Scripts/economy/inventory.gd")

func _ready() -> void:
	var miner := MinerScene.instantiate() as MinerBuilding
	add_child(miner)

	var inventory := InventoryScript.new()
	miner.output_per_minute = 60
	miner.output_resource_id = MvpDataDefaults.RES_IRON_ORE
	miner.target_inventory = inventory

	var recipe := miner.get_mining_recipe()
	_assert(recipe != null, "miner should expose a mining recipe")
	_assert(recipe.inputs.is_empty(), "mining recipe should have no inputs")
	_assert(int(recipe.outputs.get(MvpDataDefaults.RES_IRON_ORE, 0)) == 1, "mining recipe should output ore")
	_assert(is_equal_approx(recipe.duration_seconds, 1.0), "mining recipe duration should match output rate")

	miner._process(1.05)
	_assert(inventory.get_amount(MvpDataDefaults.RES_IRON_ORE) >= 1, "miner output should reach abstract inventory")
	_assert(miner.output_cache.is_empty(), "miner output cache should flush after production")

	print("miner_operation_recipe_check passed")
	get_tree().quit()

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
