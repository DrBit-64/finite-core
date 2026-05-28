extends Node2D
class_name MvpGameManager

const GridOccupancyScript := preload("res://Scripts/map/grid_occupancy.gd")
const MainBaseScene := preload("res://Scenes/buildings/main_base.tscn")
const BaseBuildingScene := preload("res://Scenes/buildings/base_building.tscn")
const MinerScene := preload("res://Scenes/buildings/miner.tscn")
const ProcessorScene := preload("res://Scenes/buildings/processor.tscn")
const RobotForgeScene := preload("res://Scenes/buildings/robot_forge.tscn")
const BuildingPlacementGhostScene := preload("res://Scenes/map/building_placement_ghost.tscn")
const GridSelectionMarkerScene := preload("res://Scenes/map/grid_selection_marker.tscn")
const ResourceNodeScene := preload("res://Scenes/map/resource_node.tscn")
const RallyPointMarkerScene := preload("res://Scenes/map/rally_point_marker.tscn")
const RobotScene := preload("res://Scenes/robot.tscn")
const MapConfigLoaderScript := preload("res://Scripts/map/map_config_loader.gd")
const OPERATION_PANEL_REFRESH_INTERVAL := 0.1

@export var stage_label: String = "阶段 4"
@export var current_goal: String = "机器人锻造厂、蓝图生产与集结点"
@export var resource_summary_placeholder: String = "资源面板占位"
@export var bottom_hint: String = "先放置主基地；生产材料后建造机器人锻造厂；选中锻造厂可设置集结点"
@export var hud_path: NodePath = ^"%MvpHUD"
@export var grid_map_path: NodePath = ^"%GridMap"
@export_file("*.json") var map_config_path: String = "res://Resources/data/maps/mvp_stage3_map.json"
@export var starting_inventory: Dictionary = {
	&"construction_mass": 120,
	&"iron_plate": 20,
	&"copper_wire": 12,
}

@onready var hud: CanvasLayer = get_node_or_null(hud_path)
@onready var grid_map: Node2D = get_node_or_null(grid_map_path)

var resource_defs: Array[ResourceDef] = []
var recipe_defs: Array[RecipeDef] = []
var basic_rifle_blueprint: UnitBlueprint
var building_defs: Array[BuildingDef] = []
var grid_occupancy = GridOccupancyScript.new()
var main_base: Node = null
var active_building_def: BuildingDef = null
var placement_ghost: Node2D = null
var selection_marker: Node2D = null
var last_hover_cell: Vector2i = Vector2i(-9999, -9999)
var resource_nodes_by_cell: Dictionary = {}
var resource_nodes_by_id: Dictionary = {}
var selected_operation_building: Node = null
var operation_panel_refresh_seconds: float = 0.0
var rally_point_target_forge: Node = null

func _ready() -> void:
	_bootstrap_mvp_scene()

func _process(delta: float) -> void:
	if active_building_def:
		_update_placement_preview()
	if selected_operation_building:
		operation_panel_refresh_seconds += delta
		if operation_panel_refresh_seconds >= OPERATION_PANEL_REFRESH_INTERVAL:
			operation_panel_refresh_seconds = 0.0
			_refresh_operation_panel()

func _unhandled_input(event: InputEvent) -> void:
	if rally_point_target_forge:
		_handle_rally_point_input(event)
		return
	if active_building_def and event is InputEventMouseMotion:
		_update_placement_preview()
	elif event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if active_building_def:
				_try_place_active_building()
			else:
				_select_map_cell_under_mouse()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and active_building_def:
			_cancel_build_mode()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE and active_building_def:
			_cancel_build_mode()

func _bootstrap_mvp_scene() -> void:
	_load_stage_one_data()
	_setup_stage_two_world()
	_configure_hud()
	_log_startup_status()

