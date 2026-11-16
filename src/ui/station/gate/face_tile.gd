class_name FaceTile
extends Button
## A team member as a face tile: a code-drawn head and shoulders, the initials, and an injury
## cross when hurt; the name and role on the hover card. Empty slot: a dashed outline.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Teams)

var _person: PersonState = null
var _card: HoverCard = null


func _init() -> void:
	theme_type_variation = &"IconKey"
	focus_mode = Control.FOCUS_ALL


func _ready() -> void:
	custom_minimum_size = HwMetrics.target(self, Vector2(64, 76))


## Shows [param person] (null for an empty slot).
func show_person(person: PersonState) -> void:
	_person = person
	var help: String = "" if person == null else "%s · %s" % [person.name, tr(String(person.role))]
	if _card == null:
		_card = HoverCard.attach(self, help if help != "" else "STATION_EMPTY_SLOT")
	else:
		_card.set_text(help)
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = Vector2(size.x * 0.5, size.y * 0.38)
	var ink: Color = Color("#ece6d2")
	if _person == null:
		draw_arc(c, size.x * 0.2, 0, TAU, 16, Color(ink, 0.3), 2.0)
		return
	draw_circle(c, size.x * 0.17, Color("#b48a6a"))
	draw_rect(
		Rect2(size.x * 0.25, c.y + size.x * 0.17, size.x * 0.5, size.y * 0.2), Color("#4b5a3c")
	)
	var initials: String = ""
	for word: String in _person.name.split(" ", false):
		initials += word.left(1)
	draw_string(
		UiThemeBuilder.data_font(),
		Vector2(0, size.y - 4),
		initials,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		13,
		ink
	)
	if _person.injury != PersonState.Injury.NONE:
		HardwareIcons.draw(self, &"injured", Rect2(size.x - 22, 2, 20, 20), Color("#e5533d"))
