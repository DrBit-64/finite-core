extends SceneTree

const CampaignStateScript := preload("res://Scripts/campaign/campaign_state.gd")
const TechnologyConfigLoaderScript := preload("res://Scripts/campaign/technology_config_loader.gd")
const TECHNOLOGY_PATH := "res://Resources/data/technology/mvp_stage1_technologies.json"

func _init() -> void:
	var technologies: Array = TechnologyConfigLoaderScript.load_technology_defs(TECHNOLOGY_PATH)
	var laser_technology: Variant = _find_technology(technologies, &"stage2_thermal_laser_weaponry")
	var cooling_technology: Variant = _find_technology(technologies, &"stage2_oscillator_cooling")
	_require(laser_technology != null, "Thermal laser technology is missing.")
	_require(cooling_technology != null, "Oscillator cooling technology is missing.")
	_require(
		not laser_technology.key_item_requirements.has(&"high_frequency_oscillator"),
		"Thermal laser must unlock before defeating the armored nest."
	)
	_require(
		cooling_technology.key_item_requirements.has(&"high_frequency_oscillator"),
		"Armored nest oscillator must gate the cooling upgrade."
	)

	var campaign_state = CampaignStateScript.new()
	campaign_state.seed_defaults()
	var unlocked_count: int = campaign_state.debug_unlock_all_technologies(technologies)
	_require(unlocked_count == technologies.size(), "Debug unlock did not unlock every technology.")
	_require(
		campaign_state.unlocked_unit_types.has(&"thermal_laser_robot"),
		"Debug unlock did not expose the thermal laser robot."
	)
	_require(
		campaign_state.unlocked_upgrades.has(&"cooling_fins_1"),
		"Debug unlock did not expose the oscillator cooling upgrade."
	)
	print("PHASE16_UNLOCKS_SMOKE_OK technologies=%d" % technologies.size())
	quit(0)

func _find_technology(technologies: Array, technology_id: StringName) -> Variant:
	for technology in technologies:
		if technology != null and technology.id == technology_id:
			return technology
	return null

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
