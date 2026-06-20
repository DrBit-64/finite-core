extends Control
class_name TechnologyTreeLines

var _segments: Array = []

func configure(segments: Array) -> void:
	_segments = segments.duplicate(true)
	queue_redraw()

func _draw() -> void:
	for segment in _segments:
		if typeof(segment) != TYPE_DICTIONARY:
			continue
		var from_point := segment.get("from", Vector2.ZERO) as Vector2
		var to_point := segment.get("to", Vector2.ZERO) as Vector2
		var color := segment.get("color", Color(0.35, 0.58, 0.72, 0.75)) as Color
		draw_line(from_point, to_point, color, 3.0, true)
