extends PanelContainer
class_name ObjectInspector

const ItemIconSlotScript := preload("res://Scripts/ui/components/item_icon_slot.gd")
const ItemSlotGridScript := preload("res://Scripts/ui/components/item_slot_grid.gd")
const RecipeSummaryCardScript := preload("res://Scripts/ui/components/recipe_summary_card.gd")
const BlueprintPartSlotScript := preload("res://Scripts/ui/components/blueprint_part_slot.gd")

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var body_label: Label = $MarginContainer/VBoxContainer/BodyLabel
@onready var content_box: VBoxContainer = $MarginContainer/VBoxContainer

var _detail_root: VBoxContainer = null
var _resource_defs: Array[ResourceDef] = []

func _ready() -> void:
	_resource_defs = MvpDataDefaults.create_resource_defs()
	_ensure_detail_root()
	_detail_root.visible = false

func show_placeholder(message: String) -> void:
	_clear_detail_root()
	if title_label:
		title_label.text = "对象检查器"
	if body_label:
		body_label.visible = true
		body_label.text = message

func inspect_node(node: Node) -> void:
	if node == null:
		show_placeholder("未选择对象")
		return

	if title_label:
		title_label.text = node.get_display_name() if node.has_method("get_display_name") else node.name
	if _try_render_cargo_robot(node):
		return
	if _try_render_building(node):
		return
	if body_label:
		_clear_detail_root()
		body_label.visible = true
		var lines: Array[String] = []
		if node.has_method("get_inspector_lines"):
			lines = node.call("get_inspector_lines")
		else:
			lines = [
				"类型：%s" % node.get_class(),
				"路径：%s" % node.get_path(),
			]
		body_label.text = "\n".join(lines)

func inspect_cell(cell: Vector2i, region_info: Dictionary = {}, region_state: String = "") -> void:
	_clear_detail_root()
	if title_label:
		title_label.text = "空地"
	if body_label:
		body_label.visible = true
		var lines: Array[String] = [
			"网格：%s, %s" % [cell.x, cell.y],
			"状态：未占用",
		]
		lines.append_array(_format_region_lines(region_info, region_state))
		body_label.text = "\n".join(lines)

func _format_region_lines(region_info: Dictionary, region_state: String) -> Array[String]:
	var lines: Array[String] = []
	if region_info.is_empty() and region_state.is_empty():
		return lines
	lines.append("")
	lines.append("区域信息")
	if not region_info.is_empty():
		lines.append("区域：%s" % str(region_info.get("display_name", "未知区域")))
		lines.append("区域 ID：%s" % str(region_info.get("region_id", "-")))
		lines.append("类型：%s" % _format_region_type(str(region_info.get("region_type", ""))))
		lines.append("威胁等级：%s" % int(region_info.get("threat_level", 0)))
		lines.append("推荐阶段：%s" % int(region_info.get("recommended_stage", 0)))
	else:
		lines.append("区域：未配置")
	if not region_state.is_empty():
		lines.append("发现状态：%s" % _format_region_state(region_state))
	return lines

func _format_region_type(region_type: String) -> String:
	match region_type:
		"starting_basin":
			return "起始盆地"
		"crystal_wasteland":
			return "晶体荒原"
		"interference_highlands":
			return "干扰高地"
		"wreckage_battlefield":
			return "残骸战场"
		"brain_core_outer":
			return "主脑核心外围"
	return region_type if not region_type.is_empty() else "-"

func _format_region_state(region_state: String) -> String:
	match region_state:
		"unknown":
			return "未知"
		"signal":
			return "信号"
		"scanned":
			return "已扫描"
		"visible":
			return "实时可见"
		"controlled":
			return "已控制"
	return region_state

func _try_render_building(node: Node) -> bool:
	var building_def: BuildingDef = node.get("building_def")
	if building_def == null:
		return false
	_ensure_detail_root()
	_clear_detail_root()
	if body_label:
		body_label.visible = false
	_detail_root.visible = true

	_detail_root.add_child(_make_building_header(node, building_def))
	_detail_root.add_child(_make_health_block(node))
	var grid_origin: Vector2i = node.get("grid_origin")
	var grid_size: Vector2i = node.get("grid_size")
	_detail_root.add_child(_make_info_label("网格：%s, %s    占格：%sx%s" % [
		grid_origin.x,
		grid_origin.y,
		grid_size.x,
		grid_size.y,
	]))
	_detail_root.add_child(_make_info_label("建造配方：%s" % String(building_def.build_recipe_id)))
	_add_cost_section(building_def)
	_add_building_specific_sections(node)
	return true

