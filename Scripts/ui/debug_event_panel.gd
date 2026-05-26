extends PanelContainer
class_name DebugEventPanel

@export var max_visible_events: int = 20

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var event_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/EventList

var _events: Array[String] = []

func _ready() -> void:
	if title_label:
		title_label.text = "调试事件"
	_refresh()

func add_event_line(text: String) -> void:
	var time_text := Time.get_time_string_from_system()
	_events.append("[%s] %s" % [time_text, text])
	while _events.size() > max_visible_events:
		_events.pop_front()
	_refresh()

func clear_events() -> void:
	_events.clear()
	_refresh()

func _refresh() -> void:
	if event_list == null:
		return

	for child in event_list.get_children():
		child.queue_free()

	if _events.is_empty():
		var empty_label := _make_event_label("暂无事件")
		empty_label.modulate = Color(0.72, 0.74, 0.78, 1.0)
		event_list.add_child(empty_label)
		return

	for event_text in _events:
		event_list.add_child(_make_event_label(event_text))

func _make_event_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)
	return label
