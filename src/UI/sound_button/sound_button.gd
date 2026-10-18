extends TextureButton

const MASTER_BUS := "Master"

@export var play_click_sound := true

var _bus_index: int


func _ready() -> void:
	_bus_index = AudioServer.get_bus_index(MASTER_BUS)
	set_pressed_no_signal(AudioServer.is_bus_mute(_bus_index))


func _toggled(toggled_on: bool) -> void:
	if play_click_sound:
		AudioManager.play_click()
	AudioServer.set_bus_mute(_bus_index, toggled_on)
