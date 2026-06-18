extends Node
class_name AIController

const AI_RULE_SCRIPT := preload("res://Scripts/ai_rule.gd")
const AI_CONDITION_SCRIPT := preload("res://Scripts/ai_condition.gd")

@export var logic_rules: Array = []
@export var tick_interval: float = 0.2
@export var use_internal_timer: bool = true

@onready var tick_timer: Timer = $TickTimer
@onready var robot: CharacterBody2D = get_parent() as CharacterBody2D

var _rule_trigger_counts: Dictionary = {}
var _active_rule_id: String = ""
var _last_logic_handled: bool = false
var _next_evaluation_msec: int = 0

func _ready() -> void:
	if robot and robot.has_method("uses_physics_ai_tick") and bool(robot.call("uses_physics_ai_tick")):
		use_internal_timer = false
	if tick_timer:
		tick_timer.wait_time = tick_interval
		tick_timer.one_shot = false
		if use_internal_timer:
			tick_timer.start()
		else:
			tick_timer.stop()

func set_logic_rules(next_rules: Array) -> void:
	logic_rules = next_rules.duplicate(true)
	_rule_trigger_counts.clear()
	_active_rule_id = ""
	_last_logic_handled = false
	_next_evaluation_msec = 0
	for rule in logic_rules:
		if rule == null:
			continue
		var rule_id := str(_rule_get(rule, "id", _rule_get(rule, "name", "unnamed_rule")))
		if not rule_id.is_empty():
			_rule_trigger_counts[rule_id] = 0

func has_rules() -> bool:
	return not logic_rules.is_empty()

func evaluate_logic() -> bool:
	if robot == null:
		return false
	var now := Time.get_ticks_msec()
	if now < _next_evaluation_msec:
		return _last_logic_handled
	_next_evaluation_msec = now + roundi(maxf(0.01, tick_interval) * 1000.0)
	for rule in logic_rules:
		if rule == null:
			continue
		var subject = _rule_get(rule, "subject", AI_RULE_SCRIPT.Subject.TARGET_NEAREST)
		var target := _resolve_subject_target(subject)
		if evaluate_single_rule(rule, target):
			var rule_name := str(_rule_get(rule, "name", _rule_get(rule, "id", "未命名规则")))
			var handled := execute_action(_rule_get(rule, "action", AI_RULE_SCRIPT.Action.STOP_ACTION), target, rule)
			_activate_rule(rule, rule_name, handled)
			_last_logic_handled = handled
			return handled
	_active_rule_id = ""
	_last_logic_handled = false
	return false

func _resolve_subject_target(subject: Variant) -> Node2D:
	if robot == null:
		return null
	var subject_text := str(subject).to_lower()
	if subject_text == "self":
		return robot
	if subject_text == "target_nearest":
		return robot.get_current_enemy() if robot.has_method("get_current_enemy") else null
	if subject_text == "target_lowest_hp":
		return robot.get_lowest_hp_enemy() if robot.has_method("get_lowest_hp_enemy") else null
	match subject:
		AI_RULE_SCRIPT.Subject.SELF:
			return robot
		AI_RULE_SCRIPT.Subject.TARGET_NEAREST:
			if robot.has_method("get_current_enemy"):
				return robot.get_current_enemy()
		AI_RULE_SCRIPT.Subject.TARGET_LOWEST_HP:
			if robot.has_method("get_lowest_hp_enemy"):
				return robot.get_lowest_hp_enemy()
	return null

func evaluate_single_rule(rule: Variant, target: Node2D) -> bool:
	if rule == null:
		return false
	var conditions: Array = _rule_get(rule, "conditions", [])
	if conditions.is_empty():
		return true

	var match_mode = _rule_get(rule, "match_mode", AI_RULE_SCRIPT.MatchMode.MATCH_ALL)
	var match_text := str(match_mode).to_lower()
	var match_all := match_text == "all" or match_text == "match_all"
	if typeof(match_mode) == TYPE_INT:
		match_all = match_all or int(match_mode) == AI_RULE_SCRIPT.MatchMode.MATCH_ALL
	if match_all:
		for cond in conditions:
			if not check_condition(target, cond):
				return false
		return true

	for cond in conditions:
		if check_condition(target, cond):
			return true
	return false

