extends Node2D
class_name MvpGameManager

const GridOccupancyScript := preload("res://Scripts/map/grid_occupancy.gd")
const MainBaseScene := preload("res://Scenes/buildings/main_base.tscn")
const BaseBuildingScene := preload("res://Scenes/buildings/base_building.tscn")
const MinerScene := preload("res://Scenes/buildings/miner.tscn")
const ProcessorScene := preload("res://Scenes/buildings/processor.tscn")
const RobotForgeScene := preload("res://Scenes/buildings/robot_forge.tscn")
const ResearchTerminalScene := preload("res://Scenes/buildings/research_terminal.tscn")
const WaterPumpScene := preload("res://Scenes/buildings/water_pump.tscn")
const ForwardSupplyPointScene := preload("res://Scenes/buildings/forward_supply_point.tscn")
const BuildingPlacementGhostScene := preload("res://Scenes/map/building_placement_ghost.tscn")
const GridSelectionMarkerScene := preload("res://Scenes/map/grid_selection_marker.tscn")
const GridHoverMarkerScene := preload("res://Scenes/map/grid_hover_marker.tscn")
const ResourceNodeScene := preload("res://Scenes/map/resource_node.tscn")
const SalvagePickupScene := preload("res://Scenes/map/salvage_pickup.tscn")
const RallyPointMarkerScene := preload("res://Scenes/map/rally_point_marker.tscn")
const RobotScene := preload("res://Scenes/robot.tscn")
const DebugEnemyScene := preload("res://Scenes/units/debug_enemy_unit.tscn")
const ScavengerHoundScene := preload("res://Scenes/units/scavenger_hound.tscn")
const EnemyNestScene := preload("res://Scenes/map/enemy_nest.tscn")
const MapConfigLoaderScript := preload("res://Scripts/map/map_config_loader.gd")
const RegionGateOverlayScript := preload("res://Scripts/map/region_gate_overlay.gd")
const StartingInventoryConfigLoaderScript := preload("res://Scripts/data/starting_inventory_config_loader.gd")
const RuntimeConfigLoaderScript := preload("res://Scripts/data/runtime_config_loader.gd")
const BlueprintLibraryScript := preload("res://Scripts/blueprints/blueprint_library.gd")
const UnitDesignConfigLoaderScript := preload("res://Scripts/data/unit_design_config_loader.gd")
const TacticalTemplateCompilerScript := preload("res://Scripts/ai/tactical_template_compiler.gd")
const EnemyConfigLoaderScript := preload("res://Scripts/data/enemy_config_loader.gd")
const CampaignStateScript := preload("res://Scripts/campaign/campaign_state.gd")
const TechnologyConfigLoaderScript := preload("res://Scripts/campaign/technology_config_loader.gd")
const ENEMY_CONFIG_PATH := "res://Resources/data/enemies/mvp_enemies.json"
const TECHNOLOGY_CONFIG_PATH := "res://Resources/data/technology/mvp_stage1_technologies.json"
const STAGE14_SAVE_PATH := "user://finite_core_stage14_save.json"
const KEY_ITEM_INITIAL_SENSOR_COIL := &"initial_sensor_coil"
const FOG_REGION_SIZE_CELLS := 4
const OPERATION_PANEL_REFRESH_INTERVAL := 0.2
const UNIT_INSPECTOR_REFRESH_INTERVAL := 0.5
const STAGE14_LOGISTICS_TICK_INTERVAL := 0.15
const STAGE14_MIN_LOAD_RATIO := 0.7
const STAGE14_MAX_PICKUP_WAIT_SECONDS := 6.0
const STAGE14_RELAY_TARGET_STOCK := 48
const STAGE14_BASE_TARGET_STOCK := 36
const RESOURCE_HUD_REFRESH_INTERVAL := 0.20
const RESOURCE_EVENT_FLUSH_INTERVAL := 1.00
const NAVIGATION_REACHABILITY_CACHE_MSEC := 300
const RECIPE_UPGRADE_MAX_LEVEL := 5
const RECIPE_UPGRADE_OUTPUT_MULTIPLIER := 1.5
const RECIPE_UPGRADE_INPUT_MULTIPLIER := 1.3
const RECIPE_UPGRADE_NEXT_COST_MULTIPLIER := 1.5
const RECIPE_UPGRADE_BASE_RESOURCE_AMOUNT := 25
const RECIPE_UPGRADE_RESOURCE_ORDER := [
	MvpDataDefaults.RES_CONSTRUCTION_MASS,
	MvpDataDefaults.RES_IRON_ORE,
	MvpDataDefaults.RES_COPPER_ORE,
	MvpDataDefaults.RES_IRON_PLATE,
	MvpDataDefaults.RES_COPPER_WIRE,
	MvpDataDefaults.RES_WATER,
	MvpDataDefaults.RES_CRYSTAL_ORE,
	MvpDataDefaults.RES_COAL,
	MvpDataDefaults.RES_REINFORCED_STEEL_PLATE,
	MvpDataDefaults.RES_OPTICAL_LENS,
	MvpDataDefaults.RES_HIGH_CAPACITY_BATTERY,
]
const MINIMAP_SEMANTIC_TAGS := [
	"water",
	"pump_candidate",
	"frontier",
	"crystal_frontier",
	"wreckage_frontier",
	"interference_frontier",
	"core_frontier",
	"gate",
	"risk_bypass",
]

@export var stage_label: String = "试玩目标"
@export var current_goal: String = "建造锻造厂，设置集结点并摧毁远处敌巢"
@export var resource_summary_placeholder: String = "资源面板占位"
@export var bottom_hint: String = "从底部建造栏选择主基地，并在起始矿区附近放置。"
@export var hud_path: NodePath = ^"%MvpHUD"
@export var grid_map_path: NodePath = ^"%GridMap"
@export var camera_path: NodePath = ^"MainCamera"
@export_file("*.json") var map_config_path: String = "res://Resources/data/maps/mvp_stage3_map.json"
@export var stage14_remote_logistics_enabled: bool = true
@export_file("*.json") var starting_inventory_config_path: String = "res://Resources/data/balance/mvp_starting_inventory.json"
@export_file("*.json") var runtime_profile_path: String = "res://Resources/data/debug/mvp_runtime_profile.json"
@export var enable_right_mouse_camera_drag: bool = true
@export var clamp_camera_to_map_bounds: bool = true
@export var camera_drag_start_threshold: float = 4.0
@export var camera_zoom_min: float = 0.55
@export var camera_zoom_max: float = 1.65
@export var camera_zoom_step: float = 1.12
@export var starting_inventory: Dictionary = {
	&"construction_mass": 120,
	&"iron_plate": 20,
	&"copper_wire": 12,
}

@onready var hud: CanvasLayer = get_node_or_null(hud_path)
@onready var grid_map: Node2D = get_node_or_null(grid_map_path)
@onready var main_camera: Camera2D = get_node_or_null(camera_path)

var resource_defs: Array[ResourceDef] = []
var recipe_defs: Array[RecipeDef] = []
var basic_rifle_blueprint: UnitBlueprint
var blueprint_library: BlueprintLibrary
var building_defs: Array[BuildingDef] = []
var technology_defs: Array = []
var campaign_state: Variant
var runtime_profile: Dictionary = {}
var runtime_debug_enabled: bool = false
var enemy_config: Dictionary = {}
var enemy_nests_by_id: Dictionary = {}
var grid_occupancy = GridOccupancyScript.new()
var main_base: Node = null
var active_building_def: BuildingDef = null
var placement_ghost: Node2D = null
var selection_marker: Node2D = null
var hover_marker: Node2D = null
var last_hover_cell: Vector2i = Vector2i(-9999, -9999)
var resource_nodes_by_cell: Dictionary = {}
var resource_nodes_by_id: Dictionary = {}
var salvage_pickups_by_cell: Dictionary = {}
var salvage_pickups_by_id: Dictionary = {}
var selected_operation_building: Node = null
var operation_panel_refresh_seconds: float = 0.0
var rally_point_target_forge: Node = null
var selected_world_unit: Node = null
var selected_inspected_node: Node = null
var unit_inspector_refresh_seconds: float = 0.0
var is_camera_dragging: bool = false
var is_camera_drag_candidate: bool = false
var camera_drag_accumulated: float = 0.0
var stage_started_seconds: float = 0.0
var playtest_hud_refresh_seconds: float = 0.0
var research_terminals: Array[Node] = []
var map_region_states: Dictionary = {}
var map_region_signal_cells: Dictionary = {}
var map_region_definitions: Array = []
var map_region_blocks: Dictionary = {}
var map_region_routes: Array = []
var map_region_connections: Array = []
var map_region_gate_states: Dictionary = {}
var map_locked_gate_cells: Dictionary = {}
var map_region_gate_tile_cache: Dictionary = {}
var map_region_gate_cluster_cells_by_gate_id: Dictionary = {}
var map_water_bodies: Array = []
var map_frontline_supply_points: Array = []
var map_pending_enemy_patrols: Array = []
var map_pending_enemy_nests: Array = []
var map_painted_region_cells_cache: Array = []
var map_semantic_cells_by_tag_cache: Dictionary = {}
var map_minimap_static_snapshot: Dictionary = {}
var map_static_cache_version: int = 0
var _map_enemy_spawn_filter_active: bool = false
var _map_enemy_spawn_ids_to_restore: Dictionary = {}
var _stage12_soft_failure_shown: bool = false
var stage14_logistics_tick_seconds: float = 0.0
var stage14_logistics_tasks_by_robot: Dictionary = {}
var stage14_logistics_wait_seconds_by_key: Dictionary = {}
var stage14_logistics_counters: Dictionary = {}
var _navigation_grid: AStarGrid2D = null
var _navigation_dirty: bool = true
var _logistics_visual_layer: Node2D = null
var _logistics_task_lines: Dictionary = {}
var _region_gate_overlay: Node2D = null
var _resource_hud_dirty: bool = false
var _resource_hud_refresh_seconds: float = 0.0
var _resource_event_flush_seconds: float = 0.0
var _pending_resource_events: Dictionary = {}
var _navigation_version: int = 0
var _navigation_reachability_cache: Dictionary = {}

func _ready() -> void:
	add_to_group("stage_path_provider")
	_bootstrap_mvp_scene()

func _process(delta: float) -> void:
	if is_camera_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		is_camera_dragging = false
		is_camera_drag_candidate = false
		camera_drag_accumulated = 0.0
	if active_building_def:
		_update_placement_preview()
	_update_hover_marker()
	playtest_hud_refresh_seconds += delta
	if playtest_hud_refresh_seconds >= 0.25:
		playtest_hud_refresh_seconds = 0.0
		_refresh_playtest_hud()
	_tick_resource_ui_and_events(delta)
	if selected_operation_building:
		operation_panel_refresh_seconds += delta
		if operation_panel_refresh_seconds >= OPERATION_PANEL_REFRESH_INTERVAL:
			operation_panel_refresh_seconds = 0.0
			_refresh_operation_panel()
	if selected_inspected_node and _should_periodically_refresh_inspector():
		unit_inspector_refresh_seconds += delta
		if unit_inspector_refresh_seconds >= UNIT_INSPECTOR_REFRESH_INTERVAL:
			unit_inspector_refresh_seconds = 0.0
			_refresh_selected_unit_inspector()
	if stage14_remote_logistics_enabled:
		stage14_logistics_tick_seconds += delta
		if stage14_logistics_tick_seconds >= STAGE14_LOGISTICS_TICK_INTERVAL:
			stage14_logistics_tick_seconds = 0.0
			_tick_stage14_logistics(STAGE14_LOGISTICS_TICK_INTERVAL)

func _unhandled_input(event: InputEvent) -> void:
	if _handle_camera_drag_input(event):
		return
	if rally_point_target_forge:
		_handle_rally_point_input(event)
		return

	if active_building_def:
		_handle_build_mode_input(event)
		return

	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_select_map_cell_under_mouse()

func _handle_build_mode_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_placement_preview()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _is_pointer_over_hud():
				return
			_try_place_active_building()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and not mouse_event.pressed:
			_cancel_build_mode()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			_cancel_build_mode()

func _handle_camera_drag_input(event: InputEvent) -> bool:
	if not enable_right_mouse_camera_drag or main_camera == null:
		return false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera_at_screen_position(camera_zoom_step, mouse_event.position)
			get_viewport().set_input_as_handled()
			return true
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera_at_screen_position(1.0 / camera_zoom_step, mouse_event.position)
			get_viewport().set_input_as_handled()
			return true
		if mouse_event.button_index != MOUSE_BUTTON_RIGHT:
			return false
		if mouse_event.pressed:
			is_camera_drag_candidate = true
			is_camera_dragging = false
			camera_drag_accumulated = 0.0
			get_viewport().set_input_as_handled()
			return true
		var was_dragging := is_camera_dragging
		if was_dragging:
			get_viewport().set_input_as_handled()
		is_camera_drag_candidate = false
		is_camera_dragging = false
		camera_drag_accumulated = 0.0
		return was_dragging
	if event is InputEventMouseMotion and (is_camera_drag_candidate or is_camera_dragging):
		var mouse_motion := event as InputEventMouseMotion
		camera_drag_accumulated += mouse_motion.relative.length()
		if is_camera_dragging or camera_drag_accumulated >= camera_drag_start_threshold:
			is_camera_dragging = true
			_pan_camera_by_screen_delta(mouse_motion.relative)
			get_viewport().set_input_as_handled()
			return true
		return false
	return false

func _zoom_camera_at_screen_position(factor: float, screen_position: Vector2) -> void:
	if main_camera == null or factor <= 0.0:
		return
	var old_zoom := maxf(main_camera.zoom.x, 0.001)
	var next_zoom := clampf(old_zoom * factor, camera_zoom_min, camera_zoom_max)
	if is_equal_approx(old_zoom, next_zoom):
		return
	var screen_offset := screen_position - get_viewport_rect().size * 0.5
	var world_position_under_cursor := main_camera.global_position + screen_offset / old_zoom
	main_camera.zoom = Vector2.ONE * next_zoom
	main_camera.global_position = world_position_under_cursor - screen_offset / next_zoom
	_clamp_camera_to_map_bounds()
	if selected_operation_building:
		_hide_operation_panel()

func _pan_camera_by_screen_delta(screen_delta: Vector2) -> void:
	if screen_delta == Vector2.ZERO or main_camera == null:
		return
	var zoom := main_camera.zoom
	var world_delta := Vector2(
		screen_delta.x / maxf(zoom.x, 0.001),
		screen_delta.y / maxf(zoom.y, 0.001)
	)
	main_camera.global_position -= world_delta
	_clamp_camera_to_map_bounds()
	if selected_operation_building:
		_hide_operation_panel()

func _clamp_camera_to_map_bounds() -> void:
	if not clamp_camera_to_map_bounds or main_camera == null or grid_map == null:
		return
	if not grid_map.has_method("get_world_size"):
		return
	var map_world_size: Vector2 = grid_map.call("get_world_size")
	var map_origin := grid_map.global_position
	var viewport_size := get_viewport_rect().size
	var zoom := main_camera.zoom
	var half_view := Vector2(
		viewport_size.x / maxf(zoom.x * 2.0, 0.001),
		viewport_size.y / maxf(zoom.y * 2.0, 0.001)
	)
	var camera_pos := main_camera.global_position
	var min_pos := map_origin + half_view
	var max_pos := map_origin + map_world_size - half_view
	if max_pos.x < min_pos.x:
		camera_pos.x = map_origin.x + map_world_size.x * 0.5
	else:
		camera_pos.x = clampf(camera_pos.x, min_pos.x, max_pos.x)
	if max_pos.y < min_pos.y:
		camera_pos.y = map_origin.y + map_world_size.y * 0.5
	else:
		camera_pos.y = clampf(camera_pos.y, min_pos.y, max_pos.y)
	main_camera.global_position = camera_pos

func _bootstrap_mvp_scene() -> void:
	stage_started_seconds = Time.get_ticks_msec() / 1000.0
	_load_stage_one_data()
	_setup_stage_two_world()
	_configure_hud()
	_log_startup_status()

func _load_stage_one_data() -> void:
	runtime_profile = RuntimeConfigLoaderScript.load_runtime_config(runtime_profile_path)
	runtime_debug_enabled = RuntimeConfigLoaderScript.is_debug_enabled(runtime_profile)
	var configured_inventory_path := RuntimeConfigLoaderScript.get_starting_inventory_path(runtime_profile)
	if not configured_inventory_path.is_empty():
		starting_inventory_config_path = configured_inventory_path
	campaign_state = CampaignStateScript.new()
	campaign_state.seed_defaults()
	campaign_state.key_item_added.connect(_on_campaign_key_item_added)
	campaign_state.unlocks_changed.connect(_on_campaign_unlocks_changed)
	campaign_state.technology_unlocked.connect(_on_campaign_technology_unlocked)
	campaign_state.stage_advanced.connect(_on_campaign_stage_advanced)
	resource_defs = MvpDataDefaults.create_resource_defs()
	recipe_defs = MvpDataDefaults.create_recipe_defs()
	blueprint_library = BlueprintLibraryScript.new()
	var configured_blueprints := MvpDataDefaults.create_unit_blueprints()
	for blueprint in configured_blueprints:
		if blueprint == null:
			continue
		if blueprint.id == MvpDataDefaults.UNIT_BASIC_RIFLE_ROBOT:
			basic_rifle_blueprint = blueprint
		blueprint_library.add_blueprint(blueprint)
	if basic_rifle_blueprint == null:
		basic_rifle_blueprint = MvpDataDefaults.create_basic_rifle_blueprint()
		if basic_rifle_blueprint:
			blueprint_library.add_blueprint(basic_rifle_blueprint)
	building_defs = MvpDataDefaults.create_mvp_building_defs()
	technology_defs = TechnologyConfigLoaderScript.load_technology_defs(TECHNOLOGY_CONFIG_PATH)
	if RuntimeConfigLoaderScript.is_debug_feature_enabled(runtime_profile, "unlock_all_technologies"):
		campaign_state.debug_unlock_all_technologies(technology_defs)
	enemy_config = EnemyConfigLoaderScript.load_enemy_config(ENEMY_CONFIG_PATH)
	starting_inventory = StartingInventoryConfigLoaderScript.load_starting_inventory(starting_inventory_config_path, starting_inventory)
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
	if hud.has_method("set_resource_definitions"):
		hud.call("set_resource_definitions", resource_defs)
	if hud.has_method("set_bottom_hint"):
		hud.call("set_bottom_hint", bottom_hint)
	if hud.has_signal("build_mode_requested"):
		hud.connect("build_mode_requested", Callable(self, "_on_build_mode_requested"))
	if hud.has_signal("processor_recipe_selected"):
		hud.connect("processor_recipe_selected", Callable(self, "_on_processor_recipe_selected"))
	if hud.has_signal("processor_pause_toggled"):
		hud.connect("processor_pause_toggled", Callable(self, "_on_processor_pause_toggled"))
	if hud.has_signal("building_demolish_requested"):
		hud.connect("building_demolish_requested", Callable(self, "_on_building_demolish_requested"))
	if hud.has_signal("debug_kill_requested"):
		hud.connect("debug_kill_requested", Callable(self, "_on_debug_kill_requested"))
	if hud.has_signal("forge_rally_point_requested"):
		hud.connect("forge_rally_point_requested", Callable(self, "_on_forge_rally_point_requested"))
	if hud.has_signal("forge_pause_toggled"):
		hud.connect("forge_pause_toggled", Callable(self, "_on_forge_pause_toggled"))
	if hud.has_signal("blueprint_library_requested"):
		hud.connect("blueprint_library_requested", Callable(self, "_on_blueprint_library_requested"))
	if hud.has_signal("blueprint_save_requested"):
		hud.connect("blueprint_save_requested", Callable(self, "_on_blueprint_save_requested"))
	if hud.has_signal("forge_blueprint_selected"):
		hud.connect("forge_blueprint_selected", Callable(self, "_on_forge_blueprint_selected"))
	if hud.has_signal("technology_research_requested"):
		hud.connect("technology_research_requested", Callable(self, "_on_technology_research_requested"))
	if hud.has_signal("recipe_upgrade_requested"):
		hud.connect("recipe_upgrade_requested", Callable(self, "_on_recipe_upgrade_requested"))
	if hud.has_signal("new_game_requested"):
		hud.connect("new_game_requested", Callable(self, "_on_new_game_requested"))
	if hud.has_signal("restart_requested"):
		hud.connect("restart_requested", Callable(self, "_on_restart_requested"))
	if hud.has_signal("save_game_requested"):
		hud.connect("save_game_requested", Callable(self, "_on_save_game_requested"))
	if hud.has_signal("load_game_requested"):
		hud.connect("load_game_requested", Callable(self, "_on_load_game_requested"))
	_refresh_build_options()
	_refresh_resource_hud()
	_refresh_campaign_hud()
	_refresh_blueprint_library_ui()
	_refresh_playtest_hud()
	if main_base == null:
		set_current_goal("请先放置主基地")
		set_guidance_hint("从底部建造栏选择主基地，并在起始矿区附近放置。")
		if hud.has_method("show_bottom_prompt"):
			hud.call("show_bottom_prompt", "先从底部建造栏选择主基地，然后点击地图放置。", 4.0, &"info")

func _setup_stage_two_world() -> void:
	if grid_map == null:
		return
	var map_config := MapConfigLoaderScript.load_map_config(map_config_path)
	_configure_grid_map_from_config(map_config)
	grid_occupancy.configure(grid_map.get("map_size_cells"))
	_navigation_dirty = true
	_create_selection_marker()
	_create_hover_marker()
	_ensure_logistics_visual_layer()
	_load_fixed_map(map_config)
	_apply_camera_start_from_config(map_config)

func _log_startup_status() -> void:
	push_debug_event("MVP GameManager 已加载")
	push_debug_event("当前目标：%s：%s" % [stage_label, current_goal])
	push_debug_event("初始库存配置：%s" % starting_inventory_config_path)
	push_debug_event("运行时配置：%s，debug 初始资源：%s" % [
		runtime_profile_path,
		"是" if RuntimeConfigLoaderScript.is_debug_feature_enabled(runtime_profile, "use_debug_starting_inventory") else "否",
	])
	push_debug_event("Debug 总开关：%s，科技全开：%s" % [
		"开" if runtime_debug_enabled else "关",
		"是" if RuntimeConfigLoaderScript.is_debug_feature_enabled(runtime_profile, "unlock_all_technologies") else "否",
	])
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
	if blueprint_library:
		push_debug_event("Blueprint library ready: %d definitions; production uses snapshots." % blueprint_library.get_blueprints().size())
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

func set_guidance_hint(next_hint: String) -> void:
	bottom_hint = next_hint
	if hud and hud.has_method("set_bottom_hint"):
		hud.call("set_bottom_hint", bottom_hint)

func _refresh_campaign_hud() -> void:
	if hud == null or campaign_state == null:
		return
	var inventory = _get_main_base_inventory()
	var amounts: Dictionary = inventory.get_all() if inventory else {}
	var terminal_status := _get_research_terminal_status()
	if hud.has_method("set_campaign_data"):
		hud.call("set_campaign_data", campaign_state, technology_defs, resource_defs, amounts, terminal_status, _get_recipe_upgrade_hud_data())
	if hud.has_method("set_unlocked_template_ids"):
		hud.call("set_unlocked_template_ids", campaign_state.unlocked_templates)
	if hud.has_method("set_blueprint_unlocks"):
		hud.call("set_blueprint_unlocks", campaign_state.unlocked_unit_types, campaign_state.unlocked_upgrades, campaign_state.unlocked_templates)

func _get_research_terminal_status() -> Dictionary:
	var terminals := _get_valid_research_terminals()
	var active: Node = null
	for terminal in terminals:
		if terminal.get("active_technology") != null:
			active = terminal
			break
	var active_technology: Variant = null
	var active_technology_id := ""
	var active_technology_name := ""
	var progress_seconds := 0.0
	var progress_ratio := 0.0
	if active != null:
		active_technology = active.get("active_technology")
		if active_technology != null:
			active_technology_id = String(active_technology.id)
			active_technology_name = active_technology.display_name
		progress_seconds = float(active.get("progress_seconds"))
		if active.has_method("get_progress_ratio"):
			progress_ratio = float(active.call("get_progress_ratio"))
	return {
		"has_terminal": not terminals.is_empty(),
		"busy": active != null,
		"active_technology_id": active_technology_id,
		"active_technology_name": active_technology_name,
		"progress_seconds": progress_seconds,
		"progress_ratio": progress_ratio,
	}

func _get_valid_research_terminals() -> Array[Node]:
	var result: Array[Node] = []
	for index in range(research_terminals.size() - 1, -1, -1):
		var terminal := research_terminals[index]
		if terminal == null or not is_instance_valid(terminal):
			research_terminals.remove_at(index)
			continue
		if terminal.has_method("is_alive") and not bool(terminal.call("is_alive")):
			continue
		result.append(terminal)
	return result

func _on_technology_research_requested(technology_id: StringName) -> void:
	var technology: Variant = _find_technology_def(technology_id)
	if technology == null:
		push_debug_event("研究失败：未知科技 %s" % String(technology_id))
		_play_audio_cue(&"build_failed")
		return
	if campaign_state == null or not campaign_state.can_research(technology):
		push_debug_event("研究失败：门槛未满足 %s" % technology.display_name)
		_play_audio_cue(&"build_failed")
		_refresh_campaign_hud()
		return
	var terminals := _get_valid_research_terminals()
	if terminals.is_empty():
		push_debug_event("研究失败：需要建造研究终端")
		_play_audio_cue(&"build_failed")
		if hud and hud.has_method("show_bottom_prompt"):
			hud.call("show_bottom_prompt", "需要先建造研究终端", 2.0, &"warning")
		return
	for terminal in terminals:
		if terminal.has_method("start_research") and terminal.call("start_research", technology):
			push_debug_event("研究开始：%s" % technology.display_name)
			if hud and hud.has_method("show_bottom_prompt"):
				hud.call("show_bottom_prompt", "研究开始：%s" % technology.display_name, 2.0, &"info")
			_refresh_campaign_hud()
			return
	push_debug_event("研究失败：资源不足或研究终端忙碌")
	_play_audio_cue(&"build_failed")
	if hud and hud.has_method("show_bottom_prompt"):
		hud.call("show_bottom_prompt", "研究失败：资源不足或研究终端忙碌", 2.0, &"warning")
	_refresh_campaign_hud()

func _on_recipe_upgrade_requested(resource_id: StringName) -> void:
	if String(resource_id).is_empty() or campaign_state == null:
		return
	var current_level := _get_recipe_upgrade_level(resource_id)
	var unlocked_max_level := _get_recipe_upgrade_unlocked_max_level()
	if current_level >= RECIPE_UPGRADE_MAX_LEVEL:
		_play_audio_cue(&"build_failed")
		return
	if current_level >= unlocked_max_level:
		_play_audio_cue(&"build_failed")
		if hud and hud.has_method("show_bottom_prompt"):
			hud.call("show_bottom_prompt", "需要推进区域战果后才能继续升级。", 2.0, &"warning")
		_refresh_campaign_hud()
		return
	var inventory = _get_main_base_inventory()
	var cost := _get_recipe_upgrade_cost(resource_id, current_level)
	if inventory == null or not inventory.spend_resources(cost, "增产升级 %s Lv%d" % [_get_resource_display_name(resource_id), current_level + 1]):
		_play_audio_cue(&"build_failed")
		if hud and hud.has_method("show_bottom_prompt"):
			hud.call("show_bottom_prompt", "增产升级失败：材料不足。", 2.0, &"warning")
		_refresh_campaign_hud()
		return
	campaign_state.call("set_recipe_upgrade_level", resource_id, current_level + 1)
	_refresh_recipe_upgrade_effects()
	_play_audio_cue(&"technology_unlocked")
	push_debug_event("增产升级完成：%s Lv%d" % [_get_resource_display_name(resource_id), current_level + 1])
	if hud and hud.has_method("show_bottom_prompt"):
		hud.call("show_bottom_prompt", "增产升级完成：%s Lv%d" % [_get_resource_display_name(resource_id), current_level + 1], 2.0, &"success")
	_refresh_resource_hud()
	_refresh_campaign_hud()
	call_deferred("_refresh_operation_panel")

func _get_recipe_upgrade_hud_data() -> Dictionary:
	var entries: Array = []
	var unlocked_max_level := _get_recipe_upgrade_unlocked_max_level()
	var inventory = _get_main_base_inventory()
	for resource_id_value in RECIPE_UPGRADE_RESOURCE_ORDER:
		var resource_id := StringName(resource_id_value)
		if not _is_recipe_upgrade_resource_visible(resource_id):
			continue
		var level := _get_recipe_upgrade_level(resource_id)
		var cost := _get_recipe_upgrade_cost(resource_id, level)
		var can_upgrade: bool = (
			level < RECIPE_UPGRADE_MAX_LEVEL
			and level < unlocked_max_level
			and inventory != null
			and inventory.can_afford(cost)
		)
		var resource_def := _find_resource_def(resource_id)
		entries.append({
			"resource_id": String(resource_id),
			"display_name": _get_resource_display_name(resource_id),
			"icon_path": resource_def.icon_path if resource_def != null else "",
			"description": _get_recipe_upgrade_description(resource_id),
			"level": level,
			"max_level": RECIPE_UPGRADE_MAX_LEVEL,
			"unlocked_max_level": unlocked_max_level,
			"can_upgrade": can_upgrade,
			"status_text": _get_recipe_upgrade_status_text(level, unlocked_max_level, cost, inventory),
			"cost": cost,
			"current_recipe": _get_recipe_upgrade_preview(resource_id, level),
			"next_recipe": _get_recipe_upgrade_preview(resource_id, mini(level + 1, RECIPE_UPGRADE_MAX_LEVEL)),
		})
	return {"resources": entries}

func _is_recipe_upgrade_resource_visible(resource_id: StringName) -> bool:
	if campaign_state == null:
		return true
	if resource_id == MvpDataDefaults.RES_CONSTRUCTION_MASS:
		return true
	return campaign_state.unlocked_resources.has(resource_id)

func _get_recipe_upgrade_status_text(level: int, unlocked_max_level: int, cost: Dictionary, inventory: Variant) -> String:
	if level >= RECIPE_UPGRADE_MAX_LEVEL:
		return "已满级"
	if level >= unlocked_max_level:
		return "未解锁：继续攻占区域目标"
	if inventory == null:
		return "需要主基地库存"
	if not inventory.can_afford(cost):
		return "材料不足"
	return "可升级"

func _get_recipe_upgrade_description(resource_id: StringName) -> String:
	if resource_id == MvpDataDefaults.RES_CONSTRUCTION_MASS:
		return "重校主基地的自构筑循环，提高建设质料的被动产出。"
	if resource_id == MvpDataDefaults.RES_WATER:
		return "优化泵组节律，提高水泵的抽取效率。"
	if resource_id == MvpDataDefaults.RES_IRON_ORE or resource_id == MvpDataDefaults.RES_COPPER_ORE or resource_id == MvpDataDefaults.RES_CRYSTAL_ORE or resource_id == MvpDataDefaults.RES_COAL:
		return "改写采矿机的采样与破碎参数，提高该矿物的采集产出。"
	return "重排加工厂的作业窗口，提高该资源配方的产出；有成本配方会同步提高原料消耗。"

func _get_recipe_upgrade_unlocked_max_level() -> int:
	if campaign_state == null:
		return 0
	var level := 0
	if campaign_state.defeated_nests.has(&"enemy_nest_001") or campaign_state.key_items.has(KEY_ITEM_INITIAL_SENSOR_COIL):
		level = 2
	if campaign_state.defeated_nests.has(&"crystal_resource_outpost_001"):
		level = maxi(level, 3)
	if campaign_state.defeated_nests.has(&"armored_scavenger_command_nest_001") or campaign_state.key_items.has(MvpDataDefaults.RES_HIGH_FREQUENCY_OSCILLATOR):
		level = maxi(level, 4)
	if campaign_state.defeated_nests.has(&"wreckage_command_nest_001") or campaign_state.key_items.has(MvpDataDefaults.RES_SALVAGE_DATA_CORE):
		level = maxi(level, 5)
	return level

func _get_recipe_upgrade_cost(resource_id: StringName, current_level: int) -> Dictionary:
	if current_level >= RECIPE_UPGRADE_MAX_LEVEL:
		return {}
	var level_multiplier := pow(RECIPE_UPGRADE_NEXT_COST_MULTIPLIER, clampi(current_level, 0, RECIPE_UPGRADE_MAX_LEVEL))
	var base_cost := _get_recipe_upgrade_base_cost(resource_id)
	var result := {}
	for cost_id in base_cost.keys():
		var amount := ceili(float(base_cost[cost_id]) * level_multiplier)
		if amount > 0:
			result[StringName(str(cost_id))] = amount
	return result

