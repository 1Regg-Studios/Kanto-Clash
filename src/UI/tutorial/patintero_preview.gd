extends "res://games/Patintero/Scripts/patintero_game.gd"

signal demo_key_changed(pressed: bool)
signal demo_action_changed(action: String)

const DEMO_SECONDS := 18.0

var _demo_elapsed := 0.0


func _ready() -> void:
	# Reuse the court, guards, and runners without starting or scoring a game.
	process_physics_priority = 1
	_timer.stop_round()
	_round_label.text = "ROUND 1 / 2"
	_round_notice.hide()
	_hud.set_round_active(false)
	_hud.set_process_input(false)
	$PauseMenu.process_mode = Node.PROCESS_MODE_DISABLED
	for player_index in _players.size():
		var player := _players[player_index]
		_spawn_positions.append(player.position)
		player.configure_demo(_guards)
		player.connect("demo_key_changed", _on_runner_key_changed.bind(player_index))
	_players[0].connect("demo_action_changed", demo_action_changed.emit)
	get_viewport().size_changed.connect(_layout_preview_camera)
	_layout_preview_camera()
	_restart_demo()


func _physics_process(delta: float) -> void:
	_demo_elapsed += delta
	if _demo_elapsed >= DEMO_SECONDS:
		_restart_demo()
	for player_index in _players.size():
		var player := _players[player_index]
		if player.position.x >= ZONE_CROSSING_XS[-1] and not _finish_order.has(player_index):
			_finish_order.append(player_index)
			player.set_demo_key(false)
			player.finish_run(_finish_order.size())
			if player_index == 0:
				demo_action_changed.emit("FINISH!")
	# A visual timer loops with the demo and never emits a round timeout.
	_timer.set("_time_left", 60.0 - _demo_elapsed)
	_timer.call("_update_label")


func _restart_demo() -> void:
	_demo_elapsed = 0.0
	_finish_order.clear()
	for guard in _guards:
		guard.reset_for_round()
	for player_index in _players.size():
		_players[player_index].reset_demo(_spawn_positions[player_index])


func _on_runner_key_changed(pressed: bool, player_index: int) -> void:
	_hud.call("_set_indicator", player_index, pressed)
	if player_index == 0:
		demo_key_changed.emit(pressed)


func _layout_preview_camera() -> void:
	var view_size := get_viewport_rect().size
	$ImpactCamera.base_zoom = 1.55 * minf(view_size.x / 1920.0, view_size.y / 1080.0)
