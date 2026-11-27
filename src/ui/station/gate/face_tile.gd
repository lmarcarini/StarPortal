class_name FaceTile
extends Button
## A team member as a face tile (interface-reference.md section 5): a coloured tile with the
## head and shoulders and an injury cross when hurt; the name and role on the hover card.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Teams)

## Background colours of a face, picked by the person's id.
const TONES: Array[Color] = [
	Color8(150, 106, 72), Color8(110, 122, 94), Color8(154, 118, 86), Color8(94, 106, 122)
]

var _person: PersonState = null
var _card: HoverCard = null


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	RefKeyLook.clear_boxes(self)


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(68, 68)


## Shows [param person] (null for an empty slot).
func show_person(person: PersonState) -> void:
	_person = person
	var help: String = "" if person == null else "%s · %s" % [person.name, tr(String(person.role))]
	if _card == null:
		_card = HoverCard.attach(self, help if help != "" else "STATION_EMPTY_SLOT")
	else:
		_card.set_text(help)
	queue_redraw()


## Draws the face of [param person] (null: an empty slot) in [param rect] on [param item]:
## a coloured tile with an ink edge, the head and the shoulders.
static func draw_face(item: CanvasItem, rect: Rect2, person: PersonState) -> void:
	if person == null:
		item.draw_rect(rect, Color(RefPaint.INK, 0.4), false, 2.0)
		return
	item.draw_rect(rect, TONES[hash(person.id) % TONES.size()])
	if not person.appearance.is_empty():
		# The real portrait's face window (owner request 2026-11-27: the Base STAFF keys
		# showed the stand-in silhouette while the Personnel office showed the portrait).
		var full: ImageTexture = PortraitCache.texture_for(person.id, person.appearance)
		item.draw_texture_rect_region(full, rect, Rect2(StaffPortrait.FACE))
	else:
		_draw_stand_in(item, rect)
	item.draw_rect(rect, RefPaint.INK, false, 2.0)
	if person.injury != PersonState.Injury.NONE:
		HardwareIcons.draw(
			item, &"injured", Rect2(rect.end.x - 20, rect.position.y + 2, 18, 18), RefPaint.RED
		)


## The head-and-shoulders silhouette for a person with no portrait record.
static func _draw_stand_in(item: CanvasItem, rect: Rect2) -> void:
	var s: float = rect.size.x / 52.0
	var head: Vector2 = rect.position + Vector2(26, 18) * s
	item.draw_circle(head, 10.0 * s, Color8(214, 190, 160))
	var body: Vector2 = rect.position + Vector2(26, 48) * s
	item.draw_arc(body, 9.0 * s, PI, TAU, 16, Color8(54, 60, 50), 18.0 * s)


func _draw() -> void:
	draw_face(self, Rect2(Vector2.ZERO, size), _person)
	if has_focus():
		RefPaint.outline(self, Rect2(Vector2.ZERO, size).grow(3.0), RefPaint.AMBER, 2.0)
