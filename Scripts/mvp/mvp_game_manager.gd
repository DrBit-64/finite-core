extends Node2D
class_name MvpGameManager

@export var stage_label: String = "阶段 1"
@export var current_goal: String = "核心数据与事件地基"
@export var resource_summary_placeholder: String = "资源面板占位"
@export var bottom_hint: String = "右侧事件面板显示阶段 1 数据加载摘要"
@export var hud_path: NodePath = ^"%MvpHUD"
@export var grid_map_path: NodePath = ^"%GridMap"

@onready var hud: CanvasLayer = get_node_or_null(hud_path)
@onready var grid_map: Node2D = get_node_or_null(grid_map_path)

var resource_defs: Array[ResourceDef] = []
var recipe_defs: Array[RecipeDef] = []
var basic_rifle_blueprint: UnitBlueprint
var building_defs: Array[BuildingDef] = []

func _ready() -> void:
	_bootstrap_mvp_scene()

func _bootstrap_mvp_scene() -> void:
	_load_stage_one_data()
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
	if hud.has_method("inspect_node"):
		hud.call("inspect_node", self)

func _log_startup_status() -> void:
	push_debug_event("MVP GameManager 已加载")
	push_debug_event("当前目标：%s：%s" % [stage_label, current_goal])
	push_debug_event("阶段 1 数据：资源 %d 项，配方 %d 条，建筑 %d 种" % [
		resource_defs.size(),
		recipe_defs.size(),
		building_defs.size(),
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
