class_name GlyphKey
extends Button
## One of the alien panel's 36 keys, round, in the reference's key material: a steel face on
## a 4 px dark base, the glyph drawn large in the text colour; lit (amber ring on a dark amber
## face, amber glyph) when it is in the address, pulsing when a typed name finds it. At least
## 72 px. The glyph's name is only on the hover card.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Composing)

## The key was pressed.
signal glyph_pressed(glyph: int)

## Key side at 1080p and 100%, never under it.
const SIDE: float = 76.0
## Smallest side, in pixels.
const MIN_SIDE: float = 72.0

var _glyph: int = -1
var _lit: bool = false
var _marked: bool = false
var _pulse: float = 0.0
var _icon: GlyphIcon = GlyphIcon.new()


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	flat = true


func _ready() -> void:
	custom_minimum_size = HwMetrics.target(self, Vector2(SIDE, SIDE))
	size = custom_minimum_size
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_lit(false)
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
	var ink: Color = RefPaint.AMBER if on else RefPaint.TEXT
	_icon.add_theme_color_override(&"line_color", Color(ink, 0.8))
	_icon.add_theme_color_override(&"star_color", ink)
	queue_redraw()


## True when lit.
func is_lit() -> bool:
	return _lit


## Marks the key as a glyph seen in the clipped document (Glyph frequency, S04).
func set_marked(on: bool) -> void:
	_marked = on
	queue_redraw()


## True when marked.
func is_marked() -> bool:
	return _marked


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
	draw_circle(c + Vector2(0, 4), r, Color8(8, 8, 7))
	var top: Color = Color8(90, 70, 36) if _lit else Color8(78, 79, 69)
	var bottom: Color = Color8(52, 40, 20) if _lit else Color8(44, 45, 40)
	if button_pressed:
		top = top.darkened(0.2)
	draw_circle(c, r, bottom)
	draw_circle(c - Vector2(0, r * 0.18), r * 0.8, top.lerp(bottom, 0.35))
	draw_arc(c, r - 1.0, 0, TAU, 48, RefPaint.EDGE, 2.0, true)
	draw_arc(c, r - 3.0, PI * 1.15, PI * 1.85, 16, Color8(120, 121, 106), 2.0, true)
	if _lit:
		draw_arc(c, r - 2.5, 0, TAU, 48, RefPaint.AMBER, 3.0, true)
	if _marked:
		draw_circle(c + Vector2(r * 0.62, -r * 0.62), 4.0, RefPaint.AMBER)
	if is_hovered():
		draw_circle(c, r, Color(1, 1, 1, 0.06))
	if _pulse > 0.0:
		var ring: float = r + 4.0 + 6.0 * (1.0 - _pulse)
		draw_arc(c, ring, 0, TAU, 40, Color(RefPaint.AMBER, _pulse), 3.0, true)
	if has_focus():
		draw_arc(c, r + 3.0, 0, TAU, 40, RefPaint.AMBER_HI, 2.0, true)
