extends Control

const LOADING_SCREEN := "res://src/UI/ldscrn/ldscrn.tscn"

const ICON_SIZE := 224
# Free spin stays within one sequence; braking travels less than one more.
const REEL_COPIES := 2
const SPIN_SPEED := 1900.0
const SPIN_RAMP_TIME := 0.4
const SPIN_ACCEL := SPIN_SPEED / SPIN_RAMP_TIME

const SPIN_START_DELAY := 1.0
const LAND_START_DELAY := 2.0
const LAND_BRAKE_TIME := 0.8
const LAND_DISTANCE := SPIN_SPEED * LAND_BRAKE_TIME * 0.5
const LAND_GAP := 0.25
const HOLD_TIME := 5.0

const READY_MODULATE := Color(1, 1, 1)
const NOT_READY_MODULATE := Color(0.6, 0.48, 0.5)
const TOGGLE_TIME := 0.15


@onready var _reels: Array[Control] = [
	$Slots/Slot1/Reel,
	$Slots/Slot2/Reel,
	$Slots/Slot3/Reel,
	$Slots/Slot4/Reel,
]

var _icons: Array[Texture2D] = []
var _sequence := 0.0
var _spinning: Array[bool] = [true, true, true, true]
var _spin_speed := 0.0
var _landed := 0
var _transitioning := false


func _ready() -> void:
	set_process(false)
	AudioManager.start_menu_music()
	_icons = GameSchedule.load_icons()
	if _icons.is_empty():
		return
	_sequence = float(ICON_SIZE * _icons.size())
	for reel in _reels:
		_build_reel(reel)
		reel.modulate = NOT_READY_MODULATE
		reel.position.y = -float(randi_range(0, _icons.size() - 1) * ICON_SIZE)
	_start_spin()


func _process(delta: float) -> void:
	_spin_speed = minf(_spin_speed + SPIN_ACCEL * delta, SPIN_SPEED)
	for i in _reels.size():
		if _spinning[i]:
			_spin_reel(i, delta)


func _start_spin() -> void:
	await get_tree().create_timer(SPIN_START_DELAY).timeout
	if _transitioning:
		return
	set_process(true)
	_roll()


func _build_reel(reel: Control) -> void:
	for copy in REEL_COPIES:
		for i in _icons.size():
			var tile := TextureRect.new()
			tile.texture = _icons[i]
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tile.position = Vector2(0.0, float((copy * _icons.size() + i) * ICON_SIZE))
			tile.size = Vector2(ICON_SIZE, ICON_SIZE)
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			reel.add_child(tile)


func _roll() -> void:
	var picked := GameSchedule.roll()
	await get_tree().create_timer(LAND_START_DELAY).timeout
	for slot in _reels.size():
		if _transitioning:
			return
		await _land_slot(slot, GameSchedule.index_of(picked[slot]))
		if slot < _reels.size() - 1:
			await get_tree().create_timer(LAND_GAP).timeout


func _spin_reel(slot: int, delta: float) -> void:
	var reel := _reels[slot]
	reel.position.y -= _spin_speed * delta
	if reel.position.y <= -_sequence:
		# Normalize even when a slow frame crosses more than one full sequence.
		reel.position.y = -fposmod(-reel.position.y, _sequence)


func _land_slot(slot: int, target_index: int) -> void:
	var reel := _reels[slot]
	var target_y := -float(target_index * ICON_SIZE)
	var until_brake := fposmod(fposmod(reel.position.y - target_y, _sequence) - LAND_DISTANCE, _sequence)
	await get_tree().create_timer(until_brake / SPIN_SPEED).timeout
	_spinning[slot] = false
	var travel := fposmod(reel.position.y - target_y, _sequence)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(reel, "position:y", reel.position.y - travel, 2.0 * travel / SPIN_SPEED)
	await tween.finished
	_on_slot_landed(slot)


func _on_slot_landed(slot: int) -> void:
	AudioManager.play_pick()
	create_tween().tween_property(_reels[slot], "modulate", READY_MODULATE, TOGGLE_TIME)
	_landed += 1
	if _landed == _reels.size():
		_finish()


func _finish() -> void:
	_transitioning = true
	set_process(false)
	await get_tree().create_timer(HOLD_TIME).timeout
	GameSchedule.next_scene_path = GameSchedule.first_scene_path()
	await SceneFader.change_scene(LOADING_SCREEN)
