extends Control

const FRAME_TEXTURE: Texture2D = preload("res://games/Tug Of war/assets/UI/TUG OF WAR FRAME.png")
const TEAM_ONE_TEXTURE: Texture2D = preload("res://games/Tug Of war/assets/UI/Meter G2.png")
const TEAM_TWO_TEXTURE: Texture2D = preload("res://games/Tug Of war/assets/UI/Meter G1.png")

const DISPLAY_SCALE := 1.65
const FRAME_SIZE := Vector2(803.0, 146.0)
const FILL_SIZE := Vector2(790.0, 64.0)
const FILL_LEFT := 6.0
const FILL_RIGHT := 796.0
const FILL_TOP := 11.0
const MARKER_MIN := 28.0
const MARKER_MAX := 774.0
const BAR_HEIGHT := 87.0
const FIXED_MARKER_LEFT := 365.0
const FIXED_MARKER_RIGHT := 438.0
const MARKER_REGION := Rect2(394.0, 0.0, 16.0, 84.0)

var progress := 0.5
var _displayed_progress := 0.5

@onready var _timer: Label = $Timer


func _ready() -> void:
	custom_minimum_size = FRAME_SIZE * DISPLAY_SCALE
	_timer.position = Vector2(225.0, 76.0) * DISPLAY_SCALE
	_timer.size = Vector2(351.0, 56.0) * DISPLAY_SCALE
	set_time_text("01:00")
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
	var boundary := lerpf(MARKER_MIN, MARKER_MAX, _displayed_progress)
	var left_width := maxf(1.0, boundary - FILL_LEFT)
	var right_width := maxf(1.0, FILL_RIGHT - boundary)

	draw_texture_rect_region(
		TEAM_ONE_TEXTURE,
		Rect2(FILL_LEFT * DISPLAY_SCALE, FILL_TOP * DISPLAY_SCALE, left_width * DISPLAY_SCALE, FILL_SIZE.y * DISPLAY_SCALE),
		Rect2(0.0, 0.0, left_width, FILL_SIZE.y)
	)
	draw_texture_rect_region(
		TEAM_TWO_TEXTURE,
		Rect2((FILL_RIGHT - right_width) * DISPLAY_SCALE, FILL_TOP * DISPLAY_SCALE, right_width * DISPLAY_SCALE, FILL_SIZE.y * DISPLAY_SCALE),
		Rect2(FILL_SIZE.x - right_width, 0.0, right_width, FILL_SIZE.y)
	)
	# Reuse the supplied frame, replacing its baked-in center marker with a clean
	# stretch of the border. The separate gold needle can then follow the rope.
	_draw_frame_region(Rect2(0.0, 0.0, FIXED_MARKER_LEFT, BAR_HEIGHT), Vector2.ZERO)
	_draw_frame_region(
		Rect2(280.0, 0.0, FIXED_MARKER_RIGHT - FIXED_MARKER_LEFT, BAR_HEIGHT),
		Vector2(FIXED_MARKER_LEFT, 0.0)
	)
	_draw_frame_region(
		Rect2(FIXED_MARKER_RIGHT, 0.0, FRAME_SIZE.x - FIXED_MARKER_RIGHT, BAR_HEIGHT),
		Vector2(FIXED_MARKER_RIGHT, 0.0)
	)
	_draw_frame_region(
		Rect2(0.0, BAR_HEIGHT, FRAME_SIZE.x, FRAME_SIZE.y - BAR_HEIGHT),
		Vector2(0.0, BAR_HEIGHT)
	)
	_draw_frame_region(MARKER_REGION, Vector2(boundary - MARKER_REGION.size.x * 0.5, 0.0))


func _draw_frame_region(region: Rect2, at: Vector2) -> void:
	draw_texture_rect_region(FRAME_TEXTURE, Rect2(at * DISPLAY_SCALE, region.size * DISPLAY_SCALE), region)
