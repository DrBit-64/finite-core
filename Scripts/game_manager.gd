extends Node2D

const AI_RULE_SCRIPT := preload("res://Scripts/ai_rule.gd")
const AI_CONDITION_SCRIPT := preload("res://Scripts/ai_condition.gd")

@export var robot_scene: PackedScene = preload("res://Scenes/robot.tscn")
@export var team_a_count: int = 5
@export var team_b_count: int = 5
@export var team_a_x_range: Vector2 = Vector2(620.0, 860.0)
@export var team_b_x_range: Vector2 = Vector2(900.0, 1160.0)
@export var spawn_y_range: Vector2 = Vector2(180.0, 900.0)
@export var min_clusters_per_team: int = 2
@export var max_clusters_per_team: int = 4
@export var cluster_radius: float = 90.0
@export var local_advantage_bias: float = 0.7
@export var match_lifespan_seconds: float = 30.0
@export var enable_low_hp_retreat_rule: bool = false
@export var pool_name: String = "robot_basic"
@export_file("*.json") var team_a_logic_rules_path: String = "res://debug_exports/rules/logic_rules_001.json"
@export_file("*.json") var team_b_logic_rules_path: String = "res://debug_exports/rules/logic_rules_002.json"

func _ready() -> void:
	randomize()
	spawn_robots_for_radar_test()

func spawn_robots_for_radar_test() -> void:
	var team_a_positions := _generate_clustered_positions("Team_A", team_a_count)
	for spawn_point in team_a_positions:
		_spawn_team_robot("Team_A", spawn_point)

	var team_b_positions := _generate_clustered_positions("Team_B", team_b_count)
	for spawn_point in team_b_positions:
		_spawn_team_robot("Team_B", spawn_point)