func _load_stage_one_data() -> void:
	resource_defs = MvpDataDefaults.create_resource_defs()
	recipe_defs = MvpDataDefaults.create_recipe_defs()
	basic_rifle_blueprint = MvpDataDefaults.create_basic_rifle_blueprint()
	building_defs = MvpDataDefaults.create_mvp_building_defs()
	resource_summary_placeholder = "资源 %d / 配方 %d / 建筑 %d" % [
		resource_defs.size(),
		recipe_defs.size(),
		building_defs.size(),
	]

func _configure_hud() -> void:
	if hud == null:
		push_warning("MVP HUD not found at path: %s" % hud_path)
		return

	if hud.has_method("set_current_goal"):
		hud.call("set_current_goal", "%s：%s" % [stage_label, current_goal])
	if hud.has_method("set_resource_summary"):
		hud.call("set_resource_summary", resource_summary_placeholder)
	if hud.has_method("set_bottom_hint"):
		hud.call("set_bottom_hint", bottom_hint)
	if hud.has_signal("build_mode_requested"):
		hud.connect("build_mode_requested", Callable(self, "_on_build_mode_requested"))
	if hud.has_signal("processor_recipe_selected"):
		hud.connect("processor_recipe_selected", Callable(self, "_on_processor_recipe_selected"))
	if hud.has_signal("forge_rally_point_requested"):
		hud.connect("forge_rally_point_requested", Callable(self, "_on_forge_rally_point_requested"))
	_refresh_build_options()
	_refresh_resource_hud()

func _setup_stage_two_world() -> void:
	if grid_map == null:
		return
	grid_occupancy.configure(grid_map.get("map_size_cells"))
	_create_selection_marker()
	_load_fixed_map()

func _log_startup_status() -> void:
	push_debug_event("MVP GameManager 已加载")
	push_debug_event("当前目标：%s：%s" % [stage_label, current_goal])
	push_debug_event("%s 数据：资源 %d 项，配方 %d 条，建筑 %d 种，矿点 %d 个" % [
		stage_label,
		resource_defs.size(),
		recipe_defs.size(),
		building_defs.size(),
		resource_nodes_by_id.size(),
	])
	if basic_rifle_blueprint:
		push_debug_event("基础蓝图：%s，配方 %s，成本 %s" % [
			basic_rifle_blueprint.display_name,
			String(basic_rifle_blueprint.production_recipe_id),
			JSON.stringify(basic_rifle_blueprint.production_cost),
		])
	if grid_map and grid_map.has_method("describe"):
		push_debug_event("网格地图：%s" % grid_map.call("describe"))
	else:
		push_debug_event("网格地图未找到或尚未配置")
	push_debug_event("请先从底部建造栏选择主基地并放置")

func push_debug_event(message: String) -> void:
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log and event_log.has_method("record"):
		event_log.call("record", &"debug", {"message": message})
	elif hud and hud.has_method("push_debug_event"):
		hud.call("push_debug_event", message)
	else:
		print("[MVP] ", message)

func set_current_goal(next_goal: String) -> void:
	current_goal = next_goal
	if hud and hud.has_method("set_current_goal"):
		hud.call("set_current_goal", "%s：%s" % [stage_label, current_goal])
	push_debug_event("目标更新：%s" % current_goal)

func _on_build_mode_requested(building_id: StringName) -> void:
	var building_def := _find_building_def(building_id)
	if building_def == null:
		push_debug_event("未知建筑：%s" % String(building_id))
		return
	_cancel_rally_point_mode(false)
	active_building_def = building_def
	last_hover_cell = Vector2i(-9999, -9999)
	_hide_operation_panel()
	_create_or_update_placement_ghost()
	_update_placement_preview()
	if hud and hud.has_method("set_bottom_hint"):
		hud.call("set_bottom_hint", "正在放置：%s。左键建造，右键或 Esc 取消。" % active_building_def.display_name)
	push_debug_event("进入建造模式：%s" % active_building_def.display_name)

func _create_or_update_placement_ghost() -> void:
	if placement_ghost == null:
		placement_ghost = BuildingPlacementGhostScene.instantiate()
		var layer := _get_layer("RallyLayer")
		(layer if layer else self).add_child(placement_ghost)
	placement_ghost.visible = active_building_def != null
	if placement_ghost.has_method("setup"):
		placement_ghost.call("setup", active_building_def, _get_grid_cell_size())

