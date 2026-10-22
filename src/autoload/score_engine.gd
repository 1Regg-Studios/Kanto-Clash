extends Node

const MAX_GAME_SCORE := 100
const PATINTERO_BASE_SCORE_CAP := MAX_GAME_SCORE
const PATINTERO_SCORE_CAP := PATINTERO_BASE_SCORE_CAP * 2
const PATINTERO_FINISH_MULTIPLIER_TENTHS: Array[int] = [20, 18, 16, 14]
const TUG_ROUND_WIN_SCORE := 50
const TUG_ROUND_DRAW_SCORE := 25

const GAME_SCORE_CAPS: Dictionary = {
	&"patintero": PATINTERO_SCORE_CAP,
	&"tug_of_war": MAX_GAME_SCORE,
	&"chinese_garter": MAX_GAME_SCORE,
	&"sipa": MAX_GAME_SCORE,
	&"tumbang_preso": MAX_GAME_SCORE,
}

const PATINTERO_ZONE_POINTS: Dictionary = {
	&"zone_1": 10,
	&"zone_2": 20,
	&"zone_3": 30,
	&"fn": 40,
}


func score_cap(game_id: StringName) -> int:
	return int(GAME_SCORE_CAPS.get(game_id, MAX_GAME_SCORE))


func award_points(game_id: StringName, current_score: int, points: int) -> int:
	return clamp_score(game_id, current_score + maxi(points, 0))


func clamp_score(game_id: StringName, score: int) -> int:
	return clampi(score, 0, score_cap(game_id))


func patintero_zone_score(zone_id: StringName) -> int:
	return int(PATINTERO_ZONE_POINTS.get(zone_id, 0))


func patintero_finish_multiplier(finish_place: int) -> float:
	return _patintero_multiplier_tenths(finish_place) / 10.0


func patintero_round_score(base_score: int, finish_place: int) -> int:
	# Integer tenths keep exact whole-number bonuses from rounding up an extra point.
	var score_tenths := clampi(base_score, 0, PATINTERO_BASE_SCORE_CAP) * _patintero_multiplier_tenths(finish_place)
	return ceili(score_tenths / 10.0)


func _patintero_multiplier_tenths(finish_place: int) -> int:
	if finish_place >= 1 and finish_place <= PATINTERO_FINISH_MULTIPLIER_TENTHS.size():
		return PATINTERO_FINISH_MULTIPLIER_TENTHS[finish_place - 1]
	# Players who have not crossed the finish line keep their zone points at x1.
	return 10


func tug_round_scores(winner_team: int, cross_team_pairs: bool) -> Array[int]:
	var scores: Array[int] = [0, 0, 0, 0]
	if winner_team == -1:
		scores.fill(TUG_ROUND_DRAW_SCORE)
		return scores
	if winner_team < 0 or winner_team > 1:
		push_error("Tug of War winner_team must be -1 (draw), 0, or 1")
		return scores

	var team_one: Array[int] = [0, 1]
	var team_two: Array[int] = [2, 3]
	if cross_team_pairs:
		team_one = [0, 2]
		team_two = [1, 3]
	var winners: Array[int] = []
	if winner_team == 0:
		winners = team_one
	else:
		winners = team_two
	for player_index in winners:
		scores[player_index] = TUG_ROUND_WIN_SCORE
	return scores
