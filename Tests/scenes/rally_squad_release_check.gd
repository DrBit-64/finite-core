extends Node

const PlayerRobotScene := preload("res://Scenes/robot.tscn")
const BlueprintLibraryScript := preload("res://Scripts/blueprints/blueprint_library.gd")
const MvpDataDefaultsScript := preload("res://Scripts/data/mvp_data_defaults.gd")

var _robots: Array[RobotUnit] = []

func _ready() -> void:
	RobotUnit.clear_shared_rally_readiness()
	var rally_blueprint: UnitBlueprint = BlueprintLibraryScript.new().create_rally_variant(
		MvpDataDefaultsScript.create_basic_rifle_blueprint(),
		"Rally release test"
	)
	for index in range(3):
		_spawn_rallied_robot(rally_blueprint, index)
		_evaluate_robot(_robots[index])
	_expect(_ready_count() == 0, "Three robots must continue waiting.")

	_spawn_robot_in_rally_radius(rally_blueprint, 3)
	_evaluate_robot(_robots[3])
	_expect(_robots[3].get_state_flag(&"rallied"), "A later robot must stop approaching once it reaches the squad arrival distance.")
	_expect(_robots[0].count_rally_release_candidates(90.0) == 4, "The fourth robot must enter the rally batch inside the rally radius.")
	_evaluate_robot(_robots[0])
	_expect(_ready_count() == 4, "Exactly four robots should be released in the first squad.")
	_expect(_robots[3].get_state_flag(&"squad_ready"), "A robot inside the rally radius must count even before reaching the arrival threshold.")

	_spawn_rallied_robot(rally_blueprint, 4)
	_evaluate_robot(_robots[4])
	_expect(not _robots[4].get_state_flag(&"squad_ready"), "The fifth robot must wait for the next squad.")

	for index in range(5, 8):
		_spawn_rallied_robot(rally_blueprint, index)
		_evaluate_robot(_robots[index])
	_expect(_ready_count() == 8, "The second complete squad should release together.")
	print("RALLY_SQUAD_RELEASE_OK")
	get_tree().quit()

func _spawn_rallied_robot(blueprint: UnitBlueprint, arrival_order: int) -> void:
	var robot := PlayerRobotScene.instantiate() as RobotUnit
	add_child(robot)
	robot.global_position = Vector2(float(arrival_order % 4) * 8.0, floorf(float(arrival_order) / 4.0) * 8.0)
	robot.setup_from_blueprint(blueprint, Vector2.ZERO, true)
	robot.set_physics_process(false)
	robot.set_state_flag(&"rallied", true)
	robot._rallied_at_msec = arrival_order + 1
	_robots.append(robot)

func _spawn_robot_in_rally_radius(blueprint: UnitBlueprint, arrival_order: int) -> void:
	var robot := PlayerRobotScene.instantiate() as RobotUnit
	add_child(robot)
	robot.global_position = Vector2(48.0, 0.0)
	robot.setup_from_blueprint(blueprint, Vector2.ZERO, true)
	robot.set_physics_process(false)
	_robots.append(robot)

func _evaluate_robot(robot: RobotUnit) -> void:
	var controller := robot.get_node("AIController")
	controller.set("_next_evaluation_msec", 0)
	controller.call("evaluate_logic")

func _ready_count() -> int:
	var count := 0
	for robot in _robots:
		if robot.get_state_flag(&"squad_ready"):
			count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
