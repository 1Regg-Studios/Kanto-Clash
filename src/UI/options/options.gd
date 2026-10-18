extends Control

signal closed

const SLIDE_TIME := 0.5
const DIM_ALPHA := 0.6

@onready var _dim: ColorRect = $Dim
@onready var _panel: TextureRect = $Panel
@onready var _master_slider: HSlider = $Panel/MasterSlider
@onready var _sfx_slider: HSlider = $Panel/SfxSlider
@onready var _music_slider: HSlider = $Panel/MusicSlider
@onready var _back_button: TextureButton = $Panel/BackButton

var _transitioning := false


func _ready() -> void:
	_master_slider.set_value_no_signal(AudioManager.master_volume)
	_sfx_slider.set_value_no_signal(AudioManager.sfx_volume)
	_music_slider.set_value_no_signal(AudioManager.music_volume)
	_master_slider.value_changed.connect(AudioManager.set_master_volume)
	_sfx_slider.value_changed.connect(AudioManager.set_sfx_volume)
	_music_slider.value_changed.connect(AudioManager.set_music_volume)
	_slide_in()


func _slide_in() -> void:
	var final_position := _panel.position
	_panel.position = final_position + Vector2(0.0, get_viewport_rect().size.y)
	var tween := create_tween()
	tween.tween_property(_panel, "position", final_position, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_dim, "color:a", DIM_ALPHA, SLIDE_TIME)


func _on_back_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	_back_button.disabled = true
	var tween := create_tween()
	tween.tween_property(_panel, "position", _panel.position + Vector2(0.0, get_viewport_rect().size.y), SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_dim, "color:a", 0.0, SLIDE_TIME)
	await tween.finished
	closed.emit()
