class_name GlyphKey
extends Button
## One of the alien panel's 36 stone keys: the glyph drawn large, lit when it is in the
## address, pulsing when a typed name finds it. The glyph's name is only on the hover card.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Composing)

## The key was pressed.
signal glyph_pressed(glyph: int)

## Key side at 1080p and 100%, never under it.
const SIDE: float = 76.0
const _STONE: Color = Color("#5c574d")
const _LIT: Color = Color("#ffb347")

var _glyph: int = -1
var _lit: bool = false
var _pulse: float = 0.0
var _icon: GlyphIcon = GlyphIcon.new()


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	flat = true


func _ready() -> void:
	custom_minimum_size = HwMetrics.target(self, Vector2(SIDE, SIDE))
	size = custom_minimum_size
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	add_child(_icon)
	pressed.connect(func() -> void: glyph_pressed.emit(_glyph))
	set_process(false)


## Shows glyph [param glyph] with its name (translation key) on the hover card.
func setup(glyph: int, name_key: String) -> void:
	_glyph = glyph
	_icon.glyph_index = glyph
	HoverCard.attach(self, name_key)


## The glyph.
func get_glyph() -> int:
	return _glyph


## Lights or darkens the key.
func set_lit(on: bool) -> void:
	_lit = on
	queue_redraw()


## True when lit.
func is_lit() -> bool:
	return _lit


## Pulses the key for a second (a typed name found it).
func pulse() -> void:
	_pulse = 1.0
	set_process(true)


## True while pulsing.
func is_pulsing() -> bool:
	return _pulse > 0.0


func _process(delta: float) -> void:
	_pulse = maxf(0.0, _pulse - delta)
	if _pulse <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5
	draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.5))
	draw_circle(c, r, _STONE.darkened(0.25 if button_pressed else 0.0))
	draw_arc(c, r - 2.0, PI, TAU, 24, _STONE.lightened(0.25), 2.0, true)
	if _lit:
		draw_arc(c, r - 3.0, 0, TAU, 40, _LIT, 4.0, true)
		draw_circle(c, r * 0.9, Color(_LIT, 0.18))
	if _pulse > 0.0:
		draw_arc(c, r + 4.0 + 6.0 * (1.0 - _pulse), 0, TAU, 40, Color(_LIT, _pulse), 3.0, true)
	if has_focus():
		draw_arc(c, r + 3.0, 0, TAU, 40, UiThemeHardware.AMBER, 3.0, true)