func _update_placement_preview() -> void:
	if active_building_def == null or placement_ghost == null or grid_map == null:
		return
	_update_build_cost_preview()
	var cell := _get_mouse_grid_cell()
	if cell == last_hover_cell:
		return
	last_hover_cell = cell
	placement_ghost.call("set_grid_origin", cell)
	placement_ghost.call("set_valid", _can_place_building(active_building_def, cell))

func _try_place_active_building() -> void:
	if active_building_def == null:
		return
	var cell := _get_mouse_grid_cell()
	if not _can_place_building(active_building_def, cell):
		push_debug_event("建造失败：%s，%s" % [active_building_def.display_name, _get_place_block_reason(active_building_def, cell)])
		_update_placement_preview()
		return
	var is_main_base := _is_main_base_def(active_building_def)
	var inventory = _get_main_base_inventory()
	if not is_main_base:
		if inventory == null:
			push_debug_event("建造失败：请先放置主基地")
			return
		if not inventory.spend_resources(active_building_def.build_cost, "建造 %s" % active_building_def.display_name):
			push_debug_event("建造失败：资源不足 %s" % JSON.stringify(inventory.get_missing(active_building_def.build_cost)))
			return
	var building := _spawn_building(active_building_def, cell, is_main_base)
	if building:
		push_debug_event("建造完成：%s @ %s, %s" % [active_building_def.display_name, cell.x, cell.y])
		if is_main_base:
			_setup_main_base_after_placement(building)
		_configure_building_runtime(building, active_building_def, cell)
		_show_selection_for_node(building)
		if hud and hud.has_method("inspect_node"):
			hud.call("inspect_node", building)
		_show_operation_panel_for_node(building)
	_cancel_build_mode()

func _cancel_build_mode() -> void:
	var canceled_name := active_building_def.display_name if active_building_def else ""
	if placement_ghost:
		placement_ghost.visible = false
	if hud and hud.has_method("hide_build_cost_preview"):
		hud.call("hide_build_cost_preview")
	active_building_def = null
	last_hover_cell = Vector2i(-9999, -9999)
	if hud and hud.has_method("set_bottom_hint"):
		hud.call("set_bottom_hint", bottom_hint)
	if not canceled_name.is_empty():
		push_debug_event("取消建造模式：%s" % canceled_name)

func _select_map_cell_under_mouse() -> void:
	if grid_map == null:
		return
	var cell := _get_mouse_grid_cell()
	if not bool(grid_map.call("is_cell_in_bounds", cell)):
		return
	var occupant = grid_occupancy.get_at(cell)
	if occupant is Node:
		_show_selection_for_node(occupant)
		if hud and hud.has_method("inspect_node"):
			hud.call("inspect_node", occupant)
		_show_operation_panel_for_node(occupant)
	elif resource_nodes_by_cell.has(cell):
		var resource_node: Node = resource_nodes_by_cell[cell]
		_show_selection_for_node(resource_node)
		if hud and hud.has_method("inspect_node"):
			hud.call("inspect_node", resource_node)
		_hide_operation_panel()
	else:
		_show_selection_for_cell(cell)
		if hud and hud.has_method("inspect_cell"):
			hud.call("inspect_cell", cell)
		_hide_operation_panel()

func _spawn_building(building_def: BuildingDef, origin: Vector2i, is_main_base: bool) -> Node:
	if grid_map == null or not grid_occupancy.register_rect(origin, building_def.grid_size, null):
		return null
	var scene := _get_building_scene(building_def, is_main_base)
	var building := scene.instantiate()
	building.name = String(building_def.id)
	var building_layer := _get_layer("BuildingLayer")
	(building_layer if building_layer else self).add_child(building)
	if building.has_method("setup"):
		building.call("setup", building_def, origin, _get_grid_cell_size())
	grid_occupancy.clear_rect(origin, building_def.grid_size)
	grid_occupancy.register_rect(origin, building_def.grid_size, building)
	return building

