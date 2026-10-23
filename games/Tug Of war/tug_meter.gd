extends Control

const FRAME_TEXTURE: Texture2D = preload("res://games/Tug Of war/assets/UI/TUG OF WAR FRAME.png")
const TEAM_ONE_TEXTURE: Texture2D = preload("res://games/Tug Of war/assets/UI/Meter G2.png")
const TEAM_TWO_TEXTURE: Texture2D = preload("res://games/Tug Of war/assets/UI/Meter G1.png")

const DISPLAY_SCALE := 1.6
const TIMER_SIZE := Vector2(290.0, 91.0)
const FILL_LEFT := 12.0
const FILL_RIGHT := 791.0
const FILL_TOP := 16.0
const FILL_HEIGHT := 54.0
const FILL_CORNER_RADIUS := 5.0
const MARKER_MIN := 28.0
const MARKER_MAX := 774.0
const FIXED_MARKER_LEFT := 365.0
const FIXED_MARKER_RIGHT := 438.0
const MARKER_LEFT := 394.0
const MARKER_WIDTH := 16.0

var progress := 0.5
var _displayed_progress := 0.5

@onready var _timer_box: Control = $Timer
@onready var _timer: Label = $Timer/Label


func _ready() -> void:
	var bar_size := FRAME_TEXTURE.get_size() * DISPLAY_SCALE
	custom_minimum_size = Vector2(bar_size.x, bar_size.y + TIMER_SIZE.y - 4.0)
	_timer_box.position = Vector2((bar_size.x - TIMER_SIZE.x) * 0.5, bar_size.y - 4.0)
	_timer_box.size = TIMER_SIZE
	set_time_text("00 : 30")
	queue_redraw()


func set_progress(value: float, snap := false) -> void:
	progress = clampf(value, 0.0, 1.0)
	if snap:
		_displayed_progress = progress
	queue_redraw()


func set_time_text(text: String, urgent := false) -> void:
	_timer.text = text
	_timer.add_theme_color_override("font_color", Color("ff7963") if urgent else Color.WHITE)


func _process(delta: float) -> void:
	if is_equal_approx(_displayed_progress, progress):
		return
	_displayed_progress = lerpf(_displayed_progress, progress, 1.0 - exp(-14.0 * delta))
	queue_redraw()


func _draw() -> void:
	var frame_size := FRAME_TEXTURE.get_size()
	var boundary := lerpf(MARKER_MIN, MARKER_MAX, _displayed_progress)
	# Patch out the artwork's fixed diamond, then reuse its gold needle as the
	# moving marker. The supplied timer is laid out independently below the bar.
	_draw_frame_region(Rect2(0.0, 0.0, FIXED_MARKER_LEFT, frame_size.y), Vector2.ZERO)
	_draw_frame_region(
		Rect2(280.0, 0.0, FIXED_MARKER_RIGHT - FIXED_MARKER_LEFT, frame_size.y),
		Vector2(FIXED_MARKER_LEFT, 0.0)
	)
	_draw_frame_region(
		Rect2(FIXED_MARKER_RIGHT, 0.0, frame_size.x - FIXED_MARKER_RIGHT, frame_size.y),
		Vector2(FIXED_MARKER_RIGHT, 0.0)
	)
	_draw_team_fill(TEAM_ONE_TEXTURE, Rect2(FILL_LEFT, FILL_TOP, boundary - FILL_LEFT, FILL_HEIGHT), true)
	_draw_team_fill(TEAM_TWO_TEXTURE, Rect2(boundary, FILL_TOP, FILL_RIGHT - boundary, FILL_HEIGHT), false)
	_draw_frame_region(
		Rect2(MARKER_LEFT, 0.0, MARKER_WIDTH, frame_size.y),
		Vector2(boundary - MARKER_WIDTH * 0.5, 0.0)
	)


func _draw_team_fill(texture: Texture2D, area: Rect2, round_left: bool) -> void:
	# Round only the outside corners so both gradients meet cleanly at the needle.
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var corners := [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]
	for corner in 4:
		var rounded := (corner == 0 or corner == 3) == round_left
		if not rounded:
			points.append(corners[corner] * DISPLAY_SCALE)
			uvs.append((corners[corner] - area.position) / area.size)
			continue
		var inward := Vector2(1.0 if corner == 0 or corner == 3 else -1.0, 1.0 if corner < 2 else -1.0)
		var center: Vector2 = corners[corner] + inward * FILL_CORNER_RADIUS
		for step in 5:
			var angle := PI + corner * PI * 0.5 + step * PI / 8.0
			var point := center + Vector2.from_angle(angle) * FILL_CORNER_RADIUS
			points.append(point * DISPLAY_SCALE)
			uvs.append((point - area.position) / area.size)
	draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, texture)


func _draw_frame_region(region: Rect2, at: Vector2) -> void:
	draw_texture_rect_region(FRAME_TEXTURE, Rect2(at * DISPLAY_SCALE, region.size * DISPLAY_SCALE), region)
