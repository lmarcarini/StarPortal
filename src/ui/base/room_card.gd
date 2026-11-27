class_name RoomCard
extends Control
## The Base's room panel (interface-reference.md section 8, room_panel; it replaces the Gate's
## destinations panel): the selected room's icon and name (24), what it is doing with a
## progress bar, a POWER key showing its state and MW (a press toggles it through the power
## switch), the staff line with faces (filled) and empty slots (+), then the [RoomPanel]
## below: INSTALLED with + INSTALL and DEMOLISH at the foot. Reads the state only.
## Bible: docs/content/interface-reference.md section 8

## Emitted when the POWER key is pressed for [param room_id].
signal power_pressed(room_id: StringName)

const FACE: float = 74.0
const FACE_PITCH: float = 84.0
const STAFF_Y: float = 194.0
## Where the [RoomPanel] (installed items, the action) starts.
const PANEL_Y: float = 318.0

var power_key: RefKey = RefKey.new()

var _room: RoomState = null
var _def: RoomDef = null


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS
	power_key.name = "PowerKey"
	power_key.label_size = 16
	power_key.size = Vector2(132, 40)
	power_key.pressed.connect(
		func() -> void: power_pressed.emit(_room.id if _room != null else &"")
	)
	add_child(power_key)
	resized.connect(_layout)


## Shows [param room] built from [param def] (null: nothing selected).
func show_room(room: RoomState, def: RoomDef) -> void:
	_room = room
	_def = def
	_layout()
	queue_redraw()


func _process(_delta: float) -> void:
	if _room != null:
		queue_redraw()


func _layout() -> void:
	power_key.position = Vector2(size.x - 150, 134)
	var panel: Control = get_node_or_null(^"RoomPanel") as Control
	if panel != null:
		panel.position = Vector2(18, PANEL_Y)
		panel.size = Vector2(size.x - 36, size.y - PANEL_Y - 16)
	var state: GameState = _state()
	var power: String = "" if _room == null or _def == null else RoomCardText.power(_room, _def)
	power_key.visible = not power.is_empty()
	power_key.label = power
	var on: bool = _room != null and _room.powered_on
	power_key.style = RefPaint.KeyStyle.LIT if on else RefPaint.KeyStyle.STEEL
	power_key.disabled = state == null or _def == null or _def.power_draw_mw <= 0.0


func _state() -> GameState:
	return SimClock.simulation.state if SimClock.simulation != null else null


func _draw() -> void:
	var state: GameState = _state()
	if _room == null or _def == null or state == null:
		return
	RoomIcon.draw(self, Vector2(28, 28), 24.0, _room.def_id, RefPaint.AMBER)
	var title: RefText = RefText.make(RefText.LABEL, 24, RefPaint.TEXT, 3.0)
	title.draw(self, Vector2(50, 28), tr(_def.name_key).to_upper(), "lm")
	_draw_work(state)
	var dim: RefText = RefText.make(RefText.LABEL_MEDIUM, 16, RefPaint.DIM, 2.0)
	if power_key.visible:
		dim.draw(self, Vector2(18, 152), tr(&"BASE_POWER"), "lm")
	dim.draw(self, Vector2(18, STAFF_Y), RoomCardText.staff(state, _room, _def))
	_draw_faces(state)


func _draw_work(state: GameState) -> void:
	var work: Array = RoomCardText.work(state, _room, _def)
	var line: String = work[0]
	var fraction: float = work[1]
	RefText.make(RefText.LABEL, 20, RefPaint.TEXT, 2.0).draw(self, Vector2(18, 64), line)
	if fraction < 0.0:
		return
	var pct: String = "%d%%" % floori(fraction * 100.0)
	RefText.make(RefText.MONO_BOLD, 18, RefPaint.AMBER).draw(
		self, Vector2(size.x - 18, 64), pct, "ra"
	)
	var bar: Rect2 = Rect2(18, 96, size.x - 36, 10)
	draw_rect(bar, Color8(20, 21, 18))
	draw_rect(
		Rect2(bar.position, Vector2(bar.size.x * clampf(fraction, 0.0, 1.0), bar.size.y)),
		RefPaint.AMBER
	)
	draw_rect(bar, RefPaint.EDGE, false, 1.0)


func _draw_faces(state: GameState) -> void:
	var people: Array[PersonState] = RoomCardText.people(state, _room)
	for k: int in _def.staff_slots:
		var at: Rect2 = Rect2(18 + k * FACE_PITCH, STAFF_Y + 28, FACE, FACE)
		if k < people.size():
			FaceTile.draw_face(self, at, people[k])
		else:
			draw_rect(at, RefPaint.DIM, false, 2.0)
			RefIcons.draw(
				self,
				&"plus",
				Rect2(at.get_center() - Vector2(13, 13), Vector2(26, 26)),
				RefPaint.DIM
			)