func _generate_clustered_positions(team: String, unit_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if unit_count <= 0:
		return positions

	var x_range := team_a_x_range if team == "Team_A" else team_b_x_range
	var cluster_count := clampi(randi_range(min_clusters_per_team, max_clusters_per_team), 1, unit_count)
	var centers: Array[Vector2] = []

	for i in cluster_count:
		var center := Vector2(
			randf_range(x_range.x, x_range.y),
			randf_range(spawn_y_range.x, spawn_y_range.y)
		)
		centers.append(center)

	var hotspot_index := randi_range(0, centers.size() - 1)
	for i in unit_count:
		var cluster_index := hotspot_index if randf() < local_advantage_bias else randi_range(0, centers.size() - 1)
		var base := centers[cluster_index]
		var angle := randf() * TAU
		var radius := randf() * cluster_radius
		var spawn_pos := base + Vector2.RIGHT.rotated(angle) * radius
		spawn_pos.x = clampf(spawn_pos.x, x_range.x, x_range.y)
		spawn_pos.y = clampf(spawn_pos.y, spawn_y_range.x, spawn_y_range.y)
		positions.append(spawn_pos)

	return positions

func _spawn_team_robot(team: String, spawn_point: Vector2) -> void:
	var robot := ObjectPool.get_instance(robot_scene, self, pool_name) as CharacterBody2D
	if robot == null:
		return
	robot.set("team", team)
	robot.set("lifespan_seconds", match_lifespan_seconds)
	robot.global_position = spawn_point
	if robot.has_method("reset_state"):
		robot.reset_state()
	_configure_logic_for_team(robot, team)

func _configure_logic_for_team(robot: CharacterBody2D, team: String) -> void:
	var rules := _load_team_logic_rules(team)
	if rules.is_empty():
		_configure_stage_four_logic(robot)
		return
	_apply_logic_rules(robot, rules)

func _load_team_logic_rules(team: String) -> Array[AIRule]:
	var path := team_a_logic_rules_path if team == "Team_A" else team_b_logic_rules_path
	if path.is_empty():
		return []
	var rules := _load_logic_rules_from_json(path)
	if rules.is_empty():
		push_warning("Falling through to hard-coded logic rules for %s. Could not load valid rules from %s." % [team, path])
	return rules

func _load_logic_rules_from_json(path: String) -> Array[AIRule]:
	if not FileAccess.file_exists(path):
		push_warning("Logic rules JSON does not exist: %s" % path)
		return []

	var json_text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		push_warning("Logic rules JSON root must be a Dictionary: %s" % path)
		return []

	var rule_entries_variant: Variant = parsed.get("rules", [])
	if not (rule_entries_variant is Array):
		push_warning("Logic rules JSON has no rules array: %s" % path)
		return []

	var rule_entries: Array = rule_entries_variant
	rule_entries.sort_custom(_sort_rule_entries_by_priority)

	var rules: Array[AIRule] = []
	for entry in rule_entries:
		if not (entry is Dictionary):
			continue
		var rule := _rule_from_json_entry(entry)
		if rule != null:
			rules.append(rule)
	return rules

func _sort_rule_entries_by_priority(a: Variant, b: Variant) -> bool:
	if not (a is Dictionary) or not (b is Dictionary):
		return false
	return int(a.get("priority", 0)) < int(b.get("priority", 0))

func _rule_from_json_entry(entry: Dictionary) -> AIRule:
	var rule := AI_RULE_SCRIPT.new() as AIRule
	rule.set("subject", _subject_from_json_value(entry.get("subject", AI_RULE_SCRIPT.Subject.TARGET_NEAREST)))
	rule.set("match_mode", _match_mode_from_json_value(entry.get("match_mode", AI_RULE_SCRIPT.MatchMode.MATCH_ALL)))
	rule.set("action", _action_from_json_value(entry.get("action", AI_RULE_SCRIPT.Action.STOP_ACTION)))

	var conditions: Array[AICondition] = []
	var condition_entries_variant: Variant = entry.get("conditions", [])
	if condition_entries_variant is Array:
		var condition_entries: Array = condition_entries_variant
		condition_entries.sort_custom(_sort_condition_entries_by_index)
		for condition_entry in condition_entries:
			if condition_entry is Dictionary:
				var condition := _condition_from_json_entry(condition_entry)
				if condition != null:
					conditions.append(condition)
	rule.conditions = conditions
	return rule

func _sort_condition_entries_by_index(a: Variant, b: Variant) -> bool:
	if not (a is Dictionary) or not (b is Dictionary):
		return false
	return int(a.get("index", 0)) < int(b.get("index", 0))

func _condition_from_json_entry(entry: Dictionary) -> AICondition:
	var condition := AI_CONDITION_SCRIPT.new() as AICondition
	condition.set("type", _condition_type_from_json_value(entry.get("type", AI_CONDITION_SCRIPT.Type.DISTANCE_LESS)))
	condition.set("param", str(entry.get("param", "")))
	return condition

func _enum_code_from_json_value(value: Variant) -> String:
	if value is Dictionary:
		return str(value.get("code", ""))
	if value is String:
		return str(value)
	return ""

func _enum_id_from_json_value(value: Variant) -> int:
	if value is Dictionary and value.has("id"):
		return int(value.get("id"))
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return -1

func _subject_from_json_value(value: Variant) -> int:
	match _enum_code_from_json_value(value):
		"SELF":
			return AI_RULE_SCRIPT.Subject.SELF
		"TARGET_NEAREST":
			return AI_RULE_SCRIPT.Subject.TARGET_NEAREST
		"TARGET_LOWEST_HP":
			return AI_RULE_SCRIPT.Subject.TARGET_LOWEST_HP
	var id := _enum_id_from_json_value(value)
	if id >= 0:
		return id
	return AI_RULE_SCRIPT.Subject.TARGET_NEAREST

func _match_mode_from_json_value(value: Variant) -> int:
	match _enum_code_from_json_value(value):
		"MATCH_ALL":
			return AI_RULE_SCRIPT.MatchMode.MATCH_ALL
		"MATCH_ANY":
			return AI_RULE_SCRIPT.MatchMode.MATCH_ANY
	var id := _enum_id_from_json_value(value)
	if id >= 0:
		return id
	return AI_RULE_SCRIPT.MatchMode.MATCH_ALL

func _action_from_json_value(value: Variant) -> int:
	match _enum_code_from_json_value(value):
		"APPROACH":
			return AI_RULE_SCRIPT.Action.APPROACH
		"FLEE":
			return AI_RULE_SCRIPT.Action.FLEE
		"FIRE_MAIN":
			return AI_RULE_SCRIPT.Action.FIRE_MAIN
		"STOP_ACTION":
			return AI_RULE_SCRIPT.Action.STOP_ACTION
	var id := _enum_id_from_json_value(value)
	if id >= 0:
		return id
	return AI_RULE_SCRIPT.Action.STOP_ACTION

func _condition_type_from_json_value(value: Variant) -> int:
	match _enum_code_from_json_value(value):
		"DISTANCE_LESS":
			return AI_CONDITION_SCRIPT.Type.DISTANCE_LESS
		"HP_LESS_PERCENT":
			return AI_CONDITION_SCRIPT.Type.HP_LESS_PERCENT
		"HAS_TAG":
			return AI_CONDITION_SCRIPT.Type.HAS_TAG
	var id := _enum_id_from_json_value(value)
	if id >= 0:
		return id
	return AI_CONDITION_SCRIPT.Type.DISTANCE_LESS

func _configure_stage_four_logic(robot: CharacterBody2D) -> void:
	_apply_logic_rules(robot, _build_stage_four_logic_rules())

func _apply_logic_rules(robot: CharacterBody2D, rules: Array[AIRule]) -> void:
	var controller := robot.get_node_or_null("AIController")
	if controller == null:
		return
	controller.set("logic_rules", rules)

func _build_stage_four_logic_rules() -> Array[AIRule]:
	var rules: Array[AIRule] = []
	var retreat_rule := AI_RULE_SCRIPT.new() as AIRule
	retreat_rule.set("subject", AI_RULE_SCRIPT.Subject.SELF)
	retreat_rule.set("match_mode", AI_RULE_SCRIPT.MatchMode.MATCH_ALL)
	retreat_rule.set("action", AI_RULE_SCRIPT.Action.FLEE)
	var retreat_conditions: Array[AICondition] = [_make_condition(AI_CONDITION_SCRIPT.Type.HP_LESS_PERCENT, "30")]
	retreat_rule.conditions = retreat_conditions
	if enable_low_hp_retreat_rule:
		rules.append(retreat_rule)

	var fire_rule := AI_RULE_SCRIPT.new() as AIRule
	fire_rule.set("subject", AI_RULE_SCRIPT.Subject.TARGET_NEAREST)
	fire_rule.set("match_mode", AI_RULE_SCRIPT.MatchMode.MATCH_ALL)
	fire_rule.set("action", AI_RULE_SCRIPT.Action.FIRE_MAIN)
	var fire_conditions: Array[AICondition] = [_make_condition(AI_CONDITION_SCRIPT.Type.DISTANCE_LESS, "140")]
	fire_rule.conditions = fire_conditions
	rules.append(fire_rule)

	var chase_rule := AI_RULE_SCRIPT.new() as AIRule
	chase_rule.set("subject", AI_RULE_SCRIPT.Subject.TARGET_NEAREST)
	chase_rule.set("match_mode", AI_RULE_SCRIPT.MatchMode.MATCH_ALL)
	chase_rule.set("action", AI_RULE_SCRIPT.Action.APPROACH)
	var chase_conditions: Array[AICondition] = [_make_condition(AI_CONDITION_SCRIPT.Type.DISTANCE_LESS, "99999")]
	chase_rule.conditions = chase_conditions
	rules.append(chase_rule)

	var fallback_rule := AI_RULE_SCRIPT.new() as AIRule
	fallback_rule.set("subject", AI_RULE_SCRIPT.Subject.SELF)
	fallback_rule.set("match_mode", AI_RULE_SCRIPT.MatchMode.MATCH_ALL)
	fallback_rule.set("action", AI_RULE_SCRIPT.Action.STOP_ACTION)
	var fallback_conditions: Array[AICondition] = []
	fallback_rule.conditions = fallback_conditions
	rules.append(fallback_rule)

	return rules

func _make_condition(condition_type: AI_CONDITION_SCRIPT.Type, param: String) -> AICondition:
	var cond := AI_CONDITION_SCRIPT.new() as AICondition
	if cond == null:
		return null
	cond.set("type", condition_type)
	cond.set("param", param)
	return cond
