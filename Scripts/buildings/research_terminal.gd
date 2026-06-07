extends "res://Scripts/buildings/base_building.gd"
class_name ResearchTerminalBuilding

signal research_state_changed
signal research_completed(technology)

var target_inventory: Variant = null
var campaign_state: Variant = null
var active_technology: Variant = null
var status_text: String = "idle"
var progress_seconds: float = 0.0

func setup_research_terminal(inventory: Variant, state: Variant) -> void:
	target_inventory = inventory
	campaign_state = state
	_update_status()

func can_start_research(technology: Variant) -> bool:
	if technology == null or active_technology != null:
		return false
	if target_inventory == null or campaign_state == null:
		return false
	if not campaign_state.can_research(technology):
		return false
	return target_inventory.can_afford(technology.costs)

func start_research(technology: Variant) -> bool:
	if not can_start_research(technology):
		_update_status()
		return false
	if not target_inventory.spend_resources(technology.costs, "research %s" % technology.display_name):
		_update_status()
		return false
	active_technology = technology
	progress_seconds = 0.0
	_set_status("researching")
	research_state_changed.emit()
	return true

func _process(delta: float) -> void:
	if active_technology == null:
		_update_status()
		return
	progress_seconds += delta
	if progress_seconds < active_technology.duration_seconds:
		return
	var completed = active_technology
	active_technology = null
	progress_seconds = 0.0
	if campaign_state:
		campaign_state.unlock_technology(completed)
	_set_status("completed")
	research_completed.emit(completed)
	research_state_changed.emit()

func get_progress_ratio() -> float:
	if active_technology == null or active_technology.duration_seconds <= 0.0:
		return 0.0
	return clampf(progress_seconds / active_technology.duration_seconds, 0.0, 1.0)

func get_inspector_lines() -> Array[String]:
	var lines := super.get_inspector_lines()
	lines.append("Research status: %s" % status_text)
	if active_technology:
		lines.append("Current research: %s" % active_technology.display_name)
		lines.append("Research progress: %d%%" % int(get_progress_ratio() * 100.0))
	else:
		lines.append("Current research: none")
	return lines

func _update_status() -> void:
	if active_technology != null:
		_set_status("researching")
	elif target_inventory == null:
		_set_status("waiting_inventory")
	elif campaign_state == null:
		_set_status("waiting_campaign")
	else:
		_set_status("idle")

func _set_status(next_status: String) -> void:
	if status_text == next_status:
		return
	status_text = next_status
	research_state_changed.emit()
