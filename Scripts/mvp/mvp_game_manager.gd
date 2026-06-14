extends Node2D
class_name MvpGameManager

const GridOccupancyScript := preload("res://Scripts/map/grid_occupancy.gd")
const MainBaseScene := preload("res://Scenes/buildings/main_base.tscn")
const BaseBuildingScene := preload("res://Scenes/buildings/base_building.tscn")
const MinerScene := preload("res://Scenes/buildings/miner.tscn")
const ProcessorScene := preload("res://Scenes/buildings/processor.tscn")
const RobotForgeScene := preload("res://Scenes/buildings/robot_forge.tscn")
const ResearchTerminalScene := preload("res://Scenes/buildings/research_terminal.tscn")
const BuildingPlacementGhostScene := preload("res://Scenes/map/building_placement_ghost.tscn")
const GridSelectionMarkerScene := preload("res://Scenes/map/grid_selection_marker.tscn")
const GridHoverMarkerScene := preload("res://Scenes/map/grid_hover_marker.tscn")
const ResourceNodeScene := preload("res://Scenes/map/resource_node.tscn")
const RallyPointMarkerScene := preload("res://Scenes/map/rally_point_marker.tscn")
const RobotScene := preload("res://Scenes/robot.tscn")
const DebugEnemyScene := preload("res://Scenes/units/debug_enemy_unit.tscn")
const ScavengerHoundScene := preload("res://Scenes/units/scavenger_hound.tscn")
const EnemyNestScene := preload("res://Scenes/map/enemy_nest.tscn")
const MapConfigLoaderScript := preload("res://Scripts/map/map_config_loader.gd")
const StartingInventoryConfigLoaderScript := preload("res://Scripts/data/starting_inventory_config_loader.gd")
const RuntimeConfigLoaderScript := preload("res://Scripts/data/runtime_config_loader.gd")
const BlueprintLibraryScript := preload("res://Scripts/blueprints/blueprint_library.gd")
const EnemyConfigLoaderScript := preload("res://Scripts/data/enemy_config_loader.gd")
const CampaignStateScript := preload("res://Scripts/campaign/campaign_state.gd")
const TechnologyConfigLoaderScript := preload("res://Scripts/campaign/technology_config_loader.gd")
const ENEMY_CONFIG_PATH := "res://Resources/data/enemies/mvp_enemies.json"
const TECHNOLOGY_CONFIG_PATH := "res://Resources/data/technology/mvp_stage1_technologies.json"
const KEY_ITEM_INITIAL_SENSOR_COIL := &"initial_sensor_coil"
const FOG_REGION_SIZE_CELLS := 4
const OPERATION_PANEL_REFRESH_INTERVAL := 0.1
const UNIT_INSPECTOR_REFRESH_INTERVAL := 0.2
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
var map_water_bodies: Array = []
var map_frontline_supply_points: Array = []
var map_painted_region_cells_cache: Array = []
var map_semantic_cells_by_tag_cache: Dictionary = {}
var map_minimap_static_snapshot: Dictionary = {}
var map_static_cache_version: int = 0
var _stage12_soft_failure_shown: bool = false

func _ready() -> void:
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
		_refresh_operation_panel()

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
		_refresh_operation_panel()

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
	var configured_inventory_path := RuntimeConfigLoaderScript.get_starting_inventory_path(runtime_profile)
	if not configured_inventory_path.is_empty():
		starting_inventory_config_path = configured_inventory_path
	campaign_state = CampaignStateScript.new()
	campaign_state.seed_defaults()
	campaign_state.unlocks_changed.connect(_on_campaign_unlocks_changed)
	campaign_state.technology_unlocked.connect(_on_campaign_technology_unlocked)
	campaign_state.stage_advanced.connect(_on_campaign_stage_advanced)
	resource_defs = MvpDataDefaults.create_resource_defs()
	recipe_defs = MvpDataDefaults.create_recipe_defs()
	basic_rifle_blueprint = MvpDataDefaults.create_basic_rifle_blueprint()
	blueprint_library = BlueprintLibraryScript.new()
	blueprint_library.add_blueprint(basic_rifle_blueprint)
	building_defs = MvpDataDefaults.create_mvp_building_defs()
	technology_defs = TechnologyConfigLoaderScript.load_technology_defs(TECHNOLOGY_CONFIG_PATH)
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
	if hud.has_signal("forge_rally_point_requested"):
		hud.connect("forge_rally_point_requested", Callable(self, "_on_forge_rally_point_requested"))
	if hud.has_signal("blueprint_library_requested"):
		hud.connect("blueprint_library_requested", Callable(self, "_on_blueprint_library_requested"))
	if hud.has_signal("blueprint_save_requested"):
		hud.connect("blueprint_save_requested", Callable(self, "_on_blueprint_save_requested"))
	if hud.has_signal("forge_blueprint_selected"):
		hud.connect("forge_blueprint_selected", Callable(self, "_on_forge_blueprint_selected"))
	if hud.has_signal("technology_research_requested"):
		hud.connect("technology_research_requested", Callable(self, "_on_technology_research_requested"))
	if hud.has_signal("new_game_requested"):
		hud.connect("new_game_requested", Callable(self, "_on_new_game_requested"))
	if hud.has_signal("restart_requested"):
		hud.connect("restart_requested", Callable(self, "_on_restart_requested"))
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
	_create_selection_marker()
	_create_hover_marker()
	_load_fixed_map(map_config)
	_apply_camera_start_from_config(map_config)

