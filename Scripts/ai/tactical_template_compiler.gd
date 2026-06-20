extends RefCounted
class_name TacticalTemplateCompiler

const TEMPLATE_DEFAULT_ATTACK := "default_attack"
const TEMPLATE_MOVE_TO_RALLY := "move_to_rally"
const TEMPLATE_RALLY_THEN_ATTACK := "rally_then_attack"
const TEMPLATE_TARGET_NEAREST := "target_nearest"
const TEMPLATE_REACTIVE_OVERRIDE := "reactive_override"
const TEMPLATE_WEAPON_HEAT_CONTROL := "weapon_heat_control"
const TEMPLATE_PRIORITIZE_TAGGED_TARGET := "prioritize_tagged_target"
const TEMPLATE_TARGET_BACKLINE_NEAR_CURRENT := "target_backline_near_current"
const TEMPLATE_SALVAGE_AND_RETURN := "salvage_and_return"
const TEMPLATE_SUPPLY_RUN := "supply_run"
const TEMPLATE_HAZARD_AVOIDANCE := "hazard_avoidance"

const DEFAULT_ARRIVAL_DISTANCE := 20.0
const DEFAULT_RALLY_RADIUS := 90.0
const DEFAULT_REQUIRED_ALLIES := 4
const MIN_SQUAD_ARRIVAL_DISTANCE := 48.0

static func get_template_defs() -> Array[Dictionary]:
	return [
		{
			"id": TEMPLATE_WEAPON_HEAT_CONTROL,
			"display_name": "热能武器控制",
			"intent": "热量过高时停火散热，降温后交还默认脑干继续战斗。",
			"parameters": [
				{"id": "hold_heat_percent", "display_name": "停火热量%", "type": "float", "default": 0.82},
			],
		},
		{
			"id": TEMPLATE_DEFAULT_ATTACK,
			"display_name": "默认进攻",
			"intent": "不添加自定义规则。机器人出生后直接使用默认脑干寻找、接近并攻击敌人。",
			"parameters": [],
		},
		{
			"id": TEMPLATE_MOVE_TO_RALLY,
			"display_name": "先到集结点",
			"intent": "机器人先移动到锻造厂设置的集结点，到达后交给默认脑干进攻。",
			"parameters": [
				{"id": "arrival_distance", "display_name": "到达距离", "type": "float", "default": DEFAULT_ARRIVAL_DISTANCE},
			],
		},
		{
			"id": TEMPLATE_RALLY_THEN_ATTACK,
			"display_name": "集结后进攻",
			"intent": "机器人先到集结点，等待附近友军达到人数门槛后再交给默认脑干进攻。",
			"parameters": [
				{"id": "required_allies", "display_name": "等待人数", "type": "int", "default": DEFAULT_REQUIRED_ALLIES},
				{"id": "rally_radius", "display_name": "集结半径", "type": "float", "default": DEFAULT_RALLY_RADIUS},
				{"id": "arrival_distance", "display_name": "到达距离", "type": "float", "default": DEFAULT_ARRIVAL_DISTANCE},
			],
		},
		{
			"id": TEMPLATE_TARGET_NEAREST,
			"display_name": "目标选择：最近敌人",
			"intent": "使用当前默认目标选择器锁定最近的敌方单位或敌方建筑。阶段 10 先作为只读战术声明。",
			"parameters": [],
		},
		{
			"id": TEMPLATE_PRIORITIZE_TAGGED_TARGET,
			"display_name": "目标选择：优先特定目标",
			"intent": "若当前目标附近存在带指定标签的敌人，则临时改锁该目标；不会全图追逐远处单位。",
			"parameters": [
				{"id": "search_radius", "display_name": "搜索半径", "type": "float", "default": 180.0},
				{"id": "tag", "display_name": "目标标签", "type": "tag", "default": "backline"},
			],
		},
		{
			"id": TEMPLATE_REACTIVE_OVERRIDE,
			"display_name": "紧急覆盖通道",
			"intent": "预留高优先级中断入口，用于后续撤退、护盾、弹药不足等反应式规则。阶段 10 只显示，不生成行为。",
			"parameters": [],
		},
		{
			"id": TEMPLATE_SALVAGE_AND_RETURN,
			"display_name": "回收并返航",
			"intent": "扫描高价值残骸，拾取或牵引后在满载、低血或高风险时返回基地。阶段 17 由物流调度器执行。",
			"parameters": [
				{"id": "scan_radius", "display_name": "扫描半径", "type": "float", "default": 520.0},
				{"id": "min_value", "display_name": "最低价值", "type": "int", "default": 1},
				{"id": "return_hp_percent", "display_name": "返航血量%", "type": "float", "default": 0.45},
			],
		},
		{
			"id": TEMPLATE_SUPPLY_RUN,
			"display_name": "前线补给",
			"intent": "给前线补给点、维修点或生产建筑配送关键物资。阶段 17 先复用现有远程物流调度。",
			"parameters": [
				{"id": "min_load_percent", "display_name": "最低装载%", "type": "float", "default": 0.70},
			],
		},
		{
			"id": TEMPLATE_HAZARD_AVOIDANCE,
			"display_name": "危险规避",
			"intent": "附近敌人过多或自身血量过低时撤退；携带关键物时优先返航。阶段 17 由物流调度器执行。",
			"parameters": [
				{"id": "enemy_radius", "display_name": "危险半径", "type": "float", "default": 260.0},
				{"id": "enemy_count", "display_name": "敌人数量", "type": "int", "default": 2},
				{"id": "return_hp_percent", "display_name": "返航血量%", "type": "float", "default": 0.45},
			],
		},
	]

