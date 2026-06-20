extends StaticBody2D
class_name BaseBuilding

signal building_destroyed(building: Node, reason: StringName)

const HealthComponentScript := preload("res://Scripts/units/health_component.gd")
const CombatTargetRegistryScript := preload("res://Scripts/map/combat_target_registry.gd")

@export var icon_size: Vector2 = Vector2(56, 56)
@export_enum("Team_A", "Team_B") var team: String = "Team_A"
@export var armor_type: StringName = &"structure"

var building_def: BuildingDef
var grid_origin: Vector2i = Vector2i.ZERO
var grid_size: Vector2i = Vector2i.ONE
var cell_size: int = 64
var hp: int = 1
var max_hp: int = 1
var _destroyed: bool = false

@onready var icon_sprite: Sprite2D = $IconSprite
@onready var footprint: Polygon2D = $Footprint
var health_component: HealthComponent
var hp_bar: ProgressBar
var collision_shape: CollisionShape2D
var _combat_target_registry: Node = null
var _damage_flash_tween: Tween = null

func setup(def: BuildingDef, origin: Vector2i, next_cell_size: int) -> void:
	_ensure_combat_nodes()
	building_def = def
	grid_origin = origin
	grid_size = def.grid_size if def else Vector2i.ONE
	cell_size = next_cell_size
	position = Vector2(origin.x * cell_size, origin.y * cell_size)
	max_hp = def.max_hp if def else 1
	_destroyed = false
	health_component.setup(max_hp)
	_sync_combat_groups()
	_update_visuals(true)
	queue_redraw()

func get_display_name() -> String:
	if building_def:
		return building_def.display_name
	return "建筑"

func get_inspector_lines() -> Array[String]:
	var lines: Array[String] = [
		"类型：建筑",
		"名称：%s" % get_display_name(),
		"网格：%s, %s" % [grid_origin.x, grid_origin.y],
		"占格：%sx%s" % [grid_size.x, grid_size.y],
		"建造配方：%s" % String(building_def.build_recipe_id if building_def else &""),
		"生命：%s / %s" % [hp, max_hp],
		"状态：%s" % ("已摧毁" if _destroyed else "运行中"),
	]
	return lines

func _ready() -> void:
	_ensure_combat_nodes()
	_update_visuals()

func is_alive() -> bool:
	return not _destroyed and health_component != null and health_component.is_alive()

func hp_ratio() -> float:
	return health_component.hp_ratio() if health_component else 0.0

func take_damage(amount: int) -> void:
	if health_component:
		health_component.take_damage(amount)

func take_damage_from(amount: int, source_payload: Dictionary = {}) -> void:
	if _destroyed:
		return
	var multiplier := _damage_multiplier_for_profile(source_payload)
	var final_damage := maxi(1, roundi(float(amount) * multiplier))
	take_damage(final_damage)
	_play_damage_impact_audio(source_payload, multiplier)

func destroy(reason: StringName = &"destroyed") -> void:
	if _destroyed:
		return
	_ensure_combat_nodes()
	if health_component:
		health_component.kill(reason)
	else:
		_on_health_died(reason)

func _apply_damage_profile(amount: int, source_payload: Dictionary) -> int:
	return maxi(1, roundi(float(amount) * _damage_multiplier_for_profile(source_payload)))

func _damage_multiplier_for_profile(source_payload: Dictionary) -> float:
	var source_damage_type := StringName(str(source_payload.get("damage_type", "kinetic")))
	var multiplier := 1.0
	if armor_type == &"structure_armor":
		match source_damage_type:
			&"kinetic":
				multiplier = 0.72
			&"thermal":
				multiplier = 1.25
	elif armor_type == &"armored":
		match source_damage_type:
			&"kinetic":
				multiplier = 0.55
			&"thermal":
				multiplier = 1.35
	return multiplier

func _damage_effectiveness_from_multiplier(multiplier: float) -> StringName:
	if multiplier <= 0.80:
		return &"weak"
	if multiplier >= 1.20:
		return &"strong"
	return &"normal"

func _play_damage_impact_audio(source_payload: Dictionary, multiplier: float) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager == null or not audio_manager.has_method("play_damage_impact_cue"):
		return
	audio_manager.call(
		"play_damage_impact_cue",
		_damage_effectiveness_from_multiplier(multiplier),
		StringName(str(source_payload.get("weapon_id", "default")))
	)

func get_target_position() -> Vector2:
	return global_position + Vector2(grid_size.x * cell_size, grid_size.y * cell_size) * 0.5

