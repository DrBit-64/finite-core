extends Node

const MvpScene := preload("res://Scenes/mvp/mvp_test_map.tscn")
const PlayerRobotScene := preload("res://Scenes/robot.tscn")

func _ready() -> void:
	var mvp := MvpScene.instantiate()
	add_child(mvp)
	await get_tree().process_frame

	var camera: Camera2D = mvp.get_node("MainCamera")
	var initial_zoom := camera.zoom.x
	mvp.call("_zoom_camera_at_screen_position", 1.2, Vector2(960, 540))
	_expect(camera.zoom.x > initial_zoom, "滚轮缩放应能放大地图")
	mvp.call("_zoom_camera_at_screen_position", 999.0, Vector2(960, 540))
	_expect(camera.zoom.x <= float(mvp.get("camera_zoom_max")), "地图缩放不能超过上限")
	mvp.call("_zoom_camera_at_screen_position", 0.0001, Vector2(960, 540))
	_expect(camera.zoom.x >= float(mvp.get("camera_zoom_min")), "地图缩放不能低于下限")

	var hover_marker: Node2D = mvp.get("hover_marker")
	_expect(hover_marker != null, "地图应创建独立悬停格标记")
	hover_marker.call("show_hover", Vector2i(2, 3), 64)
	_expect(hover_marker.visible and hover_marker.position == Vector2(128, 192), "悬停格标记应吸附到目标格子")

	var hud: CanvasLayer = mvp.get_node("MvpHUD")
	var elapsed_label: Label = hud.get_node("%ElapsedTimeLabel")
	var direction_label: Label = hud.get_node("%ObjectiveDirectionLabel")
	_expect(elapsed_label.text.begins_with("用时 "), "顶部 HUD 应显示本局经过时间")
	_expect(direction_label.text.begins_with("敌巢方向："), "顶部 HUD 应显示敌巢方向")

	var debug_panel: PanelContainer = hud.get_node("%DebugEventPanel")
	var expanded_height := debug_panel.size.y
	debug_panel.call("_toggle_collapsed")
	_expect(debug_panel.size.y < expanded_height, "调试事件面板应支持折叠")
	debug_panel.call("_toggle_collapsed")
	_expect(is_equal_approx(debug_panel.size.y, expanded_height), "调试事件面板应支持展开")

	var robot := PlayerRobotScene.instantiate()
	add_child(robot)
	robot.set_physics_process(false)
	robot.call("die", &"destroyed")
	_expect(robot.visible, "机器人死亡反馈播放期间不应立即消失")
	await get_tree().create_timer(0.3).timeout
	_expect(not robot.visible, "机器人死亡反馈结束后应回收到对象池")

	print("STAGE9_PLAYTEST_POLISH_OK")
	get_tree().quit()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(1)