func _can_place_building(building_def: BuildingDef, origin: Vector2i) -> bool:
	return _get_place_block_reason(building_def, origin).is_empty()

func _get_place_block_reason(building_def: BuildingDef, origin: Vector2i) -> String:
	if grid_map == null:
		return "地图未就绪"
	if not bool(grid_map.call("is_rect_in_bounds", origin, building_def.grid_size)):
		return "超出地图边界"
	if not grid_occupancy.can_place(origin, building_def.grid_size):
		return "格子已被占用"
	var resource_node := _get_resource_node_at(origin)
	if _is_main_base_def(building_def):
		if main_base != null:
			return "主基地已经存在"
		if resource_node != null:
			return "主基地不能覆盖资源点"
		return ""
	if _is_miner_def(building_def):
		if resource_node == null:
			return "采矿机必须覆盖矿点"
		if bool(resource_node.call("is_bound")):
			return "矿点已绑定采矿机"
	elif resource_node != null:
		return "资源点上只能放置采矿机"
	var inventory = _get_main_base_inventory()
	if inventory == null:
		return "请先放置主基地"
	if not _is_in_main_base_service_radius(origin, building_def.grid_size):
		return "超出主基地服务半径"
	var missing = inventory.get_missing(building_def.build_cost)
	if not missing.is_empty():
		return "资源不足 %s" % JSON.stringify(missing)
	return ""

func _is_in_main_base_service_radius(origin: Vector2i, size: Vector2i) -> bool:
	if main_base == null:
		return false
	var building_center := Vector2(origin) + Vector2(size) * 0.5
	var base_center := Vector2(main_base.get("grid_origin")) + Vector2(main_base.get("grid_size")) * 0.5
	return building_center.distance_to(base_center) <= float(main_base.get("service_radius_cells"))

func _on_inventory_changed(resource_id: StringName, amount: int, delta: int, reason: String) -> void:
	_refresh_resource_hud()
	if delta > 0:
		_record_event(&"resource_gained", resource_id, amount, delta, reason)
	elif delta < 0:
		_record_event(&"resource_spent", resource_id, amount, delta, reason)

func _record_event(event_type: StringName, resource_id: StringName, amount: int, delta: int, reason: String) -> void:
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log and event_log.has_method("record"):
		event_log.call("record", event_type, {
			"resource_id": String(resource_id),
			"amount": amount,
			"delta": delta,
			"reason": reason,
		})

func _refresh_resource_hud() -> void:
	var inventory = _get_main_base_inventory()
	if hud == null:
		return
	if inventory == null:
		if hud.has_method("set_resource_summary"):
			hud.call("set_resource_summary", "请先放置主基地")
		if active_building_def:
			_update_build_cost_preview()
		return
	if hud.has_method("set_resource_amounts"):
		hud.call("set_resource_amounts", resource_defs, inventory.get_all())
	if active_building_def:
		_update_build_cost_preview()

func _update_build_cost_preview() -> void:
	var inventory = _get_main_base_inventory()
	if hud == null:
		return
	var amounts: Dictionary = inventory.get_all() if inventory else {}
	if hud.has_method("show_build_cost_preview"):
		hud.call(
			"show_build_cost_preview",
			active_building_def,
			resource_defs,
			amounts,
			get_viewport().get_mouse_position()
		)

func _get_mouse_grid_cell() -> Vector2i:
	return grid_map.call("world_to_grid", get_global_mouse_position())

func _get_grid_cell_size() -> int:
	return int(grid_map.get("cell_size")) if grid_map else 64

func _get_main_base_inventory() -> Variant:
	if main_base == null:
		return null
	return main_base.get("inventory")

func _get_layer(layer_name: String) -> Node2D:
	if grid_map and grid_map.has_method("get_layer"):
		return grid_map.call("get_layer", layer_name)
	return null

