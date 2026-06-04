extends RefCounted
class_name MvpDataDefaults

const RECIPE_CONFIG_PATH := "res://Resources/data/recipes/mvp_recipes.json"
const UNIT_BLUEPRINT_CONFIG_PATH := "res://Resources/data/units/mvp_unit_blueprints.json"
const BUILDING_CONFIG_PATH := "res://Resources/data/buildings/mvp_buildings.json"
const RecipeConfigLoaderScript := preload("res://Scripts/data/recipe_config_loader.gd")
const UnitBlueprintConfigLoaderScript := preload("res://Scripts/data/unit_blueprint_config_loader.gd")
const BuildingConfigLoaderScript := preload("res://Scripts/data/building_config_loader.gd")

const RES_IRON_ORE := &"iron_ore"
const RES_COPPER_ORE := &"copper_ore"
const RES_IRON_PLATE := &"iron_plate"
const RES_COPPER_WIRE := &"copper_wire"
const RES_CONSTRUCTION_MASS := &"construction_mass"

const UNIT_BASIC_RIFLE_ROBOT := &"basic_rifle_robot"

const BUILDING_MAIN_BASE := &"main_base"
const BUILDING_MINER := &"miner"
const BUILDING_PROCESSOR := &"processor"
const BUILDING_ROBOT_FORGE := &"robot_forge"

static func create_resource_defs() -> Array[ResourceDef]:
	return [
		_make_resource(RES_IRON_ORE, "铁矿", "res://Resources/art/resources/iron_ore.svg", "基础金属矿物。"),
		_make_resource(RES_COPPER_ORE, "铜矿", "res://Resources/art/resources/copper_ore.svg", "基础导电矿物。"),
		_make_resource(RES_IRON_PLATE, "铁板", "res://Resources/art/resources/iron_plate.svg", "基础结构材料。"),
		_make_resource(RES_COPPER_WIRE, "铜线", "res://Resources/art/resources/copper_wire.svg", "基础电气材料。"),
		_make_resource(RES_CONSTRUCTION_MASS, "建设质料", "res://Resources/art/resources/construction_mass.svg", "建筑通用基础开销。"),
	]

static func create_recipe_defs() -> Array[RecipeDef]:
	return RecipeConfigLoaderScript.load_recipe_defs(RECIPE_CONFIG_PATH)

static func create_basic_rifle_blueprint() -> UnitBlueprint:
	var recipe_defs := create_recipe_defs()
	return UnitBlueprintConfigLoaderScript.load_unit_blueprint(
		UNIT_BLUEPRINT_CONFIG_PATH,
		UNIT_BASIC_RIFLE_ROBOT,
		recipe_defs,
		_create_basic_rifle_blueprint_fallback(recipe_defs)
	)

static func _create_basic_rifle_blueprint_fallback(recipe_defs: Array[RecipeDef]) -> UnitBlueprint:
	var recipe := _find_recipe_by_target(recipe_defs, &"unit", UNIT_BASIC_RIFLE_ROBOT)
	var blueprint := UnitBlueprint.new()
	blueprint.id = UNIT_BASIC_RIFLE_ROBOT
	blueprint.display_name = "基础步枪机器人"
	blueprint.version = 1
	blueprint.icon_path = "res://Resources/art/blueprints/basic_rifle_robot.svg"
	blueprint.chassis_id = &"light_chassis"
	blueprint.chassis_display_name = "轻型底盘"
	blueprint.chassis_icon_path = "res://Resources/art/chassis/light_chassis.svg"
	blueprint.module_ids = [&"rifle_module"]
	blueprint.module_display_names = ["步枪模块"]
	blueprint.module_icon_paths = ["res://Resources/art/modules/rifle_module.svg"]
	blueprint.stats = UnitStats.new()
	if recipe:
		blueprint.production_recipe_id = recipe.id
		blueprint.production_cost = recipe.inputs.duplicate(true)
		blueprint.production_time_seconds = recipe.duration_seconds
	blueprint.default_brain_enabled = true
	blueprint.tactical_templates = []
	blueprint.embedded_rules = []
	blueprint.state_flag_defaults = {}
	return blueprint

static func create_mvp_building_defs() -> Array[BuildingDef]:
	var recipe_defs := create_recipe_defs()
	return BuildingConfigLoaderScript.load_building_defs(BUILDING_CONFIG_PATH, recipe_defs, _create_building_fallbacks(recipe_defs))

static func _create_building_fallbacks(recipe_defs: Array[RecipeDef]) -> Array[BuildingDef]:
	return [
		_make_building(BUILDING_MAIN_BASE, "主基地", Vector2i(2, 2), recipe_defs, "res://Resources/art/buildings/main_base.svg", 1400),
		_make_building(BUILDING_MINER, "采矿机", Vector2i(1, 1), recipe_defs, "res://Resources/art/buildings/miner.svg", 420),
		_make_building(BUILDING_PROCESSOR, "基础加工厂", Vector2i(1, 1), recipe_defs, "res://Resources/art/buildings/processor.svg", 600),
		_make_building(BUILDING_ROBOT_FORGE, "机器人锻造厂", Vector2i(1, 1), recipe_defs, "res://Resources/art/buildings/robot_forge.svg", 700),
	]

static func _make_resource(resource_id: StringName, display_name: String, icon_path: String, description: String) -> ResourceDef:
	var def := ResourceDef.new()
	def.id = resource_id
	def.display_name = display_name
	def.icon_path = icon_path
	def.description = description
	return def

static func _make_building(building_id: StringName, display_name: String, grid_size: Vector2i, recipe_defs: Array[RecipeDef], icon_path: String, max_hp: int) -> BuildingDef:
	var recipe := _find_recipe_by_target(recipe_defs, &"building", building_id)
	var def := BuildingDef.new()
	def.id = building_id
	def.display_name = display_name
	def.grid_size = grid_size
	if recipe:
		def.build_recipe_id = recipe.id
		def.build_cost = recipe.inputs.duplicate(true)
	def.icon_path = icon_path
	def.max_hp = max_hp
	return def

static func _find_recipe_by_target(recipe_defs: Array[RecipeDef], recipe_type: StringName, target_id: StringName) -> RecipeDef:
	for recipe in recipe_defs:
		if recipe.recipe_type == recipe_type and recipe.target_id == target_id:
			return recipe
	return null