func _log_startup_status() -> void:
	push_debug_event("MVP GameManager 已加载")
	push_debug_event("当前目标：%s：%s" % [stage_label, current_goal])
	push_debug_event("初始库存配置：%s" % starting_inventory_config_path)
	push_debug_event("运行时配置：%s，debug 初始资源：%s" % [
		runtime_profile_path,
		"是" if bool(runtime_profile.get("use_debug_starting_inventory", false)) else "否",
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
		hud.call("set_campaign_data", campaign_state, technology_defs, resource_defs, amounts, terminal_status)
	if hud.has_method("set_unlocked_template_ids"):
		hud.call("set_unlocked_template_ids", campaign_state.unlocked_templates)

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

func _find_technology_def(technology_id: StringName) -> Variant:
	for technology in technology_defs:
		if technology.id == technology_id:
			return technology
	return null

func _on_campaign_unlocks_changed() -> void:
	_refresh_build_options()
	_refresh_blueprint_library_ui()
	_refresh_campaign_hud()

func _on_campaign_technology_unlocked(technology_id: StringName) -> void:
	var technology: Variant = _find_technology_def(technology_id)
	var unlock_text := _format_technology_unlocks(technology.unlocks) if technology != null else ""
	push_debug_event("科技解锁：%s %s" % [String(technology_id), unlock_text])
	_play_audio_cue(&"technology_unlocked")
	if hud and hud.has_method("show_bottom_prompt"):
		hud.call("show_bottom_prompt", "科技已生效：%s" % String(technology_id), 2.5, &"info")

func _on_campaign_stage_advanced(next_stage: int) -> void:
	stage_label = "阶段 %d" % next_stage
	set_current_goal("阶段 %d：继续在同一张地图扩张" % next_stage)

func _on_new_game_requested() -> void:
	get_tree().reload_current_scene()

func _on_restart_requested() -> void:
	get_tree().reload_current_scene()

func _get_active_unit_upgrade_ids() -> Array[StringName]:
	if campaign_state == null:
		return []
	return campaign_state.unlocked_upgrades.duplicate()

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

func get_campaign_save_snapshot() -> Dictionary:
	var inventory = _get_main_base_inventory()
	var blueprint_snapshots: Array[Dictionary] = []
	if blueprint_library and blueprint_library.has_method("get_blueprints"):
		for blueprint in blueprint_library.call("get_blueprints"):
			blueprint_snapshots.append({
				"id": String(blueprint.id),
				"display_name": blueprint.display_name,
				"version": blueprint.version,
				"tactical_templates": blueprint.tactical_templates,
				"embedded_rules": blueprint.embedded_rules,
				"state_flag_defaults": blueprint.state_flag_defaults,
			})
	return {
		"version": 1,
		"campaign": campaign_state.to_save_snapshot() if campaign_state else {},
		"inventory": inventory.get_all() if inventory else {},
		"blueprints": blueprint_snapshots,
		"map_regions": map_region_states.duplicate(true),
		"runtime_profile_path": runtime_profile_path,
	}

func get_region_info_for_cell(cell: Vector2i) -> Dictionary:
	if grid_map and grid_map.has_method("get_area_info_for_cell"):
		return _merge_region_metadata(grid_map.call("get_area_info_for_cell", cell))
	if grid_map and grid_map.has_method("get_painted_region_info"):
		return _merge_region_metadata(grid_map.call("get_painted_region_info", cell))
	return {}

func get_region_state_for_cell(cell: Vector2i) -> String:
	var region := _region_for_cell(cell, FOG_REGION_SIZE_CELLS)
	return str(map_region_states.get(_region_key(region), "unknown"))

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
		_hide_operation_panel()
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
	elif resource_nodes_by_cell.has(cell):
		var resource_node: Node = resource_nodes_by_cell[cell]
		_clear_world_unit_selection()
		_show_selection_for_node(resource_node)
		if hud and hud.has_method("inspect_node"):
			hud.call("inspect_node", resource_node)
		_hide_operation_panel()
	else:
		_clear_world_unit_selection()
		_show_selection_for_cell(cell)
		if hud and hud.has_method("inspect_cell"):
			hud.call("inspect_cell", cell, get_region_info_for_cell(cell), get_region_state_for_cell(cell))
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
	if grid_map.has_method("is_rect_blocked_by_semantic_tile") and bool(grid_map.call("is_rect_blocked_by_semantic_tile", origin, building_def.grid_size)):
		return "地形阻挡"
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
	if hud.has_method("set_minimap_snapshot"):
		hud.call("set_minimap_snapshot", _build_minimap_snapshot())

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
		"region_connections": map_region_connections,
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
		var sample := Vector2i(int(rect_value[0]) + int(rect_value[2]) / 2, int(rect_value[1]) + int(rect_value[3]) / 2)
		if _is_cell_discovered(sample):
			return true
	return false

func _get_minimap_water_flow_target_cell() -> Array:
	if main_base == null or not is_instance_valid(main_base):
		return [-1, -1]
	var origin: Vector2i = main_base.get("grid_origin")
	var size: Vector2i = main_base.get("grid_size")
	var center := origin + Vector2i(size.x / 2, size.y / 2)
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
	if selection_marker and selection_marker.has_method("show_selection"):
		selection_marker.call("show_selection", cell, Vector2i.ONE, _get_grid_cell_size())

func _show_selection_for_node(node: Node) -> void:
	_clear_world_unit_selection()
	selected_inspected_node = node
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
		if campaign_state and not campaign_state.is_building_unlocked(building_def.id):
			continue
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
	return building_def != null and building_def.id == MvpDataDefaults.BUILDING_PROCESSOR

func _is_robot_forge_def(building_def: BuildingDef) -> bool:
	return building_def != null and building_def.id == MvpDataDefaults.BUILDING_ROBOT_FORGE

func _is_research_terminal_def(building_def: BuildingDef) -> bool:
	return building_def != null and building_def.id == MvpDataDefaults.BUILDING_RESEARCH_TERMINAL

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

func _load_fixed_map(map_config: Dictionary = {}) -> void:
	if map_config.is_empty():
		map_config = MapConfigLoaderScript.load_map_config(map_config_path)
	var resource_items: Array = map_config.get("resource_nodes", [])
	for item in resource_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		_spawn_resource_node(item)
	var debug_enemy_items: Array = map_config.get("debug_enemies", [])
	for item in debug_enemy_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		_spawn_debug_enemy(item)
	var enemy_nest_items: Array = map_config.get("enemy_nests", [])
	for item in enemy_nest_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		_spawn_enemy_nest(item)
	_initialize_region_fog(map_config)

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

func _spawn_debug_enemy(data: Dictionary) -> void:
	var path_points := _get_world_path_points(data.get("grid_path", []))
	if path_points.is_empty():
		return
	var enemy := DebugEnemyScene.instantiate()
	var layer := _get_layer("EnemyLayer")
	(layer if layer else self).add_child(enemy)
	enemy.name = str(data.get("id", IdProvider.next_id(&"debug_enemy")))
	enemy.global_position = path_points[0]
	if enemy.has_method("setup_debug_enemy"):
		enemy.call("setup_debug_enemy", str(data.get("display_name", "调试靶机")), path_points, bool(data.get("loop", true)))
	push_debug_event("调试敌军已生成：%s，路径点 %d" % [enemy.name, path_points.size()])

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
	map_region_connections = map_config.get("region_connections", []).duplicate(true)
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
		var region := _region_for_cell(cell, region_size)
		min_region.x = mini(min_region.x, region.x)
		min_region.y = mini(min_region.y, region.y)
		max_region.x = maxi(max_region.x, region.x)
		max_region.y = maxi(max_region.y, region.y)

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
		"signal_type": "weak_nest",
	})
	map_region_signal_cells[key] = centers

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
	var guard := ObjectPool.get_instance(ScavengerHoundScene, layer if layer else self, "scavenger_hound") as CharacterBody2D
	if guard == null:
		return
	guard.name = IdProvider.next_id(&"scavenger_hound")
	guard.global_position = nest.call("get_spawn_position")
	guard.call("setup_scavenger_hound", guard_config, nest)
	if guard.has_signal("robot_lost") and not guard.is_connected("robot_lost", Callable(self, "_on_enemy_hound_lost")):
		guard.connect("robot_lost", Callable(self, "_on_enemy_hound_lost"))
	nest.call("register_guard", guard)
	push_debug_event("敌巢补充守军：%s" % guard.name)