func _try_render_cargo_robot(node: Node) -> bool:
	if not node.has_method("is_cargo_robot") or not bool(node.call("is_cargo_robot")):
		return false
	_ensure_detail_root()
	_clear_detail_root()
	if body_label:
		body_label.visible = false
	_detail_root.visible = true

	_detail_root.add_child(_make_robot_header(node))
	_detail_root.add_child(_make_health_block(node))
	_detail_root.add_child(_make_info_label("速度：%.1f    货舱：%s / %s" % [
		float(node.get("speed")),
		int(node.call("get_cargo_used_capacity")) if node.has_method("get_cargo_used_capacity") else 0,
		int(node.get("cargo_capacity")),
	]))
	_detail_root.add_child(_make_section_label("货舱"))
	var cargo: Dictionary = node.call("get_cargo_inventory") if node.has_method("get_cargo_inventory") else {}
	if cargo.is_empty():
		_detail_root.add_child(_make_info_label("空"))
	else:
		_detail_root.add_child(_make_resource_slot_grid(cargo, {}, false, 4, Vector2(42.5, 42.5)))
	_detail_root.add_child(_make_section_label("当前物流任务"))
	if node.has_method("get_logistics_task_summary_lines"):
		for line in node.call("get_logistics_task_summary_lines"):
			_detail_root.add_child(_make_info_label(str(line)))
	else:
		_detail_root.add_child(_make_info_label("物流任务：无"))
	return true

func _ensure_detail_root() -> void:
	if _detail_root != null:
		return
	_detail_root = VBoxContainer.new()
	_detail_root.name = "RichInspectorBody"
	_detail_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_root.add_theme_constant_override("separation", 8)
	content_box.add_child(_detail_root)

func _clear_detail_root() -> void:
	_ensure_detail_root()
	for child in _detail_root.get_children():
		_detail_root.remove_child(child)
		child.queue_free()
	_detail_root.visible = false

func _make_building_header(node: Node, building_def: BuildingDef) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var slot := ItemIconSlotScript.new()
	slot.slot_size = Vector2(64, 64)
	slot.setup(_load_texture(building_def.icon_path), "", Color(0.36, 0.62, 0.88, 0.92), building_def.display_name)
	row.add_child(slot)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)

	var name_label := _make_info_label(building_def.display_name, 16, Color(0.96, 0.98, 1.0, 1.0))
	texts.add_child(name_label)
	texts.add_child(_make_info_label("类型：%s" % ("敌巢" if node is EnemyNest else "建筑")))
	texts.add_child(_make_info_label("状态：%s" % ("运行中" if bool(node.call("is_alive")) else "已摧毁")))
	return row

func _make_robot_header(node: Node) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var slot := ItemIconSlotScript.new()
	slot.slot_size = Vector2(64, 64)
	slot.setup(_load_texture(str(node.get("icon_path"))), "", Color(0.48, 0.88, 0.98, 0.92), node.get_display_name() if node.has_method("get_display_name") else node.name)
	row.add_child(slot)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)

	texts.add_child(_make_info_label(node.get_display_name() if node.has_method("get_display_name") else node.name, 16, Color(0.96, 0.98, 1.0, 1.0)))
	texts.add_child(_make_info_label("类型：货运机器人"))
	texts.add_child(_make_info_label("状态：%s" % str(node.get("logistics_status_text"))))
	return row

func _make_health_block(node: Node) -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 3)
	var hp := int(node.get("hp"))
	var max_hp := int(node.get("max_hp"))
	root.add_child(_make_info_label("生命：%s / %s" % [hp, max_hp], 13, Color(0.88, 0.94, 0.98, 1.0)))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = maxf(1.0, float(max_hp))
	bar.value = clampf(float(hp), 0.0, float(max_hp))
	root.add_child(bar)
	return root

func _add_cost_section(building_def: BuildingDef) -> void:
	if building_def.build_cost.is_empty():
		return
	_detail_root.add_child(_make_section_label("建造成本"))
	_detail_root.add_child(_make_resource_slot_grid(building_def.build_cost, {}, false, 4))

func _add_building_specific_sections(node: Node) -> void:
	if node is MainBase:
		_add_main_base_section(node as MainBase)
	elif node is MinerBuilding:
		_add_miner_section(node as MinerBuilding)
	elif node is ProcessorBuilding:
		_add_processor_section(node as ProcessorBuilding)
	elif node is RobotForgeBuilding:
		_add_forge_section(node as RobotForgeBuilding)
	elif node.has_method("setup_water_pump"):
		_add_water_pump_section(node)
	elif node.has_method("get_all_resources"):
		_add_storage_section(node)
	elif node is EnemyNest:
		_add_enemy_nest_section(node as EnemyNest)

func _add_main_base_section(main_base: MainBase) -> void:
	_detail_root.add_child(_make_section_label("库存"))
	var inventory: Dictionary = main_base.inventory.get_all()
	if inventory.is_empty():
		_detail_root.add_child(_make_info_label("空"))
		return
	_detail_root.add_child(_make_resource_slot_grid(inventory, {}, false, 4, Vector2(42.5, 42.5)))
	_detail_root.add_child(_make_info_label("建设质料产出：%s / 分钟" % main_base.construction_mass_per_minute))
	_detail_root.add_child(_make_info_label("服务半径：%s 格" % main_base.service_radius_cells))

func _add_storage_section(storage_node: Node) -> void:
	_detail_root.add_child(_make_section_label("库存"))
	var inventory: Dictionary = storage_node.call("get_all_resources")
	if inventory.is_empty():
		_detail_root.add_child(_make_info_label("空"))
		return
	_detail_root.add_child(_make_resource_slot_grid(inventory, {}, false, 4, Vector2(42.5, 42.5)))

