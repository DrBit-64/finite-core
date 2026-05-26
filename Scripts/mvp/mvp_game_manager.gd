extends Node2D
class_name MvpGameManager

@export var stage_label: String = "阶段 0"
@export var current_goal: String = "基线验证与 HUD 占位"
@export var resource_summary_placeholder: String = "资源面板占位"
@export var bottom_hint: String = "左侧检查器 / 右侧事件面板为阶段 0 占位 UI"
@export var hud_path: NodePath = ^"%MvpHUD"
@export var grid_map_path: NodePath = ^"%GridMap"

@onready var hud: CanvasLayer = get_node_or_null(hud_path)
@onready var grid_map: Node2D = get_node_or_null(grid_map_path)

func _ready() -> void:
	_bootstrap_mvp_scene()

func _bootstrap_mvp_scene() -> void:
	_configure_hud()
	_log_startup_status()

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
	if grid_map and grid_map.has_method("describe"):
		push_debug_event("网格地图：%s" % grid_map.call("describe"))
	else:
		push_debug_event("网格地图未找到或尚未配置")

func push_debug_event(message: String) -> void:
	if hud and hud.has_method("push_debug_event"):
		hud.call("push_debug_event", message)
	else:
		print("[MVP] ", message)

func set_current_goal(next_goal: String) -> void:
	current_goal = next_goal
	if hud and hud.has_method("set_current_goal"):
		hud.call("set_current_goal", "%s：%s" % [stage_label, current_goal])
	push_debug_event("目标更新：%s" % current_goal)
