class_name MothFrame
extends Control
## The MOTH's camcorder still, drawn in code: the generated frame (MothFrameRules) under
## scanlines, "REC 00:07  <world>" at the top and "[ SCANNING: … ]" below the middle; once the
## drone is lost, static noise and "SIGNAL LOST" with the reason. Shows what it is given;
## reads and changes no state.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (MOTH) and section 7 (MOTH scan screen)

const _SCANLINE_STEP: float = 3.0
const _SCANLINE: Color = Color(0, 0, 0, 0.22)
const _TEXT: Color = Color(0.92, 0.94, 0.9)
const _REC: Color = Color(0.85, 0.15, 0.12)
const _NOISE_CELLS: int = 160
const _FONT_SIZE: int = 16

var _params: HorizonPhotoRules.Params = null
var _header: String = ""
var _caption: String = ""
var _lost_title: String = ""
var _lost_reason: String = ""


func _init() -> void:
	custom_minimum_size = Vector2(480, 300)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows the frame [param params] with [param header] at the top and [param caption] below.
func show_frame(params: HorizonPhotoRules.Params, header: String, caption: String) -> void:
	_params = params
	_header = header
	_caption = caption
	_lost_title = ""
	_lost_reason = ""
	queue_redraw()


## Shows the lost signal: noise, [param title] and [param reason].
func show_lost(header: String, title: String, reason: String) -> void:
	_params = null
	_header = header
	_caption = ""
	_lost_title = title
	_lost_reason = reason
	queue_redraw()


## Returns the frame's parameters; null while the signal is lost.
func get_params() -> HorizonPhotoRules.Params:
	return _params


## Returns the caption under the middle ("[ SCANNING: … ]"), or the lost title.
func get_caption() -> String:
	return _lost_title if _params == null else _caption


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.05, 0.05, 0.06))
	if _params != null:
		HorizonPainter.paint(self, rect, _params)
	else:
		_draw_noise(rect)
	var y: float = 0.0
	while y < size.y:
		draw_rect(Rect2(0.0, y, size.x, 1.0), _SCANLINE)
		y += _SCANLINE_STEP
	draw_circle(Vector2(16.0, 18.0), 5.0, _REC)
	_draw_text(_header, Vector2(28.0, 8.0), HORIZONTAL_ALIGNMENT_LEFT)
	if _params == null:
		_draw_text(_lost_title, Vector2(0.0, size.y * 0.4), HORIZONTAL_ALIGNMENT_CENTER)
		_draw_text(_lost_reason, Vector2(0.0, size.y * 0.4 + 28.0), HORIZONTAL_ALIGNMENT_CENTER)
	elif not _caption.is_empty():
		_draw_text(_caption, Vector2(0.0, size.y * 0.72), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_noise(rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cell := Vector2(rect.size.x / 16.0, rect.size.y / 10.0)
	for index: int in _NOISE_CELLS:
		var at := Vector2(rng.randi_range(0, 15) * cell.x, rng.randi_range(0, 9) * cell.y)
		draw_rect(Rect2(at, cell), Color(1, 1, 1, rng.randf_range(0.03, 0.18)))


func _draw_text(text: String, top_left: Vector2, align: HorizontalAlignment) -> void:
	if text.is_empty():
		return
	var font: Font = get_theme_default_font()
	var width: float = size.x - top_left.x * 2.0 if align == HORIZONTAL_ALIGNMENT_LEFT else size.x
	var baseline: Vector2 = top_left + Vector2(0.0, font.get_ascent(_FONT_SIZE))
	draw_string_outline(font, baseline, text, align, width, _FONT_SIZE, 4, Color(0, 0, 0, 0.8))
	draw_string(font, baseline, text, align, width, _FONT_SIZE, _TEXT)