func _create_selection_marker() -> void:
	if selection_marker != null:
		return
	selection_marker = GridSelectionMarkerScene.instantiate()
	var layer := _get_layer("RallyLayer")
	(layer if layer else self).add_child(selection_marker)

func _show_selection_for_cell(cell: Vector2i) -> void:
	if selection_marker and selection_marker.has_method("show_selection"):
		selection_marker.call("show_selection", cell, Vector2i.ONE, _get_grid_cell_size())

func _show_selection_for_node(node: Node) -> void:
	if selection_marker == null or not selection_marker.has_method("show_selection"):
		return
	var origin: Vector2i = node.get("grid_origin")
	var size: Vector2i = node.get("grid_size")
	selection_marker.call("show_selection", origin, size, _get_grid_cell_size())

func _find_building_def(building_id: StringName) -> BuildingDef:
	for building_def in building_defs:
		if building_def.id == building_id:
			return building_def
	return null

func _get_placeable_buildings() -> Array[BuildingDef]:
	var result: Array[BuildingDef] = []
	for building_def in building_defs:
		if main_base == null:
			if _is_main_base_def(building_def):
				result.append(building_def)
		elif not _is_main_base_def(building_def):
			result.append(building_def)
	return result

func _setup_main_base_after_placement(base_node: Node) -> void:
	main_base = base_node
	var inventory = _get_main_base_inventory()
	if inventory:
		inventory.inventory_changed.connect(_on_inventory_changed)
	if main_base.has_method("seed_inventory"):
		main_base.call("seed_inventory", starting_inventory)
	_refresh_resource_hud()
	_refresh_build_options()
	var origin: Vector2i = main_base.get("grid_origin")
	push_debug_event("主基地已部署：网格 %s, %s，其它建筑已解锁" % [
		origin.x,
		origin.y,
	])

func _refresh_build_options() -> void:
	if hud and hud.has_method("set_building_options"):
		hud.call("set_building_options", _get_placeable_buildings())

func _is_main_base_def(building_def: BuildingDef) -> bool:
	return building_def != null and building_def.id == MvpDataDefaults.BUILDING_MAIN_BASE

func _is_miner_def(building_def: BuildingDef) -> bool:
	return building_def != null and building_def.id == MvpDataDefaults.BUILDING_MINER

func _is_processor_def(building_def: BuildingDef) -> bool:
	return building_def != null and building_def.id == MvpDataDefaults.BUILDING_PROCESSOR

func _is_robot_forge_def(building_def: BuildingDef) -> bool:
	return building_def != null and building_def.id == MvpDataDefaults.BUILDING_ROBOT_FORGE

func _get_building_scene(building_def: BuildingDef, is_main_base: bool) -> PackedScene:
	if is_main_base:
		return MainBaseScene
	if _is_miner_def(building_def):
		return MinerScene
	if _is_processor_def(building_def):
		return ProcessorScene
	if _is_robot_forge_def(building_def):
		return RobotForgeScene
	return BaseBuildingScene

func _load_fixed_map() -> void:
	var map_config := MapConfigLoaderScript.load_map_config(map_config_path)
	var resource_items: Array = map_config.get("resource_nodes", [])
	for item in resource_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		_spawn_resource_node(item)

func _spawn_resource_node(data: Dictionary) -> void:
	var resource_id := StringName(str(data.get("resource_id", "")))
	var resource_def := _find_resource_def(resource_id)
	if resource_def == null:
		push_warning("Unknown map resource id: %s" % String(resource_id))
		return
	var node := ResourceNodeScene.instantiate()
	var layer := _get_layer("ResourceLayer")
	(layer if layer else self).add_child(node)
	node.call("setup", data, resource_def, _get_grid_cell_size())
	resource_nodes_by_cell[node.get("grid_origin")] = node
	resource_nodes_by_id[node.get("node_id")] = node

func _find_resource_def(resource_id: StringName) -> ResourceDef:
	for resource_def in resource_defs:
		if resource_def.id == resource_id:
			return resource_def
	return null

func _get_resource_node_at(cell: Vector2i) -> Node:
	return resource_nodes_by_cell.get(cell, null)

