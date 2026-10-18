extends Node2D

func _ready() -> void:
	print("platform ready")
	$Hitbox.body_entered.connect(_on_hitbox_body_entered)

func _on_hitbox_body_entered(body: Node2D) -> void:
	print("hitbox touched by: ", body.name)
	if body.has_method("_get_hit"):
		body._get_hit()


@export var lane_index: int = 0        # which line this guard stands on (0 = first line)
@export var speed: float = 140.0
@export var top_y: float = 140.0
@export var bottom_y: float = 600.0
@export var start_dir: int = 1         # 1 = down, -1 = up

var moving := false
var dir: int
