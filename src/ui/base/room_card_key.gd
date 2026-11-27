class_name RoomCardKey
extends Button
## One room card of the Base console's BUILD tray (interface-reference.md section 8): a well
## 106 x 128 with the room's 32 px icon, its name (15), the price in amber (mono 15) and the
## size in cells (13, dim); the picked card is outlined amber and its icon lit; a locked room
## is dim with the research it needs on its hover card.
## Bible: docs/content/interface-reference.md section 8

## Card size, in pixels.
const SIZE: Vector2 = Vector2(106, 128)
## Inner margin the title keeps from each side of the card.
const PAD: float = 5.0
## Smallest title size, in pixels, before the text is left as it is.
const MIN_TITLE: int = 11

var def_id: StringName = &""
var title: String = ""
var price: String = ""
var cells: String = ""

var _card: HoverCard = null


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	toggle_mode = true
	custom_minimum_size = SIZE
	RefKeyLook.clear_boxes(self)
	add_theme_color_override(&"font_color", Color(0, 0, 0, 0))
	for event: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited]:
		event.connect(queue_redraw)
	toggled.connect(queue_redraw.unbind(1))


## Sets the hover card to [param help] (translated text or a key).
func set_help(help: String) -> void:
	if _card == null:
		_card = HoverCard.attach(self, help)
	elif help != "":
		_card.set_text(help)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(RefPaint.rounded(rect, 4.0), [Color8(40, 41, 36)])
	RefPaint.outline(self, rect, RefPaint.EDGE, 2.0)
	var dim: bool = disabled
	var ink: Color = RefPaint.DIM if dim else RefPaint.TEXT
	var icon: Color = RefPaint.AMBER if button_pressed else ink
	if RoomIcon.has_icon(def_id):
		RoomIcon.draw(self, Vector2(size.x * 0.5, 34), 32.0, def_id, icon)
	else:
		RefIcons.draw(self, &"plus", Rect2(size.x * 0.5 - 14, 20, 28, 28), icon)
	var lines: PackedStringArray = title_lines(title, size.x - PAD * 2.0)
	var top: float = 68.0 if lines.size() == 1 else 61.0
	for k: int in lines.size():
		var face: RefText = fitted(lines[k], size.x - PAD * 2.0, ink)
		face.draw(self, Vector2(size.x * 0.5, top + k * 15.0), lines[k], "mm")
	var amber: Color = RefPaint.DIM if dim else RefPaint.AMBER
	RefText.make(RefText.MONO_BOLD, 15, amber).draw(self, Vector2(size.x * 0.5, 93), price, "mm")
	RefText.make(RefText.MONO, 13, RefPaint.DIM).draw(self, Vector2(size.x * 0.5, 112), cells, "mm")
	if button_pressed:
		RefPaint.outline(self, rect, RefPaint.AMBER, 3.0)
	elif is_hovered() and not dim:
		draw_polygon(RefPaint.rounded(rect, 4.0), [Color(1, 1, 1, 0.05)])
	if has_focus():
		RefPaint.outline(self, rect.grow(3.0), RefPaint.AMBER_HI, 2.0)


## Splits [param text] into one line, or two balanced at a space when it is wider than
## [param room] at the title size (owner request 2026-11-27: long names were cut).
static func title_lines(text: String, room: float) -> PackedStringArray:
	var face: RefText = RefText.make(RefText.LABEL, 15, Color.WHITE, 1.0)
	if face.width(text) <= room or not " " in text:
		return PackedStringArray([text])
	var best: PackedStringArray = PackedStringArray([text])
	var best_width: float = INF
	var words: PackedStringArray = text.split(" ")
	for cut: int in range(1, words.size()):
		var first: String = " ".join(words.slice(0, cut))
		var second: String = " ".join(words.slice(cut))
		var widest: float = maxf(face.width(first), face.width(second))
		if widest < best_width:
			best_width = widest
			best = PackedStringArray([first, second])
	return best


## The title face for [param line], shrunk until it fits [param room] (down to
## [constant MIN_TITLE]).
static func fitted(line: String, room: float, ink: Color) -> RefText:
	var px: int = 15
	var face: RefText = RefText.make(RefText.LABEL, px, ink, 1.0)
	while px > MIN_TITLE and face.width(line) > room:
		px -= 1
		face = RefText.make(RefText.LABEL, px, ink, 1.0)
	return face