func _get_recipe_upgrade_base_cost(resource_id: StringName) -> Dictionary:
	var ingredients := _get_recipe_upgrade_cost_ingredients(resource_id)
	var result := {}
	result[MvpDataDefaults.RES_CONSTRUCTION_MASS] = RECIPE_UPGRADE_BASE_RESOURCE_AMOUNT
	for ingredient_id in ingredients:
		if ingredient_id == MvpDataDefaults.RES_CONSTRUCTION_MASS:
			continue
		result[ingredient_id] = RECIPE_UPGRADE_BASE_RESOURCE_AMOUNT
	return result

func _get_recipe_upgrade_cost_ingredients(resource_id: StringName) -> Array[StringName]:
	match resource_id:
		MvpDataDefaults.RES_CONSTRUCTION_MASS:
			return [MvpDataDefaults.RES_IRON_PLATE, MvpDataDefaults.RES_COPPER_WIRE]
		MvpDataDefaults.RES_IRON_ORE:
			return [MvpDataDefaults.RES_IRON_PLATE]
		MvpDataDefaults.RES_COPPER_ORE:
			return [MvpDataDefaults.RES_COPPER_WIRE]
		MvpDataDefaults.RES_IRON_PLATE:
			return [MvpDataDefaults.RES_IRON_ORE]
		MvpDataDefaults.RES_COPPER_WIRE:
			return [MvpDataDefaults.RES_COPPER_ORE]
		MvpDataDefaults.RES_WATER:
			return [MvpDataDefaults.RES_IRON_PLATE, MvpDataDefaults.RES_COPPER_WIRE]
		MvpDataDefaults.RES_CRYSTAL_ORE:
			return [MvpDataDefaults.RES_IRON_PLATE, MvpDataDefaults.RES_COPPER_WIRE, MvpDataDefaults.RES_WATER]
		MvpDataDefaults.RES_COAL:
			return [MvpDataDefaults.RES_IRON_PLATE, MvpDataDefaults.RES_COPPER_WIRE, MvpDataDefaults.RES_WATER]
		MvpDataDefaults.RES_REINFORCED_STEEL_PLATE:
			return [MvpDataDefaults.RES_IRON_PLATE, MvpDataDefaults.RES_COAL, MvpDataDefaults.RES_WATER]
		MvpDataDefaults.RES_OPTICAL_LENS:
			return [MvpDataDefaults.RES_CRYSTAL_ORE, MvpDataDefaults.RES_WATER, MvpDataDefaults.RES_COPPER_WIRE]
		MvpDataDefaults.RES_HIGH_CAPACITY_BATTERY:
			return [MvpDataDefaults.RES_CRYSTAL_ORE, MvpDataDefaults.RES_COPPER_WIRE, MvpDataDefaults.RES_OPTICAL_LENS, MvpDataDefaults.RES_WATER]
		_:
			return _get_recipe_upgrade_recipe_ingredients(resource_id)

