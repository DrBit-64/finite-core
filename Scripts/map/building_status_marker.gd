extends Node2D
class_name BuildingStatusMarker

const MARKER_NONE := 0
const MARKER_PAUSED := 1
const MARKER_MISSING_INPUTS := 2

enum MarkerType {
	NONE,
	PAUSED,
	MISSING_INPUTS,
}

var marker_type: MarkerType = MarkerType.NONE

func set_marker_type(next_type: MarkerType) -> void:
	if marker_type == next_type:
		return
	marker_type = next_type
	visible = marker_type != MarkerType.NONE
	queue_redraw()

func _draw() -> void:
	if marker_type == MarkerType.NONE:
		return
	var color := Color(1.0, 0.72, 0.18, 0.98) if marker_type == MarkerType.PAUSED else Color(1.0, 0.32, 0.22, 0.98)
	draw_circle(Vector2.ZERO, 10.0, Color(0.025, 0.03, 0.04, 0.96))
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 28, color, 2.5)
	if marker_type == MarkerType.PAUSED:
		draw_rect(Rect2(Vector2(-4.5, -5.0), Vector2(2.8, 10.0)), color, true)
		draw_rect(Rect2(Vector2(1.7, -5.0), Vector2(2.8, 10.0)), color, true)
	else:
		draw_line(Vector2(0.0, -5.0), Vector2(0.0, 2.0), color, 2.8)
		draw_circle(Vector2(0.0, 5.5), 1.5, color)
