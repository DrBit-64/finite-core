extends Node
class_name AudioManagerService

const SETTINGS_PATH := "res://Resources/data/audio/mvp_audio_settings.json"
const CUE_CONFIG_PATH := "res://Resources/data/audio/mvp_audio_cues.json"

signal settings_changed(settings: Dictionary)

var master_volume: float = 0.85
var music_volume: float = 0.38
var sfx_volume: float = 0.75
var music_enabled: bool = true
var sfx_enabled: bool = true

var _cue_paths: Dictionary = {}
var _cue_volumes: Dictionary = {}
var _cue_cooldowns: Dictionary = {}
var _last_cue_time: Dictionary = {}
var _weapon_hit_cues: Dictionary = {}
var _weapon_fire_cues: Dictionary = {}
var _impact_effect_cues: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0
var _music_player: AudioStreamPlayer = null
var _seen_rule_names: Dictionary = {}
var _music_watchdog_seconds: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_load_cues()
	_create_players()
	_connect_event_log()
	if DisplayServer.get_name() != "headless":
		call_deferred("_start_music")

func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_music_watchdog_seconds += delta
	if _music_watchdog_seconds < 1.0:
		return
	_music_watchdog_seconds = 0.0
	_ensure_music_playing()

func _exit_tree() -> void:
	if _music_player:
		_music_player.stop()
		_music_player.stream = null
	for player in _sfx_players:
		if player:
			player.stop()
			player.stream = null

func play_cue(cue_id: StringName, volume_scale: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not sfx_enabled:
		return
	var cue_key := String(cue_id)
	if not _cue_paths.has(cue_key):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var cooldown := float(_cue_cooldowns.get(cue_key, 0.0))
	if cooldown > 0.0 and now - float(_last_cue_time.get(cue_key, -999.0)) < cooldown:
		return
	_last_cue_time[cue_key] = now
	var stream := load(str(_cue_paths[cue_key])) as AudioStream
	if stream == null:
		return
	var player := _get_next_sfx_player()
	player.stream = stream
	player.volume_db = linear_to_db(clampf(master_volume * sfx_volume * float(_cue_volumes.get(cue_key, 1.0)) * volume_scale, 0.0, 1.0))
	player.play()

func play_ui_click() -> void:
	play_cue(&"ui_click")

func play_weapon_hit_cue(weapon_id: StringName, volume_scale: float = 1.0) -> void:
	var cue_id := String(_weapon_hit_cues.get(String(weapon_id), _weapon_hit_cues.get("default", "unit_hit")))
	play_cue(StringName(cue_id), volume_scale)

func play_weapon_fire_cue(weapon_id: StringName, volume_scale: float = 1.0) -> void:
	var cue_id := String(_weapon_fire_cues.get(String(weapon_id), _weapon_fire_cues.get("default", "")))
	if cue_id.is_empty():
		return
	play_cue(StringName(cue_id), volume_scale)

func play_damage_impact_cue(effectiveness: StringName = &"normal", weapon_id: StringName = &"default", volume_scale: float = 1.0) -> void:
	var effect_key := String(effectiveness)
	var weapon_key := String(weapon_id)
	var cue_id := ""
	if _impact_effect_cues.has("%s:%s" % [weapon_key, effect_key]):
		cue_id = String(_impact_effect_cues["%s:%s" % [weapon_key, effect_key]])
	else:
		cue_id = String(_impact_effect_cues.get(effect_key, _impact_effect_cues.get("normal", _weapon_hit_cues.get(weapon_key, _weapon_hit_cues.get("default", "unit_hit")))))
	if cue_id.is_empty():
		return
	play_cue(StringName(cue_id), volume_scale)

func set_audio_settings(next_settings: Dictionary) -> void:
	master_volume = clampf(float(next_settings.get("master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(next_settings.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(next_settings.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	music_enabled = bool(next_settings.get("music_enabled", music_enabled))
	sfx_enabled = bool(next_settings.get("sfx_enabled", sfx_enabled))
	_apply_music_volume()
	settings_changed.emit(get_audio_settings())

func get_audio_settings() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"music_enabled": music_enabled,
		"sfx_enabled": sfx_enabled,
	}

func _load_settings() -> void:
	var data := _load_json_dictionary(SETTINGS_PATH)
	if data.is_empty():
		return
	master_volume = clampf(float(data.get("master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	music_enabled = bool(data.get("music_enabled", music_enabled))
	sfx_enabled = bool(data.get("sfx_enabled", sfx_enabled))

func _load_cues() -> void:
	var data := _load_json_dictionary(CUE_CONFIG_PATH)
	_weapon_hit_cues = data.get("weapon_hit_cues", {}).duplicate(true)
	_weapon_fire_cues = data.get("weapon_fire_cues", {}).duplicate(true)
	_impact_effect_cues = data.get("impact_effect_cues", {}).duplicate(true)
	var cues: Dictionary = data.get("cues", {})
	for cue_id in cues.keys():
		var cue: Dictionary = cues[cue_id]
		_cue_paths[String(cue_id)] = str(cue.get("path", ""))
		_cue_volumes[String(cue_id)] = float(cue.get("volume", 1.0))
		_cue_cooldowns[String(cue_id)] = float(cue.get("cooldown_seconds", 0.0))

func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _create_players() -> void:
	for index in range(10):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % index
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_players.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)

func _connect_event_log() -> void:
	var event_log := get_node_or_null("/root/CombatEventLog")
	if event_log and event_log.has_signal("event_recorded"):
		event_log.connect("event_recorded", Callable(self, "_on_event_recorded"))

func _start_music() -> void:
	var data := _load_json_dictionary(SETTINGS_PATH)
	var music_path := str(data.get("music_path", ""))
	if music_path.is_empty() or _music_player == null:
		return
	var stream := load(music_path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		var wav_stream := stream as AudioStreamWAV
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav_stream.loop_begin = 0
		wav_stream.loop_end = -1
	_music_player.stream = stream
	_apply_music_volume()
	_ensure_music_playing()

func _apply_music_volume() -> void:
	if _music_player == null:
		return
	_music_player.volume_db = linear_to_db(clampf(master_volume * music_volume, 0.0, 1.0))
	if music_enabled:
		if _music_player.stream and not _music_player.playing:
			_music_player.play()
	else:
		_music_player.stop()

func _ensure_music_playing() -> void:
	if not music_enabled or _music_player == null:
		return
	if _music_player.stream == null:
		_start_music()
		return
	if not _music_player.playing:
		_music_player.play()

func _get_next_sfx_player() -> AudioStreamPlayer:
	if _sfx_players.is_empty():
		_create_players()
	var player := _sfx_players[_next_sfx_player % _sfx_players.size()]
	_next_sfx_player += 1
	return player

func _on_event_recorded(event: Dictionary) -> void:
	var event_type := str(event.get("type", ""))
	var payload: Dictionary = event.get("payload", {})
	match event_type:
		"robot_produced":
			play_cue(&"robot_produced")
		"robot_lost":
			play_cue(&"unit_destroyed")
		"enemy_killed":
			play_cue(&"unit_destroyed", 0.72)
		"building_destroyed":
			play_cue(&"unit_destroyed", 0.9)
		"nest_destroyed":
			play_cue(&"enemy_nest_destroyed")
		"technology_unlocked":
			play_cue(&"technology_unlocked")
		"rule_triggered":
			var rule_name := str(payload.get("rule_name", payload.get("rule_id", "")))
			if not rule_name.is_empty() and not _seen_rule_names.has(rule_name):
				_seen_rule_names[rule_name] = true
				play_cue(&"rule_triggered_first")
