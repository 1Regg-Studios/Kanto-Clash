extends Control

const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const TIMER_POSITION := Vector2(815.0, 14.0)
const ROUND_POSITION := Vector2(740.0, 111.0)
const INDICATOR_POSITION := Vector2(104.0, 144.0)
# Match Tug of War's badge size, key hints, and minimum tap feedback.
const INDICATOR_SCALE := 1.12
const INDICATOR_SPACING := 216.0
const INDICATOR_HOLD := 0.12
const PLAYER_ACTIONS: Array[StringName] = [
	&"P1_Ready", &"P2_Ready", &"P3_Ready", &"P4_Ready",
]
const INDICATOR_TEXTURES: Array[Texture2D] = [
	preload("res://games/Patintero/UI/Player Press Indicator/Not Pressed/P1.png"),
	preload("res://games/Patintero/UI/Player Press Indicator/Not Pressed/P2.png"),
	preload("res://games/Patintero/UI/Player Press Indicator/Not Pressed/P3.png"),
	preload("res://games/Patintero/UI/Player Press Indicator/Not Pressed/P4.png"),
]
const INDICATOR_PRESSED_TEXTURES: Array[Texture2D] = [
	preload("res://games/Patintero/UI/Player Press Indicator/Pressed/P1.png"),
	preload("res://games/Patintero/UI/Player Press Indicator/Pressed/P2.png"),
	preload("res://games/Patintero/UI/Player Press Indicator/Pressed/P3.png"),
	preload("res://games/Patintero/UI/Player Press Indicator/Pressed/P4.png"),
]

@onready var _timer: Control = $Timer
@onready var _round_label: Label = $Round
@onready var _indicator_root: Control = $PressIndicators
@onready var _indicators: Array[TextureRect] = [
	$PressIndicators/P1Indicator,
	$PressIndicators/P2Indicator,
	$PressIndicators/P3Indicator,
	$PressIndicators/P4Indicator,
]
@onready var _key_labels: Array[Label] = [
	$PressIndicators/P1Key,
	$PressIndicators/P2Key,
	$PressIndicators/P3Key,
	$PressIndicators/P4Key,
]

var _round_active := false
var _application_focused := true
var _indicator_lanes: Array[int] = [0, 1, 2, 3]
var _indicator_down: Array[bool] = [false, false, false, false]
var _indicator_time_left: Array[float] = [0.0, 0.0, 0.0, 0.0]


func _ready() -> void:
	for player in PLAYER_ACTIONS.size():
		_indicators[player].texture = INDICATOR_TEXTURES[player]
		_key_labels[player].text = _key_hint(PLAYER_ACTIONS[player])
		_place_indicator(player)
	resized.connect(_layout_hud)
	_layout_hud()


func set_player_lanes(lanes: Array[int]) -> void:
	_indicator_lanes.assign(lanes)
	for player in PLAYER_ACTIONS.size():
		_place_indicator(player)


func set_round_active(active: bool) -> void:
	_round_active = active
	if not active:
		_reset_indicators()


func _input(event: InputEvent) -> void:
	if not _round_active or not _application_focused or not (event is InputEventKey):
		return
	for player in PLAYER_ACTIONS.size():
		if event.is_action_pressed(PLAYER_ACTIONS[player]):
			# Keep even a press/release within one frame visible without consuming
			# the input used by the runners' hold and double-tap controls.
			_indicator_time_left[player] = INDICATOR_HOLD
			_set_indicator(player, true)
			return


func _process(delta: float) -> void:
	if not _round_active or not _application_focused:
		return
	for player in PLAYER_ACTIONS.size():
		_indicator_time_left[player] = maxf(0.0, _indicator_time_left[player] - delta)
		_set_indicator(player, Input.is_action_pressed(PLAYER_ACTIONS[player]) or _indicator_time_left[player] > 0.0)


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_application_focused = false
		_reset_indicators()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_application_focused = true


func _reset_indicators() -> void:
	for player in PLAYER_ACTIONS.size():
		_indicator_time_left[player] = 0.0
		_set_indicator(player, false)


func _set_indicator(player: int, down: bool) -> void:
	if _indicator_down[player] == down:
		return
	_indicator_down[player] = down
	_indicators[player].texture = INDICATOR_PRESSED_TEXTURES[player] if down else INDICATOR_TEXTURES[player]
	_key_labels[player].add_theme_color_override("font_color", Color.WHITE if down else Color("fbc052"))
	_place_indicator(player)


func _place_indicator(player: int) -> void:
	var slot_size := INDICATOR_TEXTURES[player].get_size() * INDICATOR_SCALE
	var indicator_size := _indicators[player].texture.get_size() * INDICATOR_SCALE
	# Keep each badge in its player's assigned lane slot for the round.
	var bottom := slot_size.y + _indicator_lanes[player] * INDICATOR_SPACING
	# Both artwork states keep their native proportions and a fixed bottom edge.
	# Reserve the full idle height so pressing cannot shift the other badges.
	_indicators[player].size = indicator_size
	_indicators[player].position = Vector2((slot_size.x - indicator_size.x) * 0.5, bottom - indicator_size.y)
	_key_labels[player].position = Vector2((slot_size.x - 164.0) * 0.5, bottom - 52.0)
	_key_labels[player].size = Vector2(164.0, 36.0)


func _key_hint(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			return ";" if key == KEY_SEMICOLON else OS.get_keycode_string(key)
	return ""


func _layout_hud() -> void:
	var layout_scale := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var layout_origin := (size - DESIGN_SIZE * layout_scale) * 0.5
	_timer.scale = Vector2.ONE * layout_scale
	_timer.position = layout_origin + TIMER_POSITION * layout_scale
	_round_label.scale = Vector2.ONE * layout_scale
	_round_label.position = layout_origin + ROUND_POSITION * layout_scale
	_indicator_root.scale = Vector2.ONE * layout_scale
	_indicator_root.position = layout_origin + INDICATOR_POSITION * layout_scale
