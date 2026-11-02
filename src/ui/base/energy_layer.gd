class_name EnergyLayer
extends Control
## The energy layer drawn over the Base tab's plan (docs/content/m2-base.md section 6): the
## scenery dims and each room with a power role gets a tag with its switch and MW (`ON 4`,
## `OFF`, `LOCK 2` for an always-on room, `+30` for a plant, `CHG 26` with − and + marks for
## a bank). A room whose switch-on was just refused shows the MW it needs. Status has a shape
## as well as a colour: a running room's tag is a solid plate, an off or refused one a dashed
## outline with the "no power" mark. It only draws; the Base view turns clicks and (A) into
## commands.
## Bible: docs/content/m2-base.md sections 3 and 6

const DIM := Color(0.04, 0.05, 0.06, 0.55)
const PLATE := Color("#15171a")
const ON := Color("#e0a040")
const OFF := Color("#7a7d72")
const LOCKED := Color("#c97c2c")
const CHARGE := Color("#5cb8d6")
const REFUSED := Color("#e5534b")
const _FONT_SIZE: int = 12

var _plan: BasePlan = null
var _state: GameState = null
var _refused_room: StringName = &""
var _refused_mw: float = 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	visible = false


## Draws over [param plan] from [param state].
func setup(plan: BasePlan, state: GameState) -> void:
	_plan = plan
	_state = state
	if not plan.draw.is_connected(queue_redraw):
		plan.draw.connect(queue_redraw)
	queue_redraw()


## Marks room [param room_id] as refused for needing [param need_mw]; &"" clears the mark.
func mark_refused(room_id: StringName, need_mw: float) -> void:
	_refused_room = room_id
	_refused_mw = need_mw
	queue_redraw()


## Returns the tag drawn on room [param room_id], or "" when it has none.
func tag_of(room_id: StringName) -> String:
	var room: RoomState = _state.base.find_room(room_id)
	var def: RoomDef = null if room == null else _state.room_defs.get(room.def_id)
	if room_id == _refused_room and room_id != &"":
		return tr(&"BASE_POWER_TAG_NEED").format({"mw": PowerText.mw(_refused_mw)})
	return PowerText.tag(_state, room, def)


func _draw() -> void:
	if _plan == null or _state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), DIM)
	for room: RoomState in BaseRules.rooms_on_level(_state.base, _plan.level):
		var text: String = tag_of(room.id)
		if text.is_empty():
			continue
		var def: RoomDef = _state.room_defs.get(room.def_id)
		var cells: Rect2i = BaseRules.footprint(room, def)
		_draw_tag(_on_screen(cells), text, _colour(room, def), is_unpowered(room.id))


## True when room [param room_id]'s tag shows it without power: switched off, or its
## switch-on just refused.
func is_unpowered(room_id: StringName) -> bool:
	if room_id == _refused_room and room_id != &"":
		return true
	var room: RoomState = _state.base.find_room(room_id)
	var def: RoomDef = null if room == null else _state.room_defs.get(room.def_id)
	if def == null or PowerRules.is_bank(def) or not PowerRules.has_switch(def):
		return false
	return PowerRules.is_standing(room) and not PowerRules.is_running(room, def)


func _draw_tag(area: Rect2, text: String, colour: Color, unpowered: bool) -> void:
	var font: Font = get_theme_default_font()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE).x
	var mark: float = _FONT_SIZE + 2.0 if unpowered else 0.0
	var plate := Rect2(Vector2.ZERO, Vector2(width + 10.0 + mark, _FONT_SIZE + 8.0))
	plate.position = area.get_center() - plate.size * 0.5
	draw_rect(plate, PLATE)
	if unpowered:
		_draw_dashed(plate, colour)
		var centre := plate.position + Vector2(4.0 + mark * 0.5, plate.size.y * 0.5)
		PowerMarks.draw_no_power(self, centre, mark)
	else:
		draw_rect(plate, colour, false, 1.5)
	var at := plate.position + Vector2(5.0 + mark, _FONT_SIZE + 2.0)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE, colour)


func _draw_dashed(plate: Rect2, colour: Color) -> void:
	var corners: Array[Vector2] = [
		plate.position,
		Vector2(plate.end.x, plate.position.y),
		plate.end,
		Vector2(plate.position.x, plate.end.y),
	]
	for index: int in corners.size():
		var to: Vector2 = corners[(index + 1) % corners.size()]
		draw_dashed_line(corners[index], to, colour, 1.5, 3.0)


func _colour(room: RoomState, def: RoomDef) -> Color:
	if room.id == _refused_room:
		return REFUSED
	if PowerRules.is_bank(def):
		return CHARGE
	if def.always_on or not PowerText.lock_reason(_state, room, def).is_empty():
		return LOCKED
	return ON if room.powered_on else OFF


## [param cells] in this control's coordinates, after the plan's zoom and pan.
func _on_screen(cells: Rect2i) -> Rect2:
	var cell: float = BasePlanPainter.CELL * _plan.view.scale()
	return Rect2(_plan.view.offset + Vector2(cells.position) * cell, Vector2(cells.size) * cell)
