extends Control

class_name Leaderboard

signal count_finished
signal sort_finished

const ROW_COUNT := 4
const COUNT_TIME := 1.0
const ROW_STAGGER := 0.15
const SORT_DELAY := 0.4
const SORT_TIME := 0.6
const SORT_STAGGER := 0.05

@onready var _rows: Array[Control] = [
	$Board/Row1,
	$Board/Row2,
	$Board/Row3,
	$Board/Row4,
]

@onready var _score_labels: Array[Label] = [
	$Board/Row1/Score,
	$Board/Row2/Score,
	$Board/Row3/Score,
	$Board/Row4/Score,
]

var _row_slots: Array[float] = []
var _scores: Array[int] = [0, 0, 0, 0]
var _tweens: Array[Tween] = []
var _remaining := 0


func _ready() -> void:
	for row in _rows:
		_row_slots.append(row.position.y)


func play(scores: Array, starting_scores: Array = []) -> void:
	_stop_tweens()
	_scores = _to_scores(scores)
	AudioManager.play_score()

	var previous_scores := _to_scores(starting_scores)
	var starting_order := _players_by_score(true)
	if not starting_scores.is_empty():
		starting_order = _players_by_score(false, previous_scores)
	_place_rows(starting_order)

	_remaining = ROW_COUNT
	for slot in range(ROW_COUNT):
		var player := starting_order[slot]
		_count_up_row(player, slot, previous_scores[player])


func _count_up_row(index: int, starting_slot: int, starting_score: int) -> void:
	var label := _score_labels[index]
	_set_label_value(float(starting_score), label)
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tweens.append(tween)
	tween.tween_interval(starting_slot * ROW_STAGGER)
	tween.tween_method(_set_label_value.bind(label), float(starting_score), float(_scores[index]), COUNT_TIME)
	tween.finished.connect(_on_row_finished)


func _on_row_finished() -> void:
	_remaining -= 1
	if _remaining > 0:
		return
	count_finished.emit()
	_sort_rows()


func _sort_rows() -> void:
	var final_order := _players_by_score(false)
	_remaining = ROW_COUNT
	for slot in range(ROW_COUNT):
		_move_row_to_slot(final_order[slot], slot)


func _move_row_to_slot(row_index: int, slot: int) -> void:
	var row := _rows[row_index]
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tweens.append(tween)
	tween.tween_interval(SORT_DELAY + slot * SORT_STAGGER)
	tween.tween_property(row, "position:y", _row_slots[slot], SORT_TIME)
	tween.finished.connect(_on_sort_row_finished)


func _on_sort_row_finished() -> void:
	_remaining -= 1
	if _remaining > 0:
		return
	sort_finished.emit()
	_on_sorted()


func _on_sorted() -> void:
	pass


func _players_by_score(ascending: bool, scores: Array[int] = []) -> Array[int]:
	var values := _scores if scores.is_empty() else scores
	var order: Array[int] = []
	for i in range(ROW_COUNT):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if values[a] == values[b]:
			return a < b
		if ascending:
			return values[a] < values[b]
		return values[a] > values[b]
	)
	return order


func _place_rows(order: Array[int]) -> void:
	for slot in range(ROW_COUNT):
		_rows[order[slot]].position.y = _row_slots[slot]


func _to_scores(scores: Array) -> Array[int]:
	var values: Array[int] = []
	for i in range(ROW_COUNT):
		if i < scores.size():
			values.append(int(scores[i]))
		else:
			values.append(0)
	return values


func _set_label_value(value: float, label: Label) -> void:
	label.text = str(roundi(value))


func _stop_tweens() -> void:
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	_remaining = 0
