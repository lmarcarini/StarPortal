class_name PausePlate
extends PanelContainer
## The pause menu's plate: a raised, bolted steel plate of the interface reference with a
## dark recessed title strip ("PAUSED") along its top. Draws itself; children sit inside a
## 28 px margin under the strip.
## Bible: docs/content/interface-reference.md sections 3 and 8

## Height of the title strip, in pixels.
const STRIP: float = 52.0
## Margin round the content, in pixels.
const MARGIN: int = 28

## The title, a translation key.
var title: String = "PAUSE_TITLE"


func _init() -> void:
	name = &"PausePlate"
	var box: StyleBoxEmpty = StyleBoxEmpty.new()
	box.content_margin_left = MARGIN
	box.content_margin_right = MARGIN
	box.content_margin_bottom = MARGIN
	box.content_margin_top = STRIP + MARGIN * 0.75
	add_theme_stylebox_override(&"panel", box)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	RefPaint.steel_plate(self, rect, false, true)
	var strip: Rect2 = Rect2(Vector2(18, 14), Vector2(size.x - 36, STRIP - 10))
	RefPaint.recess(self, strip)
	RefPaint.lamp_on(self, strip.position + Vector2(22, strip.size.y * 0.5), 6.0, RefPaint.AMBER)
	RefText.make(RefText.LABEL, 24, RefPaint.AMBER, 4.0).draw(
		self, strip.position + Vector2(42, strip.size.y * 0.5 + 1), tr(title), "lm"
	)
