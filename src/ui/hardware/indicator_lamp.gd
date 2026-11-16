class_name IndicatorLamp
extends Control
## An indicator lamp in a steel bezel. Off: dark glass, an empty ring. On: lit glass in the
## given colour with a bright core and a halo, so on and off differ by shape too.
## Bible: docs/content/interface-rethink.md section 7 (indicator lamps)

const _OFF: Texture2D = preload("res://art/ui/hardware/lamp_off.png")
const _ON: Texture2D = preload("res://art/ui/hardware/lamp_on.png")

var _lit: bool = false
var _colour: Color = Color("#7fd68a")


func _init() -> void:
	custom_minimum_size = Vector2(24, 24)
	mouse_filter = Control.MOUSE_FILTER_PASS


## Lights the lamp in [param colour], or puts it out.
func set_lit(on: bool, colour: Color = Color("#7fd68a")) -> void:
	_lit = on
	_colour = colour
	queue_redraw()


## Whether the lamp is lit.
func is_lit() -> bool:
	return _lit


## The colour it lights in.
func get_colour() -> Color:
	return _colour


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	var r: Rect2 = Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	if not _lit:
		draw_texture_rect(_OFF, r, false)
		return
	draw_circle(size * 0.5, side * 0.62, Color(_colour, 0.18))
	draw_texture_rect(_ON, r, false, _colour)
