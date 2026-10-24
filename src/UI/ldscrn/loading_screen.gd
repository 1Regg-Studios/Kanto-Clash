extends Control

const BLINK_MIN_ALPHA := 0.4
const BLINK_HALF_PERIOD := 0.5
const MAIN_MENU_SCENE := "res://src/UI/main/mainmenu.tscn"

@export_file("*.tscn") var next_scene_path: String = ""
@export var simulated_load_time := 3.0
@export var fill_speed := 1.2
@export_range(0.1, 30.0, 0.1, "or_greater") var minimum_display_time := 6.0
@export var background_textures: Array[Texture2D] = []
@export_range(0.1, 10.0, 0.1, "or_greater") var background_hold_time := 2.0
@export_range(0.1, 10.0, 0.1, "or_greater") var background_fade_time := 1.0

@onready var _background: TextureRect = $Background
@onready var _background_next: TextureRect = $BackgroundNext
@onready var _progress_bar: Control = $ProgressBar
@onready var _fill_clip: Control = $ProgressBar/FillClip
@onready var _loading_text: TextureRect = $LoadingText

var _background_order: Array[Texture2D] = []
var _progress := 0.0
var _elapsed := 0.0
var _threaded := false
var _load_progress: Array = []
var _load_status := ResourceLoader.THREAD_LOAD_INVALID_RESOURCE


func _ready() -> void:
	AudioManager.stop_menu_music()
	_start_background_slideshow()
	if next_scene_path == "":
		next_scene_path = GameSchedule.next_scene_path
	_fill_clip.size.x = 0.0
	if next_scene_path != "" and ResourceLoader.exists(next_scene_path):
		_threaded = ResourceLoader.load_threaded_request(next_scene_path) == OK
		if _threaded:
			_load_status = ResourceLoader.THREAD_LOAD_IN_PROGRESS
	var blink := create_tween().set_loops()
	blink.tween_property(_loading_text, "modulate:a", BLINK_MIN_ALPHA, BLINK_HALF_PERIOD)
	blink.tween_property(_loading_text, "modulate:a", 1.0, BLINK_HALF_PERIOD)


func _process(delta: float) -> void:
	_elapsed += delta
	var target := _get_target_progress()
	# Pace fast loads so at least one background crossfade is visible.
	target = minf(target, _elapsed / minimum_display_time)
	_progress = move_toward(_progress, target, delta * fill_speed)
	_fill_clip.size.x = _progress_bar.size.x * _progress
	if target >= 1.0 and _progress >= 1.0 and _load_status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_finish()


func _start_background_slideshow() -> void:
	if background_textures.is_empty():
		return
	_background.texture = _take_next_background()
	_background_next.modulate.a = 0.0
	if background_textures.size() < 2:
		return
	var slideshow := create_tween().set_loops()
	slideshow.tween_interval(background_hold_time)
	slideshow.tween_callback(_prepare_background_fade)
	# The opaque outgoing layer prevents a dip to black during the blend.
	slideshow.tween_property(_background_next, "modulate:a", 1.0, background_fade_time).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	slideshow.tween_callback(_complete_background_fade)


func _take_next_background(previous: Texture2D = null) -> Texture2D:
	if _background_order.is_empty():
		_background_order.assign(background_textures)
		_background_order.shuffle()
		# Avoid repeating the last image when a new shuffled cycle begins.
		if _background_order.size() > 1 and _background_order.back() == previous:
			var first := _background_order[0]
			_background_order[0] = _background_order.back()
			_background_order[_background_order.size() - 1] = first
	return _background_order.pop_back()


func _prepare_background_fade() -> void:
	_background_next.texture = _take_next_background(_background.texture)


func _complete_background_fade() -> void:
	_background.texture = _background_next.texture
	_background_next.modulate.a = 0.0
	_background_next.texture = null


func _get_target_progress() -> float:
	if not _threaded:
		return minf(_elapsed / simulated_load_time, 1.0)
	if _load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_load_status = ResourceLoader.load_threaded_get_status(next_scene_path, _load_progress)
		if _load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return float(_load_progress[0]) if not _load_progress.is_empty() else 0.0
	return 1.0


func _finish() -> void:
	set_process(false)
	var packed: PackedScene
	if _load_status == ResourceLoader.THREAD_LOAD_LOADED:
		packed = ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
	if packed == null and next_scene_path != "" and ResourceLoader.exists(next_scene_path):
		# A threaded request can fail even when the scene is still loadable normally.
		packed = ResourceLoader.load(next_scene_path) as PackedScene
	if packed != null:
		await SceneFader.change_scene_to_packed(packed)
		return
	push_error("Could not load scheduled game scene: %s" % next_scene_path)
	await SceneFader.change_scene(MAIN_MENU_SCENE)
