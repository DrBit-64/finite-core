extends GridContainer
class_name ItemSlotGrid

const ItemIconSlotScript := preload("res://Scripts/ui/components/item_icon_slot.gd")

var _content_key: String = ""
var _slots_by_resource_id: Dictionary = {}

@export var slot_size: Vector2 = Vector2(34, 34)
@export var empty_text: String = "空"

func setup_from_resources(
		resources: Dictionary,
		resource_defs: Array[ResourceDef],
		current_amounts: Dictionary = {},
		show_required: bool = false,
		next_columns: int = 4
) -> void:
	var next_key := _make_structure_key(resources, show_required, next_columns)
	var should_rebuild := next_key != _content_key
	if should_rebuild:
		_content_key = next_key
		_clear()
	columns = maxi(1, next_columns)
	add_theme_constant_override("h_separation", 5)
	add_theme_constant_override("v_separation", 5)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_PASS

	if resources.is_empty():
		if should_rebuild:
			var label := Label.new()
			label.text = empty_text
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.74, 1.0))
			add_child(label)
		return

	for resource_id in resources.keys():
		var typed_resource_id := StringName(resource_id)
		var resource_key := String(typed_resource_id)
		var resource_def := _find_resource_def(resource_defs, typed_resource_id)
		var display_name := _resource_name(resource_def, typed_resource_id)
		var required := int(resources[resource_id]) if show_required else -1
		var current := int(current_amounts.get(resource_id, 0)) if show_required else int(resources[resource_id])
		var enough := required < 0 or current >= required
		var slot = _slots_by_resource_id.get(resource_key)
		if slot == null:
			slot = ItemIconSlotScript.new()
			add_child(slot)
			_slots_by_resource_id[resource_key] = slot
		slot.slot_size = slot_size
		slot.setup(
			_resource_icon(resource_def),
			_format_quantity_badge(current, required),
			Color(0.36, 0.78, 0.60, 0.92) if enough else Color(0.95, 0.30, 0.28, 0.96),
			display_name
		)

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_slots_by_resource_id.clear()

func _find_resource_def(resource_defs: Array[ResourceDef], resource_id: StringName) -> ResourceDef:
	for resource_def in resource_defs:
		if resource_def.id == resource_id:
			return resource_def
	return null

func _resource_name(resource_def: ResourceDef, resource_id: StringName) -> String:
	return resource_def.display_name if resource_def else String(resource_id)

func _resource_icon(resource_def: ResourceDef) -> Texture2D:
	if resource_def == null or resource_def.icon_path.is_empty() or not ResourceLoader.exists(resource_def.icon_path):
		return null
	return load(resource_def.icon_path) as Texture2D

func _format_quantity_badge(current_amount: int, required_amount: int) -> String:
	if required_amount >= 0:
		return "%d/%d" % [current_amount, required_amount]
	if current_amount <= 0:
		return ""
	return "%d" % current_amount

func _make_structure_key(resources: Dictionary, show_required: bool, next_columns: int) -> String:
	var parts: Array[String] = ["columns:%d" % next_columns, "required:%s" % show_required]
	var keys := resources.keys()
	keys.sort()
	for resource_id in keys:
		var typed_resource_id := StringName(resource_id)
		var required := int(resources[resource_id]) if show_required else -1
		parts.append("%s:%d" % [String(typed_resource_id), required])
	return "|".join(parts)