func _add_processor_section(processor: ProcessorBuilding) -> void:
	_detail_root.add_child(_make_section_label("当前配方"))
	var card := RecipeSummaryCardScript.new()
	card.setup(processor.selected_recipe, _resource_defs, processor.input_cache, processor.output_cache)
	_detail_root.add_child(card)
	_detail_root.add_child(_make_info_label("状态：%s" % processor.status_text))
	_detail_root.add_child(_make_info_label("进度：%d%%" % int(processor.get_progress_ratio() * 100.0)))
	_add_cache_section("原料缓存", processor.input_cache)
	_add_cache_section("产物缓存", processor.output_cache)

func _add_miner_section(miner: MinerBuilding) -> void:
	_detail_root.add_child(_make_section_label("开采配方"))
	var card := RecipeSummaryCardScript.new()
	card.setup(miner.get_mining_recipe(), _resource_defs, miner.input_cache, miner.output_cache)
	_detail_root.add_child(card)
	_detail_root.add_child(_make_info_label("绑定矿点：%s" % miner._get_bound_node_name()))
	_detail_root.add_child(_make_info_label("状态：%s" % miner.status_text))
	_detail_root.add_child(_make_info_label("进度：%d%%" % int(miner.get_progress_ratio() * 100.0)))
	_add_cache_section("产物缓存", miner.output_cache)

func _add_forge_section(forge: RobotForgeBuilding) -> void:
	var blueprint: UnitBlueprint = forge.blueprint
	_detail_root.add_child(_make_section_label("生产蓝图"))
	if blueprint == null:
		_detail_root.add_child(_make_info_label("未绑定蓝图"))
	else:
		var part_row := HBoxContainer.new()
		part_row.add_theme_constant_override("separation", 8)
		var chassis_slot := BlueprintPartSlotScript.new()
		chassis_slot.setup("底盘", blueprint.chassis_display_name, _load_texture(blueprint.chassis_icon_path))
		part_row.add_child(chassis_slot)
		for index in blueprint.module_display_names.size():
			var module_slot := BlueprintPartSlotScript.new()
			var icon_path := blueprint.module_icon_paths[index] if index < blueprint.module_icon_paths.size() else ""
			module_slot.setup("模块", blueprint.module_display_names[index], _load_texture(icon_path))
			part_row.add_child(module_slot)
		_detail_root.add_child(part_row)
		_detail_root.add_child(_make_info_label("蓝图：%s v%s" % [blueprint.display_name, blueprint.version]))
		_detail_root.add_child(_make_section_label("生产成本"))
		_detail_root.add_child(_make_resource_slot_grid(blueprint.production_cost, {}, false, 4))
	_detail_root.add_child(_make_info_label("存活：%s / %s" % [forge.get_alive_count(), forge.target_alive_count]))
	_detail_root.add_child(_make_info_label("状态：%s" % forge.status_text))
	_detail_root.add_child(_make_info_label("集结点：%s" % (forge._format_rally_point() if forge.has_rally_point else "未设置")))

func _add_water_pump_section(pump: Node) -> void:
	_detail_root.add_child(_make_section_label("抽水"))
	_detail_root.add_child(_make_info_label("状态：%s" % str(pump.get("status_text"))))
	_detail_root.add_child(_make_info_label("产出：%s / 分钟" % int(pump.get("output_per_minute"))))
	_detail_root.add_child(_make_info_label("进度：%d%%" % int(float(pump.call("get_progress_ratio")) * 100.0)))
	_add_cache_section("产物缓存", pump.get("output_cache"))

func _add_enemy_nest_section(nest: EnemyNest) -> void:
	_detail_root.add_child(_make_info_label("守军：%s / %s" % [nest.get_guard_count(), nest.max_guard_count]))
	_detail_root.add_child(_make_info_label("补充倒计时：%.1fs" % nest.replenish_seconds_remaining))
	_detail_root.add_child(_make_info_label("奖励：%s" % nest._format_reward_text()))

func _add_cache_section(title: String, cache: Dictionary) -> void:
	_detail_root.add_child(_make_section_label(title))
	if cache.is_empty():
		_detail_root.add_child(_make_info_label("空"))
		return
	_detail_root.add_child(_make_resource_slot_grid(cache, {}, false, 4))

func _make_resource_slot_grid(
		resources: Dictionary,
		current_amounts: Dictionary = {},
		show_required: bool = false,
		columns: int = 4,
		slot_size: Vector2 = Vector2(34, 34)
) -> GridContainer:
	var grid := ItemSlotGridScript.new()
	grid.slot_size = slot_size
	grid.setup_from_resources(resources, _resource_defs, current_amounts, show_required, columns)
	return grid

func _make_section_label(text: String) -> Label:
	return _make_info_label(text, 13, Color(0.72, 0.82, 0.92, 1.0))

func _make_info_label(text: String, font_size: int = 13, color: Color = Color(0.86, 0.90, 0.94, 1.0)) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
