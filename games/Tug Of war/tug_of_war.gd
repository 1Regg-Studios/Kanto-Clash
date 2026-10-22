extends Node2D

const PULLER_TEXTURES: Array[Texture2D] = [
	preload("res://games/Tug Of war/assets/p1-puller.png"),
	preload("res://games/Tug Of war/assets/p2-puller.png"),
	preload("res://games/Tug Of war/assets/p3-puller.png"),
	preload("res://games/Tug Of war/assets/p4-puller.png"),
]

const PULL_EFFECT_TEXTURES: Array[Texture2D] = [
	preload("res://games/Tug Of war/assets/p1-pull-effect.png"),
	preload("res://games/Tug Of war/assets/p2-pull-effect.png"),
	preload("res://games/Tug Of war/assets/p3-pull-effect.png"),
	preload("res://games/Tug Of war/assets/p4-pull-effect.png"),
]

const INDICATOR_TEXTURES: Array[Texture2D] = [
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Not Pressed/P1.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Not Pressed/P2.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Not Pressed/P3.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Not Pressed/P4.png"),
]

const INDICATOR_PRESSED_TEXTURES: Array[Texture2D] = [
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Pressed/P1.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Pressed/P2.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Pressed/P3.png"),
	preload("res://games/Tug Of war/assets/UI/Player Press Indicator/Pressed/P4.png"),
]

const PLAYER_ACTIONS: Array[StringName] = [
	&"P1_Ready",
	&"P2_Ready",
	&"P3_Ready",
	&"P4_Ready",
]

const PLAYER_COUNT := 4
const GAME_FONT: Font = preload("res://assets/Fonts/UpheavalPro.ttf")
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const PLAYER_X: Array[float] = [570.0, 735.0, 1125.0, 1310.0]
const CROSS_TEAM_PLAYER_X: Array[float] = [570.0, 1125.0, 735.0, 1310.0]
const PLAYER_Y := 574.0
const PLAYER_SCALE := 8.0
const SPRITE_SIZE := 32
const SPRITE_FRAMES := 4
const PULL_ANIMATION_FPS := 6.0
const PULL_EFFECT_FRAMES := 5
const PULL_EFFECT_ANIMATION_FPS := 12.0
const REST_FRAME := 1
const INDICATOR_X: Array[float] = [470.0, 693.0, 1200.0, 1440.0]
const CROSS_TEAM_INDICATOR_X: Array[float] = [470.0, 1200.0, 693.0, 1440.0]
const INDICATOR_SCALE := 1.12
const INDICATOR_BOTTOM := 954.0
const ROPE_TRAVEL := 130.0
const PULL_SMOOTHING := 14.0

const TEAM_ONE_COLOR := Color("00d18f")
const TEAM_TWO_COLOR := Color("008ee0")
const DRAW_COLOR := Color(1.0, 1.0, 1.0)
const ROUND_RESULTS_SCENE := "res://src/UI/roundleaderboard/roundleaderboard.tscn"
const PULL_SOUND := preload("res://assets/Sfx/oxidvideos-rope-amp-leather-tension-449628.mp3")
const PULL_SOUND_PITCH_MIN := 0.92
const PULL_SOUND_PITCH_MAX := 1.08
const MAIN_MUSIC := preload("res://assets/Music/Main/Tug Of War/tatamusic-gaming-minecraft-game-gaming-music-423630.mp3")

@export_range(10.0, 300.0, 1.0) var match_seconds := 30.0
@export var pull_per_click := 12.0
@export_range(-24.0, 24.0, 0.5) var pull_sound_db := 12.0
@export_range(0.05, 0.9, 0.01) var win_distance_ratio := 0.35
@export var indicator_hold := 0.12
@export var cross_team_pairs := false

