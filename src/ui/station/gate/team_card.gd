class_name TeamCard
extends Button
## The team in the field, low on the left of the Gate station: a clock ring of the time left
## and the team's world; the hover card gives what the base last heard (days, when). Hidden
## while no team is out, unless a team report waits: then a report icon that opens it.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Teams)

const _LIT: Color = Color("#e8a33d")

## True while a team report waits to be read (the card then shows a report icon; pressing
## it opens the report).
var report_waiting: bool = false

var _simulation: Simulation = null
var _card: HoverCard = null


func _init() -> void:
	theme_type_variation = &"IconKey"
	focus_mode = Control.FOCUS_ALL


func _ready() -> void:
	custom_minimum_size = HwMetrics.target(self, Vector2(150, 80))
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
	if not _simulation.state.expedition.is_out():
		HardwareIcons.draw(
			self, &"office", Rect2(size.y * 0.2, size.y * 0.2, size.y * 0.6, size.y * 0.6), _LIT
		)
		return
	var c: Vector2 = Vector2(size.y * 0.5, size.y * 0.5)
	var r: float = size.y * 0.32
	draw_arc(c, r, 0, TAU, 32, Color("#3a3128"), 6.0)
	draw_arc(c, r, -PI / 2, -PI / 2 + TAU * time_left(), 32, UiThemeHardware.AMBER, 6.0)
	HardwareIcons.draw(
		self, &"team", Rect2(size.y, size.y * 0.2, size.y * 0.6, size.y * 0.6), Color("#ece6d2")
	)
	var plan: ExpeditionState = _simulation.state.expedition
	if plan.mode == ExpeditionState.Mode.MISSING:
		HardwareIcons.draw(self, &"threat", Rect2(size.x - 28, 4, 24, 24), Color("#e5533d"))
