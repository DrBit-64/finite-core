extends Node

func _ready() -> void:
	_check_urgent_logistics_load_amount()
	_check_bulwark_robot_config()
	_check_debug_inventory()
	print("PHASE16_LOGISTICS_AND_BULWARK_OK")
	get_tree().quit()

func _check_urgent_logistics_load_amount() -> void:
	var manager := MvpGameManager.new()
	var amount := int(manager.call("_get_stage14_urgent_supply_pickup_amount", 2, 50, 24))
	_require(amount == 24, "Urgent logistics should fill cargo from available source stock, not only the immediate missing amount.")
	amount = int(manager.call("_get_stage14_urgent_supply_pickup_amount", 2, 12, 24))
	_require(amount == 12, "Urgent logistics should cap by available source stock.")
	amount = int(manager.call("_get_stage14_urgent_supply_pickup_amount", 2, 50, 0))
	_require(amount == 0, "Urgent logistics should respect cargo free capacity.")
	manager.free()

func _check_bulwark_robot_config() -> void:
	var recipes := MvpDataDefaults.create_recipe_defs()
	var blueprints := MvpDataDefaults.create_unit_blueprints()
	var bulwark := _find_blueprint(blueprints, &"shield_bulwark_robot")
	_require(bulwark != null, "Shield bulwark blueprint is missing.")
	_require(bulwark.production_recipe_id == &"forge_shield_bulwark_robot", "Shield bulwark blueprint should use its own recipe.")
	_require(bulwark.stats != null and bulwark.stats.max_hp == 800, "Shield bulwark HP should be externally configured to 800.")
	_require(bulwark.stats.speed > 112.0, "Shield bulwark should be faster than the existing chainsaw robot.")
	_require(bulwark.stats.damage == 0 and bulwark.stats.fire_range <= 0.0, "Shield bulwark should have no attack.")

	var recipe := _find_recipe(recipes, &"forge_shield_bulwark_robot")
	_require(recipe != null, "Shield bulwark production recipe is missing.")
	_require(recipe.inputs.get(&"iron_plate", 0) == 9, "Shield bulwark production cost should be near chainsaw cost.")

	var technologies := TechnologyConfigLoader.new().load_technology_defs("res://Resources/data/technology/mvp_stage1_technologies.json")
	var chainsaw_tech = _find_technology(technologies, &"stage1_kinetic_chainsaw")
	_require(chainsaw_tech != null, "Chainsaw tier technology is missing.")
	_require(chainsaw_tech.unlocks.get("unit_types", []).has("shield_bulwark_robot"), "Shield bulwark should unlock at the same tier as chainsaw robot.")

func _check_debug_inventory() -> void:
	var inventory := StartingInventoryConfigLoader.load_starting_inventory(
		"res://Resources/data/debug/mvp_debug_starting_inventory.json",
		{}
	)
	for resource_id in [
		&"crystal_ore",
		&"coal",
		&"water",
		&"reinforced_steel_plate",
		&"optical_lens",
		&"high_capacity_battery",
		&"high_frequency_oscillator",
	]:
		_require(int(inventory.get(resource_id, 0)) == 500, "Debug inventory should include %s x500." % String(resource_id))

func _find_blueprint(blueprints: Array[UnitBlueprint], blueprint_id: StringName) -> UnitBlueprint:
	for blueprint in blueprints:
		if blueprint.id == blueprint_id:
			return blueprint
	return null

func _find_recipe(recipes: Array[RecipeDef], recipe_id: StringName) -> RecipeDef:
	for recipe in recipes:
		if recipe.id == recipe_id:
			return recipe
	return null

func _find_technology(technologies: Array, technology_id: StringName) -> Variant:
	for technology in technologies:
		if technology.id == technology_id:
			return technology
	return null

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
