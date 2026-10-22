extends Node

signal totals_changed(totals: Array[int])

const PLAYER_COUNT := 4
const OVERALL_SCORE_MULTIPLIER := 10

var totals: Array[int] = [0, 0, 0, 0]
var last_round_scores: Array[int] = [0, 0, 0, 0]


func add_round_scores(round_scores: Array, game_id: StringName, append_to_game := false) -> Array[int]:
	for i in PLAYER_COUNT:
		var score := int(round_scores[i]) if i < round_scores.size() else 0
		score = ScoreEngine.clamp_score(game_id, score)
		# Multi-round games can reload their scene without losing the first
		# round's result or crediting its points a second time.
		var previous := last_round_scores[i] if append_to_game else 0
		last_round_scores[i] = ScoreEngine.clamp_score(game_id, previous + score)
		totals[i] += (last_round_scores[i] - previous) * OVERALL_SCORE_MULTIPLIER
	totals_changed.emit(totals)
	return totals


func last_round_points() -> Array[int]:
	var points: Array[int] = []
	for score in last_round_scores:
		points.append(score * OVERALL_SCORE_MULTIPLIER)
	return points


func reset() -> void:
	totals = [0, 0, 0, 0]
	last_round_scores = [0, 0, 0, 0]
	totals_changed.emit(totals)
