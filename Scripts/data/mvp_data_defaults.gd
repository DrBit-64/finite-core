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
const RES_INITIAL_SENSOR_COIL := &"initial_sensor_coil"
const RES_CRYSTAL_ORE := &"crystal_ore"
const RES_COAL := &"coal"
const RES_WATER := &"water"
const RES_REINFORCED_STEEL_PLATE := &"reinforced_steel_plate"
const RES_OPTICAL_LENS := &"optical_lens"
const RES_HIGH_CAPACITY_BATTERY := &"high_capacity_battery"
const RES_HIGH_FREQUENCY_OSCILLATOR := &"high_frequency_oscillator"
const RES_WRECKAGE_SCRAP := &"wreckage_scrap"
const RES_HEAVY_WRECKAGE := &"heavy_wreckage"
const RES_SALVAGE_DATA_CORE := &"salvage_data_core"
const RES_SALVAGED_ALLOY := &"salvaged_alloy"
const RES_RECOVERED_SERVO_CORE := &"recovered_servo_core"
const RES_TARGETING_PROCESSOR := &"targeting_processor"

const UNIT_BASIC_RIFLE_ROBOT := &"basic_rifle_robot"

const BUILDING_MAIN_BASE := &"main_base"
const BUILDING_MINER := &"miner"
const BUILDING_PROCESSOR := &"processor"
const BUILDING_ADVANCED_PROCESSOR := &"advanced_processor"
const BUILDING_ROBOT_FORGE := &"robot_forge"
const BUILDING_RESEARCH_TERMINAL := &"research_terminal"
const BUILDING_WATER_PUMP := &"water_pump"
const BUILDING_FORWARD_SUPPLY_POINT := &"forward_supply_point"

static func create_resource_defs() -> Array[ResourceDef]:
	return [
		_make_resource(RES_IRON_ORE, "铁矿", "res://Resources/art/resources/iron_ore.svg", "基础金属矿物。"),
		_make_resource(RES_COPPER_ORE, "铜矿", "res://Resources/art/resources/copper_ore.svg", "基础导电矿物。"),
		_make_resource(RES_IRON_PLATE, "铁板", "res://Resources/art/resources/iron_plate.svg", "基础结构材料。"),
		_make_resource(RES_COPPER_WIRE, "铜线", "res://Resources/art/resources/copper_wire.svg", "基础电气材料。"),
		_make_resource(RES_CONSTRUCTION_MASS, "建设质料", "res://Resources/art/resources/construction_mass.svg", "建筑通用基础开销。"),
		_make_resource(RES_INITIAL_SENSOR_COIL, "初级感应线圈", "res://Resources/art/resources/initial_sensor_coil.svg", "第一处敌巢抽象回收的阶段 1 关键道具。"),
		_make_resource(RES_CRYSTAL_ORE, "晶体矿", "res://Resources/art/resources/crystal_ore.svg", "第二资源圈的高频结构矿物。"),
		_make_resource(RES_COAL, "原煤", "res://Resources/art/resources/coal.svg", "中期能源链的基础燃料。"),
		_make_resource(RES_WATER, "水", "res://Resources/art/resources/water.svg", "水泵从水池抽取的流体资源。"),
		_make_resource(RES_REINFORCED_STEEL_PLATE, "强化钢板", "res://Resources/art/resources/reinforced_steel_plate.svg", "装甲底盘和中期建筑使用的复合结构材料。"),
		_make_resource(RES_OPTICAL_LENS, "光学透镜", "res://Resources/art/resources/optical_lens.svg", "热能激光与精密传感模块使用的晶体组件。"),
		_make_resource(RES_HIGH_CAPACITY_BATTERY, "高容电池", "res://Resources/art/resources/high_capacity_battery.svg", "热能武器与能量模块使用的中期储能件。"),
		_make_resource(RES_HIGH_FREQUENCY_OSCILLATOR, "高频振荡器", "res://Resources/art/resources/high_frequency_oscillator.svg", "装甲拾荒巢穴抽象回收的阶段 2 关键道具。"),
		_make_resource(RES_WRECKAGE_SCRAP, "残骸碎料", "res://Resources/art/resources/wreckage_scrap.svg", "战场回收得到的通用残骸材料，可重新进入生产链。"),
		_make_resource(RES_HEAVY_WRECKAGE, "重型残骸", "res://Resources/art/resources/heavy_wreckage.svg", "需要装甲回收车或牵引模块带回的高价值残骸。"),
		_make_resource(RES_SALVAGE_DATA_CORE, "残骸数据核心", "res://Resources/art/resources/salvage_data_core.svg", "从危险残骸中带回的阶段 17 战略样本。"),
		_make_resource(RES_SALVAGED_ALLOY, "回收合金", "res://Resources/art/resources/salvaged_alloy.svg", "由残骸碎料拆解出的终局机体材料。"),
		_make_resource(RES_RECOVERED_SERVO_CORE, "回收伺服核心", "res://Resources/art/resources/recovered_servo_core.svg", "从重型残骸中恢复的高扭矩伺服部件。"),
		_make_resource(RES_TARGETING_PROCESSOR, "目标锁定处理器", "res://Resources/art/resources/targeting_processor.svg", "解析残骸数据核心得到的远程制导处理器。"),
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

static func create_unit_blueprints() -> Array[UnitBlueprint]:
	var recipe_defs := create_recipe_defs()
	var configured := UnitBlueprintConfigLoaderScript.load_unit_blueprints(UNIT_BLUEPRINT_CONFIG_PATH, recipe_defs)
	if configured.is_empty():
		configured.append(_create_basic_rifle_blueprint_fallback(recipe_defs))
	return configured

static func _create_basic_rifle_blueprint_fallback(recipe_defs: Array[RecipeDef]) -> UnitBlueprint:
	var recipe := _find_recipe_by_target(recipe_defs, &"unit", UNIT_BASIC_RIFLE_ROBOT)
	var blueprint := UnitBlueprint.new()
	blueprint.id = UNIT_BASIC_RIFLE_ROBOT
	blueprint.display_name = "基础步枪机器人"
	blueprint.version = 1
	blueprint.icon_path = "res://Resources/art/blueprints/basic_rifle_robot.svg"
	blueprint.unit_type_id = UNIT_BASIC_RIFLE_ROBOT
	blueprint.unit_type_display_name = "基础步枪机器人"
	blueprint.upgrade_ids = []
	blueprint.upgrade_display_names = []
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
		_make_building(BUILDING_ADVANCED_PROCESSOR, "高级加工厂", Vector2i(1, 1), recipe_defs, "res://Resources/art/buildings/advanced_processor.svg", 760),
		_make_building(BUILDING_ROBOT_FORGE, "机器人锻造厂", Vector2i(1, 1), recipe_defs, "res://Resources/art/buildings/robot_forge.svg", 700),
		_make_building(BUILDING_RESEARCH_TERMINAL, "研究终端", Vector2i(1, 1), recipe_defs, "res://Resources/art/buildings/research_terminal.svg", 520),
		_make_building(BUILDING_WATER_PUMP, "水泵", Vector2i(1, 1), recipe_defs, "res://Resources/art/buildings/water_pump.svg", 460),
		_make_building(BUILDING_FORWARD_SUPPLY_POINT, "前线补给点", Vector2i(2, 2), recipe_defs, "res://Resources/art/buildings/forward_supply_point.svg", 900),
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

