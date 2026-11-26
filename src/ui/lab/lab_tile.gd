class_name LabTile
extends Button
## One project on the Lab board (interface-reference.md section 9, lab_board): 260 x 68, a
## round icon well with a progress ring (green when done, amber in progress), the name (17)
## and one status line in mono (DONE in green, time and cost dim, progress amber, QUEUED n,
## NEW with a lamp). The selected tile has an amber outline. A click or focus emits
## [signal chosen]; (A) or Enter emits [signal activated].
## Bible: docs/content/interface-reference.md section 9

## The tile was clicked or took focus.
signal chosen(project_id: StringName)
## (A) or Enter on the tile.
signal activated(project_id: StringName)

const WELL_RADIUS: float = 22.0
const STATUS_INK: Dictionary[LabText.Status, Color] = {
	LabText.Status.DONE: RefPaint.GREEN,
	LabText.Status.RUNNING: RefPaint.AMBER,
	LabText.Status.QUEUED: RefPaint.AMBER,
	LabText.Status.NEW: RefPaint.AMBER,
	LabText.Status.OPEN: RefPaint.DIM,
}

## The project shown.
var project_id: StringName = &""
## Whether this is the selected project.
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _name: String = ""
var _line: String = ""
var _icon: StringName = &"lab"
var _status: LabText.Status = LabText.Status.OPEN
var _progress: float = 0.0


func _init() -> void:
	custom_minimum_size = LabLayout.TILE
	size = LabLayout.TILE
	focus_mode = Control.FOCUS_ALL
	flat = true
	for box: StringName in [&"normal", &"hover", &"pressed", &"focus", &"hover_pressed"]:
		add_theme_stylebox_override(box, StyleBoxEmpty.new())
	pressed.connect(func() -> void: chosen.emit(project_id))
	focus_entered.connect(func() -> void: chosen.emit(project_id))
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Shows [param def] as it stands in [param state].
func show_project(state: GameState, def: ResearchDef) -> void:
	project_id = def.id
	name = String(def.id)
	_name = TranslationServer.translate(def.name_key).to_upper()
	_line = LabText.status_line(state, def).to_upper()
	_icon = LabText.icon_of(def.discipline)
	_status = LabText.status(state, def)
	var room: StringName = state.research.room_running(def.id)
	_progress = 1.0 if _status == LabText.Status.DONE else ResearchSpeed.progress(state, room)
	queue_redraw()


## The status shown.
func get_status() -> LabText.Status:
	return _status


## The name and status line drawn, for tests.
func texts() -> Array[String]:
	return [_name, _line]


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		activated.emit(project_id)
		accept_event()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var ink: Color = STATUS_INK[_status]
	var fill: Color = Color8(28, 30, 26) if _status != LabText.Status.DONE else Color8(26, 38, 30)
	draw_polygon(RefPaint.rounded(rect, 4.0), [fill])
	var edge: Color = ink if _status != LabText.Status.OPEN else RefPaint.BEVEL
	if selected:
		RefPaint.outline(self, rect.grow(3.0), RefPaint.AMBER, 2.0)
	RefPaint.outline(self, rect, edge, 2.0)
	if is_hovered() or has_focus():
		draw_polygon(RefPaint.rounded(rect, 4.0), [Color(1, 1, 1, 0.05)])
	_draw_well(ink)
	_name_style().draw(self, Vector2(68, 25), _name, "lm")
	RefText.make(RefText.MONO, 13, ink, 1.0).draw(self, Vector2(68, 48), _line, "lm")
	if _status == LabText.Status.NEW:
		RefPaint.lamp_on(self, Vector2(size.x - 16, 14), 7.0, RefPaint.AMBER)


## The name's style: 17 px, smaller down to 13 when the name would run into the lamp.
func _name_style() -> RefText:
	var room: float = size.x - 68 - 26
	var style: RefText = RefText.make(RefText.LABEL, 17, RefPaint.TEXT, 1.5)
	while style.size > 13 and style.width(_name) > room:
		style = RefText.make(RefText.LABEL, style.size - 1, RefPaint.TEXT, 1.0)
	return style


func _draw_well(ink: Color) -> void:
	var centre: Vector2 = Vector2(34, size.y * 0.5)
	draw_circle(centre, WELL_RADIUS, Color8(14, 15, 13))
	draw_arc(centre, WELL_RADIUS, 0.0, TAU, 40, RefPaint.BEVEL, 3.0, true)
	if _progress > 0.0:
		draw_arc(centre, WELL_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * _progress, 40, ink, 3.0, true)
	var side: float = 22.0
	var icon_ink: Color = RefPaint.TEXT if _status != LabText.Status.DONE else RefPaint.GREEN
	RefIcons.draw(
		self, _icon, Rect2(centre - Vector2(side, side) * 0.5, Vector2(side, side)), icon_ink
	)
