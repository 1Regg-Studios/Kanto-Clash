extends Control

const DESIGN_SIZE := Vector2(1920.0, 1080.0)

@export_file("*.tscn") var next_scene_path := ""

var key_up_texture: Texture2D
var key_down_texture: Texture2D
var music_track: AudioStream

@onready var _composition: Control = $Composition
@onready var _key: TextureRect = $Composition/Key
@onready var _key_label: Label = $Composition/AssignedKey
@onready var _continue: Label = $Composition/Continue

var _key_home := Vector2.ZERO
var _input_enabled := false
var _starting := false


func _ready() -> void:
	AudioManager.stop_menu_music()
	AudioManager.play_game_music(music_track)
	_key_home = _key.position
	_key_label.text = _assigned_key()
	_on_demo_key_changed(false)
	resized.connect(_layout_content)
	_layout_content()
	var blink := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	blink.tween_property(_continue, "modulate:a", 0.45, 0.65)
	blink.tween_property(_continue, "modulate:a", 1.0, 0.65)
	# Let the incoming fade finish before accepting a new key press.
	await get_tree().create_timer(0.65).timeout
	_input_enabled = true


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or not _input_enabled or _starting:
		return
	if event.is_action_pressed("Toggle_Fullscreen"):
		return
	get_viewport().set_input_as_handled()
	_starting = true
	AudioManager.play_click()
	GameSchedule.next_scene_path = next_scene_path
	await SceneFader.change_scene(next_scene_path)


func _layout_content() -> void:
	var fit := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_composition.scale = Vector2.ONE * fit
	_composition.position = (size - DESIGN_SIZE * fit) * 0.5


func _on_demo_key_changed(pressed: bool) -> void:
	_key.texture = key_down_texture if pressed else key_up_texture
	_key.position = _key_home + Vector2(0.0, 8.0 if pressed else 0.0)
	_key.modulate = Color.WHITE if pressed else Color(0.65, 0.65, 0.65)
	_key_label.add_theme_color_override("font_color", Color.WHITE if pressed else Color("fbc052"))


func _assigned_key() -> String:
	for event in InputMap.action_get_events(&"P1_Ready"):
		if event is InputEventKey:
			var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			return ";" if key == KEY_SEMICOLON else OS.get_keycode_string(key)
	return "P1"
