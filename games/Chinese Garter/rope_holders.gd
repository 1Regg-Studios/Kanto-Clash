extends Node2D

enum Height { LOW, MIDDLE, HIGH }

const MIDDLE_SCORE := 5
const HIGH_SCORE := 10
const HAND_ROWS: Array[float] = [21.0, 16.0, 10.0]
const CONNECTOR_WIDTH := 24.0
# Each player's poses are ordered low (ropeholder3), middle (ropeholder2), high.
const HOLDER_TEXTURES: Array[Array] = [
	[
		preload("res://games/Chinese Garter/ropeholder3.png"),
		preload("res://games/Chinese Garter/ropeholder2.png"),
		preload("res://games/Chinese Garter/ropeholder.png"),
	],
	[
		preload("res://games/Chinese Garter/ropeholder3orange.png"),
		preload("res://games/Chinese Garter/ropeholder2orange.png"),
		preload("res://games/Chinese Garter/ropeholderorange.png"),
	],
	[
		null, # The supplied set has no purple low pose; it is palette-matched below.
		preload("res://games/Chinese Garter/ropeholder2purple.png"),
		preload("res://games/Chinese Garter/ropeholderpurple.png"),
	],
	[
		preload("res://games/Chinese Garter/ropeholder3blue.png"),
		preload("res://games/Chinese Garter/ropeholder2blue.png"),
		preload("res://games/Chinese Garter/ropeholderblue.png"),
	],
]
const PURPLE_LOW_PALETTE := {
	0x8fde5dff: Color("e297e2"),
	0x3ca370ff: Color("9a7ac3"),
	0xcfff70ff: Color("ffbfff"),
}

@onready var _left_holder: Sprite2D = $LeftHolder
@onready var _right_holder: Sprite2D = $RightHolder
@onready var _rope: Sprite2D = $Rope

var _holder_player_ids: Array[int] = [2, 4]
var _height: Height = Height.LOW
var _purple_low_texture: Texture2D


func _ready() -> void:
	_purple_low_texture = _make_purple_low_texture()
	_update_sprites()


func start_turn(active_player_id: int) -> void:
	var candidates: Array[int] = [1, 2, 3, 4]
	candidates.erase(active_player_id)
	candidates.shuffle()
	_holder_player_ids.assign([candidates[0], candidates[1]])
	_height = Height.LOW
	_update_sprites()


func update_score(score: int) -> void:
	var next_height := Height.LOW
	if score >= HIGH_SCORE:
		next_height = Height.HIGH
	elif score >= MIDDLE_SCORE:
		next_height = Height.MIDDLE
	if _height == next_height:
		return
	_height = next_height
	_update_sprites()


func _update_sprites() -> void:
	_set_holder_pose(_left_holder, _holder_player_ids[0])
	_set_holder_pose(_right_holder, _holder_player_ids[1])
	# Connect the inward-facing hands, replacing the short rope stubs in some PNGs.
	var left_hand := _left_holder.position.x + _left_holder.region_rect.size.x - 1.0
	var right_hand := _right_holder.position.x - _right_holder.region_rect.size.x + 1.0
	_rope.position = Vector2(left_hand, _left_holder.position.y + HAND_ROWS[_height] - 1.0)
	_rope.scale = Vector2((right_hand - left_hand) / CONNECTOR_WIDTH, 1.0)


func _set_holder_pose(holder: Sprite2D, player_id: int) -> void:
	holder.texture = _purple_low_texture if player_id == 3 and _height == Height.LOW else HOLDER_TEXTURES[player_id - 1][_height]
	var width := 25.0 if _height == Height.HIGH else 23.0
	if _height == Height.LOW:
		# The orange crouch is one pixel wider than the other low poses.
		width = 25.0 if player_id == 2 else 24.0
	holder.region_rect = Rect2(0.0, 0.0, width, 32.0)


func _make_purple_low_texture() -> Texture2D:
	var source: Texture2D = HOLDER_TEXTURES[0][Height.LOW]
	var image := source.get_image()
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			var key := color.to_rgba32()
			if color.a > 0.0 and PURPLE_LOW_PALETTE.has(key):
				image.set_pixel(x, y, PURPLE_LOW_PALETTE[key])
	return ImageTexture.create_from_image(image)
