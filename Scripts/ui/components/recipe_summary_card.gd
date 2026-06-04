extends PanelContainer
class_name RecipeSummaryCard

const ItemSlotGridScript := preload("res://Scripts/ui/components/item_slot_grid.gd")

var _title_label: Label
var _body: VBoxContainer
var _input_grid: GridContainer = null
var _output_grid: GridContainer = null
var _content_key: String = ""

func _ready() -> void:
	_build()

func setup(recipe: RecipeDef, resource_defs: Array[ResourceDef], input_cache: Dictionary = {}, output_cache: Dictionary = {}) -> void:
	_build()
	var next_key := _make_structure_key(recipe)
	if next_key != _content_key:
		_content_key = next_key
		_rebuild_static_content(recipe)
	_update_resource_grids(recipe, resource_defs, input_cache, output_cache)

func _build() -> void:
	if _body != null:
		return
	add_theme_stylebox_override("panel", _make_card_style())

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 7)
	add_child(margin)

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 5)
	margin.add_child(root)

	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	root.add_child(_title_label)

	_body = VBoxContainer.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_constant_override("separation", 4)
	root.add_child(_body)

func _rebuild_static_content(recipe: RecipeDef) -> void:
	_input_grid = null
	_output_grid = null
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	if recipe == null:
		_title_label.text = "配方：未选择"
		return

	_title_label.text = "%s  %.1fs" % [recipe.display_name, recipe.duration_seconds]
	_body.add_child(_make_section_label("输入"))
	_input_grid = _make_resource_grid()
	_body.add_child(_input_grid)
	_body.add_child(_make_section_label("输出"))
	_output_grid = _make_resource_grid()
	_body.add_child(_output_grid)

func _update_resource_grids(recipe: RecipeDef, resource_defs: Array[ResourceDef], input_cache: Dictionary, output_cache: Dictionary) -> void:
	if recipe == null:
		return
	if _input_grid:
		_input_grid.call("setup_from_resources", recipe.inputs, resource_defs, input_cache, true, 4)
	if _output_grid:
		_output_grid.call("setup_from_resources", recipe.outputs, resource_defs, output_cache, false, 4)

func _make_resource_grid() -> GridContainer:
	var grid := ItemSlotGridScript.new()
	grid.slot_size = Vector2(34, 34)
	return grid

func _make_structure_key(recipe: RecipeDef) -> String:
	if recipe == null:
		return "none"
	var parts: Array[String] = [
		String(recipe.id),
		_dictionary_key(recipe.inputs),
		_dictionary_key(recipe.outputs),
	]
	return "|".join(parts)

func _dictionary_key(values: Dictionary) -> String:
	var keys := values.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s:%s" % [StringName(key), values[key]])
	return ",".join(parts)

func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.70, 0.78, 0.86, 1.0))
	return label

func _make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.03, 0.038, 0.62)
	style.border_color = Color(0.22, 0.30, 0.38, 0.82)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return style
