class_name TeamCard
extends Button
## The team in the field (interface-reference.md section 5, team_card): a paper card with an
## amber strip, the team, mission and world (24), the member faces (52 x 52), a ring clock of
## the time left and the due date; the hover card gives what the base last heard. Hidden while
## no team is out, unless a team report waits: then the card names the report and opens it.
## Bible: docs/content/interface-reference.md section 5

## Card size, in pixels.
const SIZE: Vector2 = Vector2(368, 148)

## True while a team report waits to be read (the card then shows a report icon; pressing
## it opens the report).
var report_waiting: bool = false

var _simulation: Simulation = null
var _card: HoverCard = null


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	RefKeyLook.clear_boxes(self)


func _ready() -> void:
	custom_minimum_size = SIZE
	_card = HoverCard.attach(self, " ")


## Reads [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation


## Share of the trip left, 0 to 1.
func time_left() -> float:
	var plan: ExpeditionState = _simulation.state.expedition
	var due: int = TeamContactRules.due_tick_of(plan)
	var span: float = float(maxi(1, due - plan.departed_tick))
	return clampf(float(due - _simulation.state.clock.tick) / span, 0.0, 1.0)


func _process(_delta: float) -> void:
	if _simulation == null:
		return
	var plan: ExpeditionState = _simulation.state.expedition
	visible = plan.is_out() or report_waiting
	if not plan.is_out():
		_card.set_text("HW_ICON_OFFICE")
		queue_redraw()
		return
	var heard: String = GateRoomFormat.date_time(plan.heard_tick) if plan.heard_tick >= 0 else "—"
	_card.set_text(
		tr(&"STATION_TEAM_HEARD").format(
			{
				"world": AddressBookText.name_of_world(plan.world_id, _simulation.state),
				"days": plan.heard_days,
				"of": plan.days(),
				"heard": heard
			}
		)
	)
	queue_redraw()


func _draw() -> void:
	if _simulation == null or not visible:
		return
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	RefPaint.paper(self, rect, RefPaint.AMBER)
	if has_focus():
		RefPaint.outline(self, rect.grow(3.0), RefPaint.AMBER, 2.0)
	var title: RefText = RefText.make(RefText.LABEL, 24, RefPaint.INK, 2.0)
	var plan: ExpeditionState = _simulation.state.expedition
	if not plan.is_out():
		title.draw(self, Vector2(22, 14), tr(&"STATION_TEAM_REPORT_WAITING"))
		RefIcons.draw(self, &"list", Rect2(size.x - 80, 44, 56, 56), RefPaint.INK)
		return
	title.draw(self, Vector2(22, 14), TeamCardText.title(_simulation.state))
	for i: int in ExpeditionState.SLOTS.size():
		var id: StringName = plan.team.get(ExpeditionState.SLOTS[i], &"")
		var person: PersonState = _simulation.state.staff.find_person(id)
		FaceTile.draw_face(self, Rect2(22 + i * 62, 52, 52, 52), person)
	var c: Vector2 = Vector2(size.x - 54, 78)
	draw_arc(c, 31.0, 0, TAU, 48, Color8(160, 150, 125), 6.0, true)
	draw_arc(c, 31.0, -PI / 2, -PI / 2 + TAU * time_left(), 48, Color8(150, 96, 22), 6.0, true)
	var left: RefText = RefText.make(RefText.MONO_BOLD, 15, RefPaint.INK)
	left.draw(self, c, TeamCardText.time_left(_simulation.state), "mm")
	var due: RefText = RefText.make(RefText.LABEL_MEDIUM, 16, Color8(90, 84, 66), 1.0)
	due.draw(self, Vector2(22, size.y - 14), TeamCardText.due(_simulation.state), "ls")
	if plan.mode == ExpeditionState.Mode.MISSING:
		RefIcons.draw(self, &"threat", Rect2(size.x - 40, 10, 24, 24), RefPaint.RED)
