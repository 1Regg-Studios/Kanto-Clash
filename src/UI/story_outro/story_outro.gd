extends Control

const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const MAIN_MENU_SCENE := "res://src/UI/main/mainmenu.tscn"
const PANEL_TIME := 3.4
const CROSSFADE_TIME := 0.55
const SKIP_DELAY := 0.75
const START_ZOOMS: Array[float] = [1.0, 1.045]
const END_ZOOMS: Array[float] = [1.045, 1.0]
const START_OFFSETS: Array[Vector2] = [Vector2.ZERO, Vector2(-14.0, 6.0)]
const END_OFFSETS: Array[Vector2] = [Vector2(16.0, 8.0), Vector2.ZERO]

@onready var _frame: Control = $Frame
@onready var _panels: Array[TextureRect] = [$Frame/Panel1, $Frame/Panel2]
@onready var _skip: Button = $Frame/Skip

var _elapsed := 0.0
var _finished := false


func _ready() -> void:
	AudioManager.stop_game_music()
	AudioManager.start_menu_music()
	_skip.pressed.connect(_finish)
	resized.connect(_layout_content)
	_layout_content()
	_update_animation()


func _process(delta: float) -> void:
	_elapsed += delta
	_update_animation()
	if _elapsed >= PANEL_TIME * _panels.size():
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _finished or _elapsed < SKIP_DELAY:
		return
	if event is InputEventKey and event.echo:
		return
	var skip_requested := event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel")
	if event is InputEventMouseButton:
		skip_requested = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		skip_requested = event.pressed
	if skip_requested:
		get_viewport().set_input_as_handled()
		_finish()


func _update_animation() -> void:
	for index in _panels.size():
		var panel := _panels[index]
		var local_time := _elapsed - float(index) * PANEL_TIME
		panel.visible = local_time >= 0.0 and (index == _panels.size() - 1 or local_time < PANEL_TIME + CROSSFADE_TIME)
		if not panel.visible:
			continue
		# Keep the first picture opaque beneath the second during the crossfade.
		panel.modulate.a = 1.0 if index == 0 else clampf(local_time / CROSSFADE_TIME, 0.0, 1.0)
		var duration := PANEL_TIME if index == _panels.size() - 1 else PANEL_TIME + CROSSFADE_TIME
		var weight := smoothstep(0.0, 1.0, clampf(local_time / duration, 0.0, 1.0))
		var zoom := lerpf(START_ZOOMS[index], END_ZOOMS[index], weight)
		var offset := START_OFFSETS[index].lerp(END_OFFSETS[index], weight)
		panel.scale = Vector2.ONE * zoom
		panel.position = ((DESIGN_SIZE - DESIGN_SIZE * zoom) * 0.5 + offset).round()
	_skip.disabled = _elapsed < SKIP_DELAY
	_skip.modulate.a = clampf((_elapsed - SKIP_DELAY) / CROSSFADE_TIME, 0.0, 1.0)


func _layout_content() -> void:
	var fit := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_frame.scale = Vector2.ONE * fit
	_frame.position = (size - DESIGN_SIZE * fit) * 0.5


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	_skip.disabled = true
	_skip.hide()
	await SceneFader.change_scene(MAIN_MENU_SCENE)
