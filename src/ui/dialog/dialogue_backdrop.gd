class_name DialogueBackdrop
extends Control
## The dialogue screen's ground in the reference's materials (interface-reference.md
## section 3): the dark ground, the top band of the frame under the strip, a steel plate
## behind the portrait and name plate, and one behind the answers. Never takes the mouse.
## Bible: docs/content/interface-reference.md section 3; docs/content/dialogue-screen.md

## Height of the top band, in pixels.
const BAND: float = 72.0
## Steel showing round a plate's contents, in pixels.
const PAD: float = 12.0

var _plates: Array[Control] = []


func _init() -> void:
	name = &"Backdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Draws a steel plate behind each of [param controls].
func set_plates(controls: Array[Control]) -> void:
	_plates = controls
	for control: Control in controls:
		control.resized.connect(queue_redraw)
		control.item_rect_changed.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DialogueScreen.GROUND)
	RefPaint.gradient(
		self, Rect2(0, 0, size.x, BAND), 0.0, [Color8(24, 25, 22), Color8(14, 15, 13)]
	)
	draw_line(Vector2(0, BAND - 1), Vector2(size.x, BAND - 1), RefPaint.EDGE, 2.0)
	for control: Control in _plates:
		if not control.is_visible_in_tree():
			continue
		var rect: Rect2 = control.get_global_rect()
		rect.position -= global_position
		RefPaint.steel_plate(self, rect.grow(PAD), false, true)
