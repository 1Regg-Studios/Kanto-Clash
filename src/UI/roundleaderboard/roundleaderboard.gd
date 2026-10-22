extends Leaderboard

const LOADING_SCREEN := "res://src/UI/ldscrn/ldscrn.tscn"
const OVERALL_RESULTS_SCENE := "res://src/UI/overallleaderboard/overall_leaderboard.tscn"
const RESULTS_HOLD_SECONDS := 3

@onready var _continue_label: Label = $Continue

var _continuing := false


func _ready() -> void:
	super._ready()
	var game_points := ScoreKeeper.last_round_points()
	var previous_totals: Array[int] = []
	for player in range(ROW_COUNT):
		previous_totals.append(ScoreKeeper.totals[player] - game_points[player])
	play(ScoreKeeper.totals, previous_totals)


func set_scores(scores: Array) -> void:
	_stop_tweens()
	_scores = _to_scores(scores)
	for i in range(ROW_COUNT):
		_set_label_value(float(_scores[i]), _score_labels[i])
	_place_rows(_players_by_score(false))


func _on_sorted() -> void:
	if _continuing:
		return
	_continuing = true
	AudioManager.stop_game_music()

	var next_id := GameSchedule.next_game_id()
	var destination := "OVERALL RESULTS" if next_id.is_empty() else "NEXT: %s" % GameSchedule.name_of(next_id).to_upper()
	for seconds in range(RESULTS_HOLD_SECONDS, 0, -1):
		_continue_label.text = "%s IN %d..." % [destination, seconds]
		await get_tree().create_timer(1.0, false).timeout
	if GameSchedule.advance_game():
		await SceneFader.change_scene(LOADING_SCREEN)
	else:
		await SceneFader.change_scene(OVERALL_RESULTS_SCENE)
