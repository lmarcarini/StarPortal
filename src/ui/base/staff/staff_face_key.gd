class_name StaffFaceKey
extends Button
## One person in the STAFF tray (interface-reference.md section 8): a 104 px tile with the
## face, the name (15) and "role letter · room" (13), amber while chosen. Drag it onto a
## room's empty slot or back onto the tray; a press chooses the person (keys and gamepad then
## place them on the plan).
## Bible: docs/content/interface-reference.md section 8

## A drag of this tile began (the plan highlights the rooms that take the person).
signal drag_started(person_id: StringName)

## Tile size, in pixels.
const SIZE: Vector2 = Vector2(104, 124)

var person_id: StringName = &""
var person: PersonState = null
var room_line: String = ""


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	toggle_mode = true
	custom_minimum_size = SIZE
	RefKeyLook.clear_boxes(self)
	add_theme_color_override(&"font_color", Color(0, 0, 0, 0))
	toggled.connect(queue_redraw.unbind(1))
	for event: Signal in [focus_entered, focus_exited, mouse_entered, mouse_exited]:
		event.connect(queue_redraw)


func _get_drag_data(_at: Vector2) -> Variant:
	StaffDragLine.begin(self)
	drag_started.emit(person_id)
	return {"person": person_id}


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var chosen: bool = button_pressed
	draw_rect(rect, Color8(40, 41, 36))
	draw_rect(rect, RefPaint.AMBER if chosen else RefPaint.EDGE, false, 3.0 if chosen else 2.0)
	if person != null:
		FaceTile.draw_face(self, Rect2(26, 8, 52, 52), person)
		var name_text: String = person.name.get_slice(" ", person.name.get_slice_count(" ") - 1)
		RefText.make(RefText.LABEL, 15, RefPaint.TEXT, 1.0).draw(
			self, Vector2(52, 78), name_text.to_upper(), "mm"
		)
	var ink: Color = RefPaint.AMBER if chosen else RefPaint.DIM
	RefText.make(RefText.MONO, 13, ink).draw(self, Vector2(52, 102), room_line, "mm")
	if has_focus():
		RefPaint.outline(self, rect.grow(3.0), RefPaint.AMBER_HI, 2.0)
