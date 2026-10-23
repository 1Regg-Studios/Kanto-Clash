extends Node2D

const DESIGN_SIZE := Vector2(1152.0, 648.0)
const MAIN_MUSIC := preload("res://assets/Music/Main/Tumbang Preso/hitslab-retro-arcade-game-music-396890.mp3")

@onready var camera: Camera2D = $Camera2D
@onready var hud: CanvasLayer = $CanvasLayer
@onready var letterbox: Array[ColorRect] = [
	$CanvasLayer/Letterbox/Left,
	$CanvasLayer/Letterbox/Right,
	$CanvasLayer/Letterbox/Top,
	$CanvasLayer/Letterbox/Bottom,
]


func _ready() -> void:
	AudioManager.stop_menu_music()
	AudioManager.play_game_music(MAIN_MUSIC)
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


func _fit_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var fit := minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	camera.zoom = Vector2.ONE * fit
	# Keep the screen frame and HUD aligned with the camera-fitted playfield.
	var origin := (viewport_size - DESIGN_SIZE * fit) * 0.5
	hud.transform = Transform2D(0.0, Vector2.ONE * fit, 0.0, origin)
	# Cover artwork extending past the frame on wider or taller screens.
	var margin := (origin / fit).max(Vector2.ZERO)
	var full_height := DESIGN_SIZE.y + margin.y * 2.0
	var matte_rects: Array[Rect2] = [
		Rect2(-margin, Vector2(margin.x, full_height)),
		Rect2(Vector2(DESIGN_SIZE.x, -margin.y), Vector2(margin.x, full_height)),
		Rect2(Vector2(0.0, -margin.y), Vector2(DESIGN_SIZE.x, margin.y)),
		Rect2(Vector2(0.0, DESIGN_SIZE.y), Vector2(DESIGN_SIZE.x, margin.y)),
	]
	for i in letterbox.size():
		letterbox[i].position = matte_rects[i].position
		letterbox[i].size = matte_rects[i].size
