class_name LabBench
extends Button
## One research building on the Lab console (interface-reference.md section 9, lab_benches):
## 268 x 144, the building and its staff of the right field ("2/4 SCI."), the current
## project with a progress bar and its queue as small icon chips; an idle bench says IDLE with
## a lit amber lamp. A press makes it the target bench for START and ADD TO QUEUE (amber
## outline).
## Bible: docs/content/interface-reference.md section 9

## The bench was pressed.
signal picked(room_id: StringName)

const WIDTH: float = 268.0
const CHIP: float = 32.0

## The room (research building) shown.
var room_id: StringName = &""
## Whether this is the target bench.
var target: bool = false:
	set(value):
		target = value
		queue_redraw()

var _name: String = ""
var _staff: String = ""
var _project: String = ""
var _progress: float = 0.0
var _icon: StringName = &"lab"
var _chips: Array[StringName] = []


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 144)
	focus_mode = Control.FOCUS_ALL
	flat = true
	for box: StringName in [&"normal", &"hover", &"pressed", &"focus", &"hover_pressed"]:
		add_theme_stylebox_override(box, StyleBoxEmpty.new())
	pressed.connect(func() -> void: picked.emit(room_id))
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Shows [param room]'s bench in [param state].
func show_room(state: GameState, room: RoomState) -> void:
	room_id = room.id
	name = String(room.id)
	_name = LabText.bench_name(state, room)
	_staff = LabText.staff_line(state, room)
	var def: RoomDef = state.room_defs.get(room.def_id)
	_icon = LabText.icon_of(&"" if def == null else def.research_discipline)
	var bench: ResearchBench = state.research.bench_of(room.id)
	var running: bool = bench != null and bench.is_running()
	_project = ResearchText.name_of(state, bench.active).to_upper() if running else ""
	_progress = ResearchSpeed.progress(state, room.id)
	_chips.clear()
	if bench != null:
		for queued: StringName in bench.queue:
			var queued_def: ResearchDef = state.research_defs.get(queued)
			_chips.append(&"lab" if queued_def == null else LabText.icon_of(queued_def.discipline))
	queue_redraw()


## True when no project runs here.
func is_idle() -> bool:
	return _project.is_empty()


## The building name, staff line and project drawn, for tests.
func texts() -> Array[String]:
	return [_name, _staff, _project]


## How many queue chips are drawn.
func chip_count() -> int:
	return _chips.size()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	RefPaint.recess(self, rect)
	if target:
		RefPaint.outline(self, rect.grow(-1.0), RefPaint.AMBER, 2.0)
	elif has_focus() or is_hovered():
		RefPaint.outline(self, rect.grow(-1.0), RefPaint.AMBER_HI, 1.0)
	RefIcons.draw(self, _icon, Rect2(14, 12, 22, 22), RefPaint.AMBER)
	RefText.make(RefText.LABEL, 17, RefPaint.TEXT, 2.0).draw(self, Vector2(42, 24), _name, "lm")
	RefText.make(RefText.MONO, 12, RefPaint.DIM, 1.0).draw(
		self, Vector2(size.x - 12, 24), _staff, "rm"
	)
	if is_idle():
		_draw_idle()
		return
	RefText.make(RefText.LABEL, 17, RefPaint.TEXT, 1.5).draw(self, Vector2(16, 60), _project, "lm")
	var bar: Rect2 = Rect2(16, 78, size.x - 32, 10)
	draw_rect(bar, Color8(20, 21, 18))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _progress, bar.size.y)), RefPaint.AMBER)
	for index: int in _chips.size():
		var chip: Rect2 = Rect2(16 + index * (CHIP + 8), 100, CHIP, CHIP)
		RefPaint.key(self, chip, RefPaint.KeyStyle.STEEL)
		RefIcons.draw(self, _chips[index], chip.grow(-8.0), RefPaint.TEXT)


func _draw_idle() -> void:
	RefText.make(RefText.LABEL, 17, RefPaint.AMBER, 2.5).draw(
		self, Vector2(size.x * 0.5, 78), tr(&"LAB_IDLE_PICK"), "mm"
	)
	RefPaint.lamp_on(self, Vector2(size.x * 0.5, 114), 8.0, RefPaint.AMBER)
