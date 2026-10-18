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
	_bind_slider(_master_slider, AudioManager.master_volume, AudioManager.set_master_volume)
	_bind_slider(_sfx_slider, AudioManager.sfx_volume, AudioManager.set_sfx_volume)
	_bind_slider(_music_slider, AudioManager.music_volume, AudioManager.set_music_volume)
	_back_button.pressed.connect(AudioManager.play_click)
	_slide_in()


func _bind_slider(slider: HSlider, value: float, setter: Callable) -> void:
	slider.set_value_no_signal(value)
	slider.value_changed.connect(setter)


func _slide_in() -> void:
	var end := _panel.position
	_panel.position += Vector2(0.0, get_viewport_rect().size.y)
	_slide(end, DIM_ALPHA, Tween.EASE_OUT)


func _on_back_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	_back_button.disabled = true
	await _slide(_panel.position + Vector2(0.0, get_viewport_rect().size.y), 0.0, Tween.EASE_IN).finished
	AudioManager.flush_settings()
	closed.emit()


func _slide(end: Vector2, dim_alpha: float, ease: Tween.EaseType) -> Tween:
	var tween := create_tween()
	tween.tween_property(_panel, "position", end, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(ease)
	tween.parallel().tween_property(_dim, "color:a", dim_alpha, SLIDE_TIME)
	return tween
