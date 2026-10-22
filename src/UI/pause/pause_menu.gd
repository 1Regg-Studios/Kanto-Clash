extends CanvasLayer

const OPTIONS_SCENE := preload("res://src/UI/options/options.tscn")
const MAIN_MENU_SCENE := "res://src/UI/main/mainmenu.tscn"

const DIM_ALPHA := 0.65
const OPEN_TIME := 0.2
const CLOSE_TIME := 0.15
const PANEL_OFFSET := 28.0
const HOVER_LIFT := 6.0
const HOVER_TIME := 0.18

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _center: Control = $Root/Center
@onready var _panel: TextureRect = $Root/Center/Panel
@onready var _resume_button: TextureButton = $Root/Center/Panel/ResumeButton
@onready var _options_button: TextureButton = $Root/Center/Panel/OptionsButton
@onready var _main_menu_button: TextureButton = $Root/Center/Panel/MainMenuButton
@onready var _quit_button: TextureButton = $Root/Center/Panel/QuitButton

@onready var _buttons: Array[TextureButton] = [
	_resume_button,
	_options_button,
	_main_menu_button,
	_quit_button,
]

var _is_open := false
var _busy := false
var _options_screen: Node = null
var _open_tween: Tween
var _center_home := Vector2.ZERO
var _button_home: Dictionary = {}
var _hover_tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	for button in _buttons:
		_button_home[button] = button.position
		button.pressed.connect(_on_button_pressed.bind(button))
		button.mouse_entered.connect(_set_button_hover.bind(button, true))
		button.mouse_exited.connect(_set_button_hover.bind(button, false))


func _exit_tree() -> void:
	if _is_open:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _options_screen != null:
		_options_screen.call("close")
	elif _is_open:
		_close()
	else:
		_open()
	get_viewport().set_input_as_handled()


func _open() -> void:
	if _is_open or _busy:
		return
	_is_open = true
	_reset_button_positions()
	_center_home = _center.position
	_center.position = _center_home + Vector2(0.0, PANEL_OFFSET)
	_dim.color.a = 0.0
	_panel.modulate.a = 0.0
	_root.visible = true
	get_tree().paused = true
	_open_tween = create_tween().set_parallel(true)
	_open_tween.tween_property(_dim, "color:a", DIM_ALPHA, OPEN_TIME)
	_open_tween.tween_property(_panel, "modulate:a", 1.0, OPEN_TIME)
	_open_tween.tween_property(_center, "position", _center_home, OPEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _close() -> void:
	if not _is_open or _busy:
		return
	_busy = true
	_set_buttons_disabled(true)
	_stop_hover_tweens()
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "color:a", 0.0, CLOSE_TIME)
	tween.tween_property(_panel, "modulate:a", 0.0, CLOSE_TIME)
	tween.tween_property(_center, "position", _center_home + Vector2(0.0, PANEL_OFFSET), CLOSE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	_root.visible = false
	_is_open = false
	get_tree().paused = false
	_reset_button_positions()
	_set_buttons_disabled(false)
	_busy = false


func _on_button_pressed(button: TextureButton) -> void:
	if _busy:
		return
	AudioManager.play_click()
	if button == _resume_button:
		_close()
	elif button == _options_button:
		_open_options()
	elif button == _main_menu_button:
		_go_to_main_menu()
	elif button == _quit_button:
		_quit_game()


func _open_options() -> void:
	if _options_screen != null:
		return
	_stop_hover_tweens()
	_reset_button_positions()
	_set_buttons_disabled(true)
	_options_screen = OPTIONS_SCENE.instantiate()
	_options_screen.connect("closed", _on_options_closed)
	_root.add_child(_options_screen)


func _on_options_closed() -> void:
	if _options_screen == null:
		return
	_options_screen.queue_free()
	_options_screen = null
	_set_buttons_disabled(false)


func _go_to_main_menu() -> void:
	if _busy:
		return
	_busy = true
	_set_buttons_disabled(true)
	_stop_hover_tweens()
	ScoreKeeper.reset()
	GameSchedule.reset()
	get_tree().paused = false
	SceneFader.change_scene(MAIN_MENU_SCENE)


func _quit_game() -> void:
	if _busy:
		return
	_busy = true
	_set_buttons_disabled(true)
	_stop_hover_tweens()
	get_tree().paused = false
	await SceneFader.fade_out()
	get_tree().quit()


func _set_button_hover(button: TextureButton, hovered: bool) -> void:
	if _busy:
		return
	var previous: Tween = _hover_tweens.get(button)
	if previous != null and previous.is_valid():
		previous.kill()
	var home: Vector2 = _button_home[button]
	if hovered:
		var bob := create_tween().set_loops()
		bob.tween_property(button, "position:y", home.y - HOVER_LIFT, HOVER_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(button, "position:y", home.y, HOVER_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_hover_tweens[button] = bob
	else:
		var settle := create_tween()
		settle.tween_property(button, "position:y", home.y, HOVER_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_hover_tweens[button] = settle


func _stop_hover_tweens() -> void:
	for button in _hover_tweens:
		var tween: Tween = _hover_tweens[button]
		if tween != null and tween.is_valid():
			tween.kill()
	_hover_tweens.clear()


func _reset_button_positions() -> void:
	for button in _buttons:
		button.position = _button_home[button]


func _set_buttons_disabled(disabled: bool) -> void:
	for button in _buttons:
		button.disabled = disabled
