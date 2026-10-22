extends Node2D
## Vertical timing gauge (gauge only, no character logic).
## The handle moves up and down on its own.
## Press SPACE when the handle is inside the green zone.
## Attach this ONLY to a dedicated gauge Node2D, never to the character.

signal hit(perfect: bool, points: int)
signal missed

# Reduced gauge dimensions so it fits comfortably on screen
@export var bar_size: Vector2 = Vector2(30, 160)
@export var min_handle_height: float = 10.0
@export var auto_position: bool = false ## Set to false to use custom coordinates in _ready()
@export var needle_speed: float = 0.9
@export var speed_increase: float = 0.05
@export var green_height: float = 0.12
@export var perfect_margin: float = 0.3
@export var auto_restart: bool = true
@export var restart_delay: float = 0.9

var t: float = 0.0
var direction: float = 1.0
var running: bool = true
var zone_start: float = 0.4
var zone_end: float = 0.52
var message: String = "Press SPACE!"
var score: int = 0
var streak: int = 0

var outline_box := StyleBoxFlat.new()
var bar_box := StyleBoxFlat.new()
var handle_box := StyleBoxFlat.new()


func _new_round() -> void:
	running = true
	t = 0.0
	direction = 1.0
	zone_start = randf_range(0.1, 0.9 - green_height)
	zone_end = zone_start + green_height
	message = "Press SPACE!"


func _ready() -> void:
	randomize()
	
	# ---> CHANGE THESE NUMBERS TO MOVE THE GAUGE EXACTLY WHERE YOU WANT <---
	# Vector2(X pixels from the left, Y pixels from the top)
	position = Vector2(100.0, 300.0)
	
	if auto_position:
		position = Vector2(bar_size.x * 1.5, get_viewport_rect().size.y / 2.0)
		
	var border := bar_size.x * 0.08

	outline_box.bg_color = Color.BLACK
	outline_box.set_corner_radius_all(int(bar_size.x * 0.16))

	bar_box.bg_color = Color("2e2e2e")
	bar_box.border_color = Color("f0b73e")
	bar_box.set_border_width_all(int(border))
	bar_box.set_corner_radius_all(int(bar_size.x * 0.12))

	handle_box.bg_color = Color("f0b73e")
	handle_box.border_color = Color.BLACK
	handle_box.set_border_width_all(2)
	handle_box.set_corner_radius_all(int(bar_size.x * 0.1))

	_new_round()


func _process(delta: float) -> void:
	if running:
		t += direction * needle_speed * delta
		if t >= 1.0:
			t = 1.0
			direction = -1.0
		elif t <= 0.0:
			t = 0.0
			direction = 1.0
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		if running:
			_check_hit()
		elif not auto_restart:
			_new_round()


func _check_hit() -> void:
	running = false
	if t >= zone_start and t <= zone_end:
		var center := (zone_start + zone_end) * 0.5
		var half := (zone_end - zone_start) * 0.5
		var offset: float = abs(t - center) / half
		var is_perfect := offset <= perfect_margin
		streak += 1
		
		# Point system set to 1 point per successful timing hit
		var points := 1
		score += points
		
		message = ("PERFECT! +%d Pt" if is_perfect else "GOOD! +%d Pt") % points
		needle_speed += speed_increase
		hit.emit(is_perfect, points)
	else:
		streak = 0
		message = "MISSED!"
		missed.emit()

	if auto_restart:
		await get_tree().create_timer(restart_delay).timeout
		_new_round()
	else:
		message += "\nPress SPACE to continue"


func _draw() -> void:
	var border := bar_size.x * 0.08
	var bar_rect := Rect2(-bar_size / 2.0, bar_size)
	var inner := bar_rect.grow(-border)

	# Draw background and outline
	draw_style_box(outline_box, bar_rect.grow(2.0))
	draw_style_box(bar_box, bar_rect)

	# Draw green timing zone
	var y_top: float = lerp(inner.end.y, inner.position.y, zone_end)
	var y_bottom: float = lerp(inner.end.y, inner.position.y, zone_start)
	draw_rect(Rect2(inner.position.x, y_top, inner.size.x, y_bottom - y_top), Color("4a8a10"))

	# Draw perfect zone
	var center_t := (zone_start + zone_end) * 0.5
	var perfect_half := (zone_end - zone_start) * 0.5 * perfect_margin
	var p_top: float = lerp(inner.end.y, inner.position.y, center_t + perfect_half)
	var p_bottom: float = lerp(inner.end.y, inner.position.y, center_t - perfect_half)
	draw_rect(Rect2(inner.position.x, p_top, inner.size.x, p_bottom - p_top), Color("7ac619"))

	# Draw moving handle
	var handle_w := bar_size.x * 1.3
	var handle_h := maxf(bar_size.x * 0.25, min_handle_height)
	var y: float = lerp(inner.end.y, inner.position.y, t)
	draw_style_box(handle_box, Rect2(-handle_w / 2.0, y - handle_h / 2.0, handle_w, handle_h))

	# Draw score text next to gauge
	var font := ThemeDB.fallback_font
	var x := bar_size.x * 0.5 + 15.0
	var top := -bar_size.y * 0.5
	_text(font, Vector2(x, top + 16), "Score: %d" % score, 16, Color.WHITE)
	_text(font, Vector2(x, top + 36), "Streak: %d" % streak, 14, Color(1, 0.9, 0.4))
	draw_multiline_string_outline(font, Vector2(x, 0), message, HORIZONTAL_ALIGNMENT_LEFT, 200, 16, -1, 4, Color.BLACK)
	draw_multiline_string(font, Vector2(x, 0), message, HORIZONTAL_ALIGNMENT_LEFT, 200, 16, -1, Color.WHITE)


func _text(font: Font, pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