@onready var _camera: Camera2D = $Camera2D
@onready var _background: Sprite2D = $Background
@onready var _frame_overlay: Sprite2D = $FrameOverlay
@onready var _world: Node2D = $World
@onready var _hud_root: Control = $HUD/Root
@onready var _hud_layout: Control = $HUD/Root/Composition
@onready var _meter = $HUD/Root/Composition/Meter
@onready var _pullers: Array[AnimatedSprite2D] = [
	$World/P1,
	$World/P2,
	$World/P3,
	$World/P4,
]
@onready var _indicators: Array[TextureRect] = [
	$HUD/Root/Composition/P1Indicator,
	$HUD/Root/Composition/P2Indicator,
	$HUD/Root/Composition/P3Indicator,
	$HUD/Root/Composition/P4Indicator,
]
@onready var _key_labels: Array[Label] = [
	$HUD/Root/Composition/P1Key,
	$HUD/Root/Composition/P2Key,
	$HUD/Root/Composition/P3Key,
	$HUD/Root/Composition/P4Key,
]
@onready var _result_prompt = $HUD/Root/GameOver

var _rope_pos := 0.0
var _time_left := 30.0
var _shown_seconds := -1
var _game_over := false
var _keys_held: Array[bool] = [false, false, false, false]
var _indicator_down: Array[bool] = [false, false, false, false]
var _indicator_until: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _layout_scale := 1.0
var _layout_origin := Vector2.ZERO
var _rope_visual_offset := 0.0
var _round_scores: Array[int] = [0, 0, 0, 0]
var _round_intro_active := true
var _results_started := false
var _pull_sound_players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	cross_team_pairs = GameSchedule.tug_layout_for_current_round()
	_build_pullers()
	_setup_pull_audio()
	_start_main_music()
	_setup_indicators()
	_time_left = match_seconds
	_show_time()
	_update_meter(true)
	_result_prompt.finished.connect(_show_results)
	_hud_root.resized.connect(_layout_arena)
	_layout_arena()
	_show_round_intro()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or event.echo:
		return
	if _game_over or _round_intro_active:
		return
	for player in PLAYER_COUNT:
		if event.is_action(PLAYER_ACTIONS[player]):
			_keys_held[player] = event.pressed
			if event.pressed:
				_pull(player)
			else:
				_refresh_indicator(player, _now())
			get_viewport().set_input_as_handled()
			return


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		for player in PLAYER_COUNT:
			_keys_held[player] = false
			_indicator_until[player] = 0.0
			_set_indicator(player, false)


func _process(delta: float) -> void:
	var now := _now()

	for player in PLAYER_COUNT:
		_refresh_indicator(player, now)

	_update_world(delta)

	if _game_over or _round_intro_active:
		return

	_time_left = maxf(0.0, _time_left - delta)
	_show_time()
	if _time_left <= 0.0:
		_finish_time()


func _build_pullers() -> void:
	for player in PLAYER_COUNT:
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		_add_puller_animation(frames, &"pull", PULLER_TEXTURES[player], SPRITE_FRAMES, PULL_ANIMATION_FPS, true)
		_add_puller_animation(frames, &"pull_effect", PULL_EFFECT_TEXTURES[player], PULL_EFFECT_FRAMES, PULL_EFFECT_ANIMATION_FPS, false)

		var puller := _pullers[player]
		puller.sprite_frames = frames
		puller.animation = &"pull"
		puller.frame = REST_FRAME
		puller.play(&"pull")
		var player_x := CROSS_TEAM_PLAYER_X[player] if cross_team_pairs else PLAYER_X[player]
		puller.position = Vector2(player_x, PLAYER_Y)
		puller.scale = Vector2(PLAYER_SCALE, PLAYER_SCALE)
		puller.flip_h = player == 1 or player == 3 if cross_team_pairs else player >= 2
		puller.frame_changed.connect(_align_puller_grip.bind(player))
		puller.animation_finished.connect(_on_pull_effect_finished.bind(player))
		_align_puller_grip(player)


func _add_puller_animation(frames: SpriteFrames, animation: StringName, texture: Texture2D, frame_count: int, fps: float, looping: bool) -> void:
	frames.add_animation(animation)
	frames.set_animation_loop(animation, looping)
	frames.set_animation_speed(animation, fps)
	for frame_index in frame_count:
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = texture
		frame_texture.region = Rect2(frame_index * SPRITE_SIZE, 0, SPRITE_SIZE, SPRITE_SIZE)
		frames.add_frame(animation, frame_texture)


func _align_puller_grip(player: int) -> void:
	# Frame zero holds its hands one source pixel higher. Keep every grip on
	# the same continuous rope rather than moving or stretching rope sections.
	var puller := _pullers[player]
	puller.offset.y = 1.0 if puller.frame == 0 else 0.0


