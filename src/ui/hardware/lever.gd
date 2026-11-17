class_name Lever
extends Button
## A two-position lever in a slotted steel plate (the interface reference's Shutter): handle
## up (off, open) or down (on, closed), the label below. Toggles
## on click, Enter or gamepad A; emits Button.toggled. The handle's position shows the state.
## Bible: docs/content/interface-rethink.md sections 4 (Shutter lever) and 7


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	flat = true
	RefKeyLook.clear_boxes(self)


func _ready() -> void:
	custom_minimum_size = Vector2(128, 168)
	toggled.connect(func(_on: bool) -> void: queue_redraw())


## Whether the lever is down.
func is_down() -> bool:
	return button_pressed


func _draw() -> void:
	RefPaint.steel_plate(self, Rect2(Vector2.ZERO, size), false, true)
	var slot: Rect2 = Rect2(size.x * 0.5 - 12.0, 20.0, 24.0, size.y - 68.0)
	draw_polygon(RefPaint.rounded(slot, 12.0), [Color8(10, 10, 9)])
	var y: float = slot.end.y - 46.0 if button_pressed else 26.0
	var handle: Rect2 = Rect2(size.x * 0.5 - 34.0, y, 68.0, 40.0)
	RefPaint.key(self, handle, RefPaint.KeyStyle.OFF if disabled else RefPaint.KeyStyle.STEEL)
	var label: RefText = RefText.make(RefText.LABEL, 20, RefPaint.DIM, 2.0)
	label.draw(self, Vector2(size.x * 0.5, size.y - 22.0), tr(&"STATION_SHUTTER"), "mm")
	if has_focus():
		RefPaint.outline(self, Rect2(Vector2.ZERO, size).grow(2.0), RefPaint.AMBER_HI, 2.0)
