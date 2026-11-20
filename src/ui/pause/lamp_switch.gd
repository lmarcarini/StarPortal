class_name LampSwitch
extends Button
## An on/off switch of the interface reference: a steel key with a lamp on its left (green
## and glowing when on, dark when off) and its label beside it. A toggle Button, so mouse,
## keyboard and gamepad press it and [signal Button.toggled] reports the change. Draws
## itself: the theme's boxes are cleared.
## Bible: docs/content/interface-reference.md sections 3 and 4

## The label, a translation key or text.
var label: String = "":
	set(value):
		label = value
		queue_redraw()


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	RefKeyLook.clear_boxes(self)
	add_theme_color_override(&"font_color", Color(0, 0, 0, 0))
	toggled.connect(queue_redraw.unbind(1))
	for event: Signal in [focus_entered, focus_exited, mouse_entered, mouse_exited]:
		event.connect(queue_redraw)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var ink: Color = RefPaint.key(self, rect, RefPaint.KeyStyle.STEEL)
	if is_hovered():
		draw_polygon(RefPaint.rounded(rect, 6.0), [Color(1, 1, 1, 0.06)])
	var lamp: Vector2 = Vector2(28, size.y * 0.5)
	if button_pressed:
		RefPaint.lamp_on(self, lamp, 8.0, RefPaint.GREEN)
	else:
		RefPaint.lamp_off(self, lamp, 8.0, true)
	RefText.make(RefText.LABEL, 17, ink, 1.5).draw(
		self, Vector2(54, size.y * 0.5 + 1), tr(label).to_upper(), "lm"
	)
	if has_focus():
		RefPaint.outline(self, rect.grow(3.0), RefPaint.AMBER_HI, 2.0)