func check_condition(target: Node2D, cond: Variant) -> bool:
	if robot == null or cond == null:
		return false
	var cond_type = _rule_get(cond, "type", -1)
	var cond_param: String = str(_rule_get(cond, "param", _rule_get(cond, "value", "")))
	var cond_text := str(cond_type).to_lower()
	match cond_text:
		"has_rally_point":
			return bool(robot.get("has_rally_point"))
		"distance_to_rally_greater":
			if not robot.has_method("distance_to_rally_point"):
				return false
			return float(robot.call("distance_to_rally_point")) > float(_rule_get(cond, "value", cond_param))
		"distance_to_rally_less_equal":
			if not robot.has_method("distance_to_rally_point"):
				return false
			return float(robot.call("distance_to_rally_point")) <= float(_rule_get(cond, "value", cond_param))
		"self_flag_is":
			if not robot.has_method("get_state_flag"):
				return false
			var flag_id := StringName(str(_rule_get(cond, "flag", "")))
			return bool(robot.call("get_state_flag", flag_id)) == bool(_rule_get(cond, "value", false))
		"has_enemy":
			return robot.has_method("get_current_enemy") and robot.call("get_current_enemy") != null
		"heat_above_percent":
			if not robot.has_method("heat_ratio"):
				return false
			var heat_above := float(_rule_get(cond, "value", cond_param))
			if heat_above > 1.0:
				heat_above /= 100.0
			return float(robot.call("heat_ratio")) >= heat_above
		"heat_below_percent":
			if not robot.has_method("heat_ratio"):
				return false
			var heat_below := float(_rule_get(cond, "value", cond_param))
			if heat_below > 1.0:
				heat_below /= 100.0
			return float(robot.call("heat_ratio")) <= heat_below
		"allies_near_rally_less":
			if not robot.has_method("count_allies_near_rally_point"):
				return false
			var less_radius := float(_rule_get(cond, "radius", 90.0))
			var less_required := int(_rule_get(cond, "value", 1))
			if _sync_rally_squad_ready(less_radius):
				return false
			var less_count := int(robot.call("count_rally_release_candidates", less_radius)) if robot.has_method("count_rally_release_candidates") else int(robot.call("count_allies_near_rally_point", less_radius))
			if less_count >= less_required and robot.has_method("try_mark_rally_squad_ready"):
				robot.call("try_mark_rally_squad_ready", less_radius, less_required)
				return false
			return less_count < less_required
		"allies_near_rally_at_least":
			if not robot.has_method("count_allies_near_rally_point"):
				return false
			var at_least_radius := float(_rule_get(cond, "radius", 90.0))
			var at_least_required := int(_rule_get(cond, "value", 1))
			if _sync_rally_squad_ready(at_least_radius):
				return true
			if robot.has_method("try_mark_rally_squad_ready"):
				return bool(robot.call("try_mark_rally_squad_ready", at_least_radius, at_least_required))
			var rally_ready := int(robot.call("count_allies_near_rally_point", at_least_radius)) >= at_least_required
			if rally_ready and robot.has_method("mark_rally_squad_ready"):
				robot.call("mark_rally_squad_ready", at_least_radius)
			return rally_ready
	match cond_type:
		AI_CONDITION_SCRIPT.Type.DISTANCE_LESS:
			if target == null:
				return false
			var threshold: float = cond_param.to_float()
			return robot.global_position.distance_to(target.global_position) <= threshold
		AI_CONDITION_SCRIPT.Type.HP_LESS_PERCENT:
			if target == null:
				return false
			if not target.has_method("hp_ratio"):
				return false
			var threshold: float = cond_param.to_float()
			if threshold > 1.0:
				threshold = threshold / 100.0
			return target.hp_ratio() <= threshold
		AI_CONDITION_SCRIPT.Type.HAS_TAG:
			if target == null:
				return false
			if cond_param.is_empty():
				return false
			return target.is_in_group(cond_param)
	return false

func _sync_rally_squad_ready(radius: float) -> bool:
	if robot == null or not robot.has_method("is_rally_squad_ready"):
		return false
	if not bool(robot.call("is_rally_squad_ready", radius)):
		return false
	if robot.has_method("sync_rally_squad_ready"):
		robot.call("sync_rally_squad_ready", radius)
	return true

