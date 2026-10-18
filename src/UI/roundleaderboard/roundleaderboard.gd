extends Leaderboard


func set_scores(scores: Array) -> void:
	_stop_tweens()
	_scores = _to_scores(scores)
	for i in range(ROW_COUNT):
		_set_label_value(float(_scores[i]), _score_labels[i])
	_place_rows(_players_by_score(false))
