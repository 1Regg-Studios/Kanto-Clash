extends Node2D

@export var speed: float = 140.0
@export var top_y: float = 140.0
@export var bottom_y: float = 600.0
@export var start_dir: int = 1
@export var hit_cooldown: float = 0.6

var dir: int
var can_hit := true

func _ready() -> void:
	dir = start_dir
	$Hitbox.body_entered.connect(_on_touched)
	$Hitbox.area_entered.connect(_on_touched)
	print("platform ready: ", name)

func _process(delta: float) -> void:
	position.y += dir * speed * delta
	if position.y >= bottom_y:
		position.y = bottom_y
		dir = -1
	elif position.y <= top_y:
		position.y = top_y
		dir = 1

func _on_touched(other: Node) -> void:
	print("hitbox touched by: ", other.name)
	if not can_hit:
		return
	# Walk up from whatever touched us until we find the node with _get_hit()
	var n := other
	while n != null and not n.has_method("_get_hit"):
		n = n.get_parent()
	if n == null:
		print("no _get_hit() found on ", other.name, " or its parents")
		return
	can_hit = false
	n._get_hit()
	await get_tree().create_timer(hit_cooldown).timeout
	can_hit = true
