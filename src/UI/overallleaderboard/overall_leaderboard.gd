extends Leaderboard

const MAIN_MENU_SCENE := "res://src/UI/main/mainmenu.tscn"
const PROMPT_FADE_TIME := 0.3
const BLINK_MIN_ALPHA := 0.4
const BLINK_HALF_PERIOD := 0.5

const NORMAL_COLOR := Color(1, 1, 1, 1)
const HIGHLIGHT_COLOR := Color(0.913725, 0.67451, 0.262745, 1)

const PLAYER_TEXTURES: Array[Texture2D] = [
	preload("res://assets/Overall LeaderBoard/PLAYER 1.png"),
	preload("res://assets/Overall LeaderBoard/PLAYER 2.png"),
	preload("res://assets/Overall LeaderBoard/PLAYER 3.png"),
	preload("res://assets/Overall LeaderBoard/PLAYER 4.png"),
]

const PLAYER_HIGHLIGHT_TEXTURES: Array[Texture2D] = [
	preload("res://assets/Overall LeaderBoard/PLAYER 1o.png"),
	preload("res://assets/Overall LeaderBoard/PLAYER 2o.png"),
	preload("res://assets/Overall LeaderBoard/PLAYER 3o.png"),
	preload("res://assets/Overall LeaderBoard/PLAYER 4o.png"),
]

@onready var _player_labels: Array[TextureRect] = [
	$Board/Row1/PlayerLabel,
	$Board/Row2/PlayerLabel,
	$Board/Row3/PlayerLabel,
	$Board/Row4/PlayerLabel,
]

@onready var _prompt: TextureRect = $Prompt

var _awaiting_input := false
var _transitioning := false
var _blink: Tween


func _ready() -> void:
	super._ready()
	play(ScoreKeeper.totals)


func play(scores: Array) -> void:
	_reset_prompt()
	super.play(scores)


func _on_sorted() -> void:
	_highlight_winner()
	_reveal_prompt()


func _highlight_winner() -> void:
	var winner := _players_by_score(false)[0]
	for i in range(ROW_COUNT):
		var highlighted := i == winner
		_player_labels[i].texture = PLAYER_HIGHLIGHT_TEXTURES[i] if highlighted else PLAYER_TEXTURES[i]
		_score_labels[i].add_theme_color_override("font_color", HIGHLIGHT_COLOR if highlighted else NORMAL_COLOR)


func _reveal_prompt() -> void:
	var tween := create_tween()
	_tweens.append(tween)
	tween.tween_property(_prompt, "modulate:a", 1.0, PROMPT_FADE_TIME)
	tween.finished.connect(_start_prompt_blink)


func _start_prompt_blink() -> void:
	if _blink != null and _blink.is_valid():
		_blink.kill()
	_blink = create_tween().set_loops()
	_blink.tween_property(_prompt, "modulate:a", BLINK_MIN_ALPHA, BLINK_HALF_PERIOD)
	_blink.tween_property(_prompt, "modulate:a", 1.0, BLINK_HALF_PERIOD)
	_awaiting_input = true


func _unhandled_input(event: InputEvent) -> void:
	if not _awaiting_input or _transitioning:
		return
	if event.is_action_pressed("Toggle_Fullscreen"):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_return_to_menu()
	elif event is InputEventJoypadButton and event.pressed:
		_return_to_menu()
	elif event is InputEventMouseButton and event.pressed:
		_return_to_menu()


func _return_to_menu() -> void:
	_transitioning = true
	_awaiting_input = false
	if _blink != null and _blink.is_valid():
		_blink.kill()
	get_viewport().set_input_as_handled()
	ScoreKeeper.reset()
	await SceneFader.change_scene(MAIN_MENU_SCENE)


func _reset_prompt() -> void:
	_awaiting_input = false
	if _blink != null and _blink.is_valid():
		_blink.kill()
	_prompt.modulate.a = 0.0