func _setup_pull_audio() -> void:
	# One player per participant lets overlapping pulls from different players
	# ring out instead of cutting each other off.
	for player in PLAYER_COUNT:
		var sound := AudioStreamPlayer.new()
		sound.stream = PULL_SOUND
		sound.bus = &"Sfx"
		sound.volume_db = pull_sound_db
		add_child(sound)
		_pull_sound_players.append(sound)


func _play_pull_sound(player: int) -> void:
	var sound := _pull_sound_players[player]
	sound.pitch_scale = randf_range(PULL_SOUND_PITCH_MIN, PULL_SOUND_PITCH_MAX)
	sound.play()


func _start_main_music() -> void:
	AudioManager.play_game_music(MAIN_MUSIC)


func _play_pull_effect(player: int) -> void:
	# Replay on the same sprite so taps cannot leave another character or rope
	# behind, and both animations use the same grip alignment and transform.
	var puller := _pullers[player]
	puller.stop()
	puller.play(&"pull_effect")


func _on_pull_effect_finished(player: int) -> void:
	var puller := _pullers[player]
	if _game_over or puller.animation != &"pull_effect":
		return
	puller.play(&"pull")
	# The effect ends in the last idle pose. Continue from that pose instead
	# of jumping to an independently running, hidden animation.
	puller.set_frame_and_progress(SPRITE_FRAMES - 1, 0.0)


func _pull(player: int) -> void:
	var win_distance := _win_distance()
	if _is_team_one(player):
		_rope_pos -= pull_per_click
	else:
		_rope_pos += pull_per_click
	_rope_pos = clampf(_rope_pos, -win_distance, win_distance)

	_indicator_until[player] = _now() + indicator_hold
	_set_indicator(player, true)
	_update_meter()
	_play_pull_sound(player)
	_play_pull_effect(player)

	if absf(_rope_pos) >= win_distance:
		_finish_winning_team(_rope_pos < 0.0)


func _finish_time() -> void:
	if absf(_rope_pos) < 1.0:
		_finish("DRAW!", DRAW_COLOR)
	else:
		_finish_winning_team(_rope_pos < 0.0)


func _finish_winning_team(team_one_won: bool) -> void:
	_finish("TEAM 1 WINS!" if team_one_won else "TEAM 2 WINS!", TEAM_ONE_COLOR if team_one_won else TEAM_TWO_COLOR)


func _finish(message: String, color: Color) -> void:
	if _game_over:
		return
	_game_over = true
	_time_left = maxf(0.0, _time_left)
	_show_time()
	for player in PLAYER_COUNT:
		_pullers[player].pause()
		_pullers[player].animation = &"pull"
		_pullers[player].frame = REST_FRAME
		_keys_held[player] = false
		_indicator_until[player] = 0.0
		_set_indicator(player, false)
	var winning_team := -1
	if color == TEAM_ONE_COLOR:
		winning_team = 0
	elif color == TEAM_TWO_COLOR:
		winning_team = 1
	_round_scores.assign(ScoreEngine.tug_round_scores(winning_team, cross_team_pairs))
	_result_prompt.show_result(message, color, GameSchedule.tug_round)


func _show_results() -> void:
	if _results_started:
		return
	_results_started = true
	ScoreKeeper.add_round_scores(_round_scores, &"tug_of_war", GameSchedule.tug_round > 1)
	if GameSchedule.advance_tug_round():
		await SceneFader.change_scene("res://games/Tug Of war/tug_ofwar.tscn")
	else:
		await SceneFader.change_scene(ROUND_RESULTS_SCENE)


