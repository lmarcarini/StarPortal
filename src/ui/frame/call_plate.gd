class_name CallPlate
extends Button
## The top bar's call plate (interface-reference.md section 4, top_call): a lamp and the
## phone icon; the caller in amber while a call waits, dim NO CALL otherwise. A click answers
## (through the time bar's call lamp, which submits the command).
## Bible: docs/content/interface-reference.md section 4

var _call: Button = null


func _init() -> void:
	name = &"CallPlate"
	focus_mode = Control.FOCUS_ALL
	for box: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		add_theme_stylebox_override(box, StyleBoxEmpty.new())
	pressed.connect(_on_pressed)


## Follows [param call_button] (the time bar's call lamp).
func setup(call_button: Button) -> void:
	_call = call_button


## Whether a call waits and may be answered now.
func is_waiting() -> bool:
	return _call != null and _call.visible


## Redraws from the call lamp.
func refresh() -> void:
	disabled = not is_waiting() or _call.disabled
	focus_mode = Control.FOCUS_ALL if is_waiting() else Control.FOCUS_NONE
	tooltip_text = _call.tooltip_text if is_waiting() else ""
	queue_redraw()


func _on_pressed() -> void:
	if is_waiting() and not _call.disabled:
		_call.pressed.emit()
		refresh()


func _draw() -> void:
	RefPaint.steel_plate(self, Rect2(Vector2.ZERO, size), false, true)
	var waiting: bool = is_waiting()
	if waiting:
		RefPaint.lamp_on(self, Vector2(26, 30), 9.0, RefPaint.AMBER)
	else:
		RefPaint.lamp_off(self, Vector2(26, 30), 9.0, false)
	var ink: Color = RefPaint.AMBER if waiting else RefPaint.DIM
	RefIcons.draw(self, &"phone", Rect2(45, 15, 26, 26), ink)
	var text: String = _call.text.to_upper() if waiting else tr(&"FRAME_NO_CALL")
	var style: RefText = RefText.make(RefText.LABEL, 22, ink, 2.0)
	while style.size > 15 and style.width(text) > size.x - 94.0:
		style.size -= 1
	style.draw(self, Vector2(82, 30), text, "lm")
	if has_focus():
		RefPaint.outline(self, Rect2(Vector2.ZERO, size).grow(2.0), RefPaint.AMBER_HI, 2.0)
