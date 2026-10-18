extends CanvasLayer

const FADE_TIME := 0.5

var _cover: ColorRect
var _tween: Tween
var _fade_id := 0
var _busy := false


func _ready() -> void:
	layer = 100
	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)
	fade_in()


func fade_in() -> void:
	_fade_id += 1
	var id := _fade_id
	_cover.visible = true
	_cover.modulate.a = 1.0
	await get_tree().process_frame
	await get_tree().process_frame
	if id != _fade_id:
		return
	var tween := _start_fade(0.0)
	await tween.finished
	if id == _fade_id:
		_cover.visible = false


func fade_out() -> void:
	_fade_id += 1
	var tween := _start_fade(1.0)
	await tween.finished


func change_scene(path: String) -> void:
	if _busy or not ResourceLoader.exists(path):
		return
	_busy = true
	await fade_out()
	get_tree().change_scene_to_file(path)
	await fade_in()
	_busy = false


func change_scene_to_packed(packed: PackedScene) -> void:
	if _busy or packed == null:
		return
	_busy = true
	await fade_out()
	get_tree().change_scene_to_packed(packed)
	await fade_in()
	_busy = false


func _start_fade(target: float) -> Tween:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_cover.visible = true
	_tween = create_tween()
	_tween.tween_property(_cover, "modulate:a", target, FADE_TIME)
	return _tween
