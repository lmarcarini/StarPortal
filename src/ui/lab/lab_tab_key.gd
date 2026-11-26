class_name LabTabKey
extends RefKey
## One discipline tab of the Lab (interface-reference.md section 9, lab_tabs): a steel key
## 208 x 48 with the discipline's icon and name side by side, amber when shown, and an amber
## lamp in its top right corner while the discipline has NEW projects.
## Bible: docs/content/interface-reference.md section 9

## The discipline.
var discipline: StringName = &""
## Whether the discipline has NEW projects (amber lamp).
var has_new: bool = false:
	set(value):
		has_new = value
		queue_redraw()

var _text: String = ""


func _init() -> void:
	super()
	size = Vector2(208, 48)
	custom_minimum_size = size


## Shows [param of] with its translated name.
func show_discipline(of: StringName) -> void:
	discipline = of
	name = String(of)
	_text = LabText.discipline_name(of).to_upper()
	queue_redraw()


## The name drawn, for tests.
func get_name_text() -> String:
	return _text


func _draw() -> void:
	super()
	var ink: Color = RefPaint.INK_OF[shown_style()]
	var box: Rect2 = Rect2(16, size.y * 0.5 - 14, 28, 28)
	RefIcons.draw(self, LabText.icon_of(discipline), box, ink)
	RefText.make(RefText.LABEL, 20, ink, 2.5).draw(self, Vector2(56, size.y * 0.5 + 2), _text, "lm")
	if has_new:
		RefPaint.lamp_on(self, Vector2(size.x - 16, 12), 7.0, RefPaint.AMBER)
