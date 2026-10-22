extends Node2D

signal round_started(round_number: int)

const ROUND_COUNT := 2
const COUNTDOWN_STEP_SECONDS := 0.7
const ROUND_END_SECONDS := 2.0
const ROUND_RESULTS_SCENE := "res://src/UI/roundleaderboard/roundleaderboard.tscn"
const MAIN_MUSIC := preload("res://assets/Music/Main/Patintero/tatamusic-game-gaming-music-557995.mp3")
const ZONE_IDS: Array[StringName] = [&"zone_1", &"zone_2", &"zone_3", &"fn"]
# Runners earn a zone award after clearing its guard line.
const ZONE_CROSSING_XS: Array[float] = [316.0, 582.0, 855.0, 1024.0]
const FINISH_PLACE_LABELS: Array[String] = ["1ST", "2ND", "3RD", "4TH"]

# Keep consecutive games varied as well as the two rounds within a game.
static var _last_spawn_order: Array[int] = []

@onready var _players: Array[CharacterBody2D] = [
	$Player,
	$Player2,
	$Player3,
	$Player4,
]
@onready var _guards: Array[Node2D] = [
	$Platform,
	$Platform2,
	$Platform4,
	$Platform5,
	$Platform7,
	$Platform8,
	$Platform3,
	$Platform6,
]
@onready var _timer: Node = $HUD/Root/Timer
@onready var _score_label: Label = $HUD/Root/Scores
@onready var _round_label: Label = $HUD/Root/Round
@onready var _round_notice: ColorRect = $HUD/Root/RoundNotice
@onready var _notice_title: Label = $HUD/Root/RoundNotice/Title
@onready var _notice_detail: Label = $HUD/Root/RoundNotice/Detail

var _round_number := 1
var _round_scores: Array[int] = [0, 0, 0, 0]
var _game_scores: Array[int] = [0, 0, 0, 0]
var _round_score_totals: Array[int] = [0, 0, 0, 0]
var _next_zone_by_player: Array[int] = [0, 0, 0, 0]
var _finish_order: Array[int] = []
var _previous_player_xs: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _round_finished := false
var _round_intro_active := true
var _spawn_positions: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	# Judge crossings after every runner has moved in the same physics tick.
	process_physics_priority = 1
	for player in _players:
		_spawn_positions.append(player.position)
	_timer.connect("time_expired", _on_round_timeout)
	_start_main_music()
	_start_round()


func _start_main_music() -> void:
	AudioManager.stop_menu_music()
	AudioManager.play_game_music(MAIN_MUSIC)


func _start_round() -> void:
	_round_finished = false
	_round_intro_active = true
	_timer.stop_round()
	_set_court_active(false)
	_round_scores.fill(0)
	_next_zone_by_player.fill(0)
	_finish_order.clear()
	for guard in _guards:
		guard.reset_for_round()
	_randomize_player_positions()
	_round_label.text = "ROUND %d / %d" % [_round_number, ROUND_COUNT]
	_update_score_label()
	_round_notice.show()
	_notice_title.text = _round_label.text
	for countdown in [3, 2, 1]:
		_notice_detail.text = "FIND YOUR PLAYER!\nP1 [A]     P2 [F]     P3 [J]     P4 [;]\nSTARTING IN %d..." % countdown
		await get_tree().create_timer(COUNTDOWN_STEP_SECONDS, false).timeout
	_round_notice.hide()
	_round_intro_active = false
	_set_court_active(true)
	_timer.start_round()
	round_started.emit(_round_number)


func _randomize_player_positions() -> void:
	var order: Array[int] = [0, 1, 2, 3]
	var repeats_position := true
	while repeats_position:
		# A separate random stream keeps lane assignments independent of effects
		# and guard patrol decisions. Every runner keeps their own ID and key.
		for index in range(order.size() - 1, 0, -1):
			var other := _rng.randi_range(0, index)
			var slot := order[index]
			order[index] = order[other]
			order[other] = slot
		repeats_position = false
		for player_index in _last_spawn_order.size():
			if order[player_index] == _last_spawn_order[player_index]:
				repeats_position = true
				break
	_last_spawn_order = order.duplicate()
	for player_index in _players.size():
		_players[player_index].reset_for_round(_spawn_positions[order[player_index]])
		_previous_player_xs[player_index] = to_local(_players[player_index].global_position).x


func _set_court_active(active: bool) -> void:
	for player in _players:
		player.set_round_active(active)
	for guard in _guards:
		guard.set_physics_process(active)


