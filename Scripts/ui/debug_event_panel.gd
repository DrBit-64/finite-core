extends PanelContainer
class_name DebugEventPanel

@export var max_visible_events: int = 20
@export var default_window_seconds: float = 300.0

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var root_box: VBoxContainer = $MarginContainer/VBoxContainer
@onready var event_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/EventList

var _events: Array[Dictionary] = []
var _event_log: Node = null
var _window_option: OptionButton = null
var _type_option: OptionButton = null
var _selected_window_seconds: float = 300.0
var _selected_event_type: String = ""
var _refresh_queued: bool = false
var _refresh_type_filter_queued: bool = false

func _ready() -> void:
	if title_label:
		title_label.text = "调试事件"
	_selected_window_seconds = default_window_seconds
	_build_filter_controls()
	_bind_event_log()
	_refresh()

func add_event_line(text: String) -> void:
	_append_event({
		"time": Time.get_ticks_msec() / 1000.0,
		"clock": Time.get_time_string_from_system(),
		"type": "debug",
		"payload": {"message": text},
	})
	_queue_refresh()

func clear_events() -> void:
	_events.clear()
	_refresh_type_filter()
	_refresh()

func _bind_event_log() -> void:
	_event_log = get_node_or_null("/root/CombatEventLog")
	if _event_log == null:
		return

	if _event_log.has_signal("event_recorded"):
		_event_log.event_recorded.connect(_on_event_recorded)
	if _event_log.has_signal("events_cleared"):
		_event_log.events_cleared.connect(clear_events)

	if _event_log.has_method("get_recent_events"):
		for event in _event_log.call("get_recent_events", 0.0, ""):
			_append_event(event)
		_refresh_type_filter()

func _on_event_recorded(event: Dictionary) -> void:
	_append_event(event)
	_queue_refresh(true)

func _queue_refresh(refresh_type_filter: bool = false) -> void:
	_refresh_type_filter_queued = _refresh_type_filter_queued or refresh_type_filter
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_flush_refresh")

func _flush_refresh() -> void:
	_refresh_queued = false
	if _refresh_type_filter_queued:
		_refresh_type_filter_queued = false
		_refresh_type_filter()
	_refresh()

func _build_filter_controls() -> void:
	if root_box == null or _window_option != null:
		return

	var controls := HBoxContainer.new()
	controls.name = "FilterControls"
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 8)
	root_box.add_child(controls)
	root_box.move_child(controls, 1)

	var window_label := _make_control_label("窗口")
	controls.add_child(window_label)

	_window_option = OptionButton.new()
	_window_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_window_option("1 分钟", 60.0)
	_add_window_option("5 分钟", 300.0)
	_add_window_option("10 分钟", 600.0)
	_window_option.item_selected.connect(_on_window_selected)
	controls.add_child(_window_option)
	_select_window_option(default_window_seconds)

	var type_label := _make_control_label("类型")
	controls.add_child(type_label)

	_type_option = OptionButton.new()
	_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type_option.item_selected.connect(_on_type_selected)
	controls.add_child(_type_option)
	_refresh_type_filter()

func _add_window_option(label: String, seconds: float) -> void:
	var index := _window_option.item_count
	_window_option.add_item(label)
	_window_option.set_item_metadata(index, seconds)

func _select_window_option(seconds: float) -> void:
	for index in _window_option.item_count:
		if is_equal_approx(float(_window_option.get_item_metadata(index)), seconds):
			_window_option.select(index)
			_selected_window_seconds = seconds
			return
	_window_option.select(1)
	_selected_window_seconds = 300.0

func _refresh_type_filter() -> void:
	if _type_option == null:
		return

	var previous_type := _selected_event_type
	var types: Array[String] = []
	for event in _events:
		var event_type := str(event.get("type", "event"))
		if not types.has(event_type):
			types.append(event_type)
	types.sort()

	_type_option.clear()
	_type_option.add_item("全部")
	_type_option.set_item_metadata(0, "")
	var selected_index := 0
	for event_type in types:
		var index := _type_option.item_count
		_type_option.add_item(event_type)
		_type_option.set_item_metadata(index, event_type)
		if event_type == previous_type:
			selected_index = index
	_type_option.select(selected_index)
	_selected_event_type = str(_type_option.get_item_metadata(selected_index))

func _on_window_selected(index: int) -> void:
	_selected_window_seconds = float(_window_option.get_item_metadata(index))
	_refresh()

func _on_type_selected(index: int) -> void:
	_selected_event_type = str(_type_option.get_item_metadata(index))
	_refresh()

func _append_event(event: Dictionary) -> void:
	_events.append(event.duplicate(true))
	while _events.size() > max_visible_events * 4:
		_events.pop_front()

func _refresh() -> void:
	if event_list == null:
		return

	for child in event_list.get_children():
		child.queue_free()

	var visible_events := _get_visible_events()
	if visible_events.is_empty():
		var empty_label := _make_event_label("暂无事件")
		empty_label.modulate = Color(0.72, 0.74, 0.78, 1.0)
		event_list.add_child(empty_label)
		return

	for event in visible_events:
		event_list.add_child(_make_event_row(event))

func _get_visible_events() -> Array[Dictionary]:
	var now := Time.get_ticks_msec() / 1000.0
	var result: Array[Dictionary] = []
	for index in range(_events.size() - 1, -1, -1):
		var event := _events[index]
		if _selected_window_seconds > 0.0 and now - float(event.get("time", 0.0)) > _selected_window_seconds:
			continue
		if not _selected_event_type.is_empty() and str(event.get("type", "")) != _selected_event_type:
			continue
		result.append(event)
		if result.size() >= max_visible_events:
			break
	result.reverse()
	return result

func _make_event_row(event: Dictionary) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)

	var payload: Dictionary = event.get("payload", {})
	var summary := _format_event_summary(event, not payload.is_empty())
	var summary_button := Button.new()
	summary_button.text = summary
	summary_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	summary_button.focus_mode = Control.FOCUS_NONE
	summary_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_button.add_theme_font_size_override("font_size", 14)
	summary_button.disabled = payload.is_empty()
	row.add_child(summary_button)

	var payload_label := _make_event_label(_format_payload(payload))
	payload_label.visible = false
	payload_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.90, 1.0))
	row.add_child(payload_label)

	if not payload.is_empty():
		summary_button.pressed.connect(func() -> void:
			payload_label.visible = not payload_label.visible
		)

	return row

func _format_event_summary(event: Dictionary, has_payload: bool) -> String:
	var marker := "▸" if has_payload else " "
	return "%s [%s] %s" % [
		marker,
		str(event.get("clock", Time.get_time_string_from_system())),
		str(event.get("type", "event")),
	]

func _format_payload(payload: Dictionary) -> String:
	if payload.is_empty():
		return ""
	return JSON.stringify(payload, "\t")

func _make_control_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	return label

func _make_event_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)
	return label
