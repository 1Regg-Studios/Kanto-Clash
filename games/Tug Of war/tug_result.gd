extends Control

signal finished

const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const CARD_POSITION := Vector2(440.0, 315.0)

@export_range(1.0, 10.0, 0.1) var display_seconds := 5.0

@onready var _dim: ColorRect = $Dim
@onready var _composition: Control = $Composition
@onready var _card: Panel = $Composition/Card
@onready var _accent: ColorRect = $Composition/Card/Accent
@onready var _winner: Label = $Composition/Card/Winner
@onready var _detail: Label = $Composition/Card/Detail
@onready var _redirect: Label = $Composition/Card/Redirect

var _entrance: Tween
var _countdown: Tween
var _presented := false


func _ready() -> void:
	visible = false
	resized.connect(_layout)
	_layout()


func show_result(message: String, color: Color, round_number: int) -> void:
	if _presented:
		return
	_presented = true
	_winner.text = message
	_winner.add_theme_color_override("font_color", Color.WHITE)
	_detail.text = "ROUND %d" % round_number
	_accent.color = Color("fbc04f")
	_update_countdown(display_seconds)
	_dim.color.a = 0.0
	_card.position = CARD_POSITION
	_card.scale = Vector2.ONE
	_card.modulate.a = 0.0
	visible = true

	_entrance = create_tween().set_parallel()
	_entrance.tween_property(_dim, "color:a", 0.5, 0.35)
	_entrance.tween_property(_card, "modulate:a", 1.0, 0.25)

	_countdown = create_tween()
	_countdown.tween_method(_update_countdown, display_seconds, 0.0, display_seconds)
	_countdown.tween_callback(_leave)


func _layout() -> void:
	var view_size := get_viewport_rect().size
	var fit := minf(view_size.x / DESIGN_SIZE.x, view_size.y / DESIGN_SIZE.y)
	_composition.position = (view_size - DESIGN_SIZE * fit) * 0.5
	_composition.scale = Vector2.ONE * fit


func _update_countdown(remaining: float) -> void:
	var countdown_label := "NEXT ROUND STARTS IN"
	if GameSchedule.tug_round > 1:
		countdown_label = "OVERALL RESULTS IN" if GameSchedule.is_last_game() else "ROUND RESULTS IN"
	_redirect.text = "%s %d..." % [countdown_label, maxi(1, ceili(remaining))]


func _leave() -> void:
	var results := "OPENING OVERALL RESULTS..." if GameSchedule.is_last_game() else "OPENING ROUND RESULTS..."
	_redirect.text = "STARTING NEXT ROUND..." if GameSchedule.tug_round == 1 else results
	var exit := create_tween().set_parallel()
	exit.tween_property(_card, "modulate:a", 0.0, 0.25)
	finished.emit()
