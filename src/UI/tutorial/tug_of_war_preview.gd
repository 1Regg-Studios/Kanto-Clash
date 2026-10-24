extends "res://games/Tug Of war/tug_of_war.gd"

signal demo_key_changed(pressed: bool)

const TAP_INTERVAL := 0.48
const LEAD_SECONDS := 4.8
const DEMO_PULL := 40.0

var _demo_elapsed := 0.0
var _next_left_tap := 0.3
var _next_right_tap := 0.54


func _ready() -> void:
	# Reuse the real arena without starting a match, countdown, or scoring.
	_round_label.text = "ROUND 1 / 2"
	indicator_hold = 0.17
	_build_pullers()
	_setup_pull_smoke()
	_setup_indicators()
	_time_left = match_seconds
	_show_time()
	_update_meter(true)
	_hud_root.resized.connect(_layout_arena)
	_layout_arena()
	# The embedded game must never accept gameplay input.
	set_process_unhandled_input(false)
	$PauseMenu.process_mode = Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	_demo_elapsed += delta
	var team_one_leads := int(_demo_elapsed / LEAD_SECONDS) % 2 == 0
	if _demo_elapsed >= _next_left_tap:
		_next_left_tap = _demo_elapsed + TAP_INTERVAL
		_tap_team(true, team_one_leads)
	if _demo_elapsed >= _next_right_tap:
		_next_right_tap = _demo_elapsed + TAP_INTERVAL
		_tap_team(false, not team_one_leads)
	for player in PLAYER_COUNT:
		_refresh_indicator(player, _now())
	_update_world(delta)
	# Repeat a short demonstration indefinitely while the player reads.
	_time_left = match_seconds - fmod(_demo_elapsed, LEAD_SECONDS * 2.0)
	_show_time()


func _tap_team(team_one: bool, both_players: bool) -> void:
	var tapped := false
	for player in PLAYER_COUNT:
		if _is_team_one(player) != team_one:
			continue
		if tapped and not both_players:
			break
		_demo_pull(player)
		tapped = true


func _demo_pull(player: int) -> void:
	# Bound demo movement so the preview cannot finish or publish a score.
	var limit := _win_distance() * 0.65
	_rope_pos = clampf(_rope_pos + (-DEMO_PULL if _is_team_one(player) else DEMO_PULL), -limit, limit)
	_indicator_until[player] = _now() + indicator_hold
	_set_indicator(player, true)
	_update_meter()
	_play_pull_effect(player)


func _set_indicator(player: int, down: bool) -> void:
	var changed := _indicator_down[player] != down
	super._set_indicator(player, down)
	if player == 0 and changed:
		demo_key_changed.emit(down)
