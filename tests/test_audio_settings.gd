extends Node

class CountedAudioManager:
	extends "res://src/autoload/audio_manager.gd"

	var save_count := 0

	func _save_settings() -> void:
		save_count += 1
		super._save_settings()


var _failures := 0
var _settings_path := ""


func _ready() -> void:
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		printerr("[test] audio settings: timed out")
		get_tree().quit(1)
	)
	_settings_path = "user://test_audio_settings_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	var audio := CountedAudioManager.new()
	audio._settings_path = _settings_path
	add_child(audio)
	# A burst across all sliders should update sound now and write only once later.
	for i in 100:
		var volume := float(i) / 100.0
		audio.set_master_volume(volume)
		audio.set_music_volume(volume * 0.5)
		audio.set_sfx_volume(volume * 0.25)
	_check(audio.save_count == 0, "Slider drags must not write synchronously")
	_check_bus("Master", 0.99)
	_check_bus("Music", 0.495)
	_check_bus("Sfx", 0.2475)
	await get_tree().create_timer(audio.SETTINGS_SAVE_DELAY * 0.6).timeout
	audio.set_music_volume(0.6)
	await get_tree().create_timer(audio.SETTINGS_SAVE_DELAY * 0.6).timeout
	_check(audio.save_count == 0, "New changes must restart the save delay")
	await get_tree().create_timer(audio.SETTINGS_SAVE_DELAY + 0.1).timeout
	_check(audio.save_count == 1, "One slider burst must produce one save")
	_check_saved(0.99, 0.6, 0.2475)

	# Applying the same value still restores the bus/mute state, without a new write.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	audio.set_master_volume(0.99)
	audio.set_music_volume(0.6)
	audio.set_sfx_volume(0.2475)
	_check_bus("Master", 0.99)
	audio.flush_settings()
	_check(audio.save_count == 1, "Unchanged settings and clean flushes must not save")

	audio.set_master_volume(-1.0)
	audio.set_music_volume(2.0)
	audio.set_sfx_volume(0.0)
	_check_bus("Master", 0.0)
	_check_bus("Music", 1.0)
	_check_bus("Sfx", 0.0)
	audio.flush_settings()
	_check(audio.save_count == 2, "Explicit flush must save pending values immediately")
	_check_saved(0.0, 1.0, 0.0)
	await get_tree().create_timer(audio.SETTINGS_SAVE_DELAY + 0.1).timeout
	_check(audio.save_count == 2, "Flushing must cancel the pending timer save")

	# Exiting before the timer fires must still persist the final value.
	audio.set_master_volume(0.42)
	remove_child(audio)
	_check(audio.save_count == 3, "Tree exit must flush pending settings")
	_check_saved(0.42, 1.0, 0.0)
	audio.free()
	var reloaded := CountedAudioManager.new()
	reloaded._settings_path = _settings_path
	add_child(reloaded)
	_check(is_equal_approx(reloaded.master_volume, 0.42), "Saved Master volume must reload")
	_check(is_equal_approx(reloaded.music_volume, 1.0), "Saved Music volume must reload")
	_check(is_zero_approx(reloaded.sfx_volume), "Saved Sfx volume must reload")
	reloaded.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_settings_path))
	print("[test] audio settings: ", "PASS" if _failures == 0 else "FAIL")
	get_tree().quit(0 if _failures == 0 else 1)


func _check_saved(master: float, music: float, sfx: float) -> void:
	var config := ConfigFile.new()
	_check(config.load(_settings_path) == OK, "Settings file must be readable")
	_check(is_equal_approx(float(config.get_value("audio", "master", -1.0)), master), "Saved Master value mismatch")
	_check(is_equal_approx(float(config.get_value("audio", "music", -1.0)), music), "Saved Music value mismatch")
	_check(is_equal_approx(float(config.get_value("audio", "sfx", -1.0)), sfx), "Saved Sfx value mismatch")


func _check_bus(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	_check(AudioServer.is_bus_mute(index) == is_zero_approx(volume), bus_name + " mute mismatch")
	if volume > 0.0:
		_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(index)), volume), bus_name + " volume must update immediately")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[test] FAIL: ", message)