static func get_template_def(template_id: String) -> Dictionary:
	for template_def in get_template_defs():
		if str(template_def.get("id", "")) == template_id:
			return template_def
	return {}

static func make_instance(template_id: String, params: Dictionary = {}) -> Dictionary:
	var template_def := get_template_def(template_id)
	var normalized_params := {}
	for parameter in template_def.get("parameters", []):
		var param_id := str(parameter.get("id", ""))
		if param_id.is_empty():
			continue
		normalized_params[param_id] = params.get(param_id, parameter.get("default"))
	for key in params.keys():
		if not normalized_params.has(key):
			normalized_params[key] = params[key]
	return {
		"id": template_id,
		"display_name": str(template_def.get("display_name", template_id)),
		"params": normalized_params,
	}

static func make_default_attack_instance() -> Dictionary:
	return make_instance(TEMPLATE_DEFAULT_ATTACK)

static func make_move_to_rally_instance(arrival_distance: float = DEFAULT_ARRIVAL_DISTANCE) -> Dictionary:
	return make_instance(TEMPLATE_MOVE_TO_RALLY, {"arrival_distance": arrival_distance})

static func make_rally_then_attack_instance(
	required_allies: int = DEFAULT_REQUIRED_ALLIES,
	rally_radius: float = DEFAULT_RALLY_RADIUS,
	arrival_distance: float = DEFAULT_ARRIVAL_DISTANCE
) -> Dictionary:
	return make_instance(TEMPLATE_RALLY_THEN_ATTACK, {
		"required_allies": required_allies,
		"rally_radius": rally_radius,
		"arrival_distance": arrival_distance,
	})

