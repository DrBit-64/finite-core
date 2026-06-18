extends Node2D
class_name LaserBeamEffect

var beam_vector: Vector2 = Vector2.RIGHT
var duration_seconds: float = 0.14
var elapsed_seconds: float = 0.0
var beam_color: Color = Color(0.30, 0.94, 1.0, 1.0)
var sustain_until_msec: int = 0

func setup(origin: Vector2, target_position: Vector2, next_color: Color = Color(0.30, 0.94, 1.0, 1.0)) -> void:
	global_position = origin
	beam_vector = target_position - origin
	beam_color = next_color
	elapsed_seconds = 0.0
	sustain_until_msec = Time.get_ticks_msec() + roundi(duration_seconds * 1000.0)
	z_index = 40
	queue_redraw()

func _process(delta: float) -> void:
	elapsed_seconds += delta
	if Time.get_ticks_msec() >= sustain_until_msec:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var alpha := clampf(1.0 - elapsed_seconds / maxf(duration_seconds, 0.001), 0.0, 1.0)
	var glow := Color(beam_color.r, beam_color.g, beam_color.b, alpha * 0.28)
	var core := Color(0.90, 1.0, 1.0, alpha)
	draw_line(Vector2.ZERO, beam_vector, glow, 7.0, true)
	draw_line(Vector2.ZERO, beam_vector, beam_color * Color(1.0, 1.0, 1.0, alpha), 3.0, true)
	draw_line(Vector2.ZERO, beam_vector, core, 1.2, true)
	draw_circle(beam_vector, 5.0, glow)
	draw_circle(beam_vector, 2.0, core)