func _configure_building_runtime(building: Node, building_def: BuildingDef, origin: Vector2i) -> void:
	var inventory = _get_main_base_inventory()
	if _is_miner_def(building_def) and building.has_method("setup_miner"):
		building.call("setup_miner", _get_resource_node_at(origin), inventory)
	elif _is_processor_def(building_def) and building.has_method("setup_processor"):
		building.call("setup_processor", _get_resource_recipes(), inventory)
		if building.has_signal("processor_state_changed"):
			building.connect("processor_state_changed", Callable(self, "_on_processor_state_changed").bind(building))
	elif _is_robot_forge_def(building_def) and building.has_method("setup_forge"):
		building.call("setup_forge", basic_rifle_blueprint, inventory)
		if building.has_signal("forge_state_changed"):
			building.connect("forge_state_changed", Callable(self, "_on_forge_state_changed").bind(building))
		if building.has_signal("robot_production_completed"):
			building.connect("robot_production_completed", Callable(self, "_on_forge_robot_production_completed"))

func _get_resource_recipes() -> Array[RecipeDef]:
	var result: Array[RecipeDef] = []
	for recipe in recipe_defs:
		if recipe.recipe_type == &"resource":
			result.append(recipe)
	return result

func _show_operation_panel_for_node(node: Node) -> void:
	selected_operation_building = null
	if node == null:
		_hide_operation_panel()
		return
	var building_def: BuildingDef = node.get("building_def")
	if _is_processor_def(building_def):
		selected_operation_building = node
		operation_panel_refresh_seconds = 0.0
		_refresh_operation_panel()
	elif _is_robot_forge_def(building_def):
		selected_operation_building = node
		operation_panel_refresh_seconds = 0.0
		_refresh_operation_panel()
	else:
		_hide_operation_panel()

func _refresh_operation_panel() -> void:
	if selected_operation_building == null or hud == null:
		return
	var building_def: BuildingDef = selected_operation_building.get("building_def")
	if _is_processor_def(building_def) and hud.has_method("show_processor_panel"):
		hud.call(
			"show_processor_panel",
			selected_operation_building,
			_get_resource_recipes(),
			resource_defs,
			_world_to_screen(selected_operation_building.global_position)
		)
	elif _is_robot_forge_def(building_def) and hud.has_method("show_forge_panel"):
		hud.call(
			"show_forge_panel",
			selected_operation_building,
			basic_rifle_blueprint,
			resource_defs,
			_world_to_screen(selected_operation_building.global_position)
		)

func _hide_operation_panel() -> void:
	selected_operation_building = null
	operation_panel_refresh_seconds = 0.0
	if hud and hud.has_method("hide_operation_panel"):
		hud.call("hide_operation_panel")

func _on_processor_recipe_selected(processor: Node, recipe_id: StringName) -> void:
	if processor and processor.has_method("set_recipe"):
		processor.call("set_recipe", recipe_id)
		push_debug_event("加工厂配方切换：%s" % String(recipe_id))
	call_deferred("_refresh_operation_panel")

func _on_processor_state_changed(processor: Node) -> void:
	if processor == selected_operation_building:
		call_deferred("_refresh_operation_panel")

func _on_forge_state_changed(forge: Node) -> void:
	if forge == selected_operation_building:
		call_deferred("_refresh_operation_panel")

func _on_forge_robot_production_completed(forge: Node, blueprint: UnitBlueprint) -> void:
	if forge == null or blueprint == null:
		return
	var unit_layer := _get_layer("UnitLayer")
	var robot := ObjectPool.get_instance(RobotScene, unit_layer if unit_layer else self, "robot_basic") as CharacterBody2D
	if robot == null:
		return
	robot.name = IdProvider.next_id(&"robot")
	robot.set("team", "Team_A")
	robot.global_position = forge.call("get_spawn_position") if forge.has_method("get_spawn_position") else forge.global_position
	if robot.has_method("setup_from_blueprint"):
		robot.call(
			"setup_from_blueprint",
			blueprint,
			forge.get("rally_point_position"),
			bool(forge.get("has_rally_point"))
		)
	if forge.has_method("register_robot"):
		forge.call("register_robot", robot)
	_record_robot_produced(forge, robot, blueprint)

