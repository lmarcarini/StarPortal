class_name StaffOverlay
extends RefCounted
## Room overlays drawn by the staff layer: while placing, rooms that can take the person are
## outlined green and the others dimmed; on the Staff sub-tab, rooms are tinted by filled
## slots (green full, amber part, grey empty).
## Bible: docs/content/interface-pass.md section 5 (Allocation by placing)


## Placing: allowed rooms outlined green, others dimmed. Staff sub-tab: rooms tinted by filled
## slots (green full, amber part, grey empty).
static func draw_rooms(canvas: CanvasItem, level: int, assign: AssignMode, tint: bool) -> void:
	var simulation: Simulation = SimClock.simulation
	if simulation == null or (not tint and not assign.is_active()):
		return
	var state: GameState = simulation.state
	for room: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if def == null or room.level != level or room.def_id == StartingBase.CORRIDOR_DEF:
			continue
		var cells: Rect2i = BaseRules.footprint(room, def)
		var area := Rect2(
			Vector2(cells.position) * BasePlanPainter.CELL,
			Vector2(cells.size) * BasePlanPainter.CELL
		)
		if assign.is_active():
			if assign.allows(room.id):
				canvas.draw_rect(area.grow(-1.0), UiPalette.GOOD, false, 3.0)
			else:
				canvas.draw_rect(area, Color(UiPalette.GROUND, 0.6))
		elif tint:
			canvas.draw_rect(area, Color(_fill_colour(state, room), 0.18))


static func _fill_colour(state: GameState, room: RoomState) -> Color:
	var slots: int = StaffRules.slots(state, room)
	if slots <= 0:
		return UiPalette.TEXT_DIM
	var filled: int = 0
	for person: PersonState in state.staff.people:
		if person.room_id == room.id:
			filled += 1
	if filled >= slots:
		return UiPalette.GOOD
	return UiPalette.WARN if filled > 0 else UiPalette.TEXT_DIM