static func normalize_templates(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var template_id := str(item.get("id", ""))
		if template_id.is_empty():
			continue
		result.append(make_instance(template_id, item.get("params", {})))
	return result

static func compile_templates(templates: Array) -> Dictionary:
	var rules: Array = []
	var state_defaults := {}
	var normalized_templates := normalize_templates(templates)
	for template in normalized_templates:
		var template_id := str(template.get("id", ""))
		if template_id != TEMPLATE_WEAPON_HEAT_CONTROL:
			continue
		rules.append_array(_compile_weapon_heat_control(template))
	for template in normalized_templates:
		var template_id := str(template.get("id", ""))
		match template_id:
			TEMPLATE_MOVE_TO_RALLY:
				rules.append_array(_compile_move_to_rally(template))
				state_defaults["rallied"] = false
			TEMPLATE_RALLY_THEN_ATTACK:
				rules.append_array(_compile_rally_then_attack(template))
				state_defaults["rallied"] = false
				state_defaults["squad_ready"] = false
			TEMPLATE_PRIORITIZE_TAGGED_TARGET, TEMPLATE_TARGET_BACKLINE_NEAR_CURRENT:
				rules.append_array(_compile_prioritize_tagged_target(template))
	return {
		"rules": rules,
		"state_flag_defaults": state_defaults,
	}

static func describe_template(template: Dictionary) -> String:
	var template_def := get_template_def(str(template.get("id", "")))
	var params: Dictionary = template.get("params", {})
	match str(template.get("id", "")):
		TEMPLATE_MOVE_TO_RALLY:
			return "先前往锻造厂集结点；到达 %.0f px 内后交给默认脑干。" % float(params.get("arrival_distance", DEFAULT_ARRIVAL_DISTANCE))
		TEMPLATE_RALLY_THEN_ATTACK:
			return "先到集结点；%.0f px 内友军达到 %d 个后，交给默认脑干进攻。" % [
				float(params.get("rally_radius", DEFAULT_RALLY_RADIUS)),
				int(params.get("required_allies", DEFAULT_REQUIRED_ALLIES)),
			]
		TEMPLATE_PRIORITIZE_TAGGED_TARGET, TEMPLATE_TARGET_BACKLINE_NEAR_CURRENT:
			return "当前目标 %.0f px 内若有 `%s` 标签单位，则临时切换目标。" % [
				float(params.get("search_radius", 180.0)),
				str(params.get("tag", "backline")),
			]
	return str(template_def.get("intent", "使用默认战术行为。"))

static func _compile_move_to_rally(template: Dictionary) -> Array:
	var params: Dictionary = template.get("params", {})
	var arrival_distance := float(params.get("arrival_distance", DEFAULT_ARRIVAL_DISTANCE))
	var template_name := _template_name(template)
	return [
		_rule("sequence_move_to_rally", "前往集结点", template, "前往集结点", [
			{"type": "has_rally_point"},
			{"type": "self_flag_is", "flag": "rallied", "value": false},
			{"type": "distance_to_rally_greater", "value": arrival_distance}
		], "move_to_rally"),
		_rule("sequence_mark_rallied", "标记已集结", template, "到达集结点", [
			{"type": "has_rally_point"},
			{"type": "self_flag_is", "flag": "rallied", "value": false},
			{"type": "distance_to_rally_less_equal", "value": arrival_distance}
		], "set_self_flag", {"flag": "rallied", "value": true}),
		_rule("sequence_default_after_rally", "%s完成" % template_name, template, "默认脑干接管", [
			{"type": "self_flag_is", "flag": "rallied", "value": true}
		], "default_combat"),
	]

static func _compile_rally_then_attack(template: Dictionary) -> Array:
	var params: Dictionary = template.get("params", {})
	var arrival_distance := float(params.get("arrival_distance", DEFAULT_ARRIVAL_DISTANCE))
	var rally_radius := float(params.get("rally_radius", DEFAULT_RALLY_RADIUS))
	var required_allies := int(params.get("required_allies", DEFAULT_REQUIRED_ALLIES))
	var squad_arrival_distance := minf(rally_radius, maxf(arrival_distance, MIN_SQUAD_ARRIVAL_DISTANCE))
	return [
		_rule("move_to_rally", "前往集结点", template, "前往集结点", [
			{"type": "has_rally_point"},
			{"type": "self_flag_is", "flag": "rallied", "value": false},
			{"type": "distance_to_rally_greater", "value": squad_arrival_distance}
		], "move_to_rally"),
		_rule("mark_rallied", "标记已集结", template, "到达集结点", [
			{"type": "has_rally_point"},
			{"type": "self_flag_is", "flag": "rallied", "value": false},
			{"type": "distance_to_rally_less_equal", "value": squad_arrival_distance}
		], "set_self_flag", {"flag": "rallied", "value": true}),
		_rule("wait_for_squad", "等待队友", template, "等待队友", [
			{"type": "has_rally_point"},
			{"type": "self_flag_is", "flag": "rallied", "value": true},
			{"type": "self_flag_is", "flag": "squad_ready", "value": false},
			{"type": "allies_near_rally_less", "value": required_allies, "radius": rally_radius}
		], "wait"),
		_rule("mark_squad_ready", "等待队友", template, "队友到齐", [
			{"type": "has_rally_point"},
			{"type": "self_flag_is", "flag": "rallied", "value": true},
			{"type": "self_flag_is", "flag": "squad_ready", "value": false},
			{"type": "allies_near_rally_at_least", "value": required_allies, "radius": rally_radius}
		], "set_self_flag", {"flag": "squad_ready", "value": true}),
		_rule("default_after_rally", "默认脑干接管", template, "默认脑干接管", [
			{"type": "self_flag_is", "flag": "squad_ready", "value": true}
		], "default_combat"),
	]

static func _compile_prioritize_tagged_target(template: Dictionary) -> Array:
	var params: Dictionary = template.get("params", {})
	var search_radius := maxf(1.0, float(params.get("search_radius", 180.0)))
	var tag := str(params.get("tag", "backline"))
	if tag.is_empty():
		tag = "backline"
	return [
		_rule("prioritize_tagged_target", "优先特定目标", template, "目标选择", [
			{"type": "has_enemy"}
		], "prioritize_tagged_target", {
			"search_radius": search_radius,
			"tag": tag,
		}),
	]

static func _compile_weapon_heat_control(template: Dictionary) -> Array:
	var params: Dictionary = template.get("params", {})
	var hold_heat_percent := clampf(float(params.get("hold_heat_percent", 0.82)), 0.1, 1.0)
	return [
		_rule("hold_fire_when_hot", "过热停火", template, "热能控制", [
			{"type": "heat_above_percent", "value": hold_heat_percent}
		], "hold_fire_for_heat"),
	]

static func _rule(
	rule_id: String,
	rule_name: String,
	template: Dictionary,
	stage_name: String,
	conditions: Array,
	action: String,
	extra: Dictionary = {}
) -> Dictionary:
	var result := {
		"id": rule_id,
		"name": rule_name,
		"template_id": str(template.get("id", "")),
		"template_name": _template_name(template),
		"template_stage": stage_name,
		"subject": "self",
		"match_mode": "all",
		"conditions": conditions,
		"action": action,
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result

static func _template_name(template: Dictionary) -> String:
	var template_name := str(template.get("display_name", ""))
	if not template_name.is_empty():
		return template_name
	var template_def := get_template_def(str(template.get("id", "")))
	return str(template_def.get("display_name", template.get("id", "未命名模板")))
