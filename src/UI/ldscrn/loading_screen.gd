extends Control

const BLINK_MIN_ALPHA := 0.4
const BLINK_HALF_PERIOD := 0.5
const EARLY_TIME := 1.0
const EARLY_MAX_PROGRESS := 0.9
const MAIN_MENU_SCENE := "res://src/UI/main/mainmenu.tscn"

@export_file("*.tscn") var next_scene_path: String = ""
@export var simulated_load_time := 3.0
@export var fill_speed := 1.2

@onready var _progress_bar: Control = $ProgressBar
@onready var _fill_clip: Control = $ProgressBar/FillClip
@onready var _loading_text: TextureRect = $LoadingText

var _progress := 0.0
var _elapsed := 0.0
var _threaded := false


func _ready() -> void:
	AudioManager.stop_menu_music()
	if next_scene_path == "":
		next_scene_path = GameSchedule.next_scene_path
	_fill_clip.size.x = 0.0
	if next_scene_path != "" and ResourceLoader.exists(next_scene_path):
		_threaded = ResourceLoader.load_threaded_request(next_scene_path) == OK
	var blink := create_tween().set_loops()
	blink.tween_property(_loading_text, "modulate:a", BLINK_MIN_ALPHA, BLINK_HALF_PERIOD)
	blink.tween_property(_loading_text, "modulate:a", 1.0, BLINK_HALF_PERIOD)


func _process(delta: float) -> void:
	_elapsed += delta
	var target := _get_target_progress()
	if _elapsed < EARLY_TIME:
		target = minf(target, EARLY_MAX_PROGRESS)
	_progress = move_toward(_progress, target, delta * fill_speed)
	_fill_clip.size.x = _progress_bar.size.x * _progress
	if target >= 1.0 and _progress >= 1.0:
		_finish()


func _get_target_progress() -> float:
	if not _threaded:
		return minf(_elapsed / simulated_load_time, 1.0)
	var info: Array = []
	if ResourceLoader.load_threaded_get_status(next_scene_path, info) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return info[0]
	return 1.0


func _finish() -> void:
	set_process(false)
	if _threaded:
		var packed := ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
		if packed != null:
			await SceneFader.change_scene_to_packed(packed)
			return
	await SceneFader.change_scene(MAIN_MENU_SCENE)
