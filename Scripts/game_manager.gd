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
	_configure_stage_four_logic(robot)

func _configure_stage_four_logic(robot: CharacterBody2D) -> void:
	var controller := robot.get_node_or_null("AIController")
	if controller == null:
		return

	var rules: Array = []
	var retreat_rule := AI_RULE_SCRIPT.new() as Resource
	retreat_rule.set("subject", AI_RULE_SCRIPT.Subject.SELF)
	retreat_rule.set("match_mode", AI_RULE_SCRIPT.MatchMode.MATCH_ALL)
	retreat_rule.set("action", AI_RULE_SCRIPT.Action.FLEE)
	retreat_rule.conditions = [_make_condition(AI_CONDITION_SCRIPT.Type.HP_LESS_PERCENT, "30")]
	if enable_low_hp_retreat_rule:
		rules.append(retreat_rule)

	var fire_rule := AI_RULE_SCRIPT.new() as Resource
	fire_rule.set("subject", AI_RULE_SCRIPT.Subject.TARGET_NEAREST)
	fire_rule.set("match_mode", AI_RULE_SCRIPT.MatchMode.MATCH_ALL)
	fire_rule.set("action", AI_RULE_SCRIPT.Action.FIRE_MAIN)
	fire_rule.conditions = [_make_condition(AI_CONDITION_SCRIPT.Type.DISTANCE_LESS, "140")]
	rules.append(fire_rule)

	var chase_rule := AI_RULE_SCRIPT.new() as Resource
	chase_rule.set("subject", AI_RULE_SCRIPT.Subject.TARGET_NEAREST)
	chase_rule.set("match_mode", AI_RULE_SCRIPT.MatchMode.MATCH_ALL)
	chase_rule.set("action", AI_RULE_SCRIPT.Action.APPROACH)
	chase_rule.conditions = [_make_condition(AI_CONDITION_SCRIPT.Type.DISTANCE_LESS, "99999")]
	rules.append(chase_rule)

	var fallback_rule := AI_RULE_SCRIPT.new() as Resource
	fallback_rule.set("subject", AI_RULE_SCRIPT.Subject.SELF)
	fallback_rule.set("match_mode", AI_RULE_SCRIPT.MatchMode.MATCH_ALL)
	fallback_rule.set("action", AI_RULE_SCRIPT.Action.STOP_ACTION)
	fallback_rule.conditions = []
	rules.append(fallback_rule)

	controller.set("logic_rules", rules)

func _make_condition(condition_type: AI_CONDITION_SCRIPT.Type, param: String) -> Resource:
	var cond := AI_CONDITION_SCRIPT.new() as Resource
	if cond == null:
		return null
	cond.set("type", condition_type)
	cond.set("param", param)
	return cond
