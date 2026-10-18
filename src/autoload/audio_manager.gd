extends Node

const SETTINGS_PATH := "user://settings.cfg"
const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "Sfx"
const MIN_VOLUME := 0.0001

const CLICK_SOUND := preload("res://assets/Sfx/emilianodleon-button-ui-sound-effect-395762.mp3")
const READY_SOUND := preload("res://assets/Sfx/floraphonic-90s-game-ui-3-185096.mp3")
const PICK_SOUND := preload("res://assets/Sfx/Randomizer/vadim_makes_sound-achievement-badge-pop-sound-1-547860.mp3")

const MENU_MUSIC_DIR := "res://assets/Music/Main"
const MUSIC_FADE_TIME := 2.0
const MUSIC_SILENT_DB := -60.0

var master_volume := 1.0
var music_volume := 1.0
var sfx_volume := 1.0

var _click_player: AudioStreamPlayer
var _ready_player: AudioStreamPlayer
var _pick_player: AudioStreamPlayer

var _music_playing: AudioStreamPlayer
var _music_waiting: AudioStreamPlayer
var _music_tracks: Array[AudioStream] = []
var _music_queue: Array[AudioStream] = []
var _music_timer: Timer
var _music_tween: Tween
var _music_active := false
var _last_music_track: AudioStream


func _ready() -> void:
	_load_settings()
	_apply_bus(MASTER_BUS, master_volume)
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(SFX_BUS, sfx_volume)
	_click_player = _make_sfx_player(CLICK_SOUND)
	_ready_player = _make_sfx_player(READY_SOUND)
	_pick_player = _make_sfx_player(PICK_SOUND)
	_music_playing = _make_music_player()
	_music_waiting = _make_music_player()
	_music_timer = Timer.new()
	_music_timer.one_shot = true
	_music_timer.timeout.connect(_play_next_track)
	add_child(_music_timer)
	_load_menu_tracks()


func _make_sfx_player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SFX_BUS
	add_child(player)
	return player


func _make_music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = MUSIC_BUS
	player.finished.connect(_on_music_finished.bind(player))
	add_child(player)
	return player


func play_click() -> void:
	_click_player.play()


func play_ready() -> void:
	_ready_player.play()


func play_pick() -> void:
	_pick_player.play()


func start_menu_music() -> void:
	if _music_active or _music_tracks.is_empty():
		return
	_music_active = true
	_play_next_track()


func stop_menu_music() -> void:
	if not _music_active:
		return
	_music_active = false
	_kill_music_tween()
	_music_timer.stop()
	_music_tween = create_tween().set_parallel(true)
	for player in [_music_playing, _music_waiting]:
		if player.playing:
			_music_tween.tween_property(player, "volume_db", MUSIC_SILENT_DB, MUSIC_FADE_TIME)
	_music_tween.chain().tween_callback(_stop_music_players)


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_bus(MASTER_BUS, master_volume)
	_save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus(MUSIC_BUS, music_volume)
	_save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus(SFX_BUS, sfx_volume)
	_save_settings()


func _load_menu_tracks() -> void:
	var dir := DirAccess.open(MENU_MUSIC_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		var name := file.trim_suffix(".remap")
		if name.get_extension().to_lower() != "mp3":
			continue
		var track := load(MENU_MUSIC_DIR.path_join(name)) as AudioStream
		if track != null:
			_music_tracks.append(track)


func _play_next_track() -> void:
	if not _music_active:
		return
	if _music_queue.is_empty():
		_refill_music_queue()
	var track: AudioStream = _music_queue.pop_front()
	_last_music_track = track
	var old_player := _music_playing
	_music_playing = _music_waiting
	_music_waiting = old_player
	_kill_music_tween()
	_music_playing.stop()
	_music_playing.stream = track
	_music_playing.volume_db = MUSIC_SILENT_DB
	_music_playing.play()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(old_player, "volume_db", MUSIC_SILENT_DB, MUSIC_FADE_TIME)
	_music_tween.tween_property(_music_playing, "volume_db", 0.0, MUSIC_FADE_TIME)
	_music_tween.chain().tween_callback(old_player.stop)
	var length := track.get_length()
	if length > MUSIC_FADE_TIME:
		_music_timer.start(length - MUSIC_FADE_TIME)


func _on_music_finished(player: AudioStreamPlayer) -> void:
	if not _music_active or player != _music_playing:
		return
	_music_timer.stop()
	_play_next_track()


func _refill_music_queue() -> void:
	_music_queue = _music_tracks.duplicate()
	_music_queue.shuffle()
	if _music_queue.size() > 1 and _music_queue[0] == _last_music_track:
		_music_queue.append(_music_queue.pop_front())


func _stop_music_players() -> void:
	_music_playing.stop()
	_music_waiting.stop()


func _kill_music_tween() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()


func _apply_bus(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, is_zero_approx(volume))
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, MIN_VOLUME)))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	master_volume = float(config.get_value("audio", "master", 1.0))
	music_volume = float(config.get_value("audio", "music", 1.0))
	sfx_volume = float(config.get_value("audio", "sfx", 1.0))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(SETTINGS_PATH)
