extends Node
class_name VisibleEnemySensor

@export var viewport_padding: float = 48.0

func get_visible_enemies(owner: Node2D, owner_team: String) -> Array[Node2D]:
	if owner == null or owner.get_tree() == null:
		return []

	var visible_rect := get_visible_world_rect(owner).grow(viewport_padding)
	var enemies: Array[Node2D] = []
	for candidate in owner.get_tree().get_nodes_in_group("combat_unit"):
		if candidate == owner or not (candidate is Node2D):
			continue
		var unit := candidate as Node2D
		if unit is CanvasItem and not (unit as CanvasItem).is_visible_in_tree():
			continue
		if unit.get("team") == null or String(unit.get("team")) == owner_team:
			continue
		if unit.has_method("is_alive") and not bool(unit.call("is_alive")):
			continue
		if visible_rect.has_point(unit.global_position):
			enemies.append(unit)

	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return owner.global_position.distance_squared_to(a.global_position) < owner.global_position.distance_squared_to(b.global_position)
	)
	return enemies

func get_visible_world_rect(owner: Node2D) -> Rect2:
	var viewport := owner.get_viewport()
	var viewport_rect := viewport.get_visible_rect()
	var inverse_canvas := viewport.get_canvas_transform().affine_inverse()
	var points := [
		inverse_canvas * viewport_rect.position,
		inverse_canvas * (viewport_rect.position + Vector2(viewport_rect.size.x, 0.0)),
		inverse_canvas * (viewport_rect.position + viewport_rect.size),
		inverse_canvas * (viewport_rect.position + Vector2(0.0, viewport_rect.size.y)),
	]
	var min_pos: Vector2 = points[0]
	var max_pos: Vector2 = points[0]
	for point in points:
		min_pos.x = minf(min_pos.x, point.x)
		min_pos.y = minf(min_pos.y, point.y)
		max_pos.x = maxf(max_pos.x, point.x)
		max_pos.y = maxf(max_pos.y, point.y)
	return Rect2(min_pos, max_pos - min_pos)
