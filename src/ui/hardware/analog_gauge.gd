class_name AnalogGauge
extends Control
## A round analogue gauge: a needle over a 240-degree scale, a red zone at the top end, an
## optional "need" mark (a triangle outside the scale) and one number on a readout below.
## Bible: docs/content/interface-rethink.md sections 4 (power) and 7 (analogue gauge)

const _FACE: Texture2D = preload("res://art/ui/hardware/gauge_face.png")
const _INK: Color = Color("#24221d")
const _RED: Color = Color("#c8432f")
const _NEED: Color = Color("#1f6fb0")
const _SWEEP: float = deg_to_rad(240.0)
const _START: float = deg_to_rad(150.0)

## Scale bottom.
@export var min_value: float = 0.0
## Scale top.
@export var max_value: float = 100.0
## Red zone from this value up; above max_value for none.
@export var red_from: float = 1.0e9
## Need mark; below min_value for none.
@export var need_mark: float = -1.0e9

var _value: float = 0.0
var _readout: String = ""


func _init() -> void:
	custom_minimum_size = Vector2(120, 132)
	focus_mode = Control.FOCUS_ALL


## Sets the needle to [param value] and the readout to [param readout].
func set_value(value: float, readout: String = "") -> void:
	_value = value
	_readout = readout
	queue_redraw()


## The needle's value.
func get_value() -> float:
	return _value


## Angle in radians of [param value] on the scale (clamped to it).
func angle_of(value: float) -> float:
	var span: float = maxf(max_value - min_value, 0.0001)
	return _START + _SWEEP * clampf((value - min_value) / span, 0.0, 1.0)


func _draw() -> void:
	var side: float = minf(size.x, size.y - 18.0)
	var c: Vector2 = Vector2(size.x * 0.5, side * 0.5)
	var r: float = side * 0.5
	draw_texture_rect(_FACE, Rect2(c - Vector2(r, r), Vector2(side, side)), false)
	var inner: float = r * 0.84
	if red_from < max_value:
		draw_arc(c, inner * 0.92, angle_of(red_from), angle_of(max_value), 24, _RED, r * 0.1)
	for i: int in 11:
		var a: float = _START + _SWEEP * i / 10.0
		var len: float = 0.16 if i % 5 == 0 else 0.09
		draw_line(
			c + Vector2.from_angle(a) * inner,
			c + Vector2.from_angle(a) * inner * (1.0 - len),
			_INK,
			2.0
		)
	if need_mark >= min_value:
		var a2: float = angle_of(need_mark)
		var tip: Vector2 = c + Vector2.from_angle(a2) * inner * 0.98
		var side_v: Vector2 = Vector2.from_angle(a2 + PI / 2) * r * 0.08
		var back: Vector2 = Vector2.from_angle(a2) * r * 0.14
		draw_colored_polygon(
			PackedVector2Array([tip, tip + back + side_v, tip + back - side_v]), _NEED
		)
	var tip2: Vector2 = c + Vector2.from_angle(angle_of(_value)) * inner * 0.9
	draw_line(c, tip2, _RED.darkened(0.2), 3.0, true)
	draw_circle(c, r * 0.08, _INK)
	var font: Font = UiThemeBuilder.data_font()
	draw_string(
		font,
		Vector2(0, size.y - 2),
		_readout,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		16,
		Color("#d8d2bd")
	)
