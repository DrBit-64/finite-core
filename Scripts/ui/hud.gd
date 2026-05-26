extends CanvasLayer
class_name MvpHud

@onready var current_goal_label: Label = %CurrentGoalLabel
@onready var resource_summary_label: Label = %ResourceSummaryLabel
@onready var bottom_hint_label: Label = %BottomHintLabel
@onready var object_inspector: PanelContainer = %ObjectInspector
@onready var debug_event_panel: PanelContainer = %DebugEventPanel

func _ready() -> void:
	set_current_goal("阶段 0：验证 MVP 测试入口")
	set_resource_summary("资源面板占位")
	set_bottom_hint("左侧检查器 / 右侧事件面板为阶段 0 占位 UI")
	if object_inspector:
		object_inspector.show_placeholder("未选择对象")
	if debug_event_panel:
		debug_event_panel.add_event_line("MVP HUD 已加载")

func set_current_goal(text: String) -> void:
	if current_goal_label:
		current_goal_label.text = "目标：%s" % text

func set_resource_summary(text: String) -> void:
	if resource_summary_label:
		resource_summary_label.text = text

func set_bottom_hint(text: String) -> void:
	if bottom_hint_label:
		bottom_hint_label.text = text

func inspect_node(node: Node) -> void:
	if object_inspector:
		object_inspector.inspect_node(node)

func push_debug_event(text: String) -> void:
	if debug_event_panel:
		debug_event_panel.add_event_line(text)