func _show_round_intro() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.06, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", GAME_FONT)
	label.add_theme_font_size_override("font_size", 108)
	label.add_theme_color_override("font_color", Color("fbc052"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 12)
	label.text = ""
	label.modulate.a = 0.0
	label.scale = Vector2.ONE * 0.8
	label.pivot_offset = DESIGN_SIZE * 0.5
	shade.add_child(label)
	var reveal := create_tween()
	for text in ["GET READY...", "ROUND %d" % GameSchedule.tug_round, "3", "2", "1", "START!"]:
		reveal.tween_callback(func() -> void:
			label.text = text
			label.modulate.a = 0.0
			label.scale = Vector2.ONE * 0.8
		)
		reveal.set_parallel(true)
		reveal.tween_property(label, "modulate:a", 1.0, 0.2)
		reveal.tween_property(label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.set_parallel(false)
		reveal.tween_interval(0.75 if text in ["3", "2", "1", "START!"] else 1.15)
		reveal.tween_property(label, "modulate:a", 0.0, 0.16)
	reveal.tween_callback(func() -> void: _round_intro_active = false; overlay.queue_free())


func _setup_indicators() -> void:
	for player in PLAYER_COUNT:
		_indicators[player].texture = INDICATOR_TEXTURES[player]
		_indicator_down[player] = false
		_key_labels[player].text = _key_hint(PLAYER_ACTIONS[player])
		var indicator_x := CROSS_TEAM_INDICATOR_X[player] if cross_team_pairs else INDICATOR_X[player]
		_key_labels[player].position = Vector2(indicator_x - 82.0, 902.0)
		_key_labels[player].size = Vector2(164.0, 36.0)
		_place_indicator(player)


func _key_hint(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			# The literal key is clearer than the OS name "Semicolon" on the small badge.
			return ";" if key == KEY_SEMICOLON else OS.get_keycode_string(key)
	return ""


func _refresh_indicator(player: int, now: float) -> void:
	_set_indicator(player, not _game_over and (_keys_held[player] or now < _indicator_until[player]))


func _set_indicator(player: int, down: bool) -> void:
	if _indicator_down[player] == down:
		return
	_indicator_down[player] = down
	_indicators[player].texture = INDICATOR_PRESSED_TEXTURES[player] if down else INDICATOR_TEXTURES[player]
	_key_labels[player].add_theme_color_override("font_color", Color.WHITE if down else Color("fbc052"))
	_place_indicator(player)


func _layout_arena() -> void:
	var view_size := get_viewport_rect().size
	_layout_scale = minf(view_size.x / DESIGN_SIZE.x, view_size.y / DESIGN_SIZE.y)
	_layout_origin = (view_size - DESIGN_SIZE * _layout_scale) * 0.5
	_camera.position = view_size * 0.5
	_background.position = view_size * 0.5
	_frame_overlay.position = view_size * 0.5
	_frame_overlay.scale = Vector2.ONE * _layout_scale
	var background_scale := maxf(view_size.x / DESIGN_SIZE.x, view_size.y / DESIGN_SIZE.y)
	_background.scale = Vector2.ONE * background_scale
	_world.scale = Vector2.ONE * _layout_scale
	_hud_layout.position = _layout_origin
	_hud_layout.scale = Vector2.ONE * _layout_scale
	_update_world(0.0)


func _place_indicator(player: int) -> void:
	var indicator := _indicators[player]
	var texture := indicator.texture
	if texture == null:
		return
	var indicator_size := texture.get_size() * INDICATOR_SCALE
	indicator.size = indicator_size
	var indicator_x := CROSS_TEAM_INDICATOR_X[player] if cross_team_pairs else INDICATOR_X[player]
	indicator.position = Vector2(indicator_x - indicator_size.x * 0.5, INDICATOR_BOTTOM - indicator_size.y)


func _update_meter(snap := false) -> void:
	var win_distance := _win_distance()
	var value := 0.5
	if win_distance > 0.0:
		value = 0.5 + _rope_pos / (2.0 * win_distance)
	_meter.set_progress(value, snap)


func _update_world(delta: float) -> void:
	var target := (_rope_pos / _win_distance()) * ROPE_TRAVEL
	_rope_visual_offset = lerpf(_rope_visual_offset, target, 1.0 - exp(-PULL_SMOOTHING * delta))
	_world.position = _layout_origin + Vector2(_rope_visual_offset * _layout_scale, 0.0)


func _show_time() -> void:
	var seconds := ceili(_time_left)
	if seconds == _shown_seconds:
		return
	_shown_seconds = seconds
	var minutes := floori(seconds / 60.0)
	_meter.set_time_text("%02d:%02d" % [minutes, seconds % 60], seconds <= 10)


func _win_distance() -> float:
	return DESIGN_SIZE.x * win_distance_ratio


func _is_team_one(player: int) -> bool:
	return (player == 0 or player == 2) if cross_team_pairs else player < 2


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
