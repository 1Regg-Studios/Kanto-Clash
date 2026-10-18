extends Node

signal totals_changed(totals: Array[int])

const PLAYER_COUNT := 4

var totals: Array[int] = [0, 0, 0, 0]


func add_round_scores(round_scores: Array) -> Array[int]:
	for i in mini(round_scores.size(), PLAYER_COUNT):
		totals[i] += int(round_scores[i])
	totals_changed.emit(totals)
	return totals


func reset() -> void:
	totals = [0, 0, 0, 0]
	totals_changed.emit(totals)
