extends Control

const RANDOMIZER_SCENE := "res://src/UI/randomizer/minigame_randomizer.tscn"

const READY_ACTIONS := ["P1_Ready", "P2_Ready", "P3_Ready", "P4_Ready"]

const BOX_TEXTURE := preload("res://assets/Character Select/BOX.png")
const BOX_CHECK_TEXTURE := preload("res://assets/Character Select/BOX CHECK.png")

const READY_MODULATE := Color(1, 1, 1)
const NOT_READY_MODULATE := Color(0.6, 0.48, 0.5)
const TOGGLE_TIME := 0.15

const BLINK_MIN_ALPHA := 0.4
const BLINK_HALF_PERIOD := 0.5

const READY_POP_SCALE := 1.12
const READY_HOP_HEIGHT := 20.0
const READY_SHAKE_ANGLE := 0.06
const READY_POP_TIME := 0.12
const READY_SHAKE_TIME := 0.08
const READY_SETTLE_TIME := 0.16

@onready var _prompt: TextureRect = $Prompt
@onready var _portraits: Array[Control] = [
	$Player1/Portrait,
	$Player2/Portrait,
	$Player3/Portrait,
	$Player4/Portrait,
]
@onready var _characters: Array[Control] = [
	$Player1/Portrait/Character,
	$Player2/Portrait/Character,
	$Player3/Portrait/Character,
	$Player4/Portrait/Character,
]
@onready var _boxes: Array[TextureRect] = [
	$Player1/Box,
	$Player2/Box,
	$Player3/Box,
	$Player4/Box,
]

var _ready_states: Array[bool] = [false, false, false, false]
var _portrait_tweens: Array[Tween] = [null, null, null, null]
var _character_tweens: Array[Tween] = [null, null, null, null]
var _character_home_positions: Array[Vector2] = []
var _transitioning := false


func _ready() -> void:
	AudioManager.start_menu_music()
	for portrait in _portraits:
		portrait.modulate = NOT_READY_MODULATE
	for character in _characters:
		_character_home_positions.append(character.position)
	var blink := create_tween().set_loops()
	blink.tween_property(_prompt, "modulate:a", BLINK_MIN_ALPHA, BLINK_HALF_PERIOD)
	blink.tween_property(_prompt, "modulate:a", 1.0, BLINK_HALF_PERIOD)


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	for i in range(READY_ACTIONS.size()):
		if event.is_action_pressed(READY_ACTIONS[i]):
			AudioManager.play_ready()
			_set_ready(i, not _ready_states[i])
			get_viewport().set_input_as_handled()
			return


func _set_ready(index: int, ready: bool) -> void:
	_ready_states[index] = ready
	if ready:
		_boxes[index].texture = BOX_CHECK_TEXTURE
		_tween_portrait(index, READY_MODULATE)
		_play_ready_bounce(index)
	else:
		_boxes[index].texture = BOX_TEXTURE
		_tween_portrait(index, NOT_READY_MODULATE)
		_reset_character(index)

	if _all_players_ready():
		_start_game()


func _play_ready_bounce(index: int) -> void:
	_kill_character_tween(index)
	var character := _characters[index]
	var home := _character_home_positions[index]
	character.pivot_offset = character.size * 0.5
	character.position = home
	character.rotation = 0.0
	character.scale = Vector2.ONE
	var tween := create_tween()
	_character_tweens[index] = tween
	tween.tween_property(character, "scale", Vector2.ONE * READY_POP_SCALE, READY_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(character, "position:y", home.y - READY_HOP_HEIGHT, READY_POP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(character, "rotation", READY_SHAKE_ANGLE, READY_SHAKE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(character, "rotation", -READY_SHAKE_ANGLE, READY_SHAKE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(character, "rotation", 0.0, READY_SHAKE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(character, "position:y", home.y, READY_SETTLE_TIME).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(character, "scale", Vector2.ONE, READY_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _reset_character(index: int) -> void:
	_kill_character_tween(index)
	var character := _characters[index]
	character.position = _character_home_positions[index]
	character.rotation = 0.0
	character.scale = Vector2.ONE


func _kill_character_tween(index: int) -> void:
	var previous := _character_tweens[index]
	if previous != null and previous.is_valid():
		previous.kill()
	_character_tweens[index] = null


func _tween_portrait(index: int, color: Color) -> void:
	var previous := _portrait_tweens[index]
	if previous != null and previous.is_valid():
		previous.kill()
	var tween := create_tween()
	_portrait_tweens[index] = tween
	tween.tween_property(_portraits[index], "modulate", color, TOGGLE_TIME)


func _all_players_ready() -> bool:
	for state in _ready_states:
		if not state:
			return false
	return true


func _start_game() -> void:
	_transitioning = true
	ScoreKeeper.reset()
	GameSchedule.reset()
	await SceneFader.change_scene(RANDOMIZER_SCENE)