func _on_enemy_hound_lost(hound: Node, reason: StringName) -> void:
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log and event_log.has_method("record"):
		var payload := {
			"enemy_id": hound.name,
			"enemy_type": "scavenger_hound",
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

func _on_enemy_nest_destroyed(nest: Node) -> void:
	_apply_abstract_nest_reward(nest)
	_update_region_after_nest_destroyed(nest)
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

func _apply_abstract_nest_reward(nest: Node) -> void:
	if campaign_state == null or nest == null:
		return
	var nest_id := StringName(str(nest.get("nest_id")))
	campaign_state.mark_nest_defeated(nest_id)
	var reward: Dictionary = nest.get("reward")
	if reward.has("technology_item"):
		var technology_item := str(reward.get("technology_item", ""))
		var key_item_id := KEY_ITEM_INITIAL_SENSOR_COIL if technology_item == "初级感应线圈" else StringName(technology_item)
		campaign_state.add_key_item(key_item_id)
		push_debug_event("抽象回收关键道具：%s" % _get_key_item_display_name(key_item_id))
		set_current_goal("建造研究终端，并在科技菜单中研究阶段 1 科技")

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
		building.call("setup_miner", _get_resource_node_at(origin), inventory)
		if building.has_signal("miner_state_changed"):
			building.connect("miner_state_changed", Callable(self, "_on_miner_state_changed").bind(building))
	elif _is_processor_def(building_def) and building.has_method("setup_processor"):
		building.call("setup_processor", _get_resource_recipes(), inventory)
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
	if _is_miner_def(building_def):
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
	elif _is_miner_def(building_def) and hud.has_method("show_miner_panel"):
		hud.call(
			"show_miner_panel",
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
	robot.global_position = forge.call("get_spawn_position") if forge.has_method("get_spawn_position") else forge.global_position
	if robot.has_method("setup_from_blueprint"):
		robot.call(
			"setup_from_blueprint",
			blueprint,
			forge.get("rally_point_position"),
			bool(forge.get("has_rally_point"))
		)
	if robot.has_method("apply_campaign_upgrades"):
		robot.call("apply_campaign_upgrades", _get_active_unit_upgrade_ids())
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
			"active_upgrades": _string_name_array(_get_active_unit_upgrade_ids()),
			"rally_point": _format_vector2_payload(forge.get("rally_point_position")),
			"has_rally_point": bool(forge.get("has_rally_point")),
		})
	push_debug_event("锻造完成：%s -> %s" % [blueprint.display_name, robot.name])
	if hud and hud.has_method("show_bottom_prompt") and bool(forge.get("has_rally_point")):
		hud.call("show_bottom_prompt", "机器人已出厂，将前往锻造厂集结点。", 1.8, &"info")

func _on_blueprint_library_requested() -> void:
	_refresh_blueprint_library_ui()

func _on_blueprint_save_requested(source_blueprint_id: StringName, display_name: String, tactical_templates: Array, embedded_rules: Array, state_flag_defaults: Dictionary, save_as_new: bool) -> void:
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
	saved_blueprint.tactical_templates = tactical_templates.duplicate(true)
	saved_blueprint.embedded_rules = embedded_rules.duplicate(true)
	saved_blueprint.state_flag_defaults = state_flag_defaults.duplicate(true)
	if save_as_new:
		blueprint_library.add_blueprint(saved_blueprint)
		push_debug_event("Blueprint saved as new: %s v%s" % [saved_blueprint.display_name, saved_blueprint.version])
	else:
		blueprint_library.save_blueprint(saved_blueprint)
		push_debug_event("Blueprint updated: %s v%s" % [saved_blueprint.display_name, saved_blueprint.version])
	_refresh_blueprint_library_ui()

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