func _get_recipe_upgrade_recipe_ingredients(resource_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var recipe := _find_base_resource_recipe(resource_id)
	if recipe == null:
		return [MvpDataDefaults.RES_IRON_PLATE]
	for input_id in recipe.inputs.keys():
		var id := StringName(str(input_id))
		if not result.has(id) and id != MvpDataDefaults.RES_CONSTRUCTION_MASS:
			result.append(id)
		if result.size() >= 4:
			break
	if result.is_empty():
		result.append(MvpDataDefaults.RES_IRON_PLATE)
	return result

func _find_base_resource_recipe(resource_id: StringName) -> RecipeDef:
	for recipe in recipe_defs:
		if recipe.recipe_type == &"resource" and recipe.target_id == resource_id:
			return recipe
	return null

func _get_recipe_upgrade_preview(resource_id: StringName, level: int) -> Dictionary:
	level = clampi(level, 0, RECIPE_UPGRADE_MAX_LEVEL)
	var recipe := _find_base_resource_recipe(resource_id)
	if recipe != null:
		var effective := _make_effective_resource_recipe(recipe, level)
		return {
			"inputs": effective.inputs,
			"outputs": effective.outputs,
			"duration_seconds": effective.duration_seconds,
		}
	var per_minute := _get_base_passive_output_per_minute(resource_id)
	return {
		"inputs": {},
		"outputs": {resource_id: ceili(float(per_minute) * _get_recipe_output_multiplier(level))},
		"duration_seconds": 60.0,
	}

func _get_base_passive_output_per_minute(resource_id: StringName) -> int:
	if resource_id == MvpDataDefaults.RES_CONSTRUCTION_MASS:
		return 90
	if resource_id == MvpDataDefaults.RES_WATER:
		return 24
	return 30

func _get_resource_display_name(resource_id: StringName) -> String:
	var resource_def := _find_resource_def(resource_id)
	return resource_def.display_name if resource_def != null else String(resource_id)

func _find_technology_def(technology_id: StringName) -> Variant:
	for technology in technology_defs:
		if technology.id == technology_id:
			return technology
	return null

func _on_campaign_unlocks_changed() -> void:
	_refresh_build_options()
	_refresh_blueprint_library_ui()
	_refresh_campaign_hud()

func _on_campaign_key_item_added(key_item_id: StringName) -> void:
	_unlock_region_gates_for_key_item(key_item_id)
	_refresh_build_options()
	_refresh_blueprint_library_ui()
	_refresh_campaign_hud()

func _on_campaign_technology_unlocked(technology_id: StringName) -> void:
	var technology: Variant = _find_technology_def(technology_id)
	var unlock_text := _format_technology_unlocks(technology.unlocks) if technology != null else ""
	_unlock_region_gates_for_technology(technology_id)
	push_debug_event("科技解锁：%s %s" % [String(technology_id), unlock_text])
	_play_audio_cue(&"technology_unlocked")
	if hud and hud.has_method("show_bottom_prompt"):
		hud.call("show_bottom_prompt", "科技已生效：%s" % String(technology_id), 2.5, &"info")

func _on_campaign_stage_advanced(next_stage: int) -> void:
	stage_label = "阶段 %d" % next_stage
	set_current_goal("阶段 %d：继续在同一张地图扩张" % next_stage)

func _on_new_game_requested() -> void:
	if ObjectPool and ObjectPool.has_method("clear_all"):
		ObjectPool.call("clear_all")
	RobotUnit.clear_shared_rally_readiness()
	get_tree().reload_current_scene()

func _on_restart_requested() -> void:
	if ObjectPool and ObjectPool.has_method("clear_all"):
		ObjectPool.call("clear_all")
	RobotUnit.clear_shared_rally_readiness()
	get_tree().reload_current_scene()

func _get_active_unit_upgrade_ids() -> Array[StringName]:
	if campaign_state == null:
		return []
	return campaign_state.unlocked_upgrades.duplicate()

func _get_unlocked_unit_type_ids() -> Array[StringName]:
	if campaign_state == null:
		return []
	return campaign_state.unlocked_unit_types.duplicate()

func _format_technology_unlocks(unlocks: Dictionary) -> String:
	var parts: Array[String] = []
	for key in unlocks.keys():
		var values: Variant = unlocks[key]
		if typeof(values) == TYPE_ARRAY and not values.is_empty():
			parts.append("%s=%s" % [str(key), ", ".join(_variant_string_array(values))])
	if parts.is_empty():
		return ""
	return "(%s)" % " | ".join(parts)

func _variant_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result

func _string_name_array(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

func _stats_to_save_dictionary(stats: UnitStats) -> Dictionary:
	if stats == null:
		return {}
	return {
		"max_hp": stats.max_hp,
		"speed": stats.speed,
		"lifespan_seconds": stats.lifespan_seconds,
		"target_lock_seconds": stats.target_lock_seconds,
		"fire_range": stats.fire_range,
		"damage": stats.damage,
		"fire_cooldown_seconds": stats.fire_cooldown_seconds,
		"damage_type": String(stats.damage_type),
		"armor_type": String(stats.armor_type),
		"heat_capacity": stats.heat_capacity,
		"heat_per_shot": stats.heat_per_shot,
		"heat_cooling_per_second": stats.heat_cooling_per_second,
		"overheat_threshold": stats.overheat_threshold,
		"overheated_resume_threshold": stats.overheated_resume_threshold,
		"cargo_capacity": stats.cargo_capacity,
		"logic_capacity": stats.logic_capacity,
	}

func get_campaign_save_snapshot() -> Dictionary:
	var inventory = _get_main_base_inventory()
	var blueprint_snapshots: Array[Dictionary] = []
	if blueprint_library and blueprint_library.has_method("get_blueprints"):
		for blueprint in blueprint_library.call("get_blueprints"):
			blueprint_snapshots.append({
				"id": String(blueprint.id),
				"display_name": blueprint.display_name,
				"version": blueprint.version,
				"icon_path": blueprint.icon_path,
				"unit_type_id": String(blueprint.unit_type_id),
				"unit_type_display_name": blueprint.unit_type_display_name,
				"upgrade_ids": _string_name_array(blueprint.upgrade_ids),
				"upgrade_display_names": blueprint.upgrade_display_names,
				"chassis_id": String(blueprint.chassis_id),
				"chassis_display_name": blueprint.chassis_display_name,
				"chassis_icon_path": blueprint.chassis_icon_path,
				"module_ids": _string_name_array(blueprint.module_ids),
				"module_display_names": blueprint.module_display_names,
				"module_icon_paths": blueprint.module_icon_paths,
				"stats": _stats_to_save_dictionary(blueprint.stats),
				"production_recipe_id": String(blueprint.production_recipe_id),
				"production_cost": blueprint.production_cost,
				"production_time_seconds": blueprint.production_time_seconds,
				"tactical_templates": blueprint.tactical_templates,
				"embedded_rules": blueprint.embedded_rules,
				"state_flag_defaults": blueprint.state_flag_defaults,
				"default_brain_enabled": blueprint.default_brain_enabled,
			})
	return {
		"version": 1,
		"campaign": campaign_state.to_save_snapshot() if campaign_state else {},
		"inventory": inventory.get_all() if inventory else {},
		"blueprints": blueprint_snapshots,
		"buildings": _make_building_save_snapshots(),
		"enemy_buildings": _make_enemy_building_save_snapshots(),
		"units": _make_unit_save_snapshots(),
		"salvage_pickups": _make_salvage_pickup_save_snapshots(),
		"map_regions": map_region_states.duplicate(true),
		"map_region_signals": _make_region_signal_save_snapshot(),
		"map_region_gates": map_region_gate_states.duplicate(true),
		"map_enemy_spawn_tracking": true,
		"map_enemy_spawn_ids_alive": _get_alive_map_enemy_spawn_ids(),
		"runtime_profile_path": runtime_profile_path,
		"stage15_blueprint_schema_reserve": {
			"unit_type_id": true,
			"upgrade_ids": true,
			"chassis_id": true,
			"module_ids": true,
			"template_parameters": {},
		},
	}

func _on_save_game_requested() -> void:
	var snapshot := get_campaign_save_snapshot()
	var file := FileAccess.open(STAGE14_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_debug_event("存档失败：无法写入 %s" % STAGE14_SAVE_PATH)
		return
	file.store_string(JSON.stringify(snapshot, "\t"))
	push_debug_event("游戏已保存：%s" % ProjectSettings.globalize_path(STAGE14_SAVE_PATH))
	if hud and hud.has_method("show_bottom_prompt"):
		hud.call("show_bottom_prompt", "游戏已保存。", 1.8, &"success")

func _on_load_game_requested() -> void:
	if not FileAccess.file_exists(STAGE14_SAVE_PATH):
		push_debug_event("读档失败：没有找到 %s" % STAGE14_SAVE_PATH)
		if hud and hud.has_method("show_bottom_prompt"):
			hud.call("show_bottom_prompt", "没有可读取的存档。", 2.0, &"warning")
		return
	var file := FileAccess.open(STAGE14_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_debug_event("读档失败：无法打开 %s" % STAGE14_SAVE_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_debug_event("读档失败：存档不是合法对象")
		return
	_apply_campaign_save_snapshot(parsed)
	push_debug_event("游戏已读取：%s" % ProjectSettings.globalize_path(STAGE14_SAVE_PATH))
	if hud and hud.has_method("show_bottom_prompt"):
		hud.call("show_bottom_prompt", "游戏已读取。", 1.8, &"success")

func _make_building_save_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var building_layer := _get_layer("BuildingLayer")
	if building_layer == null:
		return result
	for child in building_layer.get_children():
		if child == null or not is_instance_valid(child):
			continue
		var building_def: BuildingDef = child.get("building_def")
		if building_def == null:
			continue
		var entry := {
			"building_id": String(building_def.id),
			"name": child.name,
			"grid_origin": _vector2i_to_array(child.get("grid_origin")),
			"grid_size": _vector2i_to_array(child.get("grid_size")),
			"hp": int(child.get("hp")),
		}
		if child is ProcessorBuilding:
			var recipe: RecipeDef = child.get("selected_recipe")
			entry["selected_recipe_id"] = String(recipe.id) if recipe else ""
			entry["input_cache"] = _string_key_dictionary(child.get("input_cache"))
			entry["output_cache"] = _string_key_dictionary(child.get("output_cache"))
			entry["progress_seconds"] = float(child.get("progress_seconds"))
			entry["is_paused"] = bool(child.get("is_paused"))
		elif child is MinerBuilding or child is WaterPumpBuilding:
			entry["output_cache"] = _string_key_dictionary(child.get("output_cache"))
			entry["progress_seconds"] = float(child.get("progress_seconds"))
			entry["requires_logistics_delivery"] = bool(child.get("requires_logistics_delivery"))
		elif child is ForwardSupplyPointBuilding and child.has_method("get_all_resources"):
			entry["inventory"] = _string_key_dictionary(child.call("get_all_resources"))
		elif child is RobotForgeBuilding:
			var blueprint: UnitBlueprint = child.get("blueprint")
			entry["blueprint_id"] = String(blueprint.id) if blueprint else ""
			entry["target_alive_count"] = int(child.get("target_alive_count"))
			entry["progress_seconds"] = float(child.get("progress_seconds"))
			entry["is_paused"] = bool(child.get("is_paused"))
			entry["has_rally_point"] = bool(child.get("has_rally_point"))
			entry["rally_point_cell"] = _vector2i_to_array(child.get("rally_point_cell"))
			var rally_pos: Vector2 = child.get("rally_point_position")
			entry["rally_point_position"] = [rally_pos.x, rally_pos.y]
		result.append(entry)
	return result

func _make_enemy_building_save_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for nest_id in enemy_nests_by_id.keys():
		var nest: Node = enemy_nests_by_id[nest_id]
		if nest == null or not is_instance_valid(nest):
			continue
		result.append({
			"kind": "enemy_nest",
			"name": nest.name,
			"nest_id": String(nest.get("nest_id")),
			"nest_type": String(nest.get("nest_type")),
			"grid_origin": _vector2i_to_array(nest.get("grid_origin")),
			"grid_size": _vector2i_to_array(nest.get("grid_size")),
			"hp": int(nest.get("hp")),
			"max_hp": int(nest.get("max_hp")),
			"destroyed": nest.has_method("is_alive") and nest.call("is_alive") != true,
			"time_alive_seconds": float(nest.get("time_alive_seconds")),
			"replenish_seconds_remaining": float(nest.get("replenish_seconds_remaining")),
		})
	return result

func _make_salvage_pickup_save_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pickup_id in salvage_pickups_by_id.keys():
		var pickup: Node = salvage_pickups_by_id[pickup_id]
		if pickup == null or not is_instance_valid(pickup):
			continue
		var amount := int(pickup.get("amount"))
		if amount <= 0:
			continue
		result.append({
			"id": String(pickup.get("pickup_id")),
			"resource_id": String(pickup.get("resource_id")),
			"key_item_id": String(pickup.get("key_item_id")),
			"display_name": str(pickup.get("display_name")),
			"icon_path": str(pickup.get("icon_path")),
			"grid_origin": _vector2i_to_array(pickup.get("grid_origin")),
			"grid_size": _vector2i_to_array(pickup.get("grid_size")),
			"amount": amount,
			"value": int(pickup.get("value")),
			"salvage_type": String(pickup.get("salvage_type")),
			"source_enemy": String(pickup.get("source_enemy")),
			"requires_tether": bool(pickup.get("requires_tether")),
			"turn_in_target": String(pickup.get("turn_in_target")),
			"strategic_reward": bool(pickup.get("strategic_reward")),
			"interaction_locked": bool(pickup.get("interaction_locked")),
			"lock_reason": str(pickup.get("lock_reason")),
		})
	return result

func _make_region_signal_save_snapshot() -> Dictionary:
	var result := {}
	for key in map_region_signal_cells.keys():
		var centers_value = map_region_signal_cells[key]
		if typeof(centers_value) != TYPE_ARRAY:
			continue
		var serialized_centers: Array = []
		for signal_value in centers_value:
			if typeof(signal_value) != TYPE_DICTIONARY:
				continue
			var signal_info: Dictionary = (signal_value as Dictionary).duplicate(true)
			var cell := _vector2_from_variant(signal_info.get("cell", Vector2.ZERO))
			signal_info["cell"] = [cell.x, cell.y]
			serialized_centers.append(signal_info)
		result[str(key)] = serialized_centers
	return result

func _make_unit_save_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for layer_name in ["UnitLayer", "EnemyLayer"]:
		var layer := _get_layer(layer_name)
		if layer == null:
			continue
		for child in layer.get_children():
			if child == null or not is_instance_valid(child) or not (child is RobotUnit):
				continue
			if child is CanvasItem and not (child as CanvasItem).visible:
				continue
			if child.has_method("is_alive") and child.call("is_alive") != true:
				continue
			result.append(_make_robot_save_snapshot(child as RobotUnit, layer_name))
	return result

func _make_robot_save_snapshot(robot: RobotUnit, layer_name: String) -> Dictionary:
	var position := robot.global_position
	var guard_home: Vector2 = robot.get("guard_home_position")
	var entry := {
		"kind": _get_robot_save_kind(robot),
		"name": robot.name,
		"layer": layer_name,
		"team": String(robot.get("team")),
		"display_name": str(robot.get("display_name")),
		"position": [position.x, position.y],
		"hp": int(robot.get("hp")),
		"max_hp": int(robot.get("max_hp")),
		"brain_mode": str(robot.get("brain_mode")),
		"icon_path": str(robot.get("icon_path")),
		"speed": float(robot.get("speed")),
		"lifespan_seconds": float(robot.get("lifespan_seconds")),
		"lifespan_time_left": _get_robot_lifespan_time_left(robot),
		"blueprint_id": String(robot.get("blueprint_id")),
		"blueprint_version": int(robot.get("blueprint_version")),
		"blueprint_snapshot_id": String(robot.get("blueprint_snapshot_id")),
		"chassis_id": String(robot.get("chassis_id")),
		"active_upgrade_ids": _string_name_array(robot.get("active_upgrade_ids")),
		"rally_point_position": [robot.get("rally_point_position").x, robot.get("rally_point_position").y],
		"has_rally_point": robot.get("has_rally_point") == true,
		"producer_forge_name": _get_robot_producer_forge_name(robot),
		"cargo_capacity": int(robot.get("cargo_capacity")),
		"cargo_inventory": _string_key_dictionary(robot.call("get_cargo_inventory") if robot.has_method("get_cargo_inventory") else {}),
		"patrol_points": _vector2_array_to_arrays(robot.get("patrol_points")),
		"patrol_loop": robot.get("patrol_loop") == true,
		"source_nest_id": _get_robot_source_nest_id(robot),
		"enemy_unit_type": str(robot.get("pool_name")),
		"guard_home_position": [guard_home.x, guard_home.y],
	}
	var map_spawn_id := _get_robot_map_spawn_id(robot)
	if not map_spawn_id.is_empty():
		entry["map_spawn_id"] = map_spawn_id
	if robot.has_meta("guard_slot_index"):
		entry["guard_slot_index"] = int(robot.get_meta("guard_slot_index"))
	return entry

func _get_robot_producer_forge_name(robot: RobotUnit) -> String:
	var stored_name := str(robot.get("producer_forge_name"))
	if not stored_name.is_empty():
		return stored_name
	var building_layer := _get_layer("BuildingLayer")
	if building_layer == null:
		return ""
	for child in building_layer.get_children():
		if child is RobotForgeBuilding and child.has_method("is_tracking_robot") and child.call("is_tracking_robot", robot) == true:
			return child.name
	return ""

func _get_robot_save_kind(robot: RobotUnit) -> String:
	var pool_name := str(robot.get("pool_name"))
	if pool_name == "scavenger_hound" or str(robot.get("brain_mode")) == "melee_hound":
		return "scavenger_hound"
	if pool_name == "debug_enemy_unit" or str(robot.get("brain_mode")) == "path_patrol":
		return "debug_enemy"
	return "player_robot"

func _get_robot_lifespan_time_left(robot: RobotUnit) -> float:
	var lifespan_component = robot.get("lifespan_component")
	if lifespan_component != null and lifespan_component.has_method("get_time_left"):
		return float(lifespan_component.call("get_time_left"))
	return 0.0

func _get_robot_source_nest_id(robot: RobotUnit) -> String:
	var nest = robot.get("source_nest")
	if nest != null and is_instance_valid(nest):
		return String(nest.get("nest_id"))
	return ""

func _vector2_array_to_arrays(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if value is Vector2:
			result.append([value.x, value.y])
	return result

func _vector2_list_from_arrays(values: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		result.append(_vector2_from_array(value))
	return result

func _apply_campaign_save_snapshot(snapshot: Dictionary) -> void:
	_hide_operation_panel()
	_clear_world_unit_selection()
	RobotUnit.clear_shared_rally_readiness()
	_apply_campaign_state_snapshot(snapshot.get("campaign", {}))
	if snapshot.has("map_region_gates"):
		map_region_gate_states = snapshot.get("map_region_gates", {}).duplicate(true)
		_refresh_region_gate_runtime_state()
	else:
		_sync_gate_states_from_campaign()
	_restore_blueprint_library(snapshot.get("blueprints", []))
	_clear_dynamic_units_for_load()
	_clear_dynamic_buildings_for_load()
	_prepare_map_enemy_spawn_restore_filter(
		snapshot.get("map_enemy_spawn_ids_alive", []),
		snapshot.get("map_enemy_spawn_tracking", snapshot.has("units")) == true
	)
	if snapshot.has("map_region_gates"):
		_activate_all_unlocked_region_content()
		_refresh_resource_gate_states()
	else:
		_activate_all_unlocked_region_content()
		_refresh_resource_gate_states()
	_clear_map_enemy_spawn_restore_filter()
	var building_entries: Array = snapshot.get("buildings", [])
	for entry_value in building_entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		_restore_building_from_snapshot(entry_value)
	_restore_enemy_building_states(snapshot.get("enemy_buildings", []))
	if snapshot.has("salvage_pickups"):
		_restore_salvage_pickups_from_snapshot(snapshot.get("salvage_pickups", []))
	var unit_entries: Array = snapshot.get("units", [])
	for entry_value in unit_entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		_restore_unit_from_snapshot(entry_value)
	var inventory = _get_main_base_inventory()
	if inventory and inventory.has_method("set_all"):
		inventory.call("set_all", _string_name_key_dictionary(snapshot.get("inventory", {})), "读档恢复主库存")
	map_region_states = snapshot.get("map_regions", {}).duplicate(true)
	if snapshot.has("map_region_signals"):
		map_region_signal_cells = snapshot.get("map_region_signals", {}).duplicate(true)
	else:
		_prune_region_signals_for_current_states()
	_apply_region_fog_to_grid()
	_mark_navigation_dirty()
	_refresh_build_options()
	_refresh_resource_hud()
	_refresh_campaign_hud()
	_refresh_blueprint_library_ui()

func _prepare_map_enemy_spawn_restore_filter(alive_spawn_ids: Variant, tracking_enabled: bool) -> void:
	_map_enemy_spawn_filter_active = false
	_map_enemy_spawn_ids_to_restore.clear()
	if not tracking_enabled or typeof(alive_spawn_ids) != TYPE_ARRAY:
		return
	_map_enemy_spawn_filter_active = true
	for spawn_id_value in alive_spawn_ids:
		var spawn_id := StringName(str(spawn_id_value))
		if not String(spawn_id).is_empty():
			_map_enemy_spawn_ids_to_restore[spawn_id] = true

func _clear_map_enemy_spawn_restore_filter() -> void:
	_map_enemy_spawn_filter_active = false
	_map_enemy_spawn_ids_to_restore.clear()

func _is_map_enemy_spawn_allowed(data: Dictionary) -> bool:
	if not _map_enemy_spawn_filter_active:
		return true
	var spawn_id := StringName(str(data.get("id", "")))
	if String(spawn_id).is_empty():
		return true
	return false

func _get_alive_map_enemy_spawn_ids() -> Array[String]:
	var result: Array[String] = []
	var layer := _get_layer("EnemyLayer")
	if layer == null:
		return result
	for child in layer.get_children():
		if child == null or not is_instance_valid(child) or not (child is RobotUnit):
			continue
		var robot := child as RobotUnit
		if robot.has_method("is_alive") and robot.call("is_alive") != true:
			continue
		var spawn_id := _get_robot_map_spawn_id(robot)
		if spawn_id.is_empty() or result.has(spawn_id):
			continue
		result.append(spawn_id)
	return result

func _get_robot_map_spawn_id(robot: RobotUnit) -> String:
	if robot == null or not is_instance_valid(robot):
		return ""
	if robot.has_meta("map_spawn_id"):
		return str(robot.get_meta("map_spawn_id"))
	var candidate := str(robot.name)
	return candidate if _is_known_map_enemy_spawn_id(candidate) else ""

func _is_known_map_enemy_spawn_id(spawn_id: String) -> bool:
	if spawn_id.is_empty():
		return false
	var config := MapConfigLoaderScript.load_map_config(map_config_path)
	for section in ["debug_enemies", "enemy_patrols"]:
		for value in config.get(section, []):
			if typeof(value) != TYPE_DICTIONARY:
				continue
			if str((value as Dictionary).get("id", "")) == spawn_id:
				return true
	return false

func _set_robot_map_spawn_id(robot: RobotUnit, data: Dictionary) -> void:
	if robot == null or not is_instance_valid(robot):
		return
	var spawn_id := str(data.get("id", ""))
	if spawn_id.is_empty():
		return
	robot.set_meta("map_spawn_id", spawn_id)

func _prune_region_signals_for_current_states() -> void:
	for key in map_region_signal_cells.keys():
		var state := str(map_region_states.get(key, "unknown"))
		if state != "signal" and state != "unknown":
			map_region_signal_cells.erase(key)

func _clear_dynamic_units_for_load() -> void:
	for layer_name in ["UnitLayer", "EnemyLayer"]:
		var layer := _get_layer(layer_name)
		if layer == null:
			continue
		for child in layer.get_children():
			if child == null or not is_instance_valid(child):
				continue
			if not (child is RobotUnit):
				continue
			if child is CanvasItem and not (child as CanvasItem).visible:
				continue
			layer.remove_child(child)
			child.queue_free()
	stage14_logistics_tasks_by_robot.clear()
	stage14_logistics_wait_seconds_by_key.clear()
	_clear_logistics_visuals()

func _clear_dynamic_buildings_for_load() -> void:
	var building_layer := _get_layer("BuildingLayer")
	if building_layer:
		for child in building_layer.get_children():
			building_layer.remove_child(child)
			child.queue_free()
	main_base = null
	selected_operation_building = null
	for resource_node in resource_nodes_by_id.values():
		if resource_node != null and is_instance_valid(resource_node):
			resource_node.set("bound_miner", null)
			if resource_node is CanvasItem:
				(resource_node as CanvasItem).modulate = Color.WHITE
	grid_occupancy.configure(grid_map.get("map_size_cells") if grid_map else Vector2i.ZERO)
	for nest in enemy_nests_by_id.values():
		if nest == null or not is_instance_valid(nest):
			continue
		if nest.has_method("is_alive") and not bool(nest.call("is_alive")):
			continue
		grid_occupancy.register_rect(nest.get("grid_origin"), nest.get("grid_size"), nest)
	_clear_logistics_visuals()
	stage14_logistics_tasks_by_robot.clear()
	stage14_logistics_wait_seconds_by_key.clear()
	_mark_navigation_dirty()

func _restore_salvage_pickups_from_snapshot(entries: Variant) -> void:
	if typeof(entries) != TYPE_ARRAY:
		return
	var saved_ids := {}
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var pickup_id := StringName(str(entry.get("id", "")))
		if String(pickup_id).is_empty() or int(entry.get("amount", 0)) <= 0:
			continue
		saved_ids[pickup_id] = true
		_restore_salvage_pickup_from_snapshot(entry)

	for existing_id in salvage_pickups_by_id.keys():
		if saved_ids.has(existing_id):
			continue
		var pickup: Node = salvage_pickups_by_id.get(existing_id)
		if pickup != null and is_instance_valid(pickup):
			salvage_pickups_by_cell.erase(pickup.get("grid_origin"))
			pickup.queue_free()
		salvage_pickups_by_id.erase(existing_id)

func _restore_salvage_pickup_from_snapshot(entry: Dictionary) -> void:
	var pickup_id := StringName(str(entry.get("id", "")))
	if String(pickup_id).is_empty():
		return
	var resource_id := StringName(str(entry.get("resource_id", "")))
	var resource_def := _find_resource_def(resource_id)
	if resource_def == null:
		push_warning("Cannot restore salvage pickup with unknown resource id: %s" % String(resource_id))
		return
	var pickup: Node = salvage_pickups_by_id.get(pickup_id, null)
	if pickup == null or not is_instance_valid(pickup):
		pickup = SalvagePickupScene.instantiate()
		var layer := _get_layer("ResourceLayer")
		(layer if layer else self).add_child(pickup)
		if pickup.has_signal("depleted"):
			pickup.connect("depleted", Callable(self, "_on_salvage_pickup_depleted"))
	else:
		salvage_pickups_by_cell.erase(pickup.get("grid_origin"))
	pickup.call("setup", entry, resource_def, _get_grid_cell_size())
	if pickup.has_method("set_interaction_locked"):
		if entry.has("interaction_locked"):
			pickup.call("set_interaction_locked", bool(entry.get("interaction_locked")), str(entry.get("lock_reason", "")))
		else:
			_apply_salvage_gate_state(pickup, entry)
	var origin: Vector2i = pickup.get("grid_origin")
	salvage_pickups_by_id[pickup_id] = pickup
	salvage_pickups_by_cell[origin] = pickup

func _restore_unit_from_snapshot(entry: Dictionary) -> void:
	var kind := str(entry.get("kind", "player_robot"))
	var layer_name := str(entry.get("layer", "EnemyLayer" if kind != "player_robot" else "UnitLayer"))
	var layer := _get_layer(layer_name)
	if layer == null:
		layer = self
	var robot: RobotUnit = null
	match kind:
		"scavenger_hound":
			robot = _restore_scavenger_hound_from_snapshot(entry, layer)
		"debug_enemy":
			robot = _restore_debug_enemy_from_snapshot(entry, layer)
		_:
			robot = _restore_player_robot_from_snapshot(entry, layer)
	if robot == null:
		return
	_apply_robot_common_save_state(robot, entry)

func _restore_player_robot_from_snapshot(entry: Dictionary, layer: Node) -> RobotUnit:
	var blueprint_id := StringName(str(entry.get("blueprint_id", "")))
	var producer_forge := _find_forge_by_name(str(entry.get("producer_forge_name", "")))
	var blueprint: UnitBlueprint = producer_forge.get("blueprint") if producer_forge != null else null
	if blueprint == null:
		blueprint = blueprint_library.get_blueprint(blueprint_id) if blueprint_library else null
	if blueprint == null and basic_rifle_blueprint != null:
		blueprint = basic_rifle_blueprint
	if blueprint == null:
		return null
	var robot := RobotScene.instantiate() as RobotUnit
	layer.add_child(robot)
	robot.name = str(entry.get("name", IdProvider.next_id(&"robot")))
	robot.set("team", "Team_A")
	if robot.has_method("setup_from_blueprint"):
		robot.call(
			"setup_from_blueprint",
			blueprint,
			_vector2_from_array(entry.get("rally_point_position", [0.0, 0.0])),
			entry.get("has_rally_point", false) == true
		)
	if robot.has_signal("robot_lost") and not robot.is_connected("robot_lost", Callable(self, "_on_robot_lost_for_blueprint_cleanup")):
		robot.connect("robot_lost", Callable(self, "_on_robot_lost_for_blueprint_cleanup"))
	var forge := producer_forge if producer_forge != null else _find_robot_restore_forge(entry, blueprint)
	if forge != null and forge.has_method("register_robot"):
		forge.call("register_robot", robot)
		robot.set("producer_forge_name", forge.name)
	return robot

func _restore_scavenger_hound_from_snapshot(entry: Dictionary, layer: Node) -> RobotUnit:
	var nest := _find_enemy_nest_by_id(StringName(str(entry.get("source_nest_id", ""))))
	var guard_type := StringName("scavenger_hound")
	if nest != null and is_instance_valid(nest):
		guard_type = StringName(str(nest.get("guard_unit_type")))
	elif not str(entry.get("enemy_unit_type", "")).is_empty():
		guard_type = StringName(str(entry.get("enemy_unit_type", "")))
	var guard_config := EnemyConfigLoaderScript.get_type(enemy_config, "unit_types", guard_type)
	if guard_config.is_empty():
		guard_config = EnemyConfigLoaderScript.get_type(enemy_config, "unit_types", &"scavenger_hound")
	var robot := ScavengerHoundScene.instantiate() as RobotUnit
	layer.add_child(robot)
	robot.name = str(entry.get("name", IdProvider.next_id(&"scavenger_hound")))
	robot.global_position = _vector2_from_array(entry.get("position", [0.0, 0.0]))
	robot.call("setup_scavenger_hound", guard_config, nest)
	if robot.has_signal("robot_lost") and not robot.is_connected("robot_lost", Callable(self, "_on_enemy_hound_lost")):
		robot.connect("robot_lost", Callable(self, "_on_enemy_hound_lost"))
	var guard_slot_index := int(entry.get("guard_slot_index", -1))
	if nest != null and is_instance_valid(nest):
		if nest.has_method("register_guard_at_slot"):
			nest.call("register_guard_at_slot", robot, guard_slot_index)
		elif nest.has_method("register_guard"):
			nest.call("register_guard", robot)
	return robot

func _restore_debug_enemy_from_snapshot(entry: Dictionary, layer: Node) -> RobotUnit:
	var path_points := _vector2_list_from_arrays(entry.get("patrol_points", []))
	if path_points.is_empty():
		path_points.append(_vector2_from_array(entry.get("position", [0.0, 0.0])))
	var robot := DebugEnemyScene.instantiate() as RobotUnit
	layer.add_child(robot)
	robot.name = str(entry.get("name", IdProvider.next_id(&"debug_enemy")))
	robot.global_position = _vector2_from_array(entry.get("position", [0.0, 0.0]))
	var debug_config := EnemyConfigLoaderScript.get_type(enemy_config, "unit_types", &"debug_enemy")
	robot.call("setup_debug_enemy", str(entry.get("display_name", "调试靶机")), path_points, entry.get("patrol_loop", true) == true, debug_config)
	if robot.has_signal("robot_lost") and not robot.is_connected("robot_lost", Callable(self, "_on_enemy_hound_lost")):
		robot.connect("robot_lost", Callable(self, "_on_enemy_hound_lost"))
	return robot

func _apply_robot_common_save_state(robot: RobotUnit, entry: Dictionary) -> void:
	robot.global_position = _vector2_from_array(entry.get("position", [robot.global_position.x, robot.global_position.y]))
	robot.set("hp", clampi(int(entry.get("hp", robot.get("hp"))), 1, int(robot.get("max_hp"))))
	var saved_forge_name := str(entry.get("producer_forge_name", ""))
	if not saved_forge_name.is_empty():
		robot.set("producer_forge_name", saved_forge_name)
	var map_spawn_id := str(entry.get("map_spawn_id", ""))
	if not map_spawn_id.is_empty():
		robot.set_meta("map_spawn_id", map_spawn_id)
	if entry.has("cargo_inventory"):
		robot.set("cargo_inventory", _string_name_key_dictionary(entry.get("cargo_inventory", {})))
	if entry.has("cargo_capacity"):
		robot.set("cargo_capacity", int(entry.get("cargo_capacity", robot.get("cargo_capacity"))))
	if str(entry.get("kind", "")) == "scavenger_hound" and entry.has("guard_home_position"):
		robot.set("guard_home_position", _vector2_from_array(entry.get("guard_home_position", [robot.global_position.x, robot.global_position.y])))
	var health_component = robot.get("health_component")
	if health_component != null:
		health_component.set("hp", int(robot.get("hp")))
		health_component.set("max_hp", int(robot.get("max_hp")))
		health_component.set("_dead", false)
	var lifespan_component = robot.get("lifespan_component")
	var time_left := float(entry.get("lifespan_time_left", 0.0))
	if lifespan_component != null and time_left > 0.0 and lifespan_component.has_method("restore_time_left"):
		lifespan_component.call("restore_time_left", time_left)
	if robot.has_method("clear_logistics_task"):
		robot.call("clear_logistics_task")

func _find_robot_restore_forge(entry: Dictionary, blueprint: UnitBlueprint) -> Node:
	var preferred_name := str(entry.get("producer_forge_name", ""))
	var building_layer := _get_layer("BuildingLayer")
	if building_layer == null:
		return null
	if not preferred_name.is_empty():
		var preferred := _find_forge_by_name(preferred_name)
		if preferred != null:
			return preferred
	for child in building_layer.get_children():
		if not (child is RobotForgeBuilding):
			continue
		var forge_blueprint: UnitBlueprint = child.get("blueprint")
		if forge_blueprint != null and blueprint != null and forge_blueprint.get_snapshot_key() == blueprint.get_snapshot_key():
			return child
	return null

func _find_forge_by_name(forge_name: String) -> Node:
	if forge_name.is_empty():
		return null
	var building_layer := _get_layer("BuildingLayer")
	if building_layer == null:
		return null
	for child in building_layer.get_children():
		if child is RobotForgeBuilding and child.name == forge_name:
			return child
	return null

func _find_enemy_nest_by_id(nest_id: StringName) -> Node:
	if String(nest_id).is_empty():
		return null
	return enemy_nests_by_id.get(nest_id, null)

func _restore_building_from_snapshot(entry: Dictionary) -> void:
	var building_def := _find_building_def(StringName(str(entry.get("building_id", ""))))
	if building_def == null:
		return
	var origin := _vector2i_from_array(entry.get("grid_origin", [0, 0]))
	var is_main_base := _is_main_base_def(building_def)
	var building := _spawn_building(building_def, origin, is_main_base)
	if building == null:
		return
	var saved_name := str(entry.get("name", ""))
	if not saved_name.is_empty():
		building.name = saved_name
	if is_main_base:
		_setup_main_base_after_placement(building)
	_configure_building_runtime(building, building_def, origin)
	if entry.has("hp"):
		building.set("hp", int(entry.get("hp", building.get("hp"))))
	_apply_building_specific_save_state(building, building_def, entry)

func _apply_building_specific_save_state(building: Node, building_def: BuildingDef, entry: Dictionary) -> void:
	if building is ProcessorBuilding:
		var recipe_id := StringName(str(entry.get("selected_recipe_id", "")))
		if not String(recipe_id).is_empty() and building.has_method("set_recipe"):
			building.call("set_recipe", recipe_id)
		building.set("input_cache", _string_name_key_dictionary(entry.get("input_cache", {})))
		building.set("output_cache", _string_name_key_dictionary(entry.get("output_cache", {})))
		building.set("progress_seconds", float(entry.get("progress_seconds", 0.0)))
		if building.has_method("set_paused"):
			building.call("set_paused", bool(entry.get("is_paused", false)))
	elif building is MinerBuilding or building is WaterPumpBuilding:
		building.set("output_cache", _string_name_key_dictionary(entry.get("output_cache", {})))
		building.set("progress_seconds", float(entry.get("progress_seconds", 0.0)))
		if entry.has("requires_logistics_delivery"):
			building.set("requires_logistics_delivery", bool(entry.get("requires_logistics_delivery", false)))
	elif building is ForwardSupplyPointBuilding and building.get("inventory") != null:
		var supply_inventory = building.get("inventory")
		if supply_inventory != null and supply_inventory.has_method("set_all"):
			supply_inventory.call("set_all", _string_name_key_dictionary(entry.get("inventory", {})), "读档恢复补给点")
	elif building is RobotForgeBuilding:
		var blueprint := blueprint_library.get_blueprint(StringName(str(entry.get("blueprint_id", "")))) if blueprint_library else null
		if blueprint and building.has_method("set_blueprint_snapshot"):
			building.call("set_blueprint_snapshot", _create_blueprint_snapshot(blueprint))
		building.set("target_alive_count", int(entry.get("target_alive_count", building.get("target_alive_count"))))
		building.set("progress_seconds", float(entry.get("progress_seconds", 0.0)))
		if building.has_method("set_paused"):
			building.call("set_paused", bool(entry.get("is_paused", false)))
		if bool(entry.get("has_rally_point", false)) and building.has_method("set_rally_point"):
			var cell := _vector2i_from_array(entry.get("rally_point_cell", [0, 0]))
			var pos := _vector2_from_array(entry.get("rally_point_position", [0.0, 0.0]))
			building.call("set_rally_point", cell, pos)

func _restore_enemy_building_states(entries: Variant) -> void:
	if typeof(entries) != TYPE_ARRAY:
		return
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("kind", "")) != "enemy_nest":
			continue
		var nest := _find_enemy_nest_by_id(StringName(str(entry.get("nest_id", ""))))
		if nest == null or not is_instance_valid(nest):
			continue
		var saved_name := str(entry.get("name", ""))
		if not saved_name.is_empty():
			nest.name = saved_name
		var destroyed: bool = entry.get("destroyed", false) == true
		if nest.has_method("restore_health_state"):
			nest.call("restore_health_state", int(entry.get("hp", nest.get("hp"))), destroyed)
		nest.set("time_alive_seconds", float(entry.get("time_alive_seconds", nest.get("time_alive_seconds"))))
		nest.set("replenish_seconds_remaining", float(entry.get("replenish_seconds_remaining", nest.get("replenish_seconds_remaining"))))
		var origin: Vector2i = nest.get("grid_origin")
		var size: Vector2i = nest.get("grid_size")
		grid_occupancy.clear_rect(origin, size)
		if not destroyed:
			grid_occupancy.register_rect(origin, size, nest)
	_mark_navigation_dirty()

func _apply_campaign_state_snapshot(data: Dictionary) -> void:
	if campaign_state == null:
		return
	campaign_state.current_stage = int(data.get("current_stage", campaign_state.current_stage))
	campaign_state.defeated_nests = _string_name_list_from_variant(data.get("defeated_nests", []))
	campaign_state.key_items = _string_name_list_from_variant(data.get("key_items", []))
	campaign_state.unlocked_technologies = _string_name_list_from_variant(data.get("unlocked_technologies", []))
	campaign_state.unlocked_resources = _string_name_list_from_variant(data.get("unlocked_resources", []))
	campaign_state.unlocked_buildings = _string_name_list_from_variant(data.get("unlocked_buildings", []))
	campaign_state.unlocked_unit_types = _string_name_list_from_variant(data.get("unlocked_unit_types", campaign_state.unlocked_unit_types))
	campaign_state.unlocked_chassis = _string_name_list_from_variant(data.get("unlocked_chassis", []))
	campaign_state.unlocked_weapons = _string_name_list_from_variant(data.get("unlocked_weapons", []))
	campaign_state.unlocked_modules = _string_name_list_from_variant(data.get("unlocked_modules", []))
	campaign_state.unlocked_templates = _string_name_list_from_variant(data.get("unlocked_templates", []))
	campaign_state.unlocked_conditions = _string_name_list_from_variant(data.get("unlocked_conditions", []))
	campaign_state.unlocked_actions = _string_name_list_from_variant(data.get("unlocked_actions", []))
	campaign_state.unlocked_upgrades = _string_name_list_from_variant(data.get("unlocked_upgrades", []))
	campaign_state.recipe_upgrade_levels = _string_name_key_dictionary(data.get("recipe_upgrade_levels", {}))
	campaign_state.reconcile_unlocked_technology_unlocks(technology_defs)

func _restore_blueprint_library(entries: Array) -> void:
	blueprint_library = BlueprintLibraryScript.new()
	basic_rifle_blueprint = null
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var blueprint := _blueprint_from_save_entry(entry_value)
		if blueprint == null:
			continue
		if blueprint.id == MvpDataDefaults.UNIT_BASIC_RIFLE_ROBOT:
			basic_rifle_blueprint = blueprint
		blueprint_library.add_blueprint(blueprint)
	if basic_rifle_blueprint == null:
		basic_rifle_blueprint = MvpDataDefaults.create_basic_rifle_blueprint()
		blueprint_library.add_blueprint(basic_rifle_blueprint)

func _blueprint_from_save_entry(entry: Dictionary) -> UnitBlueprint:
	var blueprint := UnitBlueprint.new()
	blueprint.id = StringName(str(entry.get("id", "")))
	if String(blueprint.id).is_empty():
		return null
	blueprint.display_name = str(entry.get("display_name", String(blueprint.id)))
	blueprint.version = int(entry.get("version", 1))
	blueprint.icon_path = str(entry.get("icon_path", ""))
	blueprint.unit_type_id = StringName(str(entry.get("unit_type_id", blueprint.id)))
	blueprint.unit_type_display_name = str(entry.get("unit_type_display_name", ""))
	blueprint.upgrade_ids = _string_name_list_from_variant(entry.get("upgrade_ids", []))
	blueprint.upgrade_display_names = _string_list_from_variant(entry.get("upgrade_display_names", []))
	blueprint.chassis_id = StringName(str(entry.get("chassis_id", "light_chassis")))
	blueprint.chassis_display_name = str(entry.get("chassis_display_name", "轻型底盘"))
	blueprint.chassis_icon_path = str(entry.get("chassis_icon_path", ""))
	blueprint.module_ids = _string_name_list_from_variant(entry.get("module_ids", []))
	blueprint.module_display_names = _string_list_from_variant(entry.get("module_display_names", []))
	blueprint.module_icon_paths = _string_list_from_variant(entry.get("module_icon_paths", []))
	blueprint.production_recipe_id = StringName(str(entry.get("production_recipe_id", "")))
	blueprint.production_cost = _string_name_key_dictionary(entry.get("production_cost", {}))
	blueprint.production_time_seconds = float(entry.get("production_time_seconds", 12.0))
	blueprint.tactical_templates = _dictionary_array_from_variant(entry.get("tactical_templates", []))
	blueprint.embedded_rules = _dictionary_array_from_variant(entry.get("embedded_rules", []))
	blueprint.state_flag_defaults = entry.get("state_flag_defaults", {}).duplicate(true)
	if not blueprint.tactical_templates.is_empty():
		var compiled: Dictionary = TacticalTemplateCompilerScript.compile_templates(blueprint.tactical_templates)
		blueprint.embedded_rules = compiled.get("rules", []).duplicate(true)
		blueprint.state_flag_defaults = compiled.get("state_flag_defaults", {}).duplicate(true)
	blueprint.default_brain_enabled = bool(entry.get("default_brain_enabled", true))
	blueprint.stats = _stats_from_save_dictionary(entry.get("stats", {}), _find_blueprint_stats_fallback(blueprint.id, blueprint.unit_type_id))
	if blueprint.stats == null:
		UnitDesignConfigLoaderScript.apply_design_to_blueprint(blueprint, blueprint.unit_type_id, blueprint.upgrade_ids, MvpDataDefaults.create_recipe_defs())
	if blueprint.stats == null:
		blueprint.stats = _find_blueprint_stats_fallback(blueprint.id, blueprint.unit_type_id)
	return blueprint

func _find_blueprint_stats_fallback(blueprint_id: StringName, unit_type_id: StringName = &"") -> UnitStats:
	for blueprint in MvpDataDefaults.create_unit_blueprints():
		if blueprint == null or blueprint.stats == null:
			continue
		if blueprint.id == blueprint_id or (not String(unit_type_id).is_empty() and blueprint.unit_type_id == unit_type_id):
			return blueprint.stats.duplicate(true)
	return UnitStats.new()

func _stats_from_save_dictionary(data: Variant, fallback: UnitStats = null) -> UnitStats:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	if (data as Dictionary).is_empty():
		return null
	var stats := fallback.duplicate(true) if fallback != null else UnitStats.new()
	stats.max_hp = int(data.get("max_hp", stats.max_hp))
	stats.speed = float(data.get("speed", stats.speed))
	stats.lifespan_seconds = float(data.get("lifespan_seconds", stats.lifespan_seconds))
	stats.target_lock_seconds = float(data.get("target_lock_seconds", stats.target_lock_seconds))
	stats.fire_range = float(data.get("fire_range", stats.fire_range))
	stats.damage = int(data.get("damage", stats.damage))
	stats.fire_cooldown_seconds = float(data.get("fire_cooldown_seconds", stats.fire_cooldown_seconds))
	stats.damage_type = StringName(str(data.get("damage_type", stats.damage_type)))
	stats.armor_type = StringName(str(data.get("armor_type", stats.armor_type)))
	stats.heat_capacity = float(data.get("heat_capacity", stats.heat_capacity))
	stats.heat_per_shot = float(data.get("heat_per_shot", stats.heat_per_shot))
	stats.heat_cooling_per_second = float(data.get("heat_cooling_per_second", stats.heat_cooling_per_second))
	stats.overheat_threshold = float(data.get("overheat_threshold", stats.overheat_threshold))
	stats.overheated_resume_threshold = float(data.get("overheated_resume_threshold", stats.overheated_resume_threshold))
	stats.cargo_capacity = int(data.get("cargo_capacity", stats.cargo_capacity))
	stats.logic_capacity = int(data.get("logic_capacity", stats.logic_capacity))
	return stats

func _vector2i_to_array(value: Vector2i) -> Array:
	return [value.x, value.y]

func _vector2i_from_array(value: Variant) -> Vector2i:
	if typeof(value) != TYPE_ARRAY or value.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(value[0]), int(value[1]))

func _vector2_from_array(value: Variant) -> Vector2:
	if typeof(value) != TYPE_ARRAY or value.size() < 2:
		return Vector2.ZERO
	return Vector2(float(value[0]), float(value[1]))

func _string_key_dictionary(data: Variant) -> Dictionary:
	var result := {}
	if typeof(data) != TYPE_DICTIONARY:
		return result
	for key in data.keys():
		result[str(key)] = data[key]
	return result

func _string_name_key_dictionary(data: Variant) -> Dictionary:
	var result := {}
	if typeof(data) != TYPE_DICTIONARY:
		return result
	for key in data.keys():
		result[StringName(str(key))] = data[key]
	return result

func _string_name_list_from_variant(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		result.append(StringName(str(value)))
	return result

func _dictionary_array_from_variant(values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			result.append((value as Dictionary).duplicate(true))
	return result

func _string_list_from_variant(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		result.append(str(value))
	return result

func get_region_info_for_cell(cell: Vector2i) -> Dictionary:
	if grid_map and grid_map.has_method("get_area_info_for_cell"):
		return _merge_region_metadata(grid_map.call("get_area_info_for_cell", cell))
	if grid_map and grid_map.has_method("get_painted_region_info"):
		return _merge_region_metadata(grid_map.call("get_painted_region_info", cell))
	return {}

func get_region_state_for_cell(cell: Vector2i) -> String:
	var region := _region_for_cell(cell, FOG_REGION_SIZE_CELLS)
	return str(map_region_states.get(_region_key(region), "unknown"))

func get_navigation_waypoint(origin_world: Vector2, target_world: Vector2) -> Vector2:
	var id_path := _get_navigation_id_path_for_world(origin_world, target_world)
	if id_path.size() <= 1:
		return origin_world
	return _get_navigation_lookahead_point(origin_world, id_path)

func get_navigation_waypoint_to_node(origin_world: Vector2, target_node: Node) -> Vector2:
	var id_path := _get_navigation_id_path_for_node(origin_world, target_node)
	if id_path.size() <= 1:
		return origin_world
	return _get_navigation_lookahead_point(origin_world, id_path)

func get_navigation_path_points(origin_world: Vector2, target_world: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(origin_world)
	var id_path := _get_navigation_id_path_for_world(origin_world, target_world)
	if id_path.size() <= 1:
		return points
	for index in range(1, id_path.size()):
		points.append(grid_map.call("grid_to_world", id_path[index]))
	return points

func get_navigation_path_points_to_node(origin_world: Vector2, target_node: Node) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(origin_world)
	var id_path := _get_navigation_id_path_for_node(origin_world, target_node)
	if id_path.size() <= 1:
		return points
	for index in range(1, id_path.size()):
		points.append(grid_map.call("grid_to_world", id_path[index]))
	return points

func has_navigation_path_to_world(origin_world: Vector2, target_world: Vector2) -> bool:
	if grid_map == null:
		return false
	var start_cell: Vector2i = grid_map.call("world_to_grid", origin_world)
	var target_cell: Vector2i = grid_map.call("world_to_grid", target_world)
	var cache_key := _navigation_reachability_key("world", start_cell, target_cell, 0)
	var cached: Variant = _get_navigation_reachability_cache(cache_key)
	if cached != null:
		return bool(cached)
	var reachable := not _get_navigation_id_path_for_world(origin_world, target_world).is_empty()
	_store_navigation_reachability_cache(cache_key, reachable)
	return reachable

func has_navigation_path_to_node(origin_world: Vector2, target_node: Node) -> bool:
	if grid_map == null or target_node == null or not is_instance_valid(target_node):
		return false
	var start_cell: Vector2i = grid_map.call("world_to_grid", origin_world)
	var target_cell: Vector2i = grid_map.call("world_to_grid", _get_logistics_node_position(target_node))
	var target_instance_id := int(target_node.get_instance_id())
	var cache_key := _navigation_reachability_key("node", start_cell, target_cell, target_instance_id)
	var cached: Variant = _get_navigation_reachability_cache(cache_key)
	if cached != null:
		return bool(cached)
	var reachable := not _get_navigation_id_path_for_node(origin_world, target_node).is_empty()
	_store_navigation_reachability_cache(cache_key, reachable)
	return reachable

func _navigation_reachability_key(kind: String, start_cell: Vector2i, target_cell: Vector2i, target_instance_id: int) -> String:
	return "%s:%s:%s,%s:%s,%s:%s" % [
		_navigation_version,
		kind,
		start_cell.x,
		start_cell.y,
		target_cell.x,
		target_cell.y,
		target_instance_id,
	]

func _get_navigation_reachability_cache(cache_key: String) -> Variant:
	var cached: Dictionary = _navigation_reachability_cache.get(cache_key, {})
	if cached.is_empty():
		return null
	if Time.get_ticks_msec() - int(cached.get("time", 0)) > NAVIGATION_REACHABILITY_CACHE_MSEC:
		_navigation_reachability_cache.erase(cache_key)
		return null
	return bool(cached.get("reachable", false))

func _store_navigation_reachability_cache(cache_key: String, reachable: bool) -> void:
	_navigation_reachability_cache[cache_key] = {
		"time": Time.get_ticks_msec(),
		"reachable": reachable,
	}
	if _navigation_reachability_cache.size() > 512:
		_navigation_reachability_cache.clear()

func _get_navigation_id_path_for_world(origin_world: Vector2, target_world: Vector2) -> Array[Vector2i]:
	if grid_map == null:
		return []
	_ensure_navigation_grid()
	if _navigation_grid == null:
		return []
	var start_cell: Vector2i = grid_map.call("world_to_grid", origin_world)
	var target_cell: Vector2i = grid_map.call("world_to_grid", target_world)
	if grid_map.call("is_cell_in_bounds", start_cell) != true or grid_map.call("is_cell_in_bounds", target_cell) != true:
		return []
	var start_was_solid := _navigation_grid.is_point_solid(start_cell)
	_navigation_grid.set_point_solid(start_cell, false)
	var target_candidates: Array[Vector2i] = []
	if _navigation_grid.is_point_solid(target_cell):
		target_candidates = _get_navigation_adjacent_candidates(start_cell, target_cell)
	else:
		target_candidates.append(target_cell)
	var id_path := _find_navigation_id_path(start_cell, target_candidates, target_cell)
	_navigation_grid.set_point_solid(start_cell, start_was_solid)
	return id_path

func _get_navigation_id_path_for_node(origin_world: Vector2, target_node: Node) -> Array[Vector2i]:
	if grid_map == null or target_node == null or not is_instance_valid(target_node):
		return []
	_ensure_navigation_grid()
	if _navigation_grid == null:
		return []
	var start_cell: Vector2i = grid_map.call("world_to_grid", origin_world)
	if grid_map.call("is_cell_in_bounds", start_cell) != true:
		return []
	var target_cell: Vector2i = grid_map.call("world_to_grid", _get_logistics_node_position(target_node))
	var target_candidates := _get_navigation_node_interaction_candidates(start_cell, target_node)
	if target_candidates.is_empty() and grid_map.call("is_cell_in_bounds", target_cell) == true and not _navigation_grid.is_point_solid(target_cell):
		target_candidates.append(target_cell)
	var start_was_solid := _navigation_grid.is_point_solid(start_cell)
	_navigation_grid.set_point_solid(start_cell, false)
	var id_path := _find_navigation_id_path(start_cell, target_candidates, target_cell)
	_navigation_grid.set_point_solid(start_cell, start_was_solid)
	return id_path

func _find_navigation_id_path(start_cell: Vector2i, candidates: Array[Vector2i], target_cell: Vector2i) -> Array[Vector2i]:
	var best_path: Array[Vector2i] = []
	var best_score := INF
	for candidate in candidates:
		if _navigation_grid.is_point_solid(candidate):
			continue
		var candidate_path: Array[Vector2i] = _navigation_grid.get_id_path(start_cell, candidate)
		if candidate_path.is_empty():
			continue
		var score := float(candidate_path.size()) + Vector2(candidate).distance_to(Vector2(target_cell)) * 0.01
		if score < best_score:
			best_score = score
			best_path = candidate_path
	return best_path

func _get_navigation_node_interaction_candidates(start_cell: Vector2i, target_node: Node) -> Array[Vector2i]:
	if target_node is CharacterBody2D:
		var moving_target_cell: Vector2i = grid_map.call("world_to_grid", (target_node as CharacterBody2D).global_position)
		if grid_map.call("is_cell_in_bounds", moving_target_cell) == true and not _navigation_grid.is_point_solid(moving_target_cell):
			var moving_target_candidates: Array[Vector2i] = [moving_target_cell]
			return moving_target_candidates
		return _get_navigation_adjacent_candidates(start_cell, moving_target_cell)
	var origin_value = target_node.get("grid_origin")
	var size_value = target_node.get("grid_size")
	if typeof(origin_value) != TYPE_VECTOR2I or typeof(size_value) != TYPE_VECTOR2I:
		var target_cell: Vector2i = grid_map.call("world_to_grid", _get_logistics_node_position(target_node))
		if grid_map.call("is_cell_in_bounds", target_cell) == true and not _navigation_grid.is_point_solid(target_cell):
			var direct_candidates: Array[Vector2i] = [target_cell]
			return direct_candidates
		return _get_navigation_adjacent_candidates(start_cell, target_cell)
	var origin: Vector2i = origin_value
	var size: Vector2i = size_value
	var result: Array[Vector2i] = []
	var seen := {}
	for x in range(origin.x - 1, origin.x + size.x + 1):
		for y in range(origin.y - 1, origin.y + size.y + 1):
			if x >= origin.x and x < origin.x + size.x and y >= origin.y and y < origin.y + size.y:
				continue
			var cell := Vector2i(x, y)
			if grid_map.call("is_cell_in_bounds", cell) != true:
				continue
			var key := "%d,%d" % [cell.x, cell.y]
			if seen.has(key):
				continue
			seen[key] = true
			result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var dist_a := Vector2(a).distance_to(Vector2(start_cell))
		var dist_b := Vector2(b).distance_to(Vector2(start_cell))
		return dist_a < dist_b
	)
	return result

func _get_navigation_adjacent_candidates(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen := {}
	for radius in range(0, 2):
		for x in range(target_cell.x - radius, target_cell.x + radius + 1):
			for y in range(target_cell.y - radius, target_cell.y + radius + 1):
				if radius > 0 and x > target_cell.x - radius and x < target_cell.x + radius and y > target_cell.y - radius and y < target_cell.y + radius:
					continue
				var cell := Vector2i(x, y)
				if grid_map.call("is_cell_in_bounds", cell) != true:
					continue
				var key := "%d,%d" % [cell.x, cell.y]
				if seen.has(key):
					continue
				seen[key] = true
				result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var dist_a := Vector2(a).distance_to(Vector2(target_cell))
		var dist_b := Vector2(b).distance_to(Vector2(target_cell))
		if is_equal_approx(dist_a, dist_b):
			return Vector2(a).distance_to(Vector2(start_cell)) < Vector2(b).distance_to(Vector2(start_cell))
		return dist_a < dist_b
	)
	return result

func _get_navigation_lookahead_point(origin_world: Vector2, id_path: Array[Vector2i]) -> Vector2:
	var cell_size := float(_get_grid_cell_size())
	var lookahead_distance := cell_size * 0.68
	var fallback: Vector2 = grid_map.call("grid_to_world", id_path[id_path.size() - 1])
	for index in range(1, id_path.size()):
		var point: Vector2 = grid_map.call("grid_to_world", id_path[index])
		fallback = point
		if origin_world.distance_to(point) >= lookahead_distance:
			return point
	return fallback

func _ensure_navigation_grid() -> void:
	if grid_map == null:
		return
	if _navigation_grid != null and not _navigation_dirty:
		return
	var map_size: Vector2i = grid_map.get("map_size_cells")
	_navigation_grid = AStarGrid2D.new()
	_navigation_grid.region = Rect2i(Vector2i.ZERO, map_size)
	_navigation_grid.cell_size = Vector2.ONE
	_navigation_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_navigation_grid.update()
	for y in range(map_size.y):
		for x in range(map_size.x):
			var cell := Vector2i(x, y)
			if _is_navigation_cell_blocked(cell):
				_navigation_grid.set_point_solid(cell, true)
	_navigation_dirty = false

func _is_navigation_cell_blocked(cell: Vector2i) -> bool:
	if grid_map == null:
		return true
	if grid_map.call("is_cell_in_bounds", cell) != true:
		return true
	if map_locked_gate_cells.has(cell):
		return true
	if grid_map.has_method("is_cell_blocked_by_semantic_tile") and grid_map.call("is_cell_blocked_by_semantic_tile", cell) == true:
		return true
	return grid_occupancy.get_at(cell) != null

func _mark_navigation_dirty() -> void:
	_navigation_dirty = true
	_navigation_version += 1
	_navigation_reachability_cache.clear()

func is_navigation_world_position_walkable(world_position: Vector2) -> bool:
	if grid_map == null:
		return false
	_ensure_navigation_grid()
	if _navigation_grid == null:
		return false
	var cell: Vector2i = grid_map.call("world_to_grid", world_position)
	if grid_map.call("is_cell_in_bounds", cell) != true:
		return false
	return not _navigation_grid.is_point_solid(cell)

func get_navigation_cell_for_world(world_position: Vector2) -> Vector2i:
	if grid_map == null:
		return Vector2i(-1, -1)
	return grid_map.call("world_to_grid", world_position)

func _on_build_mode_requested(building_id: StringName) -> void:
	var building_def := _find_building_def(building_id)
	if building_def == null:
		push_debug_event("未知建筑：%s" % String(building_id))
		return
	_reset_camera_drag_state()
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
	if _is_pointer_over_hud():
		placement_ghost.visible = false
		if hud and hud.has_method("hide_build_cost_preview"):
			hud.call("hide_build_cost_preview")
		last_hover_cell = Vector2i(-9999, -9999)
		return
	placement_ghost.visible = true
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
	if _is_pointer_over_hud():
		return
	var cell := _get_mouse_grid_cell()
	if not _can_place_building(active_building_def, cell):
		push_debug_event("建造失败：%s，%s" % [active_building_def.display_name, _get_place_block_reason(active_building_def, cell)])
		_play_audio_cue(&"build_failed")
		_update_placement_preview()
		return
	var is_main_base := _is_main_base_def(active_building_def)
	var inventory = _get_main_base_inventory()
	if not is_main_base:
		if inventory == null:
			push_debug_event("建造失败：请先放置主基地")
			_play_audio_cue(&"build_failed")
			return
		if not inventory.spend_resources(active_building_def.build_cost, "建造 %s" % active_building_def.display_name):
			push_debug_event("建造失败：资源不足 %s" % JSON.stringify(inventory.get_missing(active_building_def.build_cost)))
			_play_audio_cue(&"build_failed")
			return
	var building := _spawn_building(active_building_def, cell, is_main_base)
	if building:
		push_debug_event("建造完成：%s @ %s, %s" % [active_building_def.display_name, cell.x, cell.y])
		_play_audio_cue(&"build_success")
		if is_main_base:
			_setup_main_base_after_placement(building)
		_configure_building_runtime(building, active_building_def, cell)
		_advance_stage12_guidance_after_build(active_building_def, building)
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
	if _is_pointer_over_hud():
		return
	var world_unit := _find_world_unit_under_mouse()
	if world_unit:
		_show_selection_for_world_unit(world_unit)
		if hud and hud.has_method("inspect_node"):
			hud.call("inspect_node", world_unit)
		_show_operation_panel_for_node(world_unit)
		return

	var cell := _get_mouse_grid_cell()
	if not bool(grid_map.call("is_cell_in_bounds", cell)):
		return
	var occupant = grid_occupancy.get_at(cell)
	if occupant is Node:
		_clear_world_unit_selection()
		_show_selection_for_node(occupant)
		if hud and hud.has_method("inspect_node"):
			hud.call("inspect_node", occupant)
		_show_operation_panel_for_node(occupant)
		return
	var ruined_building := _get_destroyed_friendly_building_at_cell(cell)
	if ruined_building != null:
		_clear_world_unit_selection()
		_show_selection_for_node(ruined_building)
		if hud and hud.has_method("inspect_node"):
			hud.call("inspect_node", ruined_building)
		_show_operation_panel_for_node(ruined_building)
		return
	if resource_nodes_by_cell.has(cell):
		var resource_node: Node = resource_nodes_by_cell[cell]
		_clear_world_unit_selection()
		_show_selection_for_node(resource_node)
		if hud and hud.has_method("inspect_node"):
			hud.call("inspect_node", resource_node)
		_hide_operation_panel()
		return
	if salvage_pickups_by_cell.has(cell):
		var salvage_pickup: Node = salvage_pickups_by_cell[cell]
		_clear_world_unit_selection()
		_show_selection_for_node(salvage_pickup)
		if hud and hud.has_method("inspect_node"):
			hud.call("inspect_node", salvage_pickup)
		_hide_operation_panel()
		return
	_clear_world_unit_selection()
	_show_selection_for_cell(cell)
	if hud and hud.has_method("inspect_cell"):
		hud.call("inspect_cell", cell, get_region_info_for_cell(cell), get_region_state_for_cell(cell))
	_hide_operation_panel()

func _get_destroyed_friendly_building_at_cell(cell: Vector2i) -> Node:
	var building_layer := _get_layer("BuildingLayer")
	if building_layer == null:
		return null
	for child in building_layer.get_children():
		if child == null or not is_instance_valid(child) or not (child is BaseBuilding):
			continue
		if String(child.get("team")) != "Team_A":
			continue
		if child.has_method("is_alive") and bool(child.call("is_alive")):
			continue
		var origin: Vector2i = child.get("grid_origin")
		var size: Vector2i = child.get("grid_size")
		if cell.x >= origin.x and cell.y >= origin.y and cell.x < origin.x + size.x and cell.y < origin.y + size.y:
			return child
	return null

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
	_mark_navigation_dirty()
	if building.has_signal("building_destroyed"):
		building.connect("building_destroyed", Callable(self, "_on_building_destroyed"))
	return building

func _can_place_building(building_def: BuildingDef, origin: Vector2i) -> bool:
	return _get_place_block_reason(building_def, origin).is_empty()

func _get_place_block_reason(building_def: BuildingDef, origin: Vector2i) -> String:
	if grid_map == null:
		return "地图未就绪"
	if not bool(grid_map.call("is_rect_in_bounds", origin, building_def.grid_size)):
		return "超出地图边界"
	if _is_rect_in_locked_region(origin, building_def.grid_size):
		return "区域尚未解锁"
	if grid_map.has_method("is_rect_blocked_by_semantic_tile") and bool(grid_map.call("is_rect_blocked_by_semantic_tile", origin, building_def.grid_size)):
		return "地形阻挡"
	if not grid_occupancy.can_place(origin, building_def.grid_size):
		return "格子已被占用"
	var resource_node := _get_resource_node_at(origin)
	if _is_water_pump_def(building_def) and not _is_water_pump_placement_cell(origin, resource_node):
		return "水泵必须放在水源或水池边缘的泵位候选格"
	if _is_main_base_def(building_def):
		if main_base != null:
			return "主基地已经存在"
		if resource_node != null:
			return "主基地不能覆盖资源点"
		return ""
	if _is_miner_def(building_def):
		if resource_node == null:
			return "采矿机必须覆盖矿点"
		if resource_node.has_method("is_interaction_locked") and bool(resource_node.call("is_interaction_locked")):
			return "资源所在区域尚未解锁"
		if _is_water_resource_node(resource_node):
			return "水源需要放置水泵"
		if bool(resource_node.call("is_bound")):
			return "矿点已绑定采矿机"
	elif resource_node != null and not (_is_water_pump_def(building_def) and _is_water_resource_node(resource_node)):
		return "资源点上只能放置采矿机"
	var inventory = _get_main_base_inventory()
	if inventory == null:
		return "请先放置主基地"
	if not _is_remote_stage14_building_def(building_def) and not _can_place_with_stage14_remote_logistics(building_def, resource_node) and not _is_in_main_base_service_radius(origin, building_def.grid_size):
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

func _is_rect_in_locked_region(origin: Vector2i, size: Vector2i) -> bool:
	for x in range(origin.x, origin.x + size.x):
		for y in range(origin.y, origin.y + size.y):
			var region_id := _get_region_id_for_cell_from_config(Vector2i(x, y))
			if not _is_region_id_unlocked(region_id):
				return true
	return false

func _is_water_pump_candidate_cell(cell: Vector2i) -> bool:
	for water_value in map_water_bodies:
		if typeof(water_value) != TYPE_DICTIONARY:
			continue
		var water: Dictionary = water_value
		for cell_value in water.get("pump_candidate_cells", []):
			var pump_cell := MapConfigLoaderScript.get_vector2i({"cell": cell_value}, "cell", Vector2i(-999999, -999999))
			if pump_cell == cell:
				return true
	return false

func _is_water_pump_placement_cell(cell: Vector2i, resource_node: Node = null) -> bool:
	if resource_node == null:
		resource_node = _get_resource_node_at(cell)
	if _is_water_resource_node(resource_node):
		return true
	return _is_water_pump_candidate_cell(cell)

func _is_water_resource_node(resource_node: Node) -> bool:
	return resource_node != null and StringName(resource_node.get("resource_id")) == MvpDataDefaults.RES_WATER

func _can_place_with_stage14_remote_logistics(building_def: BuildingDef, resource_node: Node) -> bool:
	if not stage14_remote_logistics_enabled:
		return false
	if not _is_miner_def(building_def):
		return false
	if resource_node == null or _is_water_resource_node(resource_node):
		return false
	return true

func _on_inventory_changed(resource_id: StringName, amount: int, delta: int, reason: String) -> void:
	_queue_resource_hud_refresh()
	if delta > 0:
		_queue_resource_event(&"resource_gained", resource_id, amount, delta, reason)
	elif delta < 0:
		_queue_resource_event(&"resource_spent", resource_id, amount, delta, reason)

func _tick_resource_ui_and_events(delta: float) -> void:
	if _resource_hud_dirty:
		_resource_hud_refresh_seconds += delta
		if _resource_hud_refresh_seconds >= RESOURCE_HUD_REFRESH_INTERVAL:
			_resource_hud_refresh_seconds = 0.0
			_resource_hud_dirty = false
			_refresh_resource_hud()
	if not _pending_resource_events.is_empty():
		_resource_event_flush_seconds += delta
		if _resource_event_flush_seconds >= RESOURCE_EVENT_FLUSH_INTERVAL:
			_resource_event_flush_seconds = 0.0
			_flush_pending_resource_events()

func _queue_resource_hud_refresh() -> void:
	_resource_hud_dirty = true

func _queue_resource_event(event_type: StringName, resource_id: StringName, amount: int, delta: int, reason: String) -> void:
	var key := "%s|%s" % [String(event_type), String(resource_id)]
	var entry: Dictionary = _pending_resource_events.get(key, {})
	if entry.is_empty():
		entry = {
			"event_type": event_type,
			"resource_id": resource_id,
			"amount": amount,
			"delta": 0,
			"count": 0,
			"sample_reason": reason,
		}
	entry["amount"] = amount
	entry["delta"] = int(entry.get("delta", 0)) + delta
	entry["count"] = int(entry.get("count", 0)) + 1
	if str(entry.get("sample_reason", "")).is_empty() and not reason.is_empty():
		entry["sample_reason"] = reason
	_pending_resource_events[key] = entry

func _flush_pending_resource_events() -> void:
	if _pending_resource_events.is_empty():
		return
	var events := _pending_resource_events
	_pending_resource_events = {}
	for entry in events.values():
		var event_type := StringName(str(entry.get("event_type", "")))
		var resource_id := StringName(str(entry.get("resource_id", "")))
		var delta := int(entry.get("delta", 0))
		if String(event_type).is_empty() or String(resource_id).is_empty() or delta == 0:
			continue
		var count := int(entry.get("count", 1))
		var reason := str(entry.get("sample_reason", ""))
		if count > 1:
			reason = "批量资源流水：%d 次变动%s" % [count, "；样例：%s" % reason if not reason.is_empty() else ""]
		_record_event(event_type, resource_id, int(entry.get("amount", 0)), delta, reason)

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
	_refresh_campaign_hud()
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

func _create_hover_marker() -> void:
	if hover_marker != null:
		return
	hover_marker = GridHoverMarkerScene.instantiate()
	var layer := _get_layer("RallyLayer")
	(layer if layer else self).add_child(hover_marker)

func _update_hover_marker() -> void:
	if hover_marker == null or grid_map == null:
		return
	if active_building_def != null or _is_pointer_over_hud():
		hover_marker.call("clear_hover")
		return
	var cell := _get_mouse_grid_cell()
	if not bool(grid_map.call("is_cell_in_bounds", cell)):
		hover_marker.call("clear_hover")
		return
	hover_marker.call("show_hover", cell, _get_grid_cell_size())

func _refresh_playtest_hud() -> void:
	if hud == null:
		return
	var elapsed_seconds := maxf(0.0, Time.get_ticks_msec() / 1000.0 - stage_started_seconds)
	if hud.has_method("set_elapsed_seconds"):
		hud.call("set_elapsed_seconds", elapsed_seconds)
	if hud.has_method("set_objective_direction"):
		hud.call("set_objective_direction", _get_objective_direction_text())
	if hud.has_method("set_guidance_highlights"):
		hud.call("set_guidance_highlights", _get_guidance_highlights())
	if hud.has_method("set_available_enemy_target_tags"):
		hud.call("set_available_enemy_target_tags", _get_visible_enemy_target_tags())
	if hud.has_method("set_minimap_snapshot"):
		hud.call("set_minimap_snapshot", _build_minimap_snapshot())

func _get_visible_enemy_target_tags() -> Array[String]:
	var result: Array[String] = []
	for enemy in get_tree().get_nodes_in_group("team_b"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy is CanvasItem and not (enemy as CanvasItem).is_visible_in_tree():
			continue
		if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
			continue
		var tags_value: Variant = enemy.get("tags")
		if typeof(tags_value) == TYPE_ARRAY:
			for tag_value in tags_value:
				var tag_text := str(tag_value)
				if not tag_text.is_empty() and not result.has(tag_text):
					result.append(tag_text)
		for group_value in enemy.get_groups():
			var group_text := str(group_value)
			if _is_target_priority_tag(group_text) and not result.has(group_text):
				result.append(group_text)
	if result.is_empty():
		result = ["backline", "frontline"]
	result.sort()
	return result

func _is_target_priority_tag(tag: String) -> bool:
	return tag == "frontline" or tag == "backline"

func _build_minimap_snapshot() -> Dictionary:
	if grid_map == null:
		return {}
	var map_size: Vector2i = grid_map.get("map_size_cells")
	var snapshot := map_minimap_static_snapshot.duplicate(false)
	if snapshot.is_empty():
		snapshot = _build_minimap_static_snapshot(map_size)
	snapshot["resources"] = _get_minimap_resource_nodes()
	snapshot["enemy_nests"] = _get_minimap_enemy_nests()
	snapshot["main_base"] = _get_minimap_main_base()
	snapshot["supply_points"] = _get_minimap_supply_points()
	snapshot["region_connections"] = _get_minimap_region_connections()
	snapshot["region_signals"] = _get_minimap_region_signals()
	snapshot["water_flow_target_cell"] = _get_minimap_water_flow_target_cell()
	snapshot["camera_cell"] = _get_minimap_camera_cell()
	snapshot["viewport_rect"] = _get_minimap_viewport_rect()
	return snapshot

func _build_minimap_static_snapshot(map_size: Vector2i) -> Dictionary:
	return {
		"map_size": [map_size.x, map_size.y],
		"static_version": map_static_cache_version,
		"regions": map_region_definitions,
		"region_cells": _get_minimap_region_cells(),
		"region_connections": _get_minimap_region_connections(),
		"water_bodies": map_water_bodies,
		"water_cells": _get_minimap_semantic_cells("water"),
		"pump_candidate_cells": _get_minimap_semantic_cells("pump_candidate"),
		"frontier_cells": _get_minimap_semantic_cells("frontier"),
		"frontier_cell_groups": _get_minimap_frontier_cell_groups(),
		"gate_cells": _get_minimap_semantic_cells("gate"),
		"risk_bypass_cells": _get_minimap_semantic_cells("risk_bypass"),
	}

func _get_minimap_region_cells() -> Array:
	var result: Array = []
	for cell_value in map_painted_region_cells_cache:
		if typeof(cell_value) != TYPE_DICTIONARY:
			continue
		var region_cell: Dictionary = cell_value
		var cell: Vector2i = region_cell.get("cell", Vector2i.ZERO)
		result.append({
			"cell": [cell.x, cell.y],
			"region_id": str(region_cell.get("region_id", "")),
			"display_name": str(region_cell.get("display_name", "")),
			"minimap_color": region_cell.get("minimap_color", []),
		})
	return result

func _get_minimap_region_connections() -> Array:
	var result: Array = []
	for connection_value in map_region_connections:
		if typeof(connection_value) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_value.duplicate(true)
		var gate_id := str(connection.get("id", ""))
		connection["gate_state"] = str(map_region_gate_states.get(gate_id, "open"))
		result.append(connection)
	return result

func _get_minimap_semantic_cells(tag: String) -> Array:
	var result: Array = []
	var seen := {}
	for cell_value in map_semantic_cells_by_tag_cache.get(tag, []):
		var cell: Vector2i = cell_value
		var key := _region_key(cell)
		if seen.has(key):
			continue
		seen[key] = true
		result.append([cell.x, cell.y])
	return result

func _get_minimap_frontier_cell_groups() -> Dictionary:
	var result := {}
	for tag in ["crystal_frontier", "wreckage_frontier", "interference_frontier", "core_frontier"]:
		result[tag] = _get_minimap_semantic_cells(tag)
	return result

func _get_minimap_region_signals() -> Array:
	var result: Array = []
	for centers_value in map_region_signal_cells.values():
		if typeof(centers_value) != TYPE_ARRAY:
			continue
		var centers: Array = centers_value
		for signal_value in centers:
			if typeof(signal_value) != TYPE_DICTIONARY:
				continue
			var signal_info: Dictionary = signal_value
			var cell := _vector2_from_variant(signal_info.get("cell", Vector2.ZERO))
			result.append({
				"cell": [cell.x, cell.y],
				"signal_type": str(signal_info.get("signal_type", "unknown")),
			})
	return result

func _get_minimap_resource_nodes() -> Array:
	var result: Array = []
	for node in resource_nodes_by_id.values():
		if node == null or not is_instance_valid(node):
			continue
		var origin: Vector2i = node.get("grid_origin")
		result.append({
			"id": String(node.get("node_id")),
			"resource_id": String(node.get("resource_id")),
			"cell": [origin.x, origin.y],
			"discovered": _is_cell_discovered(origin),
		})
	return result

func _get_minimap_enemy_nests() -> Array:
	var result: Array = []
	for nest in enemy_nests_by_id.values():
		if nest == null or not is_instance_valid(nest):
			continue
		var origin: Vector2i = nest.get("grid_origin")
		var size: Vector2i = nest.get("grid_size")
		result.append({
			"id": String(nest.name),
			"origin": [origin.x, origin.y],
			"size": [size.x, size.y],
			"discovered": _is_cell_discovered(origin),
		})
	return result

func _get_minimap_main_base() -> Dictionary:
	if main_base == null or not is_instance_valid(main_base):
		return {}
	var origin: Vector2i = main_base.get("grid_origin")
	var size: Vector2i = main_base.get("grid_size")
	return {
		"origin": [origin.x, origin.y],
		"size": [size.x, size.y],
	}

func _get_minimap_supply_points() -> Array:
	var result: Array = []
	for point_value in map_frontline_supply_points:
		if typeof(point_value) != TYPE_DICTIONARY:
			continue
		var point: Dictionary = point_value
		var cell := MapConfigLoaderScript.get_vector2i(point, "grid_origin", MapConfigLoaderScript.get_vector2i(point, "cell", Vector2i.ZERO))
		result.append({
			"id": str(point.get("id", "frontline_supply")),
			"cell": [cell.x, cell.y],
			"discovered": _is_cell_discovered(cell),
			"source": "map_config",
		})
	var building_layer := _get_layer("BuildingLayer")
	if building_layer == null:
		return result
	for child in building_layer.get_children():
		if child == null or not is_instance_valid(child):
			continue
		var building_def: BuildingDef = child.get("building_def")
		var building_id := ""
		if building_def != null:
			building_id = String(building_def.id)
		if not child.is_in_group("frontline_supply") and not building_id.contains("supply"):
			continue
		var origin: Vector2i = child.get("grid_origin")
		result.append({
			"id": String(child.name),
			"cell": [origin.x, origin.y],
			"discovered": _is_cell_discovered(origin),
			"source": "building",
		})
	return result

func _get_discovered_water_bodies() -> Array:
	var result: Array = []
	for water_value in map_water_bodies:
		if typeof(water_value) != TYPE_DICTIONARY:
			continue
		var water: Dictionary = water_value
		if _is_water_body_discovered(water):
			result.append(water.duplicate(true))
	return result

func _is_water_body_discovered(water: Dictionary) -> bool:
	for cell_value in water.get("pump_candidate_cells", []):
		if _is_cell_discovered(MapConfigLoaderScript.get_vector2i({"cell": cell_value}, "cell")):
			return true
	for rect_value in water.get("grid_rects", []):
		if typeof(rect_value) != TYPE_ARRAY or rect_value.size() < 4:
			continue
		var sample := Vector2i(
			int(rect_value[0]) + floori(float(int(rect_value[2])) * 0.5),
			int(rect_value[1]) + floori(float(int(rect_value[3])) * 0.5)
		)
		if _is_cell_discovered(sample):
			return true
	return false

func _get_minimap_water_flow_target_cell() -> Array:
	if main_base == null or not is_instance_valid(main_base):
		return [-1, -1]
	var origin: Vector2i = main_base.get("grid_origin")
	var size: Vector2i = main_base.get("grid_size")
	var center := origin + Vector2i(floori(float(size.x) * 0.5), floori(float(size.y) * 0.5))
	return [center.x, center.y]

func _get_minimap_camera_cell() -> Array:
	if main_camera == null or grid_map == null:
		return [-1, -1]
	var cell: Vector2i = grid_map.call("world_to_grid", main_camera.global_position)
	return [cell.x, cell.y]

func _get_minimap_viewport_rect() -> Dictionary:
	if main_camera == null or grid_map == null:
		return {}
	var cell_size := float(_get_grid_cell_size())
	var viewport_size := get_viewport_rect().size
	var zoom := main_camera.zoom
	var half_view_world := Vector2(
		viewport_size.x / maxf(zoom.x * 2.0, 0.001),
		viewport_size.y / maxf(zoom.y * 2.0, 0.001)
	)
	var top_left_world := main_camera.global_position - half_view_world
	var view_size_world := half_view_world * 2.0
	return {
		"position": [top_left_world.x / cell_size, top_left_world.y / cell_size],
		"size": [view_size_world.x / cell_size, view_size_world.y / cell_size],
	}

func _is_cell_discovered(cell: Vector2i) -> bool:
	var state := get_region_state_for_cell(cell)
	return state == "scanned" or state == "visible" or state == "controlled" or state == "signal"

func _get_guidance_highlights() -> Dictionary:
	var building_ids: Array[StringName] = []
	var highlight_blueprint := false
	var highlight_technology := false
	var highlight_forge_blueprint_picker := false
	if active_building_def != null or rally_point_target_forge != null:
		return {
			"building_ids": building_ids,
			"blueprint_button": false,
			"technology_button": false,
			"forge_blueprint_picker": false,
		}
	if main_base == null:
		building_ids.append(MvpDataDefaults.BUILDING_MAIN_BASE)
	elif _count_player_buildings(MvpDataDefaults.BUILDING_MINER) < 2:
		building_ids.append(MvpDataDefaults.BUILDING_MINER)
	elif _count_player_buildings(MvpDataDefaults.BUILDING_PROCESSOR) < 1:
		building_ids.append(MvpDataDefaults.BUILDING_PROCESSOR)
	elif _count_player_buildings(MvpDataDefaults.BUILDING_ROBOT_FORGE) < 1:
		building_ids.append(MvpDataDefaults.BUILDING_ROBOT_FORGE)
	elif _needs_rally_blueprint_guidance():
		highlight_blueprint = true
		highlight_forge_blueprint_picker = true
	elif _needs_technology_guidance():
		if _count_player_buildings(MvpDataDefaults.BUILDING_RESEARCH_TERMINAL) < 1:
			building_ids.append(MvpDataDefaults.BUILDING_RESEARCH_TERMINAL)
		else:
			highlight_technology = true
	return {
		"building_ids": building_ids,
		"blueprint_button": highlight_blueprint,
		"technology_button": highlight_technology,
		"forge_blueprint_picker": highlight_forge_blueprint_picker,
	}

func _needs_rally_blueprint_guidance() -> bool:
	if _count_player_buildings(MvpDataDefaults.BUILDING_ROBOT_FORGE) < 1:
		return false
	if not _has_rally_template_blueprint():
		return true
	return _has_forge_without_rally_template_blueprint()

func _needs_technology_guidance() -> bool:
	if campaign_state == null:
		return false
	if campaign_state.key_items.is_empty() and campaign_state.defeated_nests.is_empty():
		return false
	for technology in technology_defs:
		if campaign_state.can_research(technology):
			return true
	return false

func _count_player_buildings(building_id: StringName) -> int:
	var count := 0
	for building in _get_player_buildings_by_id(building_id):
		if building.has_method("is_alive") and not bool(building.call("is_alive")):
			continue
		count += 1
	return count

func _get_player_buildings_by_id(building_id: StringName) -> Array[Node]:
	var result: Array[Node] = []
	var building_layer := _get_layer("BuildingLayer")
	if building_layer == null:
		return result
	for child in building_layer.get_children():
		if child == null or not is_instance_valid(child):
			continue
		var building_def: BuildingDef = child.get("building_def")
		if building_def == null or building_def.id != building_id:
			continue
		if not _is_player_building(child):
			continue
		result.append(child)
	return result

func _is_player_building(building: Node) -> bool:
	if building == null or not is_instance_valid(building):
		return false
	return str(building.get("team")) == "Team_A" or building.is_in_group("team_a")

func _has_rally_template_blueprint() -> bool:
	if blueprint_library == null:
		return false
	for blueprint in blueprint_library.get_blueprints():
		if _blueprint_has_rally_template(blueprint):
			return true
	return false

func _has_forge_without_rally_template_blueprint() -> bool:
	for forge in _get_player_buildings_by_id(MvpDataDefaults.BUILDING_ROBOT_FORGE):
		var forge_blueprint: UnitBlueprint = forge.get("blueprint")
		if not _blueprint_has_rally_template(forge_blueprint):
			return true
	return false

func _blueprint_has_rally_template(blueprint: UnitBlueprint) -> bool:
	if blueprint == null:
		return false
	for template in blueprint.tactical_templates:
		if typeof(template) == TYPE_DICTIONARY and str(template.get("id", "")) == "rally_then_attack":
			return true
	return false

func _get_objective_direction_text() -> String:
	var nest := _get_active_enemy_nest()
	if nest == null:
		return "敌巢已摧毁"
	var target_position: Vector2 = nest.global_position
	if nest.has_method("get_target_position"):
		target_position = nest.call("get_target_position")
	var origin: Vector2 = main_camera.global_position if main_camera else Vector2.ZERO
	if main_base != null and is_instance_valid(main_base) and main_base.has_method("get_target_position"):
		origin = main_base.call("get_target_position")
	var offset: Vector2 = target_position - origin
	return "敌巢方向：%s  距离约 %d" % [_format_compass_direction(offset), roundi(offset.length())]

func _get_active_enemy_nest() -> Node2D:
	for nest in enemy_nests_by_id.values():
		if nest == null or not is_instance_valid(nest):
			continue
		if nest.has_method("is_alive") and not bool(nest.call("is_alive")):
			continue
		if nest.has_method("is_mainline_objective") and not bool(nest.call("is_mainline_objective")):
			continue
		return nest as Node2D
	return null

func _format_compass_direction(offset: Vector2) -> String:
	if offset.length_squared() <= 1.0:
		return "当前位置"
	var horizontal := ""
	var vertical := ""
	if absf(offset.x) >= 48.0:
		horizontal = "东" if offset.x > 0.0 else "西"
	if absf(offset.y) >= 48.0:
		vertical = "南" if offset.y > 0.0 else "北"
	return "%s%s" % [vertical, horizontal]

func _show_selection_for_cell(cell: Vector2i) -> void:
	_clear_world_unit_selection()
	selected_inspected_node = null
	_clear_logistics_visuals()
	if selection_marker and selection_marker.has_method("show_selection"):
		selection_marker.call("show_selection", cell, Vector2i.ONE, _get_grid_cell_size())

func _show_selection_for_node(node: Node) -> void:
	_clear_world_unit_selection()
	selected_inspected_node = node
	_refresh_selected_logistics_visual()
	if selection_marker == null or not selection_marker.has_method("show_selection"):
		return
	var origin: Vector2i = node.get("grid_origin")
	var size: Vector2i = node.get("grid_size")
	selection_marker.call("show_selection", origin, size, _get_grid_cell_size())

func _show_selection_for_world_unit(unit: Node) -> void:
	_clear_world_unit_selection()
	selected_world_unit = unit
	selected_inspected_node = unit
	unit_inspector_refresh_seconds = 0.0
	_refresh_selected_logistics_visual()
	if selection_marker and selection_marker.has_method("clear_selection"):
		selection_marker.call("clear_selection")
	if selected_world_unit.has_method("set_selected"):
		selected_world_unit.call("set_selected", true)

func _clear_world_unit_selection() -> void:
	if selected_world_unit and is_instance_valid(selected_world_unit) and selected_world_unit.has_method("set_selected"):
		selected_world_unit.call("set_selected", false)
	if selected_inspected_node == selected_world_unit:
		selected_inspected_node = null
	selected_world_unit = null
	unit_inspector_refresh_seconds = 0.0
	_clear_logistics_visuals()

func _refresh_selected_unit_inspector() -> void:
	if selected_inspected_node == null or not is_instance_valid(selected_inspected_node):
		_clear_world_unit_selection()
		selected_inspected_node = null
		return
	if selected_inspected_node.has_method("is_alive") and not bool(selected_inspected_node.call("is_alive")):
		_clear_world_unit_selection()
		selected_inspected_node = null
		return
	if hud and hud.has_method("inspect_node"):
		hud.call("inspect_node", selected_inspected_node)

func _should_periodically_refresh_inspector() -> bool:
	if selected_inspected_node == null or not is_instance_valid(selected_inspected_node):
		return false
	return (
		selected_inspected_node is RobotUnit
		or selected_inspected_node is BaseBuilding
		or selected_inspected_node is EnemyNest
		or selected_inspected_node.has_method("get_salvage_value")
	)

func _find_world_unit_under_mouse() -> Node:
	var mouse_world := get_global_mouse_position()
	var best_unit: Node = null
	var best_distance_sq := 32.0 * 32.0
	for layer_name in ["UnitLayer", "EnemyLayer"]:
		var layer := _get_layer(layer_name)
		if layer == null:
			continue
		for child in layer.get_children():
			if not (child is Node2D):
				continue
			if child is CanvasItem and not (child as CanvasItem).is_visible_in_tree():
				continue
			if child.has_method("is_alive") and not bool(child.call("is_alive")):
				continue
			var distance_sq := mouse_world.distance_squared_to((child as Node2D).global_position)
			if distance_sq < best_distance_sq:
				best_distance_sq = distance_sq
				best_unit = child
	return best_unit

func _is_pointer_over_hud() -> bool:
	if hud == null or not hud.has_method("is_pointer_over_ui"):
		return false
	return bool(hud.call("is_pointer_over_ui", get_viewport().get_mouse_position()))

func _find_building_def(building_id: StringName) -> BuildingDef:
	for building_def in building_defs:
		if building_def.id == building_id:
			return building_def
	return null

func _get_placeable_buildings() -> Array[BuildingDef]:
	var result: Array[BuildingDef] = []
	for building_def in building_defs:
		if not _is_building_visible_in_build_bar(building_def):
			continue
		if main_base == null:
			if _is_main_base_def(building_def):
				result.append(building_def)
		elif not _is_main_base_def(building_def):
			result.append(building_def)
	return result

func _is_building_visible_in_build_bar(building_def: BuildingDef) -> bool:
	if building_def == null or not building_def.build_bar_visible:
		return false
	if campaign_state == null:
		return building_def.unlock_stage <= 0 and not building_def.requires_campaign_unlock
	if campaign_state.is_building_unlocked(building_def.id):
		return true
	if building_def.requires_campaign_unlock:
		return false
	return campaign_state.current_stage >= building_def.unlock_stage

func _setup_main_base_after_placement(base_node: Node) -> void:
	main_base = base_node
	var inventory = _get_main_base_inventory()
	if inventory:
		inventory.inventory_changed.connect(_on_inventory_changed)
	if main_base.has_method("seed_inventory"):
		main_base.call("seed_inventory", starting_inventory)
	_apply_main_base_recipe_upgrade()
	_refresh_resource_hud()
	_refresh_build_options()
	var origin: Vector2i = main_base.get("grid_origin")
	push_debug_event("主基地已部署：网格 %s, %s，其它建筑已解锁" % [
		origin.x,
		origin.y,
	])
	set_current_goal("建造采矿机覆盖铁矿和铜矿，再放置基础加工厂")
	set_guidance_hint("在铁矿和铜矿矿点上建造采矿机，然后建造基础加工厂。")
	if hud and hud.has_method("show_bottom_prompt"):
		hud.call("show_bottom_prompt", "主基地已部署。下一步：在矿点上建造采矿机。", 3.2, &"success")

func _refresh_build_options() -> void:
	if hud and hud.has_method("set_building_options"):
		hud.call("set_building_options", _get_placeable_buildings())

func _is_main_base_def(building_def: BuildingDef) -> bool:
	return building_def != null and building_def.id == MvpDataDefaults.BUILDING_MAIN_BASE

func _is_miner_def(building_def: BuildingDef) -> bool:
	return building_def != null and building_def.id == MvpDataDefaults.BUILDING_MINER

func _is_processor_def(building_def: BuildingDef) -> bool:
	return building_def != null and (
		building_def.id == MvpDataDefaults.BUILDING_PROCESSOR
		or building_def.id == MvpDataDefaults.BUILDING_ADVANCED_PROCESSOR
	)

func _is_robot_forge_def(building_def: BuildingDef) -> bool:
	return building_def != null and building_def.id == MvpDataDefaults.BUILDING_ROBOT_FORGE

func _is_research_terminal_def(building_def: BuildingDef) -> bool:
	return building_def != null and building_def.id == MvpDataDefaults.BUILDING_RESEARCH_TERMINAL

func _is_water_pump_def(building_def: BuildingDef) -> bool:
	return building_def != null and building_def.id == MvpDataDefaults.BUILDING_WATER_PUMP

func _is_forward_supply_point_def(building_def: BuildingDef) -> bool:
	return building_def != null and building_def.id == MvpDataDefaults.BUILDING_FORWARD_SUPPLY_POINT

func _is_remote_stage14_building_def(building_def: BuildingDef) -> bool:
	return _is_water_pump_def(building_def) or _is_forward_supply_point_def(building_def)

func _is_cargo_robot_node(node: Node) -> bool:
	return node != null and node.has_method("is_cargo_robot") and bool(node.call("is_cargo_robot"))

func _is_producer_operation_node(node: Node) -> bool:
	return node != null and node.has_method("get_operation_recipe") and node.get("output_cache") != null

func _get_building_scene(building_def: BuildingDef, is_main_base: bool) -> PackedScene:
	if is_main_base:
		return MainBaseScene
	if _is_miner_def(building_def):
		return MinerScene
	if _is_processor_def(building_def):
		return ProcessorScene
	if _is_robot_forge_def(building_def):
		return RobotForgeScene
	if _is_research_terminal_def(building_def):
		return ResearchTerminalScene
	if _is_water_pump_def(building_def):
		return WaterPumpScene
	if _is_forward_supply_point_def(building_def):
		return ForwardSupplyPointScene
	return BaseBuildingScene

func _configure_grid_map_from_config(map_config: Dictionary) -> void:
	if grid_map == null:
		return
	var current_size: Vector2i = grid_map.get("map_size_cells")
	var map_size := MapConfigLoaderScript.get_vector2i(map_config, "map_size", current_size)
	var next_cell_size := int(map_config.get("cell_size", int(grid_map.get("cell_size"))))
	if grid_map.has_method("configure"):
		grid_map.call("configure", map_size, next_cell_size)
	else:
		grid_map.set("map_size_cells", map_size)
		grid_map.set("cell_size", next_cell_size)

func _apply_camera_start_from_config(map_config: Dictionary) -> void:
	if main_camera == null or grid_map == null:
		return
	var camera_start_cell := MapConfigLoaderScript.get_vector2i(map_config, "camera_start_cell", Vector2i(-1, -1))
	if camera_start_cell.x >= 0 and camera_start_cell.y >= 0 and grid_map.has_method("grid_to_world"):
		main_camera.global_position = grid_map.call("grid_to_world", camera_start_cell)
		_clamp_camera_to_map_bounds()

func _initialize_region_gate_runtime(map_config: Dictionary) -> void:
	map_region_definitions = map_config.get("regions", []).duplicate(true)
	map_region_routes = map_config.get("region_routes", []).duplicate(true)
	map_region_connections = _normalize_region_connections(map_config.get("region_connections", []))
	map_region_gate_states.clear()
	map_locked_gate_cells.clear()
	map_pending_enemy_patrols.clear()
	map_pending_enemy_nests.clear()
	for connection_value in map_region_connections:
		if typeof(connection_value) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_value
		var gate_id := str(connection.get("id", ""))
		if gate_id.is_empty():
			continue
		var locked_by_default := bool(connection.get("locked_by_default", false))
		var unlock_source := _get_connection_unlock_source(connection)
		var unlock_technology := _get_connection_unlock_technology(connection)
		var unlock_key_item := _get_connection_unlock_key_item(connection)
		if not unlock_source.is_empty() or not unlock_technology.is_empty() or not unlock_key_item.is_empty():
			locked_by_default = true
		var state := "locked" if locked_by_default else "open"
		if not unlock_source.is_empty() and _is_nest_defeated_in_campaign(StringName(unlock_source)):
			state = "open"
		if not unlock_technology.is_empty() and _is_technology_unlocked_in_campaign(StringName(unlock_technology)):
			state = "open"
		if not unlock_key_item.is_empty() and _is_key_item_owned_in_campaign(StringName(unlock_key_item)):
			state = "open"
		map_region_gate_states[gate_id] = state
	_rebuild_locked_gate_cells()
	_ensure_region_gate_overlay()

func _normalize_region_connections(raw_connections: Array) -> Array:
	var result: Array = []
	var index := 0
	for connection_value in raw_connections:
		if typeof(connection_value) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_value.duplicate(true)
		if str(connection.get("id", "")).is_empty():
			var route_id := str(connection.get("route_id", ""))
			if route_id.is_empty():
				route_id = "connection_%02d" % index
			connection["id"] = route_id
		if not connection.has("locked_by_default"):
			connection["locked_by_default"] = not _get_connection_unlock_source(connection).is_empty() or not _get_connection_unlock_technology(connection).is_empty() or not _get_connection_unlock_key_item(connection).is_empty()
		result.append(connection)
		index += 1
	return result

func _get_connection_unlock_source(connection: Dictionary) -> String:
	var direct := str(connection.get("unlock_source_id", connection.get("unlocked_by", "")))
	if not direct.is_empty():
		return direct
	var revealed_by := str(connection.get("revealed_by", ""))
	if revealed_by.ends_with("_destroyed"):
		return revealed_by.substr(0, revealed_by.length() - "_destroyed".length())
	return ""

func _get_connection_unlock_technology(connection: Dictionary) -> String:
	var direct := str(connection.get("unlock_technology_id", connection.get("technology_id", "")))
	if not direct.is_empty():
		return direct
	var revealed_by := str(connection.get("revealed_by", ""))
	if revealed_by.begins_with("stage") or revealed_by.begins_with("tech_"):
		return revealed_by
	return ""

func _get_connection_unlock_key_item(connection: Dictionary) -> String:
	return str(connection.get("unlock_key_item_id", connection.get("key_item_id", "")))

func _is_nest_defeated_in_campaign(nest_id: StringName) -> bool:
	if campaign_state == null or String(nest_id).is_empty():
		return false
	return campaign_state.defeated_nests.has(nest_id)

func _is_technology_unlocked_in_campaign(technology_id: StringName) -> bool:
	if campaign_state == null or String(technology_id).is_empty():
		return false
	return campaign_state.unlocked_technologies.has(technology_id)

func _is_key_item_owned_in_campaign(key_item_id: StringName) -> bool:
	if campaign_state == null or String(key_item_id).is_empty():
		return false
	return campaign_state.key_items.has(key_item_id)

func _rebuild_locked_gate_cells() -> void:
	map_locked_gate_cells.clear()
	for connection_value in map_region_connections:
		if typeof(connection_value) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_value
		var gate_id := str(connection.get("id", ""))
		if str(map_region_gate_states.get(gate_id, "open")) != "locked":
			continue
		var cells: Array = map_region_gate_cluster_cells_by_gate_id.get(gate_id, [])
		if cells.is_empty():
			cells = connection.get("gate_cells", [])
		for cell_value in cells:
			var cell := _cell_from_gate_value(cell_value)
			if cell.x > -999999:
				map_locked_gate_cells[cell] = gate_id

func _ensure_region_gate_overlay() -> void:
	if _region_gate_overlay != null and is_instance_valid(_region_gate_overlay):
		return
	if grid_map == null:
		return
	_region_gate_overlay = RegionGateOverlayScript.new()
	_region_gate_overlay.name = "RegionGateOverlay"
	_region_gate_overlay.z_index = 50
	grid_map.add_child(_region_gate_overlay)

func _refresh_region_gate_runtime_state() -> void:
	_prepare_region_gate_tile_mapping()
	_rebuild_locked_gate_cells()
	_apply_region_gate_tile_visibility()
	_mark_navigation_dirty()
	_refresh_region_gate_overlay()

func _apply_region_gate_tile_visibility() -> void:
	var gate_layer := _get_region_gate_tile_layer()
	if gate_layer == null:
		return
	for cell_key in map_region_gate_tile_cache.keys():
		var cell := _parse_region_key(str(cell_key))
		if map_locked_gate_cells.has(cell):
			if gate_layer.has_method("erase_cell"):
				gate_layer.call("erase_cell", cell)
			continue
		var cached: Dictionary = map_region_gate_tile_cache[cell_key]
		if gate_layer.has_method("set_cell"):
			gate_layer.call(
				"set_cell",
				cell,
				int(cached.get("source_id", -1)),
				cached.get("atlas_coords", Vector2i.ZERO),
				int(cached.get("alternative_tile", 0))
			)
	if gate_layer.has_method("notify_runtime_tile_data_update"):
		gate_layer.call("notify_runtime_tile_data_update")
	if gate_layer.has_method("queue_redraw"):
		gate_layer.call("queue_redraw")
	if grid_map != null and grid_map.has_method("invalidate_semantic_cache"):
		grid_map.call("invalidate_semantic_cache")
	_rebuild_static_map_cache()

func _prepare_region_gate_tile_mapping() -> void:
	var gate_layer := _get_region_gate_tile_layer()
	if gate_layer == null:
		return
	_capture_region_gate_tiles(gate_layer)
	_assign_region_gate_tile_clusters()

func _capture_region_gate_tiles(gate_layer: Node) -> void:
	if gate_layer == null:
		return
	if not gate_layer.has_method("get_used_cells") or not gate_layer.has_method("get_cell_source_id"):
		return
	for cell_value in gate_layer.call("get_used_cells"):
		var cell: Vector2i = cell_value
		var key := _region_key(cell)
		if map_region_gate_tile_cache.has(key):
			continue
		var source_id := int(gate_layer.call("get_cell_source_id", cell))
		if source_id < 0:
			continue
		var atlas_coords := Vector2i.ZERO
		if gate_layer.has_method("get_cell_atlas_coords"):
			atlas_coords = gate_layer.call("get_cell_atlas_coords", cell)
		var alternative_tile := 0
		if gate_layer.has_method("get_cell_alternative_tile"):
			alternative_tile = int(gate_layer.call("get_cell_alternative_tile", cell))
		map_region_gate_tile_cache[key] = {
			"source_id": source_id,
			"atlas_coords": atlas_coords,
			"alternative_tile": alternative_tile,
		}

func _assign_region_gate_tile_clusters() -> void:
	if map_region_gate_tile_cache.is_empty():
		return
	var clusters := _build_region_gate_tile_clusters()
	if clusters.is_empty():
		return
	map_region_gate_cluster_cells_by_gate_id.clear()
	for connection_value in map_region_connections:
		if typeof(connection_value) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_value
		var gate_id := str(connection.get("id", ""))
		if gate_id.is_empty():
			continue
		var gate_center := _gate_cells_center(connection.get("gate_cells", []))
		var best_cluster: Dictionary = {}
		var best_distance := INF
		for cluster_value in clusters:
			var cluster: Dictionary = cluster_value
			var center: Vector2 = cluster.get("center", Vector2.ZERO)
			var distance := center.distance_squared_to(gate_center)
			if distance < best_distance:
				best_distance = distance
				best_cluster = cluster
		if not best_cluster.is_empty():
			map_region_gate_cluster_cells_by_gate_id[gate_id] = best_cluster.get("cells", [])

func _build_region_gate_tile_clusters() -> Array[Dictionary]:
	var unvisited := {}
	for key in map_region_gate_tile_cache.keys():
		unvisited[str(key)] = true
	var clusters: Array[Dictionary] = []
	while not unvisited.is_empty():
		var start_key := str(unvisited.keys()[0])
		unvisited.erase(start_key)
		var queue: Array[String] = [start_key]
		var cells: Array[Vector2i] = []
		while not queue.is_empty():
			var key: String = queue.pop_front()
			var cell := _parse_region_key(key)
			cells.append(cell)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var next_cell := cell + Vector2i(dx, dy)
					var next_key := _region_key(next_cell)
					if not unvisited.has(next_key):
						continue
					unvisited.erase(next_key)
					queue.append(next_key)
		clusters.append({
			"cells": cells,
			"center": _vector2i_cells_center(cells),
		})
	return clusters

func _gate_cells_center(cells: Array) -> Vector2:
	var parsed: Array[Vector2i] = []
	for cell_value in cells:
		var cell := _cell_from_gate_value(cell_value)
		if cell.x > -999999:
			parsed.append(cell)
	return _vector2i_cells_center(parsed)

func _vector2i_cells_center(cells: Array[Vector2i]) -> Vector2:
	if cells.is_empty():
		return Vector2.ZERO
	var total := Vector2.ZERO
	for cell in cells:
		total += Vector2(cell)
	return total / float(cells.size())

func _cell_from_gate_value(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(roundi(value.x), roundi(value.y))
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-999999, -999999)

func _get_region_gate_tile_layer() -> Node:
	if grid_map == null:
		return null
	return grid_map.get_node_or_null("TerrainLayer/GateLayer")

func _refresh_region_gate_overlay() -> void:
	_ensure_region_gate_overlay()
	if _region_gate_overlay != null and is_instance_valid(_region_gate_overlay) and _region_gate_overlay.has_method("setup"):
		_region_gate_overlay.call("setup", map_region_connections, map_region_gate_states, _get_grid_cell_size())

func _sync_gate_states_from_campaign() -> void:
	for connection_value in map_region_connections:
		if typeof(connection_value) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_value
		var gate_id := str(connection.get("id", ""))
		var unlock_source := _get_connection_unlock_source(connection)
		var unlock_technology := _get_connection_unlock_technology(connection)
		var unlock_key_item := _get_connection_unlock_key_item(connection)
		if gate_id.is_empty():
			continue
		if not unlock_source.is_empty() and _is_nest_defeated_in_campaign(StringName(unlock_source)):
			map_region_gate_states[gate_id] = "open"
		if not unlock_technology.is_empty() and _is_technology_unlocked_in_campaign(StringName(unlock_technology)):
			map_region_gate_states[gate_id] = "open"
		if not unlock_key_item.is_empty() and _is_key_item_owned_in_campaign(StringName(unlock_key_item)):
			map_region_gate_states[gate_id] = "open"
	_refresh_region_gate_runtime_state()

func _is_map_content_region_unlocked(data: Dictionary) -> bool:
	var region_id := _get_map_item_region_id(data)
	return _is_region_id_unlocked(region_id)

func _is_region_id_unlocked(region_id: String) -> bool:
	if region_id.is_empty() or region_id == "starting_basin":
		return true
	for connection_value in map_region_connections:
		if typeof(connection_value) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_value
		if str(connection.get("to_region_id", "")) != region_id:
			continue
		var gate_id := str(connection.get("id", ""))
		if str(map_region_gate_states.get(gate_id, "open")) == "open":
			return true
	return false

func _get_map_item_region_id(data: Dictionary) -> String:
	var explicit := str(data.get("region_id", ""))
	if not explicit.is_empty():
		return explicit
	var cell := MapConfigLoaderScript.get_vector2i(data, "grid_origin", Vector2i(-999999, -999999))
	if cell.x <= -999999:
		return ""
	return _get_region_id_for_cell_from_config(cell)

func _get_region_id_for_cell_from_config(cell: Vector2i) -> String:
	for region_value in map_region_definitions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		for rect_value in region.get("grid_rects", []):
			if typeof(rect_value) != TYPE_ARRAY or rect_value.size() < 4:
				continue
			var origin := Vector2i(int(rect_value[0]), int(rect_value[1]))
			var size := Vector2i(int(rect_value[2]), int(rect_value[3]))
			if cell.x >= origin.x and cell.y >= origin.y and cell.x < origin.x + size.x and cell.y < origin.y + size.y:
				return str(region.get("region_id", ""))
	return ""

func _load_fixed_map(map_config: Dictionary = {}) -> void:
	if map_config.is_empty():
		map_config = MapConfigLoaderScript.load_map_config(map_config_path)
	_initialize_region_gate_runtime(map_config)
	var resource_items: Array = map_config.get("resource_nodes", [])
	for item in resource_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		_spawn_resource_node(item)
	var salvage_items: Array = map_config.get("salvage_pickups", [])
	for item in salvage_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		_spawn_salvage_pickup(item)
	if RuntimeConfigLoaderScript.is_debug_feature_enabled(runtime_profile, "spawn_debug_wandering_enemy"):
		var debug_enemy_items: Array = map_config.get("debug_enemies", [])
		for item in debug_enemy_items:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			if _is_map_content_region_unlocked(item):
				_spawn_debug_enemy(item)
	var enemy_patrol_items: Array = map_config.get("enemy_patrols", [])
	for item in enemy_patrol_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if _is_map_content_region_unlocked(item):
			_spawn_enemy_patrol(item)
		else:
			map_pending_enemy_patrols.append(item.duplicate(true))
	var enemy_nest_items: Array = map_config.get("enemy_nests", [])
	for item in enemy_nest_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if _is_map_content_region_unlocked(item) or _is_nest_defeated_in_campaign(StringName(str(item.get("id", "")))):
			_spawn_enemy_nest(item)
		else:
			map_pending_enemy_nests.append(item.duplicate(true))
	_initialize_region_fog(map_config)
	_refresh_resource_gate_states()
	_refresh_region_gate_runtime_state()

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
	_apply_resource_gate_state(node, data)

func _spawn_salvage_pickup(data: Dictionary) -> Node:
	var resource_id := StringName(str(data.get("resource_id", "")))
	var resource_def := _find_resource_def(resource_id)
	if resource_def == null:
		push_warning("Unknown salvage resource id: %s" % String(resource_id))
		return null
	var pickup := SalvagePickupScene.instantiate()
	var layer := _get_layer("ResourceLayer")
	(layer if layer else self).add_child(pickup)
	pickup.call("setup", data, resource_def, _get_grid_cell_size())
	if pickup.has_signal("depleted"):
		pickup.connect("depleted", Callable(self, "_on_salvage_pickup_depleted"))
	var pickup_id := StringName(str(pickup.get("pickup_id")))
	var origin: Vector2i = pickup.get("grid_origin")
	salvage_pickups_by_id[pickup_id] = pickup
	salvage_pickups_by_cell[origin] = pickup
	_apply_salvage_gate_state(pickup, data)
	return pickup

func _is_salvage_spawn_cell_free(cell: Vector2i, reserved_cells: Dictionary = {}) -> bool:
	if grid_map and grid_map.has_method("is_cell_in_bounds") and not bool(grid_map.call("is_cell_in_bounds", cell)):
		return false
	if reserved_cells.has(cell):
		return false
	if grid_occupancy != null and grid_occupancy.get_at(cell) != null:
		return false
	if salvage_pickups_by_cell.has(cell):
		var existing_pickup: Node = salvage_pickups_by_cell[cell]
		if existing_pickup != null and is_instance_valid(existing_pickup) and int(existing_pickup.get("amount")) > 0:
			return false
		salvage_pickups_by_cell.erase(cell)
	return true

func _find_nearest_free_salvage_cell(preferred_cell: Vector2i, reserved_cells: Dictionary = {}, max_radius: int = 8) -> Vector2i:
	if _is_salvage_spawn_cell_free(preferred_cell, reserved_cells):
		return preferred_cell
	for radius in range(1, max_radius + 1):
		var candidates: Array[Vector2i] = []
		for y in range(preferred_cell.y - radius, preferred_cell.y + radius + 1):
			for x in range(preferred_cell.x - radius, preferred_cell.x + radius + 1):
				var cell := Vector2i(x, y)
				if maxi(absi(cell.x - preferred_cell.x), absi(cell.y - preferred_cell.y)) != radius:
					continue
				if _is_salvage_spawn_cell_free(cell, reserved_cells):
					candidates.append(cell)
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var distance_a := Vector2(a - preferred_cell).length_squared()
			var distance_b := Vector2(b - preferred_cell).length_squared()
			if not is_equal_approx(distance_a, distance_b):
				return distance_a < distance_b
			if a.y != b.y:
				return a.y < b.y
			return a.x < b.x
		)
		if not candidates.is_empty():
			return candidates[0]
	return Vector2i(-999999, -999999)

func _assign_salvage_spawn_cell(data: Dictionary, preferred_cell: Vector2i, reserved_cells: Dictionary = {}) -> bool:
	var spawn_cell := _find_nearest_free_salvage_cell(preferred_cell, reserved_cells)
	if spawn_cell.x <= -999999:
		return false
	data["grid_origin"] = _vector2i_to_array(spawn_cell)
	reserved_cells[spawn_cell] = true
	return true

func _on_salvage_pickup_depleted(pickup: Node) -> void:
	if pickup == null:
		return
	salvage_pickups_by_id.erase(StringName(str(pickup.get("pickup_id"))))
	salvage_pickups_by_cell.erase(pickup.get("grid_origin"))

func _apply_salvage_gate_state(pickup: Node, source_data: Dictionary = {}) -> void:
	if pickup == null or not is_instance_valid(pickup) or not pickup.has_method("set_interaction_locked"):
		return
	var region_id := _get_map_item_region_id(source_data)
	if region_id.is_empty():
		var origin: Vector2i = pickup.get("grid_origin")
		region_id = _get_region_id_for_cell_from_config(origin)
	var locked := not _is_region_id_unlocked(region_id)
	pickup.call("set_interaction_locked", locked, "区域尚未解锁" if locked else "")

func _apply_resource_gate_state(node: Node, source_data: Dictionary = {}) -> void:
	if node == null or not is_instance_valid(node) or not node.has_method("set_interaction_locked"):
		return
	var region_id := _get_map_item_region_id(source_data)
	if region_id.is_empty():
		var origin: Vector2i = node.get("grid_origin")
		region_id = _get_region_id_for_cell_from_config(origin)
	var locked := not _is_region_id_unlocked(region_id)
	node.call("set_interaction_locked", locked, "区域尚未解锁" if locked else "")

func _refresh_resource_gate_states() -> void:
	for node in resource_nodes_by_id.values():
		if node == null or not is_instance_valid(node):
			continue
		_apply_resource_gate_state(node)
	for pickup in salvage_pickups_by_id.values():
		if pickup == null or not is_instance_valid(pickup):
			continue
		_apply_salvage_gate_state(pickup)

func _spawn_debug_enemy(data: Dictionary) -> void:
	if not _is_map_enemy_spawn_allowed(data):
		return
	var path_points := _get_world_path_points(data.get("grid_path", []))
	if path_points.is_empty():
		return
	var enemy := DebugEnemyScene.instantiate()
	var layer := _get_layer("EnemyLayer")
	(layer if layer else self).add_child(enemy)
	enemy.name = str(data.get("id", IdProvider.next_id(&"debug_enemy")))
	enemy.global_position = path_points[0]
	_set_robot_map_spawn_id(enemy, data)
	if enemy.has_method("setup_debug_enemy"):
		var debug_config := EnemyConfigLoaderScript.get_type(enemy_config, "unit_types", &"debug_enemy")
		debug_config.merge(data, true)
		enemy.call("setup_debug_enemy", str(data.get("display_name", debug_config.get("display_name", "调试靶机"))), path_points, data.get("loop", true) == true, debug_config)
	if enemy.has_signal("robot_lost") and not enemy.is_connected("robot_lost", Callable(self, "_on_enemy_hound_lost")):
		enemy.connect("robot_lost", Callable(self, "_on_enemy_hound_lost"))
	push_debug_event("调试敌军已生成：%s，路径点 %d" % [enemy.name, path_points.size()])

func _spawn_enemy_patrol(data: Dictionary) -> void:
	if not _is_map_enemy_spawn_allowed(data):
		return
	var unit_type := StringName(str(data.get("unit_type", "armored_scout")))
	var guard_config := EnemyConfigLoaderScript.get_type(enemy_config, "unit_types", unit_type)
	if guard_config.is_empty():
		push_warning("Unknown enemy patrol unit type: %s" % String(unit_type))
		return
	guard_config.merge(data, true)
	var origin := MapConfigLoaderScript.get_vector2i(data, "grid_origin", Vector2i(-1, -1))
	if origin.x < 0 or origin.y < 0:
		push_warning("Enemy patrol missing grid_origin: %s" % str(data.get("id", "")))
		return
	var world_position: Vector2 = grid_map.call("grid_to_world", origin) if grid_map and grid_map.has_method("grid_to_world") else Vector2(origin.x, origin.y) * _get_grid_cell_size()
	var layer := _get_layer("EnemyLayer")
	var pool_name := str(guard_config.get("pool_name", unit_type))
	var patrol := ObjectPool.get_instance(ScavengerHoundScene, layer if layer else self, pool_name) as RobotUnit
	if patrol == null:
		return
	patrol.name = str(data.get("id", IdProvider.next_id(unit_type)))
	patrol.global_position = world_position
	_set_robot_map_spawn_id(patrol, data)
	patrol.call("setup_scavenger_hound", guard_config, null)
	patrol.set("guard_home_position", world_position)
	if patrol.has_signal("robot_lost") and not patrol.is_connected("robot_lost", Callable(self, "_on_enemy_hound_lost")):
		patrol.connect("robot_lost", Callable(self, "_on_enemy_hound_lost"))
	push_debug_event("阶段16装甲巡逻已生成：%s" % patrol.name)

func _spawn_enemy_nest(data: Dictionary) -> void:
	var nest_id := StringName(str(data.get("id", IdProvider.next_id(&"enemy_nest"))))
	var nest_type := StringName(str(data.get("nest_type", "weak_scavenger_nest")))
	var nest_config := EnemyConfigLoaderScript.get_type(enemy_config, "nest_types", nest_type)
	if nest_config.is_empty():
		push_warning("Unknown enemy nest type: %s" % String(nest_type))
		return
	var origin := MapConfigLoaderScript.get_vector2i(data, "grid_origin")
	var grid_size := MapConfigLoaderScript.get_vector2i(nest_config, "grid_size", Vector2i(2, 2))
	if not grid_occupancy.register_rect(origin, grid_size, null):
		push_warning("Enemy nest cannot occupy grid rect: %s @ %s" % [String(nest_id), origin])
		return

	var nest := EnemyNestScene.instantiate()
	nest.name = String(nest_id)
	var layer := _get_layer("EnemyLayer")
	(layer if layer else self).add_child(nest)
	nest.call("setup_nest", nest_id, nest_type, nest_config, origin, _get_grid_cell_size())
	grid_occupancy.clear_rect(origin, grid_size)
	grid_occupancy.register_rect(origin, grid_size, nest)
	_mark_navigation_dirty()
	nest.connect("guard_spawn_requested", Callable(self, "_on_enemy_nest_guard_spawn_requested"))
	nest.connect("nest_destroyed", Callable(self, "_on_enemy_nest_destroyed"))
	if nest.has_signal("building_destroyed"):
		nest.connect("building_destroyed", Callable(self, "_on_building_destroyed"))
	enemy_nests_by_id[nest_id] = nest
	nest.call_deferred("spawn_initial_guards")
	push_debug_event("敌巢已生成：%s @ %s, %s，距离起始矿区较远" % [nest.call("get_display_name"), origin.x, origin.y])

func _initialize_region_fog(map_config: Dictionary = {}) -> void:
	if grid_map == null:
		return
	map_region_states.clear()
	map_region_signal_cells.clear()
	map_region_definitions = map_config.get("regions", []).duplicate(true)
	map_region_routes = map_config.get("region_routes", []).duplicate(true)
	map_region_connections = _normalize_region_connections(map_config.get("region_connections", []))
	map_water_bodies = map_config.get("water_bodies", []).duplicate(true)
	map_frontline_supply_points = map_config.get("frontline_supply_points", []).duplicate(true)
	var region_size := FOG_REGION_SIZE_CELLS
	var map_size: Vector2i = grid_map.get("map_size_cells")
	var region_count := Vector2i(ceili(float(map_size.x) / float(region_size)), ceili(float(map_size.y) / float(region_size)))
	_rebuild_static_map_cache()
	for x in range(region_count.x):
		for y in range(region_count.y):
			map_region_states[_region_key(Vector2i(x, y))] = "unknown"
	map_region_blocks = _build_region_blocks_from_cached_tiles(region_count, region_size)
	_apply_region_default_discovery_states(region_count)
	_mark_starting_resource_basin_scanned(region_count, region_size)
	for nest in enemy_nests_by_id.values():
		if nest == null or not is_instance_valid(nest):
			continue
		_mark_enemy_nest_signal(nest, region_size)
	_mark_pending_enemy_presence_signals(region_size)
	_apply_region_fog_to_grid()

func _update_region_after_nest_destroyed(nest: Node) -> void:
	if nest == null:
		return
	var region_size := FOG_REGION_SIZE_CELLS
	var nest_region := _region_for_cell(nest.get("grid_origin"), region_size)
	var nest_key := _region_key(nest_region)
	map_region_states[nest_key] = "controlled"
	map_region_signal_cells.erase(nest_key)
	for neighbor in [
		nest_region + Vector2i(1, 0),
		nest_region + Vector2i(0, 1),
		nest_region + Vector2i(1, 1),
	]:
		var key := _region_key(neighbor)
		if map_region_states.has(key) and str(map_region_states[key]) == "unknown":
			map_region_states[key] = "signal"
	_apply_region_fog_to_grid()

func _apply_region_fog_to_grid() -> void:
	if grid_map == null:
		return
	var overlay: Node = grid_map.get("grid_overlay")
	if overlay and overlay.has_method("set_region_states"):
		overlay.set("fog_region_size_cells", FOG_REGION_SIZE_CELLS)
		overlay.call("set_region_states", map_region_states)
		if overlay.has_method("set_region_signals"):
			overlay.call("set_region_signals", map_region_signal_cells)

func _rebuild_static_map_cache() -> void:
	map_painted_region_cells_cache.clear()
	map_semantic_cells_by_tag_cache.clear()
	map_minimap_static_snapshot.clear()
	if grid_map == null:
		return
	if grid_map.has_method("invalidate_semantic_cache"):
		grid_map.call("invalidate_semantic_cache")
	if grid_map.has_method("get_painted_region_cells"):
		for cell_value in grid_map.call("get_painted_region_cells"):
			if typeof(cell_value) != TYPE_DICTIONARY:
				continue
			var painted_cell: Dictionary = cell_value
			map_painted_region_cells_cache.append(_merge_region_metadata(painted_cell))
	if grid_map.has_method("get_semantic_cells_by_tags"):
		var batched: Dictionary = grid_map.call("get_semantic_cells_by_tags", MINIMAP_SEMANTIC_TAGS)
		for tag in MINIMAP_SEMANTIC_TAGS:
			map_semantic_cells_by_tag_cache[tag] = batched.get(tag, [])
	elif grid_map.has_method("get_semantic_cells_by_tag"):
		for tag in MINIMAP_SEMANTIC_TAGS:
			map_semantic_cells_by_tag_cache[tag] = grid_map.call("get_semantic_cells_by_tag", tag)
	var map_size: Vector2i = grid_map.get("map_size_cells")
	map_static_cache_version += 1
	map_minimap_static_snapshot = _build_minimap_static_snapshot(map_size)

func _build_region_blocks_from_cached_tiles(region_count: Vector2i, region_size: int) -> Dictionary:
	var block_counts := {}
	var block_infos := {}
	for cell_value in map_painted_region_cells_cache:
		if typeof(cell_value) != TYPE_DICTIONARY:
			continue
		var region_info: Dictionary = cell_value
		var region_id := str(region_info.get("region_id", ""))
		if region_id.is_empty():
			continue
		var cell: Vector2i = region_info.get("cell", Vector2i.ZERO)
		var region := _region_for_cell(cell, region_size)
		if region.x < 0 or region.y < 0 or region.x >= region_count.x or region.y >= region_count.y:
			continue
		var key := _region_key(region)
		if not block_counts.has(key):
			block_counts[key] = {}
			block_infos[key] = {}
		var counts: Dictionary = block_counts[key]
		counts[region_id] = int(counts.get(region_id, 0)) + 1
		block_counts[key] = counts
		var infos: Dictionary = block_infos[key]
		infos[region_id] = region_info
		block_infos[key] = infos
	var result := {}
	for key in block_counts.keys():
		var counts: Dictionary = block_counts[key]
		var best_region_id := ""
		var best_count := -1
		for region_id_value in counts.keys():
			var region_id := str(region_id_value)
			var count := int(counts[region_id_value])
			if count > best_count:
				best_count = count
				best_region_id = region_id
		if best_region_id.is_empty():
			continue
		var infos: Dictionary = block_infos.get(key, {})
		result[key] = infos.get(best_region_id, {}).duplicate(true)
	return result

func _merge_region_metadata(region_info: Dictionary) -> Dictionary:
	if region_info.is_empty():
		return {}
	var result := region_info.duplicate(true)
	var region_id := str(result.get("region_id", ""))
	if region_id.is_empty():
		return result
	for region_value in map_region_definitions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		if str(region.get("region_id", "")) != region_id:
			continue
		for key in ["region_type", "display_name", "threat_level", "recommended_stage", "discovery_state", "minimap_color"]:
			if region.has(key):
				result[key] = region[key]
		break
	return result

func _apply_region_default_discovery_states(region_count: Vector2i) -> void:
	for region_value in map_region_definitions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		var discovery_state := str(region.get("discovery_state", "unknown"))
		if discovery_state == "unknown":
			continue
		for key in map_region_blocks.keys():
			var block: Dictionary = map_region_blocks[key]
			if str(block.get("region_id", "")) != str(region.get("region_id", "")):
				continue
			var region_cell := _parse_region_key(str(key))
			_mark_region_state(region_cell, region_count, discovery_state)

func _mark_starting_resource_basin_scanned(region_count: Vector2i, region_size: int) -> void:
	if resource_nodes_by_cell.is_empty():
		for region in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			_mark_region_state(region, region_count, "scanned")
		return

	var min_region := Vector2i(999999, 999999)
	var max_region := Vector2i(-999999, -999999)
	for cell_value in resource_nodes_by_cell.keys():
		var cell: Vector2i = cell_value
		var region_id := _get_region_id_for_cell_from_config(cell)
		if not _is_region_id_unlocked(region_id):
			continue
		var region := _region_for_cell(cell, region_size)
		min_region.x = mini(min_region.x, region.x)
		min_region.y = mini(min_region.y, region.y)
		max_region.x = maxi(max_region.x, region.x)
		max_region.y = maxi(max_region.y, region.y)
	if min_region.x >= 999999:
		for region in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			_mark_region_state(region, region_count, "scanned")
		return

	for x in range(min_region.x, max_region.x + 1):
		for y in range(min_region.y, max_region.y + 1):
			_mark_region_state(Vector2i(x, y), region_count, "scanned")

func _mark_enemy_nest_signal(nest: Node, region_size: int) -> void:
	var origin: Vector2i = nest.get("grid_origin")
	var size: Vector2i = nest.get("grid_size")
	var nest_region := _region_for_cell(origin, region_size)
	var key := _region_key(nest_region)
	map_region_states[key] = "signal"
	var centers: Array = map_region_signal_cells.get(key, [])
	centers.append({
		"cell": Vector2(origin) + Vector2(size) * 0.5,
		"size_cells": [size.x, size.y],
		"signal_type": str(nest.get("nest_type")),
	})
	map_region_signal_cells[key] = centers

func _mark_pending_enemy_presence_signals(region_size: int) -> void:
	for pending in map_pending_enemy_nests:
		if typeof(pending) == TYPE_DICTIONARY:
			_mark_pending_enemy_signal(pending, region_size, "armored_activity")
	for pending in map_pending_enemy_patrols:
		if typeof(pending) == TYPE_DICTIONARY:
			_mark_pending_enemy_signal(pending, region_size, "weak_nest")

func _mark_pending_enemy_signal(data: Dictionary, region_size: int, fallback_signal_type: String) -> void:
	var origin := MapConfigLoaderScript.get_vector2i(data, "grid_origin", Vector2i(-999999, -999999))
	if origin.x <= -999999:
		return
	var size := _pending_enemy_signal_size(data)
	var region := _region_for_cell(origin, region_size)
	var key := _region_key(region)
	if map_region_states.has(key) and str(map_region_states[key]) == "unknown":
		map_region_states[key] = "signal"
	var centers: Array = map_region_signal_cells.get(key, [])
	var signal_payload := {
		"cell": [origin.x + float(size.x) * 0.5, origin.y + float(size.y) * 0.5] if size.x > 0 else [origin.x, origin.y],
		"signal_type": str(data.get("signal_type", fallback_signal_type)),
		"locked_presence": true,
	}
	if size.x > 0 and size.y > 0:
		signal_payload["size_cells"] = [size.x, size.y]
		signal_payload["signal_type"] = str(data.get("nest_type", signal_payload["signal_type"]))
	centers.append(signal_payload)
	map_region_signal_cells[key] = centers

func _pending_enemy_signal_size(data: Dictionary) -> Vector2i:
	var nest_type := StringName(str(data.get("nest_type", "")))
	if String(nest_type).is_empty():
		return Vector2i.ZERO
	var nest_config := EnemyConfigLoaderScript.get_type(enemy_config, "nest_types", nest_type)
	if nest_config.is_empty():
		return Vector2i(2, 2)
	return MapConfigLoaderScript.get_vector2i(nest_config, "grid_size", Vector2i(2, 2))

func _mark_region_state(region: Vector2i, region_count: Vector2i, state: String) -> void:
	if region.x < 0 or region.y < 0 or region.x >= region_count.x or region.y >= region_count.y:
		return
	map_region_states[_region_key(region)] = state

func _region_for_cell(cell: Vector2i, region_size: int) -> Vector2i:
	return Vector2i(floori(float(cell.x) / float(region_size)), floori(float(cell.y) / float(region_size)))

func _region_key(region: Vector2i) -> String:
	return "%d,%d" % [region.x, region.y]

func _parse_region_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

func _on_enemy_nest_guard_spawn_requested(nest: Node, guard_type: StringName) -> void:
	if nest == null or not is_instance_valid(nest) or not bool(nest.call("is_alive")):
		return
	var guard_config := EnemyConfigLoaderScript.get_type(enemy_config, "unit_types", guard_type)
	if guard_config.is_empty():
		push_warning("Unknown enemy guard type: %s" % String(guard_type))
		return
	var layer := _get_layer("EnemyLayer")
	var pool_name := str(guard_config.get("pool_name", guard_type))
	var guard := ObjectPool.get_instance(ScavengerHoundScene, layer if layer else self, pool_name) as CharacterBody2D
	if guard == null:
		return
	guard.name = IdProvider.next_id(guard_type)
	var guard_slot_index := -1
	if nest.has_method("reserve_guard_slot"):
		guard_slot_index = int(nest.call("reserve_guard_slot"))
	guard.global_position = nest.call("get_spawn_position", guard_slot_index)
	guard.call("setup_scavenger_hound", guard_config, nest)
	if guard.has_signal("robot_lost") and not guard.is_connected("robot_lost", Callable(self, "_on_enemy_hound_lost")):
		guard.connect("robot_lost", Callable(self, "_on_enemy_hound_lost"))
	if nest.has_method("register_guard_at_slot"):
		nest.call("register_guard_at_slot", guard, guard_slot_index)
	else:
		nest.call("register_guard", guard)
	push_debug_event("敌巢补充守军：%s" % guard.name)

func _on_enemy_hound_lost(hound: Node, reason: StringName) -> void:
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log and event_log.has_method("record"):
		var payload := {
			"enemy_id": hound.name,
			"enemy_type": str(hound.get("pool_name")) if hound.get("pool_name") != null else "enemy_guard",
			"reason": String(reason),
		}
		if hound.has_method("get_last_damage_source_payload"):
			var source_payload: Dictionary = hound.call("get_last_damage_source_payload")
			payload["killer_robot_id"] = str(source_payload.get("robot_id", ""))
			payload["killer_blueprint_id"] = str(source_payload.get("blueprint_id", ""))
			payload["killer_blueprint_version"] = int(source_payload.get("blueprint_version", 0))
			payload["killer_blueprint_snapshot_id"] = str(source_payload.get("blueprint_snapshot_id", ""))
			payload["killer_blueprint_name"] = str(source_payload.get("blueprint_name", ""))
		event_log.call("record", &"enemy_killed", payload)
	_spawn_salvage_drops_for_enemy(hound)
	if hound != null and is_instance_valid(hound) and str(hound.get("pool_name")) == "wreckage_titan":
		_on_final_boss_defeated(hound)

func _spawn_salvage_drops_for_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
		return
	var enemy_type := StringName(str(enemy.get("pool_name")))
	var enemy_def := EnemyConfigLoaderScript.get_type(enemy_config, "unit_types", enemy_type)
	if enemy_def.is_empty():
		return
	var drops: Array = enemy_def.get("drops", [])
	if drops.is_empty():
		return
	var base_cell: Vector2i = grid_map.call("world_to_grid", (enemy as Node2D).global_position) if grid_map else Vector2i.ZERO
	var reserved_cells := {}
	var index := 0
	for drop_value in drops:
		if typeof(drop_value) != TYPE_DICTIONARY:
			continue
		var drop: Dictionary = drop_value.duplicate(true)
		var preferred_cell := base_cell + Vector2i(index % 2, floori(float(index) / 2.0))
		drop["id"] = "drop_%s_%d" % [enemy.name, index]
		drop["source_enemy"] = str(enemy_type)
		if not _assign_salvage_spawn_cell(drop, preferred_cell, reserved_cells):
			index += 1
			continue
		var pickup := _spawn_salvage_pickup(drop)
		if pickup != null:
			_record_salvage_event(&"salvage_dropped", pickup, enemy)
		index += 1

func _spawn_cargo_drops_for_lost_robot(robot: Node) -> void:
	if robot == null or not is_instance_valid(robot) or not (robot is Node2D):
		return
	if String(robot.get("team")) != "Team_A":
		return
	if not robot.has_method("get_cargo_inventory"):
		return
	var cargo: Dictionary = robot.call("get_cargo_inventory")
	if cargo.is_empty():
		return
	var base_cell: Vector2i = grid_map.call("world_to_grid", (robot as Node2D).global_position) if grid_map else Vector2i.ZERO
	var reserved_cells := {}
	var index := 0
	for resource_key in cargo.keys():
		var amount := int(cargo[resource_key])
		if amount <= 0:
			continue
		var resource_id := StringName(str(resource_key))
		var drop := {
			"id": "cargo_drop_%s_%d" % [robot.name, index],
			"resource_id": String(resource_id),
			"amount": amount,
			"value": maxi(1, amount),
			"salvage_type": "cargo_wreckage",
			"source_enemy": str(robot.name),
		}
		var key_item_id := _infer_key_item_from_salvage_resource(resource_id)
		if not String(key_item_id).is_empty():
			drop["key_item_id"] = String(key_item_id)
			drop["strategic_reward"] = true
			drop["salvage_type"] = "key_drop"
		var preferred_cell := base_cell + Vector2i(index % 2, floori(float(index) / 2.0))
		if not _assign_salvage_spawn_cell(drop, preferred_cell, reserved_cells):
			index += 1
			continue
		var pickup := _spawn_salvage_pickup(drop)
		if pickup != null:
			_record_salvage_event(&"cargo_salvage_dropped", pickup, robot)
		index += 1

func _on_final_boss_defeated(boss: Node) -> void:
	push_debug_event("Final boss defeated: Wreckage Titan")
	if hud and hud.has_method("show_bottom_prompt"):
		hud.call("show_bottom_prompt", "最终 Boss 已击败：干扰高原核心被摧毁。", 4.0, &"success")
	set_current_goal("最终 Boss 已击败：回收战利品并复盘战斗。")
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log and event_log.has_method("record"):
		event_log.call("record", &"final_boss_defeated", {
			"boss_id": boss.name if boss != null and is_instance_valid(boss) else "wreckage_titan",
			"boss_type": "wreckage_titan",
		})
	_refresh_campaign_hud()

func _record_salvage_event(event_type: StringName, pickup: Node, source: Node = null) -> void:
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log == null or not event_log.has_method("record") or pickup == null:
		return
	event_log.call("record", event_type, {
		"pickup_id": String(pickup.get("pickup_id")),
		"resource_id": String(pickup.get("resource_id")),
		"amount": int(pickup.get("amount")),
		"value": int(pickup.get("value")),
		"source": source.name if source != null and is_instance_valid(source) else "",
	})

func _on_enemy_nest_destroyed(nest: Node) -> void:
	_apply_abstract_nest_reward(nest)
	_update_region_after_nest_destroyed(nest)
	_unlock_region_gates_for_nest(nest)
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log and event_log.has_method("record"):
		event_log.call("record", &"nest_destroyed", {
			"nest_id": String(nest.get("nest_id")),
			"time_alive": float(nest.get("time_alive_seconds")),
			"reward": nest.get("reward"),
		})
	if hud and hud.has_method("show_victory_summary"):
		hud.call("show_victory_summary", _build_victory_summary(nest))
	_play_audio_cue(&"enemy_nest_destroyed")
	push_debug_event("胜利：敌巢已摧毁")
	_refresh_campaign_hud()

func _unlock_region_gates_for_nest(nest: Node) -> void:
	if nest == null:
		return
	var nest_id := str(nest.get("nest_id"))
	if nest_id.is_empty():
		return
	var unlocked_regions: Array[String] = []
	var unlocked_gate_ids: Array[String] = []
	for connection_value in map_region_connections:
		if typeof(connection_value) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_value
		var gate_id := str(connection.get("id", ""))
		if gate_id.is_empty() or str(map_region_gate_states.get(gate_id, "open")) == "open":
			continue
		if _get_connection_unlock_source(connection) != nest_id:
			continue
		map_region_gate_states[gate_id] = "open"
		unlocked_gate_ids.append(gate_id)
		var target_region := str(connection.get("to_region_id", ""))
		if not target_region.is_empty() and not unlocked_regions.has(target_region):
			unlocked_regions.append(target_region)
		if _region_gate_overlay != null and is_instance_valid(_region_gate_overlay) and _region_gate_overlay.has_method("animate_gate"):
			_region_gate_overlay.call("animate_gate", gate_id)
	for gate_id in unlocked_gate_ids:
		push_debug_event("区域通道已开启：%s" % gate_id)
	if unlocked_gate_ids.is_empty():
		return
	_refresh_region_gate_runtime_state()
	for region_id in unlocked_regions:
		_activate_region_content(region_id)
	_mark_regions_discovered_after_gate_unlock(unlocked_regions)
	_refresh_resource_gate_states()
	_apply_region_fog_to_grid()

func _unlock_region_gates_for_technology(technology_id: StringName) -> void:
	if String(technology_id).is_empty():
		return
	var unlocked_regions: Array[String] = []
	var unlocked_gate_ids: Array[String] = []
	for connection_value in map_region_connections:
		if typeof(connection_value) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_value
		var gate_id := str(connection.get("id", ""))
		if gate_id.is_empty() or str(map_region_gate_states.get(gate_id, "open")) == "open":
			continue
		if _get_connection_unlock_technology(connection) != String(technology_id):
			continue
		map_region_gate_states[gate_id] = "open"
		unlocked_gate_ids.append(gate_id)
		var target_region := str(connection.get("to_region_id", ""))
		if not target_region.is_empty() and not unlocked_regions.has(target_region):
			unlocked_regions.append(target_region)
		if _region_gate_overlay != null and is_instance_valid(_region_gate_overlay) and _region_gate_overlay.has_method("animate_gate"):
			_region_gate_overlay.call("animate_gate", gate_id)
	for gate_id in unlocked_gate_ids:
		push_debug_event("Technology gate opened: %s" % gate_id)
	if unlocked_gate_ids.is_empty():
		return
	_refresh_region_gate_runtime_state()
	for region_id in unlocked_regions:
		_activate_region_content(region_id)
	_mark_regions_discovered_after_gate_unlock(unlocked_regions)
	_refresh_resource_gate_states()
	_apply_region_fog_to_grid()

func _unlock_region_gates_for_key_item(key_item_id: StringName) -> void:
	if String(key_item_id).is_empty():
		return
	var unlocked_regions: Array[String] = []
	var unlocked_gate_ids: Array[String] = []
	for connection_value in map_region_connections:
		if typeof(connection_value) != TYPE_DICTIONARY:
			continue
		var connection: Dictionary = connection_value
		var gate_id := str(connection.get("id", ""))
		if gate_id.is_empty() or str(map_region_gate_states.get(gate_id, "open")) == "open":
			continue
		if _get_connection_unlock_key_item(connection) != String(key_item_id):
			continue
		map_region_gate_states[gate_id] = "open"
		unlocked_gate_ids.append(gate_id)
		var target_region := str(connection.get("to_region_id", ""))
		if not target_region.is_empty() and not unlocked_regions.has(target_region):
			unlocked_regions.append(target_region)
		if _region_gate_overlay != null and is_instance_valid(_region_gate_overlay) and _region_gate_overlay.has_method("animate_gate"):
			_region_gate_overlay.call("animate_gate", gate_id)
	for gate_id in unlocked_gate_ids:
		push_debug_event("Key item gate opened: %s" % gate_id)
	if unlocked_gate_ids.is_empty():
		return
	_refresh_region_gate_runtime_state()
	for region_id in unlocked_regions:
		_activate_region_content(region_id)
	_mark_regions_discovered_after_gate_unlock(unlocked_regions)
	_refresh_resource_gate_states()
	_apply_region_fog_to_grid()

func _activate_region_content(region_id: String) -> void:
	if region_id.is_empty():
		return
	for index in range(map_pending_enemy_patrols.size() - 1, -1, -1):
		var data: Dictionary = map_pending_enemy_patrols[index]
		if _get_map_item_region_id(data) != region_id:
			continue
		_spawn_enemy_patrol(data)
		map_pending_enemy_patrols.remove_at(index)
	for index in range(map_pending_enemy_nests.size() - 1, -1, -1):
		var data: Dictionary = map_pending_enemy_nests[index]
		if _get_map_item_region_id(data) != region_id:
			continue
		if _is_nest_defeated_in_campaign(StringName(str(data.get("id", "")))):
			map_pending_enemy_nests.remove_at(index)
			continue
		_spawn_enemy_nest(data)
		map_pending_enemy_nests.remove_at(index)

func _activate_all_unlocked_region_content() -> void:
	var unlocked_regions: Array[String] = []
	for region_value in map_region_definitions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		var region_id := str(region.get("region_id", ""))
		if _is_region_id_unlocked(region_id):
			unlocked_regions.append(region_id)
	for region_id in unlocked_regions:
		_activate_region_content(region_id)

func _mark_regions_discovered_after_gate_unlock(region_ids: Array[String]) -> void:
	for cell_key in map_region_blocks.keys():
		var block: Dictionary = map_region_blocks[cell_key]
		var region_id := str(block.get("region_id", ""))
		if not region_ids.has(region_id):
			continue
		map_region_signal_cells.erase(cell_key)
		var state := str(map_region_states.get(cell_key, "unknown"))
		if state == "unknown" or state == "signal":
			map_region_states[cell_key] = "scanned"

func _apply_abstract_nest_reward(nest: Node) -> void:
	if campaign_state == null or nest == null:
		return
	var nest_id := StringName(str(nest.get("nest_id")))
	campaign_state.mark_nest_defeated(nest_id)
	var reward: Dictionary = nest.get("reward")
	if bool(reward.get("requires_salvage_return", false)):
		_spawn_salvage_reward_for_nest(nest, reward)
		return
	if reward.has("technology_item"):
		var technology_item := str(reward.get("technology_item", ""))
		var key_item_id := KEY_ITEM_INITIAL_SENSOR_COIL if technology_item == "初级感应线圈" else StringName(technology_item)
		campaign_state.add_key_item(key_item_id)
		push_debug_event("抽象回收关键道具：%s" % _get_key_item_display_name(key_item_id))
		set_current_goal("建造研究终端，并在科技菜单中研究阶段 1 科技")

func _spawn_salvage_reward_for_nest(nest: Node, reward: Dictionary) -> void:
	if nest == null or not is_instance_valid(nest):
		return
	var drop: Dictionary = reward.get("salvage_drop", {}).duplicate(true)
	var technology_item := str(reward.get("technology_item", ""))
	var key_item_id := StringName(str(drop.get("key_item_id", technology_item)))
	var resource_id := StringName(str(drop.get("resource_id", technology_item)))
	if String(resource_id).is_empty():
		resource_id = key_item_id
	if String(resource_id).is_empty():
		return
	var origin: Vector2i = nest.get("grid_origin")
	var size: Vector2i = nest.get("grid_size")
	var drop_cell := origin + Vector2i(maxi(0, size.x), maxi(0, floori(float(size.y) * 0.5)))
	drop["id"] = str(drop.get("id", "%s_reward_drop" % String(nest.get("nest_id"))))
	drop["resource_id"] = String(resource_id)
	drop["key_item_id"] = String(key_item_id)
	drop["grid_origin"] = drop.get("grid_origin", _vector2i_to_array(drop_cell))
	drop["grid_size"] = drop.get("grid_size", [1, 1])
	drop["amount"] = int(drop.get("amount", 1))
	drop["value"] = int(drop.get("value", 90))
	drop["salvage_type"] = str(drop.get("salvage_type", "key_drop"))
	drop["source_enemy"] = String(nest.get("nest_id"))
	drop["strategic_reward"] = bool(drop.get("strategic_reward", true))
	drop["requires_tether"] = bool(drop.get("requires_tether", false))
	var pickup := _spawn_salvage_pickup(drop)
	if pickup != null:
		push_debug_event("关键奖励已掉落，需回收：%s" % _get_key_item_display_name(key_item_id))

func _get_key_item_display_name(key_item_id: StringName) -> String:
	for resource_def in resource_defs:
		if resource_def.id == key_item_id:
			return resource_def.display_name
	return String(key_item_id)

func _build_victory_summary(nest: Node) -> Dictionary:
	var event_log := get_node_or_null("/root/CombatEventLog")
	var events: Array[Dictionary] = []
	if event_log and event_log.has_method("get_recent_events"):
		events = event_log.call("get_recent_events", 0.0, "")
	var rule_names := {}
	var produced := 0
	var lost := 0
	var killed := 0
	var triggered := 0
	for event in events:
		var event_type := str(event.get("type", ""))
		if event_type == "robot_produced":
			produced += 1
		elif event_type == "robot_lost":
			lost += 1
		elif event_type == "enemy_killed":
			killed += 1
		elif event_type == "rule_triggered":
			triggered += 1
			var rule_name := str(event.get("payload", {}).get("rule_name", "未命名规则"))
			rule_names[rule_name] = int(rule_names.get(rule_name, 0)) + 1
	return {
		"target": nest.call("get_display_name"),
		"elapsed_seconds": Time.get_ticks_msec() / 1000.0 - stage_started_seconds,
		"robots_produced": produced,
		"robots_lost": lost,
		"enemies_killed": killed,
		"rules_triggered": triggered,
		"rule_names": rule_names,
		"reward": nest.get("reward"),
	}

func _get_world_path_points(grid_path: Variant) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if grid_map == null or typeof(grid_path) != TYPE_ARRAY:
		return points
	for value in grid_path:
		if typeof(value) != TYPE_ARRAY or value.size() < 2:
			continue
		var cell := Vector2i(int(value[0]), int(value[1]))
		if bool(grid_map.call("is_cell_in_bounds", cell)):
			points.append(grid_map.call("grid_to_world", cell))
	return points

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
		var use_entity_logistics := stage14_remote_logistics_enabled and not _is_in_main_base_service_radius(origin, building_def.grid_size)
		building.call("setup_miner", _get_resource_node_at(origin), inventory, use_entity_logistics)
		_apply_producer_recipe_upgrade(building)
		if building.has_signal("miner_state_changed"):
			building.connect("miner_state_changed", Callable(self, "_on_miner_state_changed").bind(building))
	elif _is_processor_def(building_def) and building.has_method("setup_processor"):
		building.call("setup_processor", _get_resource_recipes_for_processor(building_def), inventory)
		if building.has_signal("processor_state_changed"):
			building.connect("processor_state_changed", Callable(self, "_on_processor_state_changed").bind(building))
	elif _is_robot_forge_def(building_def) and building.has_method("setup_forge"):
		building.call("setup_forge", _create_blueprint_snapshot(basic_rifle_blueprint), inventory)
		if building.has_signal("forge_state_changed"):
			building.connect("forge_state_changed", Callable(self, "_on_forge_state_changed").bind(building))
		if building.has_signal("robot_production_completed"):
			building.connect("robot_production_completed", Callable(self, "_on_forge_robot_production_completed"))
	elif _is_research_terminal_def(building_def) and building.has_method("setup_research_terminal"):
		building.call("setup_research_terminal", inventory, campaign_state)
		if building.has_signal("research_state_changed"):
			building.connect("research_state_changed", Callable(self, "_on_research_terminal_state_changed").bind(building))
		if building.has_signal("research_completed"):
			building.connect("research_completed", Callable(self, "_on_research_completed"))
		if not research_terminals.has(building):
			research_terminals.append(building)
	elif _is_water_pump_def(building_def) and building.has_method("setup_water_pump"):
		var use_entity_logistics := stage14_remote_logistics_enabled and not _is_in_main_base_service_radius(origin, building_def.grid_size)
		building.call("setup_water_pump", inventory, use_entity_logistics)
		_apply_producer_recipe_upgrade(building)
		if building.has_signal("water_pump_state_changed"):
			building.connect("water_pump_state_changed", Callable(self, "_on_water_pump_state_changed").bind(building))

func _get_resource_recipes() -> Array[RecipeDef]:
	var result: Array[RecipeDef] = []
	for recipe in recipe_defs:
		if recipe.recipe_type == &"resource" and _is_resource_recipe_unlocked(recipe):
			result.append(_make_effective_resource_recipe(recipe))
	return result

func _get_resource_recipes_for_processor(building_def: BuildingDef) -> Array[RecipeDef]:
	var allowed_recipe_ids: Array[StringName] = []
	if building_def != null and building_def.id == MvpDataDefaults.BUILDING_ADVANCED_PROCESSOR:
		allowed_recipe_ids = [
			&"process_reinforced_steel_plate",
			&"process_optical_lens",
			&"process_high_capacity_battery",
			&"decompose_wreckage_scrap_to_alloy",
			&"decompose_heavy_wreckage_to_servo",
			&"analyze_salvage_data_core",
		]
	else:
		allowed_recipe_ids = [
			&"process_iron_plate",
			&"process_copper_wire",
		]
	var result: Array[RecipeDef] = []
	for recipe in _get_resource_recipes():
		if allowed_recipe_ids.has(recipe.id):
			result.append(recipe)
	return result

func _make_effective_resource_recipe(recipe: RecipeDef, forced_level: int = -1) -> RecipeDef:
	if recipe == null:
		return null
	var effective := RecipeDef.new()
	effective.id = recipe.id
	effective.display_name = recipe.display_name
	effective.recipe_type = recipe.recipe_type
	effective.target_id = recipe.target_id
	effective.duration_seconds = recipe.duration_seconds
	effective.source_path = recipe.source_path
	var level := forced_level
	if level < 0:
		level = _get_recipe_upgrade_level(recipe.target_id)
	effective.inputs = _scale_recipe_amounts(recipe.inputs, _get_recipe_input_multiplier(level), true)
	effective.outputs = _scale_recipe_amounts(recipe.outputs, _get_recipe_output_multiplier(level), true)
	return effective

func _scale_recipe_amounts(amounts: Dictionary, multiplier: float, ceil_costs: bool) -> Dictionary:
	var result := {}
	for resource_id in amounts.keys():
		var base_amount := int(amounts[resource_id])
		var scaled := ceili(float(base_amount) * multiplier) if ceil_costs else floori(float(base_amount) * multiplier)
		result[StringName(str(resource_id))] = maxi(base_amount, scaled)
	return result

func _get_recipe_upgrade_level(resource_id: StringName) -> int:
	if campaign_state == null or not campaign_state.has_method("get_recipe_upgrade_level"):
		return 0
	return int(campaign_state.call("get_recipe_upgrade_level", resource_id))

func _get_recipe_output_multiplier(level: int) -> float:
	return pow(RECIPE_UPGRADE_OUTPUT_MULTIPLIER, clampi(level, 0, RECIPE_UPGRADE_MAX_LEVEL))

func _get_recipe_input_multiplier(level: int) -> float:
	return pow(RECIPE_UPGRADE_INPUT_MULTIPLIER, clampi(level, 0, RECIPE_UPGRADE_MAX_LEVEL))

func _refresh_recipe_upgrade_effects() -> void:
	_apply_main_base_recipe_upgrade()
	var building_layer := _get_layer("BuildingLayer")
	if building_layer == null:
		return
	for child in building_layer.get_children():
		if child == null or not is_instance_valid(child):
			continue
		var building_def: BuildingDef = child.get("building_def")
		if _is_miner_def(building_def) or _is_water_pump_def(building_def):
			_apply_producer_recipe_upgrade(child)
		elif _is_processor_def(building_def) and child.has_method("setup_processor"):
			var selected_recipe_id := &""
			var selected_recipe: RecipeDef = child.get("selected_recipe")
			if selected_recipe != null:
				selected_recipe_id = selected_recipe.id
			child.call("setup_processor", _get_resource_recipes_for_processor(building_def), _get_main_base_inventory())
			if not String(selected_recipe_id).is_empty() and child.has_method("set_recipe"):
				child.call("set_recipe", selected_recipe_id)

func _apply_main_base_recipe_upgrade() -> void:
	if main_base == null or not is_instance_valid(main_base):
		return
	if not main_base.has_meta("base_construction_mass_per_minute"):
		main_base.set_meta("base_construction_mass_per_minute", int(main_base.get("construction_mass_per_minute")))
	var base_rate := int(main_base.get_meta("base_construction_mass_per_minute"))
	var level := _get_recipe_upgrade_level(MvpDataDefaults.RES_CONSTRUCTION_MASS)
	main_base.set("construction_mass_per_minute", maxi(1, ceili(float(base_rate) * _get_recipe_output_multiplier(level))))

func _apply_producer_recipe_upgrade(producer: Node) -> void:
	if producer == null or not is_instance_valid(producer):
		return
	var resource_id := _get_producer_output_resource_id(producer)
	if String(resource_id).is_empty():
		return
	if not producer.has_meta("base_output_per_minute"):
		producer.set_meta("base_output_per_minute", int(producer.get("output_per_minute")))
	var base_rate := int(producer.get_meta("base_output_per_minute"))
	var level := _get_recipe_upgrade_level(resource_id)
	producer.set("output_per_minute", maxi(1, ceili(float(base_rate) * _get_recipe_output_multiplier(level))))
	if producer.has_method("_rebuild_mining_recipe"):
		producer.call("_rebuild_mining_recipe")
	if producer.has_method("_rebuild_operation_recipe"):
		producer.call("_rebuild_operation_recipe")

func _get_producer_output_resource_id(producer: Node) -> StringName:
	if producer is WaterPumpBuilding:
		return MvpDataDefaults.RES_WATER
	if producer is MinerBuilding:
		return StringName(producer.get("output_resource_id"))
	if producer.get("output_resource_id") != null:
		return StringName(producer.get("output_resource_id"))
	return &""

func _is_resource_recipe_unlocked(recipe: RecipeDef) -> bool:
	if recipe == null:
		return false
	if campaign_state == null:
		return true
	return campaign_state.unlocked_resources.has(recipe.target_id)

func _is_runtime_debug_enabled() -> bool:
	return runtime_debug_enabled and RuntimeConfigLoaderScript.is_debug_enabled(runtime_profile)

func _is_debug_enemy_unit_node(node: Node) -> bool:
	if not _is_runtime_debug_enabled():
		return false
	if node == null or not is_instance_valid(node):
		return false
	return node is RobotUnit and String(node.get("team")) == "Team_B"

func _is_debug_enemy_nest_node(node: Node) -> bool:
	if not _is_runtime_debug_enabled():
		return false
	if node == null or not is_instance_valid(node):
		return false
	return node is EnemyNest and String(node.get("team")) == "Team_B"

func _show_operation_panel_for_node(node: Node) -> void:
	selected_operation_building = null
	if node == null:
		_hide_operation_panel()
		return
	if _is_cargo_robot_node(node):
		selected_operation_building = node
		operation_panel_refresh_seconds = 0.0
		_refresh_operation_panel()
		return
	if _is_debug_enemy_unit_node(node) or _is_debug_enemy_nest_node(node):
		selected_operation_building = node
		operation_panel_refresh_seconds = 0.0
		_refresh_operation_panel()
		return
	var building_def: BuildingDef = node.get("building_def")
	if _is_main_base_def(building_def):
		selected_operation_building = node
		operation_panel_refresh_seconds = 0.0
		_refresh_operation_panel()
	elif _is_producer_operation_node(node):
		selected_operation_building = node
		operation_panel_refresh_seconds = 0.0
		_refresh_operation_panel()
	elif _is_processor_def(building_def):
		selected_operation_building = node
		operation_panel_refresh_seconds = 0.0
		_refresh_operation_panel()
	elif _is_robot_forge_def(building_def):
		selected_operation_building = node
		operation_panel_refresh_seconds = 0.0
		_refresh_operation_panel()
	elif _is_research_terminal_def(building_def):
		selected_operation_building = node
		operation_panel_refresh_seconds = 0.0
		_refresh_operation_panel()
	elif _is_forward_supply_point_def(building_def):
		selected_operation_building = node
		operation_panel_refresh_seconds = 0.0
		_refresh_operation_panel()
	elif node is BaseBuilding and String(node.get("team")) == "Team_A":
		selected_operation_building = node
		operation_panel_refresh_seconds = 0.0
		_refresh_operation_panel()
	else:
		_hide_operation_panel()

func _refresh_operation_panel() -> void:
	if selected_operation_building == null or hud == null:
		return
	if _is_debug_enemy_unit_node(selected_operation_building) and hud.has_method("show_debug_enemy_panel"):
		hud.call(
			"show_debug_enemy_panel",
			selected_operation_building,
			_get_operation_panel_screen_position(selected_operation_building)
		)
		return
	if _is_debug_enemy_nest_node(selected_operation_building) and hud.has_method("show_debug_enemy_nest_panel"):
		hud.call(
			"show_debug_enemy_nest_panel",
			selected_operation_building,
			_get_operation_panel_screen_position(selected_operation_building)
		)
		return
	if _is_cargo_robot_node(selected_operation_building) and hud.has_method("show_cargo_robot_panel"):
		hud.call(
			"show_cargo_robot_panel",
			selected_operation_building,
			resource_defs,
			_world_to_screen(selected_operation_building.global_position)
		)
		return
	var building_def: BuildingDef = selected_operation_building.get("building_def")
	if _is_main_base_def(building_def) and hud.has_method("show_inventory_storage_panel"):
		hud.call(
			"show_inventory_storage_panel",
			selected_operation_building,
			resource_defs,
			_world_to_screen(selected_operation_building.global_position)
		)
	elif _is_processor_def(building_def) and hud.has_method("show_processor_panel"):
		hud.call(
			"show_processor_panel",
			selected_operation_building,
			_get_resource_recipes_for_processor(building_def),
			resource_defs,
			_world_to_screen(selected_operation_building.global_position)
		)
	elif _is_producer_operation_node(selected_operation_building) and hud.has_method("show_producer_panel"):
		hud.call(
			"show_producer_panel",
			selected_operation_building,
			resource_defs,
			_world_to_screen(selected_operation_building.global_position)
		)
	elif _is_robot_forge_def(building_def) and hud.has_method("show_forge_panel"):
		var forge_blueprint: UnitBlueprint = selected_operation_building.get("blueprint")
		hud.call(
			"show_forge_panel",
			selected_operation_building,
			forge_blueprint,
			blueprint_library.get_blueprints() if blueprint_library else [],
			resource_defs,
			_world_to_screen(selected_operation_building.global_position)
		)
	elif _is_research_terminal_def(building_def) and hud.has_method("show_research_terminal_panel"):
		hud.call(
			"show_research_terminal_panel",
			selected_operation_building,
			technology_defs,
			resource_defs,
			_world_to_screen(selected_operation_building.global_position)
		)
	elif _is_forward_supply_point_def(building_def) and hud.has_method("show_supply_point_panel"):
		hud.call(
			"show_supply_point_panel",
			selected_operation_building,
			resource_defs,
			_world_to_screen(selected_operation_building.global_position)
		)
	elif selected_operation_building is BaseBuilding and String(selected_operation_building.get("team")) == "Team_A" and hud.has_method("show_basic_building_panel"):
		hud.call(
			"show_basic_building_panel",
			selected_operation_building,
			_world_to_screen(selected_operation_building.global_position)
		)

func _get_operation_panel_screen_position(node: Node) -> Vector2:
	if node is Node2D:
		if node.has_method("get_target_position"):
			return _world_to_screen(node.call("get_target_position"))
		return _world_to_screen((node as Node2D).global_position)
	return get_viewport().get_mouse_position()

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

func _on_processor_pause_toggled(processor: Node) -> void:
	if processor and processor.has_method("toggle_paused"):
		processor.call("toggle_paused")
		push_debug_event("加工厂%s" % ("已暂停" if bool(processor.get("is_paused")) else "继续加工"))
	call_deferred("_refresh_operation_panel")

func _on_forge_pause_toggled(forge: Node) -> void:
	if forge and forge.has_method("toggle_paused"):
		forge.call("toggle_paused")
		push_debug_event("机器人锻造厂%s" % ("已暂停" if bool(forge.get("is_paused")) else "继续生产"))
	call_deferred("_refresh_operation_panel")

func _on_building_demolish_requested(building: Node) -> void:
	_demolish_building(building)

func _on_debug_kill_requested(target: Node) -> void:
	if not _is_runtime_debug_enabled():
		push_debug_event("Debug 击毁被拒绝：debug 总开关未开启")
		return
	if target == null or not is_instance_valid(target):
		return
	if not (_is_debug_enemy_unit_node(target) or _is_debug_enemy_nest_node(target)):
		push_debug_event("Debug 击毁被拒绝：目标不是敌方单位或敌巢")
		return
	if target.has_method("is_alive") and not bool(target.call("is_alive")):
		return
	var target_name: String = target.name
	if target.has_method("get_display_name"):
		target_name = str(target.call("get_display_name"))
	if _is_debug_enemy_unit_node(target):
		if target.has_method("die"):
			target.call("die", &"debug_kill")
		elif target.has_method("take_damage"):
			target.call("take_damage", maxi(1, int(target.get("max_hp"))))
	elif _is_debug_enemy_nest_node(target):
		if target.has_method("destroy"):
			target.call("destroy", &"debug_kill")
		elif target.has_method("take_damage"):
			target.call("take_damage", maxi(1, int(target.get("max_hp"))))
	if selected_operation_building == target:
		_hide_operation_panel()
	if selected_inspected_node == target:
		selected_inspected_node = null
	if selection_marker and selection_marker.has_method("clear_selection"):
		selection_marker.call("clear_selection")
	push_debug_event("Debug 击毁：%s" % target_name)

func _demolish_building(building: Node) -> void:
	if building == null or not is_instance_valid(building):
		return
	if not (building is BaseBuilding):
		return
	var building_def: BuildingDef = building.get("building_def")
	var origin: Vector2i = building.get("grid_origin")
	var size: Vector2i = building.get("grid_size")
	grid_occupancy.clear_rect(origin, size)
	_unbind_resource_for_demolished_building(building)
	_clear_logistics_tasks_for_node(building)
	if building == main_base:
		main_base = null
	if selected_operation_building == building:
		_hide_operation_panel()
	if selected_inspected_node == building:
		selected_inspected_node = null
		if hud and hud.has_method("inspect_cell"):
			hud.call("inspect_cell", origin, get_region_info_for_cell(origin), get_region_state_for_cell(origin))
	if selection_marker and selection_marker.has_method("clear_selection"):
		selection_marker.call("clear_selection")
	var rally_marker = building.get("rally_marker")
	if rally_marker != null and is_instance_valid(rally_marker):
		rally_marker.queue_free()
	push_debug_event("拆除建筑：%s" % (building_def.display_name if building_def else building.name))
	building.queue_free()
	_mark_navigation_dirty()
	_refresh_build_options()
	_refresh_resource_hud()
	_refresh_campaign_hud()

func _clear_logistics_tasks_for_node(node: Node) -> void:
	for robot in stage14_logistics_tasks_by_robot.keys():
		var task: Dictionary = stage14_logistics_tasks_by_robot[robot]
		if _get_stage14_task_node(task, "source") == node or _get_stage14_task_node(task, "target") == node:
			_clear_stage14_robot_task(robot)

func _unbind_resource_for_demolished_building(building: Node) -> void:
	if building is MinerBuilding:
		var bound_resource = building.get("bound_resource_node")
		if bound_resource != null and is_instance_valid(bound_resource):
			bound_resource.set("bound_miner", null)
			if bound_resource is CanvasItem:
				(bound_resource as CanvasItem).modulate = Color.WHITE
		return
	var origin: Vector2i = building.get("grid_origin")
	var resource_node := _get_resource_node_at(origin)
	if resource_node != null and is_instance_valid(resource_node):
		resource_node.set("bound_miner", null)
		if resource_node is CanvasItem:
			(resource_node as CanvasItem).modulate = Color.WHITE

func _on_miner_state_changed(miner: Node) -> void:
	if miner == selected_operation_building:
		call_deferred("_refresh_operation_panel")

func _on_processor_state_changed(processor: Node) -> void:
	if processor == selected_operation_building:
		call_deferred("_refresh_operation_panel")

func _on_forge_state_changed(forge: Node) -> void:
	if forge == selected_operation_building:
		call_deferred("_refresh_operation_panel")

func _on_research_terminal_state_changed(terminal: Node) -> void:
	if terminal == selected_operation_building:
		call_deferred("_refresh_operation_panel")
	_refresh_campaign_hud()

func _on_water_pump_state_changed(pump: Node) -> void:
	if pump == selected_inspected_node and hud and hud.has_method("inspect_node"):
		call_deferred("_refresh_selected_unit_inspector")
	_refresh_resource_hud()

func _on_research_completed(technology: Variant) -> void:
	push_debug_event("研究完成：%s" % technology.display_name)
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log and event_log.has_method("record"):
		event_log.call("record", &"technology_unlocked", {
			"technology_id": String(technology.id),
			"display_name": technology.display_name,
		})
	_refresh_campaign_hud()
	_refresh_build_options()

func _on_forge_robot_production_completed(forge: Node, blueprint: UnitBlueprint) -> void:
	if forge == null or blueprint == null:
		return
	var unit_layer := _get_layer("UnitLayer")
	var robot := ObjectPool.get_instance(RobotScene, unit_layer if unit_layer else self, "robot_basic") as CharacterBody2D
	if robot == null:
		return
	robot.name = IdProvider.next_id(&"robot")
	robot.set("team", "Team_A")
	robot.set("producer_forge_name", forge.name)
	robot.global_position = forge.call("get_spawn_position") if forge.has_method("get_spawn_position") else forge.global_position
	if robot.has_method("setup_from_blueprint"):
		robot.call(
			"setup_from_blueprint",
			blueprint,
			forge.get("rally_point_position"),
			bool(forge.get("has_rally_point"))
		)
	if robot.has_signal("robot_lost") and not robot.is_connected("robot_lost", Callable(self, "_on_robot_lost_for_blueprint_cleanup")):
		robot.connect("robot_lost", Callable(self, "_on_robot_lost_for_blueprint_cleanup"))
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
			"blueprint_name": blueprint.display_name,
			"blueprint_version": blueprint.version,
			"blueprint_snapshot_id": blueprint.get_snapshot_key(),
			"blueprint_rules": _get_blueprint_rule_summaries(blueprint),
			"blueprint_templates": _get_blueprint_template_summaries(blueprint),
			"active_upgrades": _string_name_array(blueprint.upgrade_ids),
			"rally_point": _format_vector2_payload(forge.get("rally_point_position")),
			"has_rally_point": bool(forge.get("has_rally_point")),
		})
	push_debug_event("锻造完成：%s -> %s" % [blueprint.display_name, robot.name])
	if hud and hud.has_method("show_bottom_prompt") and bool(forge.get("has_rally_point")):
		hud.call("show_bottom_prompt", "机器人已出厂，将前往锻造厂集结点。", 1.8, &"info")

func _tick_stage14_logistics(delta: float) -> void:
	if main_base == null:
		return
	_prune_stage14_logistics_tasks()
	_update_stage14_logistics_waits(delta)
	for robot in get_tree().get_nodes_in_group("cargo"):
		if not _is_available_stage14_cargo_robot(robot):
			continue
		if stage14_logistics_tasks_by_robot.has(robot):
			_advance_stage14_logistics_task(robot, stage14_logistics_tasks_by_robot[robot])
		else:
			_try_assign_stage14_logistics_task(robot)
	_refresh_stage14_logistics_diagnostics()

func _is_available_stage14_cargo_robot(robot: Node) -> bool:
	if robot == null or not is_instance_valid(robot):
		return false
	if not _is_cargo_robot_node(robot):
		return false
	if String(robot.get("team")) != "Team_A":
		return false
	if robot.has_method("is_alive") and not bool(robot.call("is_alive")):
		return false
	return true

func _prune_stage14_logistics_tasks() -> void:
	for robot in stage14_logistics_tasks_by_robot.keys():
		if not _is_available_stage14_cargo_robot(robot):
			stage14_logistics_tasks_by_robot.erase(robot)
			_clear_logistics_task_visual(robot)

func _try_assign_stage14_logistics_task(robot: Node) -> void:
	if _should_stage14_logistics_robot_evade(robot):
		var cargo_used := int(robot.call("get_cargo_used_capacity")) if robot.has_method("get_cargo_used_capacity") else 0
		if cargo_used > 0:
			if _assign_stage14_hazard_return_task(robot):
				return
		elif _assign_stage14_hazard_evasion_task(robot):
			return
	if _try_assign_stage14_existing_cargo_delivery(robot):
		return
	var task := _build_stage14_best_logistics_task(robot)
	if task.is_empty():
		return
	stage14_logistics_tasks_by_robot[robot] = task
	_sync_stage14_robot_task(robot, task)
	_update_logistics_task_visual(robot, task)

func _advance_stage14_logistics_task(robot: Node, task: Dictionary) -> void:
	var stage := str(task.get("stage", ""))
	var source := _get_stage14_task_node(task, "source")
	var target := _get_stage14_task_node(task, "target")
	_update_logistics_task_visual(robot, task)
	if _try_interrupt_stage14_task_for_hazard(robot, task):
		return
	if stage == "to_safe":
		var safe_position := _vector2_from_array(task.get("safe_position", [0.0, 0.0]))
		if robot is Node2D and (robot as Node2D).global_position.distance_to(safe_position) <= 40.0:
			_clear_stage14_robot_task(robot)
			return
		_move_logistics_robot_towards(robot, safe_position, str(task.get("status", "紧急避险：撤退到安全点")))
		return
	if stage == "to_pickup":
		if source == null or not is_instance_valid(source):
			_clear_stage14_robot_task(robot)
			return
		if _is_logistics_robot_near(robot, source):
			if _pickup_stage14_logistics_cargo(robot, task):
				task["stage"] = "to_dropoff"
				task["status"] = _get_stage14_dropoff_status(task)
				stage14_logistics_tasks_by_robot[robot] = task
				_sync_stage14_robot_task(robot, task)
				_update_logistics_task_visual(robot, task)
			else:
				_clear_stage14_robot_task(robot)
			return
		_move_logistics_robot_towards(robot, _get_logistics_node_position(source), "前往取货", source)
	elif stage == "to_dropoff":
		if target == null or not is_instance_valid(target):
			_clear_stage14_robot_task(robot)
			return
		if _is_logistics_robot_near(robot, target):
			_deliver_stage14_logistics_cargo(robot, task)
			_clear_stage14_robot_task(robot)
			return
		_move_logistics_robot_towards(robot, _get_logistics_node_position(target), _get_stage14_dropoff_status(task), target)
	else:
		_clear_stage14_robot_task(robot)

func _try_interrupt_stage14_task_for_hazard(robot: Node, task: Dictionary) -> bool:
	if _is_stage14_hazard_task(task):
		return false
	if not _should_stage14_logistics_robot_evade(robot):
		return false
	var cargo_used := int(robot.call("get_cargo_used_capacity")) if robot.has_method("get_cargo_used_capacity") else 0
	if cargo_used > 0:
		return _assign_stage14_hazard_return_task(robot)
	return _assign_stage14_hazard_evasion_task(robot)

func _is_stage14_hazard_task(task: Dictionary) -> bool:
	return str(task.get("type", "")) in ["hazard_return", "hazard_evasion"]

func _should_stage14_logistics_robot_evade(robot: Node) -> bool:
	if robot == null or not is_instance_valid(robot):
		return false
	if robot.has_method("hp_ratio") and float(robot.call("hp_ratio")) <= 0.45:
		return true
	if not (robot is Node2D):
		return false
	return _count_enemy_units_near((robot as Node2D).global_position, 220.0) >= 3

func _assign_stage14_hazard_return_task(robot: Node) -> bool:
	if main_base == null or not is_instance_valid(main_base):
		return false
	var cargo: Dictionary = robot.call("get_cargo_inventory") if robot.has_method("get_cargo_inventory") else {}
	for resource_id in cargo.keys():
		var amount := int(cargo[resource_id])
		if amount <= 0:
			continue
		var task := _make_stage14_task("hazard_return", robot, main_base, StringName(resource_id), amount, "紧急避险：携货返航", 0.0)
		task["stage"] = "to_dropoff"
		stage14_logistics_tasks_by_robot[robot] = task
		_sync_stage14_robot_task(robot, task)
		_update_logistics_task_visual(robot, task)
		push_debug_event("物流紧急避险：%s 携货返航" % robot.name)
		return true
	return false

func _assign_stage14_hazard_evasion_task(robot: Node) -> bool:
	if not (robot is Node2D):
		return false
	var safe_position := _get_nearest_stage14_safe_retreat_position(robot)
	var task := {
		"stage": "to_safe",
		"type": "hazard_evasion",
		"source": robot,
		"target": null,
		"resource_id": &"",
		"amount": 0,
		"status": "紧急避险：撤退到安全点",
		"score": 0.0,
		"safe_position": [safe_position.x, safe_position.y],
	}
	stage14_logistics_tasks_by_robot[robot] = task
	_sync_stage14_robot_task(robot, task)
	_update_logistics_task_visual(robot, task)
	push_debug_event("物流紧急避险：%s 撤退到安全点" % robot.name)
	return true

func _get_nearest_stage14_safe_retreat_position(robot: Node) -> Vector2:
	var robot_position: Vector2 = (robot as Node2D).global_position if robot is Node2D else Vector2.ZERO
	var best_position := Vector2.ZERO
	var best_distance := INF
	for forge in _get_player_buildings_by_id(MvpDataDefaults.BUILDING_ROBOT_FORGE):
		if forge == null or not is_instance_valid(forge) or not bool(forge.get("has_rally_point")):
			continue
		var rally_position: Vector2 = forge.get("rally_point_position")
		var distance := robot_position.distance_squared_to(rally_position)
		if distance < best_distance:
			best_distance = distance
			best_position = rally_position
	if best_distance < INF:
		return best_position
	if main_base != null and is_instance_valid(main_base):
		return _get_logistics_node_position(main_base)
	return robot_position

func _pickup_stage14_logistics_cargo(robot: Node, task: Dictionary) -> bool:
	var source := _get_stage14_task_node(task, "source")
	if source == null or not is_instance_valid(source):
		return false
	var resource_id := StringName(str(task.get("resource_id", "")))
	if String(resource_id).is_empty():
		return false
	var free_capacity := int(robot.call("get_cargo_free_capacity")) if robot.has_method("get_cargo_free_capacity") else 0
	var requested := int(task.get("amount", free_capacity))
	var amount := _take_stage14_resource_from_node(source, resource_id, mini(requested, free_capacity), "%s 物流取货" % robot.name)
	if amount <= 0:
		return false
	robot.call("add_cargo", resource_id, amount)
	task["amount"] = amount
	stage14_logistics_wait_seconds_by_key.erase(_make_stage14_wait_key(source, resource_id))
	_record_stage14_logistics_event(&"logistics_picked", robot, task, amount, source, _get_stage14_task_node(task, "target"))
	return true

func _deliver_stage14_logistics_cargo(robot: Node, task: Dictionary) -> void:
	var target := _get_stage14_task_node(task, "target")
	if target == null or not is_instance_valid(target):
		return
	var resource_id := StringName(str(task.get("resource_id", "")))
	if String(resource_id).is_empty():
		return
	var cargo: Dictionary = robot.call("get_cargo_inventory") if robot.has_method("get_cargo_inventory") else {}
	var amount := int(cargo.get(resource_id, 0))
	if amount <= 0:
		return
	var accepted := _add_stage14_resource_to_node(target, resource_id, amount, "%s 物流送达" % robot.name)
	if accepted > 0:
		robot.call("remove_cargo", resource_id, accepted)
		var source := _get_stage14_task_node(task, "source")
		_record_stage14_logistics_event(&"logistics_delivered", robot, task, accepted, source, target)
		if str(task.get("type", "")) == "salvage_return":
			_record_stage14_logistics_event(&"salvage_delivered", robot, task, accepted, source, target)
			_grant_salvage_key_item_from_task(task)
	var leftover := int(robot.call("get_cargo_used_capacity")) if robot.has_method("get_cargo_used_capacity") else 0
	if leftover > 0 and target != main_base:
		_deliver_remaining_stage14_cargo_to_main_base(robot)
	_refresh_resource_hud()

func _grant_salvage_key_item_from_task(task: Dictionary) -> void:
	if campaign_state == null:
		return
	var key_item_id := StringName(str(task.get("key_item_id", "")))
	if String(key_item_id).is_empty():
		return
	campaign_state.add_key_item(key_item_id)
	push_debug_event("回收关键掉落：%s" % _get_key_item_display_name(key_item_id))
	_refresh_campaign_hud()

func _build_stage14_best_logistics_task(robot: Node) -> Dictionary:
	var candidates: Array = []
	candidates.append_array(_build_stage17_salvage_candidates(robot))
	candidates.append_array(_build_stage14_urgent_supply_candidates(robot))
	candidates.append_array(_build_stage14_source_to_relay_candidates(robot))
	candidates.append_array(_build_stage14_relay_to_base_candidates(robot))
	candidates.append_array(_build_stage14_direct_to_base_candidates(robot))
	var best_task := {}
	var best_score := -INF
	for candidate_value in candidates:
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = candidate_value
		var score := float(candidate.get("score", 0.0))
		if score > best_score:
			best_score = score
			best_task = candidate
	if best_task.is_empty():
		return {}
	best_task.erase("score")
	return best_task

func _build_stage17_salvage_candidates(robot: Node) -> Array:
	var candidates: Array = []
	if not _is_stage17_salvage_robot(robot):
		return candidates
	if _stage17_salvage_robot_should_stand_down(robot):
		return candidates
	var free_capacity := _get_stage14_robot_free_capacity(robot)
	if free_capacity <= 0:
		return candidates
	for pickup in salvage_pickups_by_id.values():
		if not _is_active_salvage_pickup(pickup):
			continue
		var resource_id := StringName(str(pickup.get("resource_id")))
		var available := _get_stage14_available_for_assignment(pickup, resource_id)
		if available <= 0:
			continue
		if bool(pickup.get("requires_tether")) and not _stage17_salvage_robot_has_tether(robot):
			continue
		var amount := mini(available, free_capacity)
		if amount <= 0:
			continue
		var score := _get_stage17_salvage_score(robot, pickup, amount)
		candidates.append(_make_stage14_task(
			"salvage_return",
			pickup,
			main_base,
			resource_id,
			amount,
			"回收战场残骸",
			score
		))
	return candidates

func _is_stage17_salvage_robot(robot: Node) -> bool:
	if robot == null or not is_instance_valid(robot):
		return false
	if robot.is_in_group("salvage"):
		return true
	return String(robot.get("blueprint_id")).contains("salvage")

func _stage17_salvage_robot_has_tether(robot: Node) -> bool:
	if robot == null:
		return false
	if robot.is_in_group("salvage"):
		return true
	return String(robot.get("blueprint_id")).contains("salvage")

func _stage17_salvage_robot_should_stand_down(robot: Node) -> bool:
	if robot == null or not is_instance_valid(robot):
		return true
	if robot.has_method("hp_ratio") and float(robot.call("hp_ratio")) <= 0.45:
		return true
	if not (robot is Node2D):
		return false
	return _count_enemy_units_near((robot as Node2D).global_position, 220.0) >= 3

func _is_active_salvage_pickup(pickup: Variant) -> bool:
	if pickup == null or not is_instance_valid(pickup) or not (pickup is Node):
		return false
	if pickup is CanvasItem and not (pickup as CanvasItem).is_visible_in_tree():
		return false
	if pickup.has_method("is_interaction_locked") and bool(pickup.call("is_interaction_locked")):
		return false
	return int(pickup.get("amount")) > 0

func _get_stage17_salvage_score(robot: Node, pickup: Node, amount: int) -> float:
	var value := float(pickup.call("get_salvage_value") if pickup.has_method("get_salvage_value") else pickup.get("value"))
	var distance_cost := _get_stage14_route_cost(robot, pickup, main_base)
	var risk_penalty := 0.0
	if pickup is Node2D:
		risk_penalty = float(_count_enemy_units_near((pickup as Node2D).global_position, 300.0)) * 220.0
	var strategic_bonus := 1800.0 if bool(pickup.get("strategic_reward")) else 0.0
	var tether_bonus := 500.0 if bool(pickup.get("requires_tether")) else 0.0
	return 6000.0 + value * 100.0 + float(amount) * 16.0 + strategic_bonus + tether_bonus - distance_cost - risk_penalty

func _build_stage14_urgent_supply_candidates(robot: Node) -> Array:
	var candidates: Array = []
	var free_capacity := _get_stage14_robot_free_capacity(robot)
	if free_capacity <= 0:
		return candidates
	for demand_value in _get_stage14_shortage_demands():
		var demand: Dictionary = demand_value
		var target := demand.get("target") as Node
		if target == null or not is_instance_valid(target):
			continue
		var resource_id := StringName(str(demand.get("resource_id", "")))
		var missing := int(demand.get("amount", 0)) - _get_stage14_reserved_delivery(target, resource_id)
		if missing <= 0:
			continue
		var source := _find_stage14_best_source_for_resource(resource_id, target)
		if source == null:
			continue
		var available := _get_stage14_available_for_assignment(source, resource_id)
		var amount := _get_stage14_urgent_supply_pickup_amount(missing, available, free_capacity)
		if amount <= 0:
			continue
		candidates.append(_make_stage14_task(
			"urgent_supply",
			source,
			target,
			resource_id,
			amount,
			"紧急补货",
			100000.0 + float(demand.get("urgency", 0.0)) + float(missing) * 25.0 + float(amount)
		))
	return candidates

func _get_stage14_urgent_supply_pickup_amount(_missing: int, available: int, free_capacity: int) -> int:
	return mini(maxi(0, free_capacity), maxi(0, available))

func _build_stage14_source_to_relay_candidates(robot: Node) -> Array:
	var candidates: Array = []
	var free_capacity := _get_stage14_robot_free_capacity(robot)
	if free_capacity <= 0:
		return candidates
	for source in _get_stage14_logistics_sources():
		for resource_id in _get_stage14_pickup_resource_ids(source):
			var resource_name := StringName(str(resource_id))
			var available := _get_stage14_available_for_assignment(source, resource_name)
			if available <= 0:
				continue
			var relay := _find_stage14_best_supply_point_for_source(source, resource_name)
			if relay == null:
				continue
			var relay_free := int(relay.call("get_free_capacity")) if relay.has_method("get_free_capacity") else free_capacity
			var amount := mini(available, mini(free_capacity, relay_free))
			if amount <= 0 or not _can_dispatch_stage14_load(source, resource_name, amount, free_capacity, false):
				continue
			var distance_cost := _get_stage14_route_cost(robot, source, relay)
			candidates.append(_make_stage14_task(
				"source_to_relay",
				source,
				relay,
				resource_name,
				amount,
				"运往前线补给点",
				3000.0 + float(amount) * 12.0 - distance_cost
			))
	return candidates

func _build_stage14_relay_to_base_candidates(robot: Node) -> Array:
	var candidates: Array = []
	var free_capacity := _get_stage14_robot_free_capacity(robot)
	if free_capacity <= 0:
		return candidates
	for relay in _get_stage14_supply_points():
		for resource_id in _get_stage14_pickup_resource_ids(relay):
			var resource_name := StringName(str(resource_id))
			var available := _get_stage14_available_for_assignment(relay, resource_name)
			if available <= 0:
				continue
			var amount := mini(available, free_capacity)
			if amount <= 0 or not _can_dispatch_stage14_load(relay, resource_name, amount, free_capacity, false):
				continue
			var base_shortage_bonus := maxi(0, STAGE14_BASE_TARGET_STOCK - _get_main_base_resource_amount(resource_name))
			var distance_cost := _get_stage14_route_cost(robot, relay, main_base)
			candidates.append(_make_stage14_task(
				"relay_to_base",
				relay,
				main_base,
				resource_name,
				amount,
				"补给点回运主基地",
				2000.0 + float(amount) * 10.0 + float(base_shortage_bonus) * 8.0 - distance_cost
			))
	return candidates

func _build_stage14_direct_to_base_candidates(robot: Node) -> Array:
	var candidates: Array = []
	var free_capacity := _get_stage14_robot_free_capacity(robot)
	if free_capacity <= 0:
		return candidates
	for source in _get_stage14_logistics_sources():
		if _find_stage14_best_supply_point_for_source(source, &"") != null:
			continue
		for resource_id in _get_stage14_pickup_resource_ids(source):
			var resource_name := StringName(str(resource_id))
			var available := _get_stage14_available_for_assignment(source, resource_name)
			var amount := mini(available, free_capacity)
			if amount <= 0 or not _can_dispatch_stage14_load(source, resource_name, amount, free_capacity, false):
				continue
			var distance_cost := _get_stage14_route_cost(robot, source, main_base)
			candidates.append(_make_stage14_task(
				"direct_to_base",
				source,
				main_base,
				resource_name,
				amount,
				"远程直送主基地",
				1000.0 + float(amount) * 8.0 - distance_cost
			))
	return candidates

func _get_stage14_shortage_demands() -> Array:
	var demands: Array = []
	var inventory = _get_main_base_inventory()
	for node in get_tree().get_nodes_in_group("team_a"):
		if node is ProcessorBuilding:
			demands.append_array(_get_stage14_processor_demands(node, inventory))
		elif node is RobotForgeBuilding:
			demands.append_array(_get_stage14_forge_demands(node))
	return demands

func _get_stage14_processor_demands(processor: Node, inventory: Variant) -> Array:
	var demands: Array = []
	var recipe: RecipeDef = processor.get("selected_recipe")
	if recipe == null or float(processor.get("progress_seconds")) > 0.0:
		return demands
	var input_cache: Dictionary = processor.get("input_cache")
	for resource_id in recipe.inputs.keys():
		var required := int(recipe.inputs[resource_id])
		var cached := int(input_cache.get(resource_id, 0))
		var main_available := int(inventory.get_amount(resource_id)) if inventory != null else 0
		var missing := required - cached - main_available
		if missing <= 0:
			continue
		demands.append({
			"target": processor,
			"resource_id": StringName(resource_id),
			"amount": missing,
			"urgency": 600.0 + float(missing) * 40.0,
		})
	return demands

func _get_stage14_forge_demands(forge: Node) -> Array:
	var demands: Array = []
	if float(forge.get("progress_seconds")) > 0.0 or not forge.has_method("get_missing_resources"):
		return demands
	var missing: Dictionary = forge.call("get_missing_resources")
	for resource_id in missing.keys():
		var amount := int(missing[resource_id])
		if amount <= 0:
			continue
		demands.append({
			"target": main_base,
			"resource_id": StringName(resource_id),
			"amount": amount,
			"urgency": 500.0 + float(amount) * 35.0,
		})
	return demands

func _get_stage14_logistics_sources() -> Array:
	var sources: Array = []
	for node in get_tree().get_nodes_in_group("team_a"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is MinerBuilding or node is WaterPumpBuilding):
			continue
		var requires_delivery = node.get("requires_logistics_delivery")
		if typeof(requires_delivery) != TYPE_BOOL or not requires_delivery:
			continue
		var output_cache: Dictionary = node.get("output_cache")
		if output_cache.is_empty():
			continue
		sources.append(node)
	return sources

func _get_stage14_supply_points() -> Array:
	var supply_points: Array = []
	for node in get_tree().get_nodes_in_group("frontline_supply"):
		if node != null and is_instance_valid(node) and node.has_method("get_free_capacity"):
			supply_points.append(node)
	for node in get_tree().get_nodes_in_group("team_a"):
		if node == null or not is_instance_valid(node) or supply_points.has(node):
			continue
		var building_def_value = node.get("building_def")
		if building_def_value is BuildingDef and (building_def_value as BuildingDef).id == MvpDataDefaults.BUILDING_FORWARD_SUPPLY_POINT:
			supply_points.append(node)
	return supply_points

func _find_stage14_best_supply_point_for_source(source: Node, resource_id: StringName) -> Node:
	var best: Node = null
	var best_score := -INF
	for relay in _get_stage14_supply_points():
		if relay == source:
			continue
		var free_capacity := int(relay.call("get_free_capacity")) if relay.has_method("get_free_capacity") else 0
		if free_capacity <= 0:
			continue
		var current_stock := int(relay.call("get_amount", resource_id)) if relay.has_method("get_amount") and not String(resource_id).is_empty() else 0
		if not String(resource_id).is_empty() and current_stock >= STAGE14_RELAY_TARGET_STOCK and _get_stage14_available_for_assignment(source, resource_id) < _get_stage14_min_load_amount(_get_stage14_largest_cargo_capacity()):
			continue
		var score := 10000.0 - _get_logistics_node_position(source).distance_to(_get_logistics_node_position(relay)) + float(free_capacity) * 0.25
		if score > best_score:
			best_score = score
			best = relay
	return best

func _find_stage14_best_source_for_resource(resource_id: StringName, target: Node) -> Node:
	var best: Node = null
	var best_score := -INF
	for source in _get_stage14_supply_points():
		var available := _get_stage14_available_for_assignment(source, resource_id)
		if available <= 0:
			continue
		var score := 5000.0 + float(available) * 3.0 - _get_logistics_node_position(source).distance_to(_get_logistics_node_position(target))
		if score > best_score:
			best_score = score
			best = source
	for source in _get_stage14_logistics_sources():
		var available := _get_stage14_available_for_assignment(source, resource_id)
		if available <= 0:
			continue
		var score := 3000.0 + float(available) * 2.0 - _get_logistics_node_position(source).distance_to(_get_logistics_node_position(target))
		if score > best_score:
			best_score = score
			best = source
	return best

func _try_assign_stage14_existing_cargo_delivery(robot: Node) -> bool:
	var cargo: Dictionary = robot.call("get_cargo_inventory") if robot.has_method("get_cargo_inventory") else {}
	if cargo.is_empty():
		return false
	for resource_id in cargo.keys():
		var amount := int(cargo[resource_id])
		if amount <= 0:
			continue
		var task := _make_stage14_task("recover_cargo", robot, main_base, StringName(resource_id), amount, "回收残余货物", 0.0)
		task["stage"] = "to_dropoff"
		stage14_logistics_tasks_by_robot[robot] = task
		_sync_stage14_robot_task(robot, task)
		return true
	return false

func _make_stage14_task(task_type: String, source: Node, target: Node, resource_id: StringName, amount: int, status: String, score: float) -> Dictionary:
	var task := {
		"stage": "to_pickup",
		"type": task_type,
		"source": source,
		"target": target,
		"resource_id": resource_id,
		"amount": amount,
		"status": status,
		"score": score,
	}
	if task_type == "salvage_return" and source != null and is_instance_valid(source) and source.get("key_item_id") != null:
		var key_item_id := StringName(str(source.get("key_item_id")))
		if not String(key_item_id).is_empty():
			task["key_item_id"] = String(key_item_id)
	var inferred_key_item := _infer_key_item_from_salvage_resource(resource_id)
	if not String(inferred_key_item).is_empty():
		task["type"] = "salvage_return"
		task["key_item_id"] = String(inferred_key_item)
	return task

func _infer_key_item_from_salvage_resource(resource_id: StringName) -> StringName:
	if resource_id == &"salvage_data_core":
		return resource_id
	return &""

func _get_stage14_pickup_resource_ids(node: Node) -> Array:
	if node == null or not is_instance_valid(node):
		return []
	if node.has_method("get_all_resources"):
		return node.call("get_all_resources").keys()
	var output_cache: Dictionary = node.get("output_cache")
	return output_cache.keys()

func _get_stage14_available_for_assignment(node: Node, resource_id: StringName) -> int:
	return maxi(0, _get_stage14_node_amount(node, resource_id) - _get_stage14_reserved_pickup(node, resource_id))

func _get_stage14_node_amount(node: Node, resource_id: StringName) -> int:
	if node == null or not is_instance_valid(node):
		return 0
	if node.has_method("get_amount"):
		return int(node.call("get_amount", resource_id))
	var output_cache: Dictionary = node.get("output_cache")
	return int(output_cache.get(resource_id, 0))

func _take_stage14_resource_from_node(node: Node, resource_id: StringName, amount: int, reason: String) -> int:
	if node == null or not is_instance_valid(node) or amount <= 0:
		return 0
	if node.has_method("remove_resource"):
		return int(node.call("remove_resource", resource_id, amount, reason))
	var output_cache: Dictionary = node.get("output_cache")
	var available := int(output_cache.get(resource_id, 0))
	var removed := mini(available, amount)
	if removed <= 0:
		return 0
	var next_amount := available - removed
	if next_amount > 0:
		output_cache[resource_id] = next_amount
	else:
		output_cache.erase(resource_id)
	node.set("output_cache", output_cache)
	return removed

func _add_stage14_resource_to_node(node: Node, resource_id: StringName, amount: int, reason: String) -> int:
	if node == null or not is_instance_valid(node) or amount <= 0:
		return 0
	if node == main_base:
		var inventory = _get_main_base_inventory()
		if inventory == null:
			return 0
		inventory.add_resource(resource_id, amount, reason)
		return amount
	if node.has_method("add_resource"):
		return int(node.call("add_resource", resource_id, amount, reason))
	var input_cache_value = node.get("input_cache")
	if typeof(input_cache_value) == TYPE_DICTIONARY:
		var input_cache: Dictionary = input_cache_value
		input_cache[resource_id] = int(input_cache.get(resource_id, 0)) + amount
		node.set("input_cache", input_cache)
		if node.has_signal("processor_state_changed"):
			node.emit_signal("processor_state_changed")
		return amount
	return 0

func _deliver_remaining_stage14_cargo_to_main_base(robot: Node) -> void:
	var inventory = _get_main_base_inventory()
	if inventory == null:
		return
	var cargo: Dictionary = robot.call("get_cargo_inventory") if robot.has_method("get_cargo_inventory") else {}
	for resource_id in cargo.keys():
		var amount := int(cargo[resource_id])
		if amount <= 0:
			continue
		inventory.add_resource(StringName(resource_id), amount, "%s 物流余货入库" % robot.name)
		robot.call("remove_cargo", StringName(resource_id), amount)
		_record_stage14_logistics_event(&"logistics_delivered", robot, {
			"type": "leftover_to_base",
			"resource_id": StringName(resource_id),
			"amount": amount,
		}, amount, robot, main_base)

func _get_stage14_reserved_pickup(source: Node, resource_id: StringName) -> int:
	var total := 0
	for task_value in stage14_logistics_tasks_by_robot.values():
		var task: Dictionary = task_value
		if _get_stage14_task_node(task, "source") != source or StringName(str(task.get("resource_id", ""))) != resource_id:
			continue
		if str(task.get("stage", "")) == "to_pickup":
			total += int(task.get("amount", 0))
	return total

func _get_stage14_reserved_delivery(target: Node, resource_id: StringName) -> int:
	var total := 0
	for task_value in stage14_logistics_tasks_by_robot.values():
		var task: Dictionary = task_value
		if _get_stage14_task_node(task, "target") != target or StringName(str(task.get("resource_id", ""))) != resource_id:
			continue
		total += int(task.get("amount", 0))
	return total

func _can_dispatch_stage14_load(source: Node, resource_id: StringName, amount: int, robot_capacity: int, urgent: bool) -> bool:
	if urgent:
		return amount > 0
	if amount >= _get_stage14_min_load_amount(robot_capacity):
		return true
	return float(stage14_logistics_wait_seconds_by_key.get(_make_stage14_wait_key(source, resource_id), 0.0)) >= STAGE14_MAX_PICKUP_WAIT_SECONDS

func _get_stage14_min_load_amount(robot_capacity: int) -> int:
	return maxi(1, ceili(float(maxi(1, robot_capacity)) * STAGE14_MIN_LOAD_RATIO))

func _get_stage14_robot_free_capacity(robot: Node) -> int:
	return int(robot.call("get_cargo_free_capacity")) if robot != null and robot.has_method("get_cargo_free_capacity") else 0

func _get_stage14_task_node(task: Dictionary, key: String) -> Node:
	var value: Variant = task.get(key, null)
	if value == null or not is_instance_valid(value) or not (value is Node):
		return null
	return value as Node

func _get_stage14_largest_cargo_capacity() -> int:
	var capacity := 1
	for robot in get_tree().get_nodes_in_group("cargo"):
		if robot != null and robot.has_method("get_cargo_free_capacity"):
			capacity = maxi(capacity, int(robot.get("cargo_capacity")))
	return capacity

func _update_stage14_logistics_waits(delta: float) -> void:
	var active_keys := {}
	for source in _get_stage14_logistics_sources():
		for resource_id in _get_stage14_pickup_resource_ids(source):
			var resource_name := StringName(str(resource_id))
			if _get_stage14_available_for_assignment(source, resource_name) <= 0:
				continue
			var key := _make_stage14_wait_key(source, resource_name)
			active_keys[key] = true
			stage14_logistics_wait_seconds_by_key[key] = float(stage14_logistics_wait_seconds_by_key.get(key, 0.0)) + delta
	for relay in _get_stage14_supply_points():
		for resource_id in _get_stage14_pickup_resource_ids(relay):
			var resource_name := StringName(str(resource_id))
			if _get_stage14_available_for_assignment(relay, resource_name) <= 0:
				continue
			var key := _make_stage14_wait_key(relay, resource_name)
			active_keys[key] = true
			stage14_logistics_wait_seconds_by_key[key] = float(stage14_logistics_wait_seconds_by_key.get(key, 0.0)) + delta
	for key in stage14_logistics_wait_seconds_by_key.keys():
		if not active_keys.has(key):
			stage14_logistics_wait_seconds_by_key.erase(key)

func _make_stage14_wait_key(source: Node, resource_id: StringName) -> String:
	if source == null:
		return "none:%s" % String(resource_id)
	return "%s:%s" % [source.get_instance_id(), String(resource_id)]

func _get_stage14_route_cost(robot: Node, source: Node, target: Node) -> float:
	if not (robot is Node2D):
		return 0.0
	return (robot as Node2D).global_position.distance_to(_get_logistics_node_position(source)) * 0.015 + _get_logistics_node_position(source).distance_to(_get_logistics_node_position(target)) * 0.01

func _count_enemy_units_near(center: Vector2, radius: float) -> int:
	var count := 0
	var radius_squared := radius * radius
	for enemy in get_tree().get_nodes_in_group("team_b"):
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if not enemy.is_in_group("combat_unit"):
			continue
		if enemy.has_method("is_alive") and not bool(enemy.call("is_alive")):
			continue
		if center.distance_squared_to((enemy as Node2D).global_position) <= radius_squared:
			count += 1
	return count

func _get_main_base_resource_amount(resource_id: StringName) -> int:
	var inventory = _get_main_base_inventory()
	if inventory == null:
		return 0
	return int(inventory.get_amount(resource_id))

func _get_stage14_dropoff_status(task: Dictionary) -> String:
	match str(task.get("type", "")):
		"urgent_supply":
			return "紧急补货"
		"source_to_relay":
			return "投递前线补给点"
		"relay_to_base", "direct_to_base", "recover_cargo":
			return "送回主基地"
		"salvage_return":
			return "回收残骸返航"
		"hazard_return":
			return "紧急避险：携货返航"
		"hazard_evasion":
			return "紧急避险：撤退到安全点"
	return "投递物资"

func _move_logistics_robot_towards(robot: Node, world_position: Vector2, action_text: String, target_node: Node = null) -> void:
	var moving := true
	if robot.has_method("move_towards"):
		moving = robot.call("move_towards", world_position, target_node) == true
	robot.set("current_action", action_text if moving else "路径阻塞")

func _is_logistics_robot_near(robot: Node, target: Node) -> bool:
	if not (robot is Node2D) or not (target is Node2D):
		return false
	if _is_node_adjacent_to_grid_footprint(robot as Node2D, target):
		return true
	return (robot as Node2D).global_position.distance_to(_get_logistics_node_position(target)) <= 34.0

func _is_node_adjacent_to_grid_footprint(node: Node2D, target: Node) -> bool:
	if grid_map == null or target == null or not is_instance_valid(target):
		return false
	var origin_value = target.get("grid_origin")
	var size_value = target.get("grid_size")
	if typeof(origin_value) != TYPE_VECTOR2I or typeof(size_value) != TYPE_VECTOR2I:
		return false
	var origin: Vector2i = origin_value
	var size: Vector2i = size_value
	if size.x <= 0 or size.y <= 0:
		return false
	var node_cell: Vector2i = grid_map.call("world_to_grid", node.global_position)
	return node_cell.x >= origin.x - 1 \
		and node_cell.y >= origin.y - 1 \
		and node_cell.x <= origin.x + size.x \
		and node_cell.y <= origin.y + size.y

func _get_logistics_node_position(node: Node) -> Vector2:
	if node.has_method("get_target_position"):
		return node.call("get_target_position")
	if node is Node2D:
		return (node as Node2D).global_position
	return Vector2.ZERO

func _sync_stage14_robot_task(robot: Node, task: Dictionary) -> void:
	if robot == null or not robot.has_method("setup_logistics_task"):
		return
	var public_task := {
		"type": str(task.get("type", "delivery")),
		"status": str(task.get("status", "")),
		"resource_id": String(task.get("resource_id", "")),
		"amount": int(task.get("amount", 0)),
		"pickup": _node_display_name(_get_stage14_task_node(task, "source")),
		"dropoff": _node_display_name(_get_stage14_task_node(task, "target")),
	}
	robot.call("setup_logistics_task", public_task)
	_update_logistics_task_visual(robot, task)

func _clear_stage14_robot_task(robot: Node) -> void:
	stage14_logistics_tasks_by_robot.erase(robot)
	_clear_logistics_task_visual(robot)
	if robot and robot.has_method("clear_logistics_task"):
		robot.call("clear_logistics_task")
	if robot and robot.has_method("stop_and_idle"):
		robot.call("stop_and_idle")

func _ensure_logistics_visual_layer() -> void:
	if _logistics_visual_layer != null and is_instance_valid(_logistics_visual_layer):
		return
	_logistics_visual_layer = Node2D.new()
	_logistics_visual_layer.name = "LogisticsVisualLayer"
	_logistics_visual_layer.z_index = 36
	var parent := _get_layer("RallyLayer")
	if parent == null:
		parent = self
	parent.add_child(_logistics_visual_layer)

func _update_logistics_task_visual(robot: Node, task: Dictionary) -> void:
	if robot == null or not is_instance_valid(robot) or not (robot is Node2D):
		return
	if robot != selected_inspected_node:
		_clear_logistics_task_visual(robot)
		return
	var source := _get_stage14_task_node(task, "source")
	var target := _get_stage14_task_node(task, "target")
	if target == null or not is_instance_valid(target):
		_clear_logistics_task_visual(robot)
		return
	_ensure_logistics_visual_layer()
	var key := int(robot.get_instance_id())
	var line := _logistics_task_lines.get(key) as Line2D
	if line == null or not is_instance_valid(line):
		line = Line2D.new()
		line.name = "LogisticsRoute_%s" % key
		line.width = 3.0
		line.antialiased = true
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_logistics_visual_layer.add_child(line)
		_logistics_task_lines[key] = line
	line.default_color = _get_logistics_task_color(str(task.get("type", "")))
	var current_segment_node := target
	var current_segment_target := _get_logistics_node_position(target)
	if str(task.get("stage", "")) == "to_pickup" and source != null and is_instance_valid(source):
		current_segment_node = source
		current_segment_target = _get_logistics_node_position(source)
	var points := get_navigation_path_points_to_node((robot as Node2D).global_position, current_segment_node) if current_segment_node != null and is_instance_valid(current_segment_node) else get_navigation_path_points((robot as Node2D).global_position, current_segment_target)
	if points.size() <= 1:
		points.append((robot as Node2D).global_position)
		line.default_color = Color(1.0, 0.34, 0.24, 0.85)
	line.points = points

func _clear_logistics_task_visual(robot: Node) -> void:
	if robot == null:
		return
	var key := int(robot.get_instance_id())
	var line := _logistics_task_lines.get(key) as Line2D
	if line != null and is_instance_valid(line):
		line.queue_free()
	_logistics_task_lines.erase(key)

func _clear_logistics_visuals() -> void:
	for line_value in _logistics_task_lines.values():
		var line := line_value as Line2D
		if line != null and is_instance_valid(line):
			line.queue_free()
	_logistics_task_lines.clear()

func _refresh_selected_logistics_visual() -> void:
	_clear_logistics_visuals()
	if selected_inspected_node == null or not _is_cargo_robot_node(selected_inspected_node):
		return
	if not stage14_logistics_tasks_by_robot.has(selected_inspected_node):
		return
	var task: Dictionary = stage14_logistics_tasks_by_robot[selected_inspected_node]
	_update_logistics_task_visual(selected_inspected_node, task)

func _get_logistics_task_color(task_type: String) -> Color:
	match task_type:
		"urgent_supply":
			return Color(1.0, 0.72, 0.25, 0.86)
		"source_to_relay":
			return Color(0.30, 0.92, 1.0, 0.72)
		"relay_to_base":
			return Color(0.46, 0.82, 0.40, 0.76)
		"direct_to_base":
			return Color(0.68, 0.74, 1.0, 0.72)
		"salvage_return":
			return Color(1.0, 0.62, 0.18, 0.82)
		"recover_cargo", "leftover_to_base":
			return Color(0.92, 0.92, 0.72, 0.70)
	return Color(0.78, 0.88, 1.0, 0.68)

func _record_stage14_logistics_event(event_type: StringName, robot: Node, task: Dictionary, amount: int, source: Node, target: Node) -> void:
	if amount <= 0:
		return
	var resource_id := StringName(str(task.get("resource_id", "")))
	if String(resource_id).is_empty():
		return
	_bump_stage14_logistics_counter(str(event_type), resource_id, amount)
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log and event_log.has_method("record"):
		event_log.call("record", event_type, {
			"robot": robot.name if robot else "",
			"task_type": str(task.get("type", "")),
			"resource_id": String(resource_id),
			"amount": amount,
			"source": _node_display_name(source),
			"target": _node_display_name(target),
		})

func _bump_stage14_logistics_counter(kind: String, resource_id: StringName, amount: int) -> void:
	var resource_key := String(resource_id)
	var row: Dictionary = stage14_logistics_counters.get(resource_key, {})
	row[kind] = int(row.get(kind, 0)) + amount
	stage14_logistics_counters[resource_key] = row

func _refresh_stage14_logistics_diagnostics() -> void:
	if hud == null or not hud.has_method("set_logistics_diagnostics"):
		return
	hud.call("set_logistics_diagnostics", _build_stage14_logistics_diagnostics())

func _build_stage14_logistics_diagnostics() -> Dictionary:
	var active_tasks: Array[Dictionary] = []
	for task_value in stage14_logistics_tasks_by_robot.values():
		var task: Dictionary = task_value
		active_tasks.append({
			"type": str(task.get("type", "")),
			"stage": str(task.get("stage", "")),
			"resource_id": String(task.get("resource_id", "")),
			"amount": int(task.get("amount", 0)),
			"pickup": _node_display_name(_get_stage14_task_node(task, "source")),
			"dropoff": _node_display_name(_get_stage14_task_node(task, "target")),
			"status": str(task.get("status", "")),
		})
	var shortages: Array[Dictionary] = []
	for demand_value in _get_stage14_shortage_demands():
		var demand: Dictionary = demand_value
		var target := demand.get("target") as Node
		shortages.append({
			"target": _node_display_name(target),
			"resource_id": String(demand.get("resource_id", "")),
			"amount": int(demand.get("amount", 0)),
			"urgency": float(demand.get("urgency", 0.0)),
		})
	var waiting_sources: Array[Dictionary] = []
	for source in _get_stage14_logistics_sources():
		for resource_id in _get_stage14_pickup_resource_ids(source):
			var resource_name := StringName(str(resource_id))
			var available := _get_stage14_available_for_assignment(source, resource_name)
			if available <= 0:
				continue
			waiting_sources.append({
				"source": _node_display_name(source),
				"resource_id": String(resource_name),
				"available": available,
				"wait_seconds": float(stage14_logistics_wait_seconds_by_key.get(_make_stage14_wait_key(source, resource_name), 0.0)),
			})
	return {
		"active_tasks": active_tasks,
		"shortages": shortages,
		"waiting_sources": waiting_sources,
		"counters": stage14_logistics_counters.duplicate(true),
	}

func _node_display_name(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return "-"
	if node.has_method("get_display_name"):
		return str(node.call("get_display_name"))
	return str(node.name)

func _on_blueprint_library_requested() -> void:
	_refresh_blueprint_library_ui()

func _on_blueprint_save_requested(source_blueprint_id: StringName, display_name: String, unit_type_id: StringName, upgrade_ids: Array[StringName], tactical_templates: Array, _embedded_rules: Array, _state_flag_defaults: Dictionary, save_as_new: bool) -> void:
	if blueprint_library == null:
		return
	var source_blueprint := blueprint_library.get_blueprint(source_blueprint_id)
	if source_blueprint == null:
		source_blueprint = basic_rifle_blueprint
	if source_blueprint == null:
		return
	var final_name := display_name.strip_edges()
	if final_name.is_empty():
		final_name = "%s 自定义" % source_blueprint.display_name if save_as_new else source_blueprint.display_name
	elif save_as_new and final_name == source_blueprint.display_name:
		final_name = "%s 自定义" % source_blueprint.display_name
	var saved_blueprint := source_blueprint.make_snapshot()
	saved_blueprint.id = StringName("custom_%d" % Time.get_ticks_msec()) if save_as_new else source_blueprint.id
	saved_blueprint.display_name = final_name
	saved_blueprint.version = 1 if save_as_new else source_blueprint.version
	saved_blueprint.snapshot_id = &""
	saved_blueprint.source_blueprint_id = &""
	saved_blueprint.is_snapshot = false
	var design_unit_type_id := unit_type_id if not String(unit_type_id).is_empty() else source_blueprint.unit_type_id
	if not _is_unit_type_unlocked_for_blueprint_editor(design_unit_type_id):
		design_unit_type_id = source_blueprint.unit_type_id if _is_unit_type_unlocked_for_blueprint_editor(source_blueprint.unit_type_id) else MvpDataDefaults.UNIT_BASIC_RIFLE_ROBOT
	var design_upgrade_ids := source_blueprint.upgrade_ids if String(unit_type_id).is_empty() else upgrade_ids
	design_upgrade_ids = _filter_unlocked_blueprint_upgrade_ids(design_upgrade_ids)
	UnitDesignConfigLoaderScript.apply_design_to_blueprint(saved_blueprint, design_unit_type_id, design_upgrade_ids, MvpDataDefaults.create_recipe_defs())
	var safe_templates := _filter_blueprint_tactical_templates(tactical_templates, saved_blueprint.unit_type_id)
	var compiled: Dictionary = TacticalTemplateCompilerScript.compile_templates(safe_templates)
	saved_blueprint.tactical_templates = safe_templates
	saved_blueprint.embedded_rules = compiled.get("rules", []).duplicate(true)
	saved_blueprint.state_flag_defaults = compiled.get("state_flag_defaults", {}).duplicate(true)
	if save_as_new:
		blueprint_library.add_blueprint(saved_blueprint)
		push_debug_event("Blueprint saved as new: %s v%s" % [saved_blueprint.display_name, saved_blueprint.version])
	else:
		blueprint_library.save_blueprint(saved_blueprint)
		push_debug_event("Blueprint updated: %s v%s" % [saved_blueprint.display_name, saved_blueprint.version])
	_refresh_blueprint_library_ui()

func _is_unit_type_unlocked_for_blueprint_editor(unit_type_id: StringName) -> bool:
	if campaign_state == null:
		return true
	return campaign_state.unlocked_unit_types.has(unit_type_id)

func _filter_unlocked_blueprint_upgrade_ids(upgrade_ids: Array[StringName]) -> Array[StringName]:
	if campaign_state == null:
		return upgrade_ids
	var result: Array[StringName] = []
	for upgrade_id in upgrade_ids:
		if campaign_state.unlocked_upgrades.has(upgrade_id):
			result.append(upgrade_id)
	return result

func _filter_blueprint_tactical_templates(templates: Array, unit_type_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for template in _dictionary_array_from_variant(templates):
		var template_id := StringName(str(template.get("id", "")))
		if not _is_template_unlocked_for_blueprint_editor(template_id):
			continue
		if not _is_template_allowed_for_unit_type(template_id, unit_type_id):
			continue
		result.append(template.duplicate(true))
	if result.is_empty():
		result.append(TacticalTemplateCompilerScript.make_default_attack_instance())
	return result

func _is_template_unlocked_for_blueprint_editor(template_id: StringName) -> bool:
	if campaign_state == null:
		return true
	return campaign_state.unlocked_templates.has(template_id)

func _is_template_allowed_for_unit_type(template_id: StringName, unit_type_id: StringName) -> bool:
	if String(template_id) == TacticalTemplateCompilerScript.TEMPLATE_DEFAULT_ATTACK:
		return true
	var config := UnitDesignConfigLoaderScript.load_design_config()
	var unit_type := UnitDesignConfigLoaderScript.get_unit_type(config, unit_type_id)
	if unit_type.is_empty():
		return false
	var tags := _string_list_from_variant(unit_type.get("tags", []))
	if String(template_id) == TacticalTemplateCompilerScript.TEMPLATE_LOCK_TARGET:
		return tags.has("locker")
	if String(template_id) == TacticalTemplateCompilerScript.TEMPLATE_LOCKED_MISSILE_STRIKE:
		return tags.has("missile")
	if tags.has("logistics") or tags.has("cargo"):
		return String(template_id) in [
			TacticalTemplateCompilerScript.TEMPLATE_SALVAGE_AND_RETURN,
			TacticalTemplateCompilerScript.TEMPLATE_SUPPLY_RUN,
			TacticalTemplateCompilerScript.TEMPLATE_HAZARD_AVOIDANCE,
		]
	return tags.has("combat")

func _on_forge_blueprint_selected(forge: Node, blueprint_id: StringName) -> void:
	if forge == null or not is_instance_valid(forge) or blueprint_library == null:
		return
	var blueprint := blueprint_library.get_blueprint(blueprint_id)
	if blueprint == null:
		push_debug_event("Blueprint switch failed: %s" % String(blueprint_id))
		return
	if forge.has_method("set_blueprint_snapshot"):
		forge.call("set_blueprint_snapshot", _create_blueprint_snapshot(blueprint))
	push_debug_event("Forge blueprint switched: %s v%s" % [blueprint.display_name, blueprint.version])
	_prune_blueprint_snapshots()
	call_deferred("_refresh_operation_panel")

func _refresh_blueprint_library_ui() -> void:
	if hud and hud.has_method("set_blueprint_library"):
		hud.call("set_blueprint_library", blueprint_library.get_blueprints() if blueprint_library else [])
	if hud and hud.has_method("set_unlocked_template_ids") and campaign_state:
		hud.call("set_unlocked_template_ids", campaign_state.unlocked_templates)
	if hud and hud.has_method("set_blueprint_unlocks") and campaign_state:
		hud.call("set_blueprint_unlocks", campaign_state.unlocked_unit_types, campaign_state.unlocked_upgrades, campaign_state.unlocked_templates)

func _create_blueprint_snapshot(blueprint: UnitBlueprint) -> UnitBlueprint:
	if blueprint_library:
		return blueprint_library.create_snapshot(blueprint)
	if blueprint:
		return blueprint.make_snapshot()
	return null

func _on_robot_lost_for_blueprint_cleanup(robot: Node, reason: StringName) -> void:
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log and event_log.has_method("record") and robot and String(robot.get("team")) == "Team_A":
		event_log.call("record", &"robot_lost", {
			"robot_id": robot.name,
			"team": String(robot.get("team")),
			"blueprint_id": String(robot.get("blueprint_id")),
			"blueprint_name": str(robot.get("display_name")),
			"blueprint_version": int(robot.get("blueprint_version")),
			"reason": String(reason),
		})
		_maybe_show_stage12_soft_failure_hint()
		_spawn_cargo_drops_for_lost_robot(robot)
	call_deferred("_prune_blueprint_snapshots")

func _get_blueprint_rule_summaries(blueprint: UnitBlueprint) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if blueprint == null:
		return result
	for rule in blueprint.embedded_rules:
		if typeof(rule) != TYPE_DICTIONARY:
			continue
		result.append({
			"id": str(rule.get("id", rule.get("name", "unnamed_rule"))),
			"name": str(rule.get("name", rule.get("id", "未命名规则"))),
		})
	return result

func _get_blueprint_template_summaries(blueprint: UnitBlueprint) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if blueprint == null:
		return result
	for template in blueprint.tactical_templates:
		if typeof(template) != TYPE_DICTIONARY:
			continue
		result.append({
			"id": str(template.get("id", "")),
			"name": str(template.get("display_name", template.get("id", "未命名模板"))),
		})
	return result

func _on_building_destroyed(building: Node, reason: StringName) -> void:
	if building != null and is_instance_valid(building):
		var origin: Vector2i = building.get("grid_origin")
		var size: Vector2i = building.get("grid_size")
		grid_occupancy.clear_rect(origin, size)
		_mark_navigation_dirty()
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log and event_log.has_method("record"):
		event_log.call("record", &"building_destroyed", {
			"building": building.name,
			"team": String(building.get("team")),
			"reason": String(reason),
		})

func _advance_stage12_guidance_after_build(building_def: BuildingDef, _building: Node) -> void:
	if building_def == null or hud == null:
		return
	if _is_main_base_def(building_def):
		return
	if _is_miner_def(building_def):
		set_current_goal("保持铁矿和铜矿采集，建造基础加工厂生产铁板和铜线")
		set_guidance_hint("继续补齐矿点；下一步建造基础加工厂，用铁矿和铜矿加工铁板、铜线。")
		if hud.has_method("show_bottom_prompt"):
			hud.call("show_bottom_prompt", "采矿机开始工作。继续补齐矿点，并建造基础加工厂。", 2.8, &"info")
	elif _is_processor_def(building_def):
		set_current_goal("选择加工配方，生产铁板和铜线；材料足够后建造机器人锻造厂")
		set_guidance_hint("点开基础加工厂选择配方；材料足够后，在底部建造栏建造机器人锻造厂。")
		if hud.has_method("show_bottom_prompt"):
			hud.call("show_bottom_prompt", "点开基础加工厂选择配方。补足铁板和铜线后，在底部建造栏建造机器人锻造厂并开始生产机器人。", 4.2, &"info")
	elif _is_robot_forge_def(building_def):
		set_current_goal("为锻造厂设置集结点，选择集结后进攻蓝图并摧毁远处敌巢")
		set_guidance_hint("点开锻造厂设置集结点，并在锻造厂面板中选择集结后进攻蓝图。")
		if hud.has_method("show_bottom_prompt"):
			hud.call("show_bottom_prompt", "锻造厂会持续生产机器人。建议先设置集结点，再绑定集结后进攻蓝图。", 3.4, &"info")
	elif _is_research_terminal_def(building_def):
		set_current_goal("在科技菜单选择阶段 1 科技，并等待研究终端完成")
		set_guidance_hint("打开右下角科技菜单，选择可研究的阶段 1 科技。")
		if hud.has_method("show_bottom_prompt"):
			hud.call("show_bottom_prompt", "研究终端已就绪。打开右下角科技菜单开始研究。", 3.0, &"success")

func _maybe_show_stage12_soft_failure_hint() -> void:
	if _stage12_soft_failure_shown:
		return
	if campaign_state and not campaign_state.defeated_nests.is_empty():
		return
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log == null or not event_log.has_method("count_events"):
		return
	var lost_count := int(event_log.call("count_events", "robot_lost", 0.0))
	if lost_count < 3:
		return
	_stage12_soft_failure_shown = true
	_play_audio_cue(&"soft_failure")
	set_current_goal("零散进攻损失较高：复制或选择集结后进攻蓝图，再组织小队推进")
	if hud and hud.has_method("show_bottom_prompt"):
		hud.call("show_bottom_prompt", "零散进攻正在损失机器人。尝试在蓝图中使用“集结后进攻”，等小队成形后再推进。", 5.0, &"warning")

func _play_audio_cue(cue_id: StringName, volume_scale: float = 1.0) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_cue"):
		audio_manager.call("play_cue", cue_id, volume_scale)

func _prune_blueprint_snapshots() -> void:
	if blueprint_library == null:
		return
	var removed := blueprint_library.prune_unused_snapshots(_collect_active_blueprint_snapshot_ids())
	if removed > 0:
		push_debug_event("Removed stale blueprint snapshots: %d" % removed)

func _collect_active_blueprint_snapshot_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var building_layer := _get_layer("BuildingLayer")
	if building_layer == null:
		return result
	for child in building_layer.get_children():
		if child == null or not is_instance_valid(child):
			continue
		var building_def: BuildingDef = child.get("building_def")
		if not _is_robot_forge_def(building_def):
			continue
		var forge_blueprint: UnitBlueprint = child.get("blueprint")
		if forge_blueprint and not String(forge_blueprint.snapshot_id).is_empty() and not result.has(forge_blueprint.snapshot_id):
			result.append(forge_blueprint.snapshot_id)
		if child.has_method("get_tracked_snapshot_ids"):
			for snapshot_id in child.call("get_tracked_snapshot_ids"):
				var typed_snapshot_id := StringName(str(snapshot_id))
				if not String(typed_snapshot_id).is_empty() and not result.has(typed_snapshot_id):
					result.append(typed_snapshot_id)
	return result

func _on_forge_rally_point_requested(forge: Node) -> void:
	if forge == null or not is_instance_valid(forge):
		return
	_reset_camera_drag_state()
	rally_point_target_forge = forge
	_hide_operation_panel()
	if hud and hud.has_method("show_bottom_prompt"):
		hud.call("show_bottom_prompt", "单击地图空白格点设置集结点，右键或 Esc 取消", 0.0, &"info")
	push_debug_event("进入集结点设置模式：%s" % forge.name)

func _handle_rally_point_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _is_pointer_over_hud():
				return
			_try_set_rally_point_under_mouse()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and not mouse_event.pressed:
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

func _vector2_from_variant(value: Variant) -> Vector2:
	match typeof(value):
		TYPE_VECTOR2:
			return value
		TYPE_VECTOR2I:
			var vector_i: Vector2i = value
			return Vector2(vector_i)
		TYPE_ARRAY:
			var array: Array = value
			if array.size() >= 2:
				return Vector2(float(array[0]), float(array[1]))
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2.ZERO

func _format_vector2_payload(value: Variant) -> Dictionary:
	var vector: Vector2 = value
	return {"x": vector.x, "y": vector.y}

func _reset_camera_drag_state() -> void:
	is_camera_dragging = false
	is_camera_drag_candidate = false
	camera_drag_accumulated = 0.0

func _world_to_screen(world_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_position
