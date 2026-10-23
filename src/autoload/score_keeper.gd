extends Node

signal totals_changed(totals: Array[int])

const PLAYER_COUNT := 4
const CHINESE_GARTER_SCORE_MULTIPLIER := 3
const TUMBANG_PRESO_SCORE_MULTIPLIER := 2
const OVERALL_SCORE_MULTIPLIER := 10

var totals: Array[int] = [0, 0, 0, 0]
var last_round_scores: Array[int] = [0, 0, 0, 0]
var last_round_starting_totals: Array[int] = [0, 0, 0, 0]

var _last_game_id: StringName = &""
var _recorded_rounds: Array[int] = []


func add_round_scores(round_scores: Array, game_id: StringName, append_to_game := false, round_number := 0) -> Array[int]:
	var continuing_game := append_to_game and game_id == _last_game_id
	if continuing_game and round_number > 0 and _recorded_rounds.has(round_number):
		return totals
	if not continuing_game:
		last_round_starting_totals = totals.duplicate()
		_recorded_rounds.clear()

	var game_scores: Array[int] = []
	var updated_totals: Array[int] = []
	for i in PLAYER_COUNT:
		var score := int(round_scores[i]) if i < round_scores.size() else 0
		score = ScoreEngine.clamp_score(game_id, score)
		var previous := last_round_scores[i] if continuing_game else 0
		game_scores.append(ScoreEngine.clamp_score(game_id, previous + score))
		# Anchor the complete award to the totals before this minigame, converting
		# its score units once even when internal rounds reload the scene.
		updated_totals.append(last_round_starting_totals[i] + _leaderboard_points(game_scores[i], game_id))

	last_round_scores = game_scores
	totals = updated_totals
	_last_game_id = game_id
	if round_number > 0:
		_recorded_rounds.append(round_number)
	totals_changed.emit(totals)
	return totals


func last_round_points() -> Array[int]:
	var points: Array[int] = []
	for score in last_round_scores:
		points.append(_leaderboard_points(score, _last_game_id))
	return points


func _leaderboard_points(score: int, game_id: StringName) -> int:
	# Tug stores its final point values directly to avoid fractional base scores.
	if game_id == &"tug_of_war":
		return score
	if game_id == &"tumbang_preso":
		return score * TUMBANG_PRESO_SCORE_MULTIPLIER
	if game_id == &"chinese_garter":
		score *= CHINESE_GARTER_SCORE_MULTIPLIER
	return score * OVERALL_SCORE_MULTIPLIER


func reset() -> void:
	totals = [0, 0, 0, 0]
	last_round_scores = [0, 0, 0, 0]
	last_round_starting_totals = [0, 0, 0, 0]
	_last_game_id = &""
	_recorded_rounds.clear()
	totals_changed.emit(totals)