func execute_action(act: Variant, target: Node2D, rule: Variant = null) -> bool:
	if robot == null:
		return false
	var act_text := str(act).to_lower()
	match act_text:
		"move_to_rally":
			if robot.has_method("move_to_rally_point"):
				robot.call("move_to_rally_point")
				return true
		"set_self_flag":
			if robot.has_method("set_state_flag"):
				var flag_id := StringName(str(_rule_get(rule, "flag", "")))
				var value := bool(_rule_get(rule, "value", true))
				var current_value := bool(robot.call("get_state_flag", flag_id)) if robot.has_method("get_state_flag") else false
				if current_value == value:
					return false
				robot.call("set_state_flag", flag_id, value, "战术标记：%s = %s" % [String(flag_id), "是" if value else "否"])
				_record_state_flag_changed(flag_id, value, rule)
				return true
		"clear_self_flag":
			if robot.has_method("set_state_flag"):
				var flag_id := StringName(str(_rule_get(rule, "flag", "")))
				var current_value := bool(robot.call("get_state_flag", flag_id)) if robot.has_method("get_state_flag") else false
				if not current_value:
					return false
				robot.call("set_state_flag", flag_id, false, "战术标记：%s = 否" % String(flag_id))
				_record_state_flag_changed(flag_id, false, rule)
				return true
		"default_combat":
			return false
		"hold_fire_for_heat":
			if robot.has_method("hold_fire_for_heat"):
				robot.call("hold_fire_for_heat")
				return true
		"wait":
			if robot.has_method("stop_and_idle"):
				robot.call("stop_and_idle")
				robot.set("current_action", "等待队友")
				return true
	match act:
		AI_RULE_SCRIPT.Action.APPROACH:
			if target and robot.has_method("move_towards"):
				robot.move_towards(target.global_position, target)
				return true
		AI_RULE_SCRIPT.Action.FLEE:
			if not robot.has_method("flee_from"):
				return false
			var flee_target := target
			if flee_target == robot and robot.has_method("get_current_enemy"):
				flee_target = robot.get_current_enemy()
			if flee_target:
				robot.flee_from(flee_target.global_position)
				return true
		AI_RULE_SCRIPT.Action.FIRE_MAIN:
			if target and robot.has_method("fire_weapon"):
				robot.fire_weapon(target)
				return true
		AI_RULE_SCRIPT.Action.STOP_ACTION:
			if robot.has_method("stop_and_idle"):
				robot.stop_and_idle()
				return true
	return false

func _on_tick_timer_timeout() -> void:
	evaluate_logic()

func _record_rule_trigger(description: String) -> void:
	if robot and robot.has_method("record_brain_trigger"):
		robot.record_brain_trigger(StringName(description), description)

func _activate_rule(rule: Variant, rule_name: String, handled: bool) -> void:
	var rule_id := str(_rule_get(rule, "id", _rule_get(rule, "name", "unnamed_rule")))
	if rule_id.is_empty():
		rule_id = "unnamed_rule"
	if rule_id == _active_rule_id:
		return
	_active_rule_id = rule_id
	_rule_trigger_counts[rule_id] = int(_rule_trigger_counts.get(rule_id, 0)) + 1
	_record_rule_trigger("规则：%s" % rule_name)

	var payload_robot_name := ""
	if robot:
		payload_robot_name = str(robot.name)

	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log and event_log.has_method("record"):
		event_log.call("record", &"rule_triggered", {
			"robot": payload_robot_name,
			"blueprint_id": String(robot.get("blueprint_id")) if robot else "",
			"blueprint_version": int(robot.get("blueprint_version")) if robot else 0,
			"blueprint_snapshot_id": String(robot.get("blueprint_snapshot_id")) if robot else "",
			"rule_id": rule_id,
			"rule_name": rule_name,
			"template_id": str(_rule_get(rule, "template_id", "")),
			"template_name": str(_rule_get(rule, "template_name", "")),
			"template_stage": str(_rule_get(rule, "template_stage", "")),
			"action": str(_rule_get(rule, "action", "")),
			"handled": handled,
		})

func get_rule_debug_lines() -> Array[String]:
	var lines: Array[String] = []
	if logic_rules.is_empty():
		return lines
	lines.append("规则触发统计：")
	for rule in logic_rules:
		if rule == null:
			continue
		var rule_id := str(_rule_get(rule, "id", _rule_get(rule, "name", "unnamed_rule")))
		if rule_id.is_empty():
			rule_id = "unnamed_rule"
		var rule_name := str(_rule_get(rule, "name", rule_id))
		var count := int(_rule_trigger_counts.get(rule_id, 0))
		var count_text := "%d 次" % count if count > 0 else "未触发"
		lines.append("  %s：%s" % [rule_name, count_text])
	return lines

func _record_state_flag_changed(flag_id: StringName, value: bool, rule: Variant) -> void:
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log and event_log.has_method("record"):
		event_log.call("record", &"state_flag_changed", {
			"robot": robot.name,
			"blueprint_id": String(robot.get("blueprint_id")),
			"blueprint_version": int(robot.get("blueprint_version")),
			"blueprint_snapshot_id": String(robot.get("blueprint_snapshot_id")),
			"flag": String(flag_id),
			"value": value,
			"rule_id": str(_rule_get(rule, "id", "")),
		})

func _rule_get(source: Variant, key: String, default_value: Variant = null) -> Variant:
	if typeof(source) == TYPE_DICTIONARY:
		return source.get(key, default_value)
	if source is Object:
		var value = source.get(key)
		return default_value if value == null else value
	return default_value
