extends Control

const LOADING_SCREEN := "res://src/UI/ldscrn/ldscrn.tscn"

const ICON_SIZE := 224
const REEL_COPIES := 4
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


class ReelState:
	enum Phase { SPINNING, ARMED, BRAKING, LANDED }

	var phase := Phase.SPINNING
	var target_index := 0
	var armed_ready := false
	var speed := 0.0
	var decel := 0.0
	var target_y := 0.0


@onready var _reels: Array[Control] = [
	$Slots/Slot1/Reel,
	$Slots/Slot2/Reel,
	$Slots/Slot3/Reel,
	$Slots/Slot4/Reel,
]

var _icons: Array[Texture2D] = []
var _states: Array[ReelState] = []
var _spin_speed := 0.0
var _spin_started := false
var _landed := 0
var _transitioning := false


func _ready() -> void:
	_icons = GameSchedule.load_icons()
	if _icons.is_empty():
		return
	for i in _reels.size():
		_states.append(ReelState.new())
	for reel in _reels:
		_build_reel(reel)
		reel.modulate = NOT_READY_MODULATE
		reel.position.y = -float(randi_range(0, _icons.size() - 1) * ICON_SIZE)
	_start_spin()


func _process(delta: float) -> void:
	if not _spin_started:
		return
	_spin_speed = minf(_spin_speed + SPIN_ACCEL * delta, SPIN_SPEED)
	var sequence_px := float(ICON_SIZE * _icons.size())
	for i in _reels.size():
		match _states[i].phase:
			ReelState.Phase.SPINNING:
				_spin_reel(i, sequence_px, delta)
			ReelState.Phase.ARMED:
				_spin_reel(i, sequence_px, delta)
				_update_armed(i)
			ReelState.Phase.BRAKING:
				_brake_reel(i, delta)


func _start_spin() -> void:
	await get_tree().create_timer(SPIN_START_DELAY).timeout
	if _transitioning:
		return
	_spin_started = true
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
		_arm_slot(slot, GameSchedule.index_of(picked[slot]))
		while _states[slot].phase != ReelState.Phase.LANDED:
			await get_tree().process_frame
		if slot < _reels.size() - 1:
			await get_tree().create_timer(LAND_GAP).timeout


func _arm_slot(slot: int, target_index: int) -> void:
	var state := _states[slot]
	state.target_index = target_index
	state.armed_ready = _brake_distance(slot) > _brake_trigger()
	state.phase = ReelState.Phase.ARMED


func _spin_reel(slot: int, sequence_px: float, delta: float) -> void:
	var reel := _reels[slot]
	reel.position.y -= _spin_speed * delta
	if reel.position.y <= -sequence_px:
		reel.position.y += sequence_px


func _update_armed(slot: int) -> void:
	var state := _states[slot]
	var travel := _brake_distance(slot)
	if travel > _brake_trigger():
		state.armed_ready = true
		return
	if state.armed_ready:
		_start_braking(slot, travel)


func _start_braking(slot: int, travel: float) -> void:
	var state := _states[slot]
	state.phase = ReelState.Phase.BRAKING
	state.speed = _spin_speed
	state.decel = _spin_speed * _spin_speed / maxf(2.0 * travel, 1.0)
	state.target_y = _reels[slot].position.y - travel


func _brake_reel(slot: int, delta: float) -> void:
	var state := _states[slot]
	var reel := _reels[slot]
	reel.position.y -= state.speed * delta
	state.speed = maxf(state.speed - state.decel * delta, 0.0)
	if reel.position.y <= state.target_y:
		reel.position.y = state.target_y
		state.phase = ReelState.Phase.LANDED
		_on_slot_landed(slot)


func _brake_distance(slot: int) -> float:
	var y_final := -float(_states[slot].target_index * ICON_SIZE)
	return fposmod(_reels[slot].position.y - y_final, float(ICON_SIZE * _icons.size()))


func _brake_trigger() -> float:
	return minf(LAND_DISTANCE, float(ICON_SIZE * _icons.size()) * 0.8)


func _on_slot_landed(slot: int) -> void:
	create_tween().tween_property(_reels[slot], "modulate", READY_MODULATE, TOGGLE_TIME)
	_landed += 1
	if _landed == _reels.size():
		_finish()


func _finish() -> void:
	_transitioning = true
	await get_tree().create_timer(HOLD_TIME).timeout
	GameSchedule.next_scene_path = GameSchedule.first_scene_path()
	await SceneFader.change_scene(LOADING_SCREEN)
