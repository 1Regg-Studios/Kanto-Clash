extends Control

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


func play(scores: Array) -> void:
	_stop_tweens()
	_scores = _to_scores(scores)

	var starting_order := _players_by_score(true)
	_place_rows(starting_order)
	var starting_slot := _slots_for(starting_order)

	_remaining = ROW_COUNT
	for i in range(ROW_COUNT):
		_count_up_row(i, starting_slot[i])


func set_scores(scores: Array) -> void:
	_stop_tweens()
	_scores = _to_scores(scores)
	for i in range(ROW_COUNT):
		_set_label_value(float(_scores[i]), _score_labels[i])
	_place_rows(_players_by_score(false))


func _count_up_row(index: int, starting_slot: int) -> void:
	var label := _score_labels[index]
	label.text = "0"
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tweens.append(tween)
	tween.tween_interval(starting_slot * ROW_STAGGER)
	tween.tween_method(_set_label_value.bind(label), 0.0, float(_scores[index]), COUNT_TIME)
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
	if _remaining <= 0:
		sort_finished.emit()


func _players_by_score(ascending: bool) -> Array[int]:
	var order: Array[int] = []
	for i in range(ROW_COUNT):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if _scores[a] == _scores[b]:
			return a < b
		if ascending:
			return _scores[a] < _scores[b]
		return _scores[a] > _scores[b]
	)
	return order


func _place_rows(order: Array[int]) -> void:
	for slot in range(ROW_COUNT):
		_rows[order[slot]].position.y = _row_slots[slot]


func _slots_for(order: Array[int]) -> Array[int]:
	var slots: Array[int] = []
	slots.resize(ROW_COUNT)
	for slot in range(ROW_COUNT):
		slots[order[slot]] = slot
	return slots


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
