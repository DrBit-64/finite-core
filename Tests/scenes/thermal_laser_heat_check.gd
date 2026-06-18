extends Node

const RobotScene := preload("res://Scenes/robot.tscn")
const ProcessorScene := preload("res://Scenes/buildings/processor.tscn")
const InventoryScript := preload("res://Scripts/economy/inventory.gd")

class DamageTarget:
	extends Node2D
	var received_damage: int = 0
	var received_payload: Dictionary = {}

	func get_target_position() -> Vector2:
		return global_position

	func take_damage_from(amount: int, payload: Dictionary) -> void:
		received_damage += amount
		received_payload = payload.duplicate(true)

func _ready() -> void:
	_check_laser_attack()
	_check_heat_lock()
	_check_active_heat_hold_blocks_laser()
	_check_processor_marker_layer()
	print("THERMAL_LASER_HEAT_OK")
	get_tree().quit()

func _check_laser_attack() -> void:
	var robot := RobotScene.instantiate() as RobotUnit
	add_child(robot)
	robot.damage_type = &"thermal"
	robot.weapon_audio_id = &"thermal_laser"
	robot.weapon_component.setup(180.0, 2, 0.0, "laser")
	var target := DamageTarget.new()
	target.global_position = Vector2(96.0, 0.0)
	add_child(target)

	var fired := bool(robot.weapon_component.try_fire("Team_A", robot.muzzle, target, self))
	_expect(fired, "热能武器应能发射激光")
	_expect(target.received_damage == 2, "激光应按固定tick结算低额连续伤害")
	_expect(str(target.received_payload.get("damage_type", "")) == "thermal", "激光伤害类型应为 thermal")
	_expect(_count_nodes_by_script_name("LaserBeamEffect") == 1, "激光攻击应生成短暂光束效果")
	_expect(_count_nodes_by_script_name("BulletProjectile") == 0, "激光攻击不应生成普通子弹")
	fired = bool(robot.weapon_component.try_fire("Team_A", robot.muzzle, target, self))
	_expect(not fired, "激光连续照射不应每帧都重复结算伤害")
	_expect(target.received_damage == 2, "激光伤害应与模拟tick绑定，而不是逐帧扣血")
	_expect(robot.weapon_component.fire_state == &"channeling", "未到结算tick时应显示为持续照射")
	_expect(_count_nodes_by_script_name("LaserBeamEffect") == 1, "持续照射应复用同一条光束效果")
	robot.queue_free()
	target.queue_free()

func _check_heat_lock() -> void:
	var robot := RobotScene.instantiate() as RobotUnit
	add_child(robot)
	robot.heat_capacity = 100.0
	robot.heat_per_shot = 100.0
	robot.heat_cooling_per_second = 20.0
	robot._add_weapon_heat()
	var full_dissipation_seconds := robot.heat_capacity / robot.heat_cooling_per_second

	_expect(robot.is_overheated, "热量满格后应进入强制过热锁定")
	_expect(robot.get_overheat_lock_remaining() > full_dissipation_seconds, "强制关闭时间必须长于满热自然消散时间")
	robot._update_heat(full_dissipation_seconds + 0.1)
	_expect(is_zero_approx(robot.current_heat), "停火期间热量应自动散去")
	_expect(robot.is_overheated, "热量散尽后仍应等待强制锁定时间结束")
	robot.overheat_locked_until_msec = Time.get_ticks_msec() - 1
	robot._update_heat(0.0)
	_expect(not robot.is_overheated, "强制锁定时间结束后应恢复武器")
	robot.queue_free()

func _check_active_heat_hold_blocks_laser() -> void:
	var robot := RobotScene.instantiate() as RobotUnit
	add_child(robot)
	robot.damage_type = &"thermal"
	robot.weapon_audio_id = &"thermal_laser"
	robot.heat_capacity = 100.0
	robot.heat_per_shot = 4.0
	robot.heat_cooling_per_second = 15.0
	robot.overheated_resume_threshold = 42.0
	robot.weapon_component.setup(180.0, 2, 0.0, "laser")
	var target := DamageTarget.new()
	target.global_position = Vector2(96.0, 0.0)
	add_child(target)

	robot.current_heat = 82.0
	robot.hold_fire_for_heat()
	robot.fire_weapon(target)
	_expect(target.received_damage == 0, "Active heat hold should block the default brain from firing the laser again.")
	_expect(not robot.is_overheated, "Active heat hold should not be treated as forced overheat lock.")

	robot.current_heat = 40.0
	robot._update_heat(0.0)
	robot.fire_weapon(target)
	_expect(target.received_damage == 2, "Laser should resume after heat drops below the resume threshold.")
	robot.queue_free()
	target.queue_free()

func _check_processor_marker_layer() -> void:
	var processor := ProcessorScene.instantiate() as ProcessorBuilding
	add_child(processor)
	var building_def := BuildingDef.new()
	building_def.id = &"processor"
	building_def.grid_size = Vector2i.ONE
	processor.setup(building_def, Vector2i.ZERO, 64)
	processor.setup_processor([], InventoryScript.new())
	processor.set_paused(true)
	var marker := processor.get_node_or_null("StatusMarker") as Node2D
	_expect(marker != null and marker.visible, "暂停加工厂应显示状态标记")
	_expect(marker.z_index > processor.icon_sprite.z_index, "状态标记应绘制在建筑图标上方")
	processor.queue_free()

func _count_nodes_by_script_name(expected_name: String) -> int:
	var count := 0
	for child in get_children():
		var script = child.get_script()
		if script != null and str(script.get_global_name()) == expected_name:
			count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
