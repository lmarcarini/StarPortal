class_name Lever
extends Button
## A two-position lever in a slotted plate: handle up (off, open) or down (on, closed). Toggles
## on click, Enter or gamepad A; emits Button.toggled. The handle's position shows the state.
## Bible: docs/content/interface-rethink.md sections 4 (Shutter lever) and 7

const _SLOT: Color = Color("#121311")
const _HANDLE: Color = Color("#c8432f")
const _ROD: Color = Color("#8e8b80")


func _init() -> void:
	toggle_mode = true
	theme_type_variation = &"RecessedPanel"
	focus_mode = Control.FOCUS_ALL
	flat = true


func _ready() -> void:
	custom_minimum_size = HwMetrics.target(self, Vector2(56, 112))
	toggled.connect(func(_on: bool) -> void: queue_redraw())


## Whether the lever is down.
func is_down() -> bool:
	return button_pressed


func _draw() -> void:
	var s: float = HwMetrics.scale_of(self)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2b2a27"))
	var slot: Rect2 = Rect2(size.x * 0.5 - 4 * s, 10 * s, 8 * s, size.y - 20 * s)
	draw_rect(slot, _SLOT)
	var pivot: Vector2 = Vector2(size.x * 0.5, size.y * 0.5)
	var end_y: float = size.y - 18 * s if button_pressed else 18 * s
	var knob: Vector2 = Vector2(size.x * 0.5, end_y)
	draw_line(pivot, knob, _ROD, 6 * s)
	draw_circle(knob, 12 * s, _HANDLE if not disabled else _HANDLE.darkened(0.6))
	draw_circle(pivot, 6 * s, _ROD.darkened(0.3))
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), UiThemeHardware.AMBER, false, 3 * s)