func _record_robot_produced(forge: Node, robot: Node, blueprint: UnitBlueprint) -> void:
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log and event_log.has_method("record"):
		event_log.call("record", &"robot_produced", {
			"forge": forge.name,
			"robot": robot.name,
			"blueprint_id": String(blueprint.id),
			"blueprint_version": blueprint.version,
			"rally_point": _format_vector2_payload(forge.get("rally_point_position")),
			"has_rally_point": bool(forge.get("has_rally_point")),
		})
	push_debug_event("锻造完成：%s -> %s" % [blueprint.display_name, robot.name])

func _on_forge_rally_point_requested(forge: Node) -> void:
	if forge == null or not is_instance_valid(forge):
		return
	rally_point_target_forge = forge
	_hide_operation_panel()
	if hud and hud.has_method("show_bottom_prompt"):
		hud.call("show_bottom_prompt", "单击地图空白格点设置集结点，右键或 Esc 取消", 0.0, &"info")
	push_debug_event("进入集结点设置模式：%s" % forge.name)

func _handle_rally_point_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_try_set_rally_point_under_mouse()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_rally_point_mode(true)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			_cancel_rally_point_mode(true)

func _try_set_rally_point_under_mouse() -> void:
	if rally_point_target_forge == null or not is_instance_valid(rally_point_target_forge):
		_cancel_rally_point_mode(false)
		return
	var cell := _get_mouse_grid_cell()
	var block_reason := _get_rally_point_block_reason(cell)
	if not block_reason.is_empty():
		if hud and hud.has_method("show_bottom_prompt"):
			hud.call("show_bottom_prompt", "不能设置集结点：%s。请单击地图空白格点，右键或 Esc 取消" % block_reason, 0.0, &"warning")
		return
	var world_position: Vector2 = grid_map.call("grid_to_world", cell)
	rally_point_target_forge.call("set_rally_point", cell, world_position)
	_create_or_update_rally_marker(rally_point_target_forge, cell)
	if hud and hud.has_method("show_bottom_prompt"):
		hud.call("show_bottom_prompt", "集结点已设置：%s, %s" % [cell.x, cell.y], 2.4, &"success")
	push_debug_event("集结点已设置：%s @ %s, %s" % [rally_point_target_forge.name, cell.x, cell.y])
	rally_point_target_forge = null

func _get_rally_point_block_reason(cell: Vector2i) -> String:
	if grid_map == null or not bool(grid_map.call("is_cell_in_bounds", cell)):
		return "超出地图边界"
	if grid_occupancy.get_at(cell) != null:
		return "格子已有建筑"
	if resource_nodes_by_cell.has(cell):
		return "资源点不能作为集结点"
	return ""

func _cancel_rally_point_mode(show_message: bool) -> void:
	if rally_point_target_forge == null:
		return
	rally_point_target_forge = null
	if show_message and hud and hud.has_method("show_bottom_prompt"):
		hud.call("show_bottom_prompt", "已取消设置集结点", 1.8, &"warning")
	elif hud and hud.has_method("hide_bottom_prompt"):
		hud.call("hide_bottom_prompt")

func _create_or_update_rally_marker(forge: Node, cell: Vector2i) -> void:
	var marker: Node = forge.get("rally_marker")
	if marker == null or not is_instance_valid(marker):
		marker = RallyPointMarkerScene.instantiate()
		var layer := _get_layer("RallyLayer")
		(layer if layer else self).add_child(marker)
		forge.set("rally_marker", marker)
	if marker.has_method("setup"):
		marker.call("setup", cell, _get_grid_cell_size())

func _format_vector2_payload(value: Variant) -> Dictionary:
	var vector: Vector2 = value
	return {"x": vector.x, "y": vector.y}

func _world_to_screen(world_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_position
