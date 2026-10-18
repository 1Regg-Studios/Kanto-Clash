extends Node

const SETTINGS_PATH := "user://settings.cfg"
const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "Sfx"
const MIN_VOLUME := 0.0001

var master_volume := 1.0
var music_volume := 1.0
var sfx_volume := 1.0


func _ready() -> void:
	_load_settings()
	_apply_bus(MASTER_BUS, master_volume)
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(SFX_BUS, sfx_volume)


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
