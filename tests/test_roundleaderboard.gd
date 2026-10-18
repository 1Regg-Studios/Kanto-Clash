extends Control

const PLACEHOLDER_SCORES: Array[int] = [250, 100, 300, 150]
const SLOT_YS: Array[float] = [125.0, 236.0, 347.0, 458.0]
const EXPECTED_ROWS: Array[int] = [2, 0, 3, 1]

@onready var _board: Control = $Leaderboard


func _ready() -> void:
	print("[test] placeholder scores: ", PLACEHOLDER_SCORES)
	_board.count_finished.connect(func() -> void: print("[test] count-up finished"))
	_board.sort_finished.connect(_on_sort_finished)
	_board.play(PLACEHOLDER_SCORES)


func _on_sort_finished() -> void:
	print("[test] sort finished")
	await get_tree().create_timer(0.5).timeout
	var ok := true
	for slot in range(4):
		var row_name := "Row%d" % (EXPECTED_ROWS[slot] + 1)
		var row: Control = _board.get_node("Board/" + row_name)
		if not is_equal_approx(row.position.y, SLOT_YS[slot]):
			ok = false
			printerr("[test] %s expected y=%.0f, got y=%.0f" % [row_name, SLOT_YS[slot], row.position.y])
	print("[test] %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
