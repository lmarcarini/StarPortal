class_name SealLampRow
extends Control
## The dial block's eight seal lamps in a row (interface-reference.md section 5), lit amber as
## the Ring's seals lock (the eighth is CAIRN's mark); all lit while a wormhole is open.
## Bible: docs/content/interface-reference.md section 5 (dial_block)

## Lamp radius and pitch, in pixels.
const RADIUS: float = 10.0
const PITCH: float = 50.0

var _lit: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Lights the lamps for [param look].
func show_look(look: RingLook) -> void:
	var lit: int = clampi(look.seals, 0, RingLook.SEALS)
	if lit != _lit:
		_lit = lit
		queue_redraw()


## Lamps lit now.
func lit_count() -> int:
	return _lit


func _draw() -> void:
	for i: int in RingLook.SEALS:
		var centre: Vector2 = Vector2(25.0 + i * PITCH, 18.0)
		if i < _lit:
			RefPaint.lamp_on(self, centre, RADIUS, RefPaint.AMBER)
		else:
			RefPaint.lamp_off(self, centre, RADIUS, false)
