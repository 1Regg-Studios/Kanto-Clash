extends SceneTree

# Run with --script; add --main-pack <exported.exe> to test the packaged game.
const MAIN_MENU := "res://src/UI/main/mainmenu.tscn"
const MENU_TRACKS: Array[String] = [
	"res://assets/Music/Main/mfcc-retro-arcade-game-music-297305.mp3",
	"res://assets/Music/Main/tatamusic-game-game-music-599001.mp3",
	"res://assets/Music/Main/tatamusic-game-gaming-video-game-music-482380.mp3",
	"res://assets/Music/Main/tatamusic-gaming-game-video-game-music-550079.mp3",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node_or_null("AudioManager")
	_check(manager != null, "The audio manager is available")
	if manager == null:
		quit(1)
		return
	var tracks: Array = manager.get("_music_tracks")
	_check(tracks.size() == MENU_TRACKS.size(), "The menu playlist loads all four tracks")
	var loaded_paths: Array[String] = []
	for track: AudioStream in tracks:
		loaded_paths.append(track.resource_path)
		_check(track.get_length() > 0.0, "Loaded music has a playable duration")
	for path in MENU_TRACKS:
		_check(loaded_paths.has(path), "The playlist includes " + path.get_file())

	var bus := AudioServer.get_bus_index("Music")
	_check(bus >= 0, "The music bus is available")
	if bus < 0:
		quit(1)
		return
	# Isolate playback checks from saved volume settings without writing them.
	var was_muted := AudioServer.is_bus_mute(bus)
	var volume_db := AudioServer.get_bus_volume_db(bus)
	AudioServer.set_bus_mute(bus, false)
	AudioServer.set_bus_volume_db(bus, 0.0)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	var effect_index := AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus, capture)

	var error := change_scene_to_file(MAIN_MENU)
	_check(error == OK, "The real main-menu scene loads")
	if error != OK:
		quit(1)
		return
	await scene_changed
	await create_timer(2.5).timeout
	var player := manager.get("_music_playing") as AudioStreamPlayer
	_check(bool(manager.get("_music_active")) and player.playing, "The main menu starts its music automatically")
	_check(player.stream != null and player.bus == "Music", "Menu playback uses a loaded track on the music bus")
	var position := player.get_playback_position()
	await create_timer(0.25).timeout
	_check(player.get_playback_position() > position, "Menu music playback advances")
	var peak := 0.0
	for frame in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	_check(peak > 0.0001, "Menu music produces non-silent audio")
	AudioServer.remove_bus_effect(bus, effect_index)
	AudioServer.set_bus_mute(bus, was_muted)
	AudioServer.set_bus_volume_db(bus, volume_db)
	manager.call("stop_menu_music")
	await create_timer(2.15).timeout
	print("MENU MUSIC: %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error(message)