func restore_health_state(next_hp: int, destroyed: bool = false) -> void:
	_ensure_combat_nodes()
	var restored_hp := clampi(next_hp, 0, max_hp)
	_destroyed = destroyed or restored_hp <= 0
	health_component.max_hp = max_hp
	health_component.hp = 0 if _destroyed else restored_hp
	health_component.set("_dead", _destroyed)
	hp = health_component.hp
	if _destroyed:
		set_deferred("collision_layer", 0)
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		remove_from_group("combat_target")
		_unregister_combat_target()
		set_process(false)
	else:
		if collision_shape:
			collision_shape.set_deferred("disabled", false)
		set_process(true)
		_sync_combat_groups()
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		hp_bar.visible = hp < max_hp and hp > 0
	_update_visuals()

func _update_visuals(update_collision_shape: bool = false) -> void:
	if building_def == null or icon_sprite == null or footprint == null:
		return

	var pixel_size := Vector2(grid_size.x * cell_size, grid_size.y * cell_size)
	footprint.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(pixel_size.x, 0.0),
		pixel_size,
		Vector2(0.0, pixel_size.y),
	])
	icon_sprite.position = pixel_size * 0.5
	icon_sprite.modulate = Color(0.42, 0.42, 0.42, 0.72) if _destroyed else Color.WHITE

	var texture: Texture2D = null
	if not building_def.icon_path.is_empty():
		texture = load(building_def.icon_path) as Texture2D
	if texture:
		icon_sprite.texture = texture
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			icon_sprite.scale = Vector2(
				minf(icon_size.x, pixel_size.x * 0.82) / texture_size.x,
				minf(icon_size.y, pixel_size.y * 0.82) / texture_size.y
			)
	if collision_shape and update_collision_shape:
		var shape := RectangleShape2D.new()
		shape.size = pixel_size
		collision_shape.shape = shape
		collision_shape.position = pixel_size * 0.5
		collision_shape.set_deferred("disabled", false)
	if hp_bar:
		hp_bar.position = Vector2(pixel_size.x * 0.5 - 32.0, -13.0)

func _ensure_combat_nodes() -> void:
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
		if collision_shape == null:
			collision_shape = CollisionShape2D.new()
			collision_shape.name = "CollisionShape2D"
			add_child(collision_shape)
	if health_component == null:
		health_component = get_node_or_null("HealthComponent")
		if health_component == null:
			health_component = HealthComponentScript.new()
			health_component.name = "HealthComponent"
			add_child(health_component)
		if not health_component.health_changed.is_connected(_on_health_changed):
			health_component.health_changed.connect(_on_health_changed)
		if not health_component.died.is_connected(_on_health_died):
			health_component.died.connect(_on_health_died)
	if hp_bar == null:
		hp_bar = get_node_or_null("HPBar")
		if hp_bar == null:
			hp_bar = ProgressBar.new()
			hp_bar.name = "HPBar"
			hp_bar.custom_minimum_size = Vector2(64.0, 7.0)
			hp_bar.show_percentage = false
			add_child(hp_bar)

func _sync_combat_groups() -> void:
	_unregister_combat_target()
	add_to_group("combat_target")
	if team == "Team_A":
		add_to_group("team_a")
		remove_from_group("team_b")
		collision_layer = 1
	else:
		add_to_group("team_b")
		remove_from_group("team_a")
		collision_layer = 2
	collision_mask = 0
	_register_combat_target()

func _on_health_changed(current_hp: int, current_max_hp: int, delta: int) -> void:
	hp = current_hp
	max_hp = current_max_hp
	if delta < 0:
		_flash_damage()
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
		hp_bar.visible = hp < max_hp and hp > 0

func _on_health_died(reason: StringName) -> void:
	if _destroyed:
		return
	_destroyed = true
	if _damage_flash_tween:
		_damage_flash_tween.kill()
		_damage_flash_tween = null
	set_deferred("collision_layer", 0)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	remove_from_group("combat_target")
	_unregister_combat_target()
	if hp_bar:
		hp_bar.visible = false
	_update_visuals()
	building_destroyed.emit(self, reason)
	_on_building_destroyed(reason)
	set_process(false)

func _flash_damage() -> void:
	if icon_sprite == null or _destroyed:
		return
	if _damage_flash_tween:
		_damage_flash_tween.kill()
	icon_sprite.modulate = Color(1.0, 0.46, 0.34, 1.0)
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(icon_sprite, "modulate", Color.WHITE, 0.16)
	_damage_flash_tween.finished.connect(func() -> void:
		_damage_flash_tween = null
	)

func _on_building_destroyed(_reason: StringName) -> void:
	pass

func _register_combat_target() -> void:
	_combat_target_registry = CombatTargetRegistryScript.find_for(self)
	if _combat_target_registry != null:
		_combat_target_registry.call("register_target", self)

func _unregister_combat_target() -> void:
	if _combat_target_registry != null and is_instance_valid(_combat_target_registry):
		_combat_target_registry.call("unregister_target", self)
	_combat_target_registry = null
