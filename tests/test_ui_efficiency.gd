extends Node

const RANDOMIZER := preload("res://src/UI/randomizer/minigame_randomizer.tscn")
const READY_SCREEN := preload("res://src/UI/rdyplyr/rdyplyr.tscn")
const LOADING_SCREEN := preload("res://src/UI/ldscrn/ldscrn.tscn")
const ROUND_BOARD := "res://src/UI/roundleaderboard/roundleaderboard.tscn"
const MAIN_MENU := "res://src/UI/main/mainmenu.tscn"

var _failures := 0
var _completed_suites := 0
var _history_path := ""


func _ready() -> void:
	# Keep the harness alive while exercising real SceneFader scene transitions.
	get_tree().current_scene = null
	get_tree().create_timer(45.0).timeout.connect(func() -> void:
		printerr("[test] UI efficiency: timed out")
		get_tree().quit(1)
	)
	# Isolate the real randomizer's roll from the player's saved variety history.
	_history_path = "user://test_ui_schedule_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	GameSchedule._history_path = _history_path
	await _test_ready_toggles()
	await _test_randomizer()
	await _test_loading()
	_check(_completed_suites == 3, "All UI suites must complete without script errors")
	# Let the final menu track release its playback before shutting down audio.
	AudioManager.stop_menu_music()
	await get_tree().create_timer(AudioManager.MUSIC_FADE_TIME + 0.1).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_history_path))
	print("[test] UI efficiency: ", "PASS" if _failures == 0 else "FAIL")
	get_tree().quit(0 if _failures == 0 else 1)


func _test_ready_toggles() -> void:
	var screen := READY_SCREEN.instantiate()
	add_child(screen)
	screen._set_ready(0, true)
	var first_tween: Tween = screen._portrait_tweens[0]
	await get_tree().create_timer(0.03).timeout
	screen._set_ready(0, false)
	_check(not first_tween.is_valid(), "A newer toggle must cancel the old portrait tween")
	screen._set_ready(0, true)
	screen._set_ready(1, true)
	screen._set_ready(1, false)
	await get_tree().create_timer(screen.TOGGLE_TIME + 0.1).timeout
	_check(screen._portraits[0].modulate.is_equal_approx(screen.READY_MODULATE), "Latest ready state must finish bright")
	_check(screen._portraits[1].modulate.is_equal_approx(screen.NOT_READY_MODULATE), "Latest unready state must finish dark")
	_check(screen._boxes[0].texture == screen.BOX_CHECK_TEXTURE, "Ready checkbox must remain checked")
	_check(screen._boxes[1].texture == screen.BOX_TEXTURE, "Unready checkbox must remain unchecked")
	screen.free()
	_completed_suites += 1
	print("[test] rapid ready toggles: PASS" if _failures == 0 else "[test] rapid ready toggles: FAIL")


func _test_randomizer() -> void:
	var screen := RANDOMIZER.instantiate()
	add_child(screen)
	_check(not screen.is_processing(), "Reels must not process during the opening pause")
	var tile_count := 0
	for reel in screen._reels:
		tile_count += reel.get_child_count()
	_check(tile_count == 40, "Four reels must use only 40 tiles (formerly 80)")
	# Large deltas must still wrap into the first sequence, keeping the strip covered.
	screen._spin_speed = screen.SPIN_SPEED
	for reel in screen._reels:
		var slot: int = screen._reels.find(reel)
		screen._spin_reel(slot, 5.0)
		_check(reel.position.y <= 0.0 and reel.position.y > -screen._sequence, "Slow-frame wrap must stay within one sequence")
	screen._spin_speed = 0.0
	var checked := 0
	var previous_speed := 0.0
	while screen._landed < screen._reels.size():
		await get_tree().process_frame
		_check(screen._spin_speed >= previous_speed and screen._spin_speed <= screen.SPIN_SPEED, "Acceleration must ramp up without overshooting")
		previous_speed = screen._spin_speed
		for reel in screen._reels:
			_check_strip_coverage(reel, screen.ICON_SIZE)
		while checked < screen._landed:
			var reel: Control = screen._reels[checked]
			var tile_index := int(round(-reel.position.y / screen.ICON_SIZE))
			var tile := reel.get_child(tile_index) as TextureRect
			var expected := GameSchedule.index_of(GameSchedule.picked[checked])
			_check(tile.texture == screen._icons[expected], "Landed icon must match the scheduled game")
			_check(is_equal_approx(reel.position.y + tile.position.y, 0.0), "Landed tile must align exactly with its slot")
			checked += 1
	_check(checked == 4, "All four scheduled games must be revealed")
	_check(not screen.is_processing(), "Landed reels must stop processing during the result hold")
	await get_tree().create_timer(screen.TOGGLE_TIME + 0.1).timeout
	for reel in screen._reels:
		_check(reel.modulate.is_equal_approx(screen.READY_MODULATE), "Landed reels must retain the bright highlight")
	# Exercise the existing hold, loading-screen hand-off, and missing-game fallback.
	await _wait_for_scene(MAIN_MENU)
	_check(GameSchedule.next_scene_path == GameSchedule.first_scene_path(), "Randomizer must hand off the first selected scene")
	screen.free()
	_clear_current_scene()
	_completed_suites += 1
	print("[test] 40-tile randomizer, hold, loading fallback: complete")


func _check_strip_coverage(reel: Control, icon_size: int) -> void:
	var first_visible := int(floor(-reel.position.y / icon_size))
	var last_visible := int(ceil((icon_size - reel.position.y) / icon_size)) - 1
	_check(first_visible >= 0 and last_visible < reel.get_child_count(), "Reel strip must cover the complete slot throughout spin and braking")


func _test_loading() -> void:
	var screen := LOADING_SCREEN.instantiate()
	screen.next_scene_path = ROUND_BOARD
	add_child(screen)
	await get_tree().create_timer(0.5).timeout
	_check(screen._progress <= screen.EARLY_MAX_PROGRESS, "Fast loads must retain the early progress cap")
	await _wait_for_scene(ROUND_BOARD)
	_check(screen._load_status == ResourceLoader.THREAD_LOAD_LOADED, "A valid target must complete threaded loading")
	_check(not screen.is_processing() and is_equal_approx(screen._progress, 1.0), "Completed loading must fill the bar and stop processing")
	_check(screen._get_target_progress() == 1.0, "Consumed loads must retain their cached completed status")
	screen.free()
	_clear_current_scene()

	# A terminal failed status must fall back without querying/getting a failed resource.
	screen = LOADING_SCREEN.instantiate()
	screen.next_scene_path = "res://tests/does_not_exist.tscn"
	add_child(screen)
	screen._threaded = true
	screen._load_status = ResourceLoader.THREAD_LOAD_FAILED
	await _wait_for_scene(MAIN_MENU)
	_check(screen._load_status == ResourceLoader.THREAD_LOAD_FAILED, "Failed load status must stay cached")
	_check(not screen.is_processing(), "Fallback loading must stop processing")
	screen.free()
	_clear_current_scene()
	_completed_suites += 1
	print("[test] threaded loading, progress cap, failure fallback: complete")


func _wait_for_scene(path: String) -> void:
	while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != path or SceneFader._busy:
		await get_tree().process_frame


func _clear_current_scene() -> void:
	var scene := get_tree().current_scene
	get_tree().current_scene = null
	if scene != null:
		scene.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("[test] FAIL: ", message)