func _physics_process(_delta: float) -> void:
	if _round_finished or _round_intro_active:
		return
	var new_finishers: Array[int] = []
	var finish_fractions: Dictionary[int, float] = {}
	var progress_changed := false
	for player_index in _players.size():
		var player := _players[player_index]
		if not is_instance_valid(player) or _next_zone_by_player[player_index] == ZONE_IDS.size():
			continue
		var player_x := to_local(player.global_position).x
		while _next_zone_by_player[player_index] < ZONE_IDS.size():
			var zone_index: int = _next_zone_by_player[player_index]
			if player_x < ZONE_CROSSING_XS[zone_index]:
				break
			var points := ScoreEngine.patintero_zone_score(ZONE_IDS[zone_index])
			_round_scores[player_index] = mini(
				_round_scores[player_index] + points, ScoreEngine.PATINTERO_BASE_SCORE_CAP
			)
			_next_zone_by_player[player_index] += 1
			progress_changed = true
		if _next_zone_by_player[player_index] == ZONE_IDS.size():
			new_finishers.append(player_index)
			var previous_x := _previous_player_xs[player_index]
			var distance := player_x - previous_x
			finish_fractions[player_index] = clampf((ZONE_CROSSING_XS[-1] - previous_x) / distance, 0.0, 1.0) if distance > 0.0 else 0.0
		_previous_player_xs[player_index] = player_x
	# Estimate the crossing instant inside this tick so same-tick finishes are
	# ordered by arrival rather than scene order. Exact ties use the player ID.
	new_finishers.sort_custom(func(a: int, b: int) -> bool:
		return a < b if finish_fractions[a] == finish_fractions[b] else finish_fractions[a] < finish_fractions[b]
	)
	for player_index in new_finishers:
		_finish_order.append(player_index)
		var finish_place := _finish_order.size()
		_players[player_index].finish_run(finish_place, ScoreEngine.patintero_finish_multiplier(finish_place))
	if progress_changed:
		_update_score_label()
	if _finish_order.size() == _players.size():
		_finish_round()


func _on_round_timeout() -> void:
	_finish_round()


func _finish_round() -> void:
	if _round_finished or _round_intro_active:
		return
	_round_finished = true
	_timer.stop_round()
	_set_court_active(false)
	for player_index in _players.size():
		var finish_place := _finish_order.find(player_index) + 1
		_round_score_totals[player_index] += ScoreEngine.patintero_round_score(_round_scores[player_index], finish_place)
		# Average both placement-adjusted rounds, rounding up before ScoreKeeper
		# applies the leaderboard's x10 conversion. Do not truncate each round.
		_game_scores[player_index] = ScoreEngine.clamp_score(
			&"patintero", ceili(_round_score_totals[player_index] / float(ROUND_COUNT))
		)
	_round_notice.show()
	_notice_title.text = "ROUND %d COMPLETE" % _round_number
	_notice_detail.text = _round_results_text()
	await get_tree().create_timer(ROUND_END_SECONDS, false).timeout
	if _round_number < ROUND_COUNT:
		_round_number += 1
		_start_round()
	else:
		ScoreKeeper.add_round_scores(_game_scores, &"patintero")
		await SceneFader.change_scene(ROUND_RESULTS_SCENE)


func _round_results_text() -> String:
	var finishers: Array[String] = []
	for place_index in _finish_order.size():
		finishers.append("%s: P%d (x%.1f)" % [
			FINISH_PLACE_LABELS[place_index],
			_finish_order[place_index] + 1,
			ScoreEngine.patintero_finish_multiplier(place_index + 1),
		])
	var lines: Array[String] = []
	for line_start in range(0, finishers.size(), 2):
		lines.append("    ".join(finishers.slice(line_start, line_start + 2)))
	var unfinished: Array[String] = []
	for player_index in _players.size():
		if not _finish_order.has(player_index):
			unfinished.append("P%d" % (player_index + 1))
	if not unfinished.is_empty():
		lines.append("UNFINISHED: %s (x1.0)" % ", ".join(unfinished))
	lines.append("RESHUFFLING POSITIONS FOR ROUND 2..." if _round_number < ROUND_COUNT else "OPENING GAME LEADERBOARD...")
	return "\n".join(lines)


func _update_score_label() -> void:
	_score_label.text = "   |   ".join([
		"P1 %d" % _round_scores[0],
		"P2 %d" % _round_scores[1],
		"P3 %d" % _round_scores[2],
		"P4 %d" % _round_scores[3],
	])
