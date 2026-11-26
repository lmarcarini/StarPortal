class_name LabBenches
extends Control
## The Lab console (interface-reference.md section 9, lab_benches): one [LabBench] per
## standing research building, 268 wide and 10 apart, scrolling sideways when there are more
## than fit. Remembers the target bench: the one pressed last, while it stands.
## Bible: docs/content/interface-reference.md section 9

## The target bench changed (&"" for none).
signal target_changed(room_id: StringName)

const GAP: int = 10

var _scroll: ScrollContainer = ScrollContainer.new()
var _row: HBoxContainer = HBoxContainer.new()
var _benches: Dictionary[StringName, LabBench] = {}
var _target: StringName = &""


func _init() -> void:
	name = &"LabBenches"
	z_index = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_row.add_theme_constant_override(&"separation", GAP)
	_scroll.add_child(_row)
	add_child(_scroll)
	resized.connect(func() -> void: _scroll.size = size)


## Shows a bench for each standing research building of [param state], in base order.
func show_state(state: GameState) -> void:
	var rooms: Array[RoomState] = LabBenches.buildings(state)
	var ids: Array[StringName] = []
	for room: RoomState in rooms:
		ids.append(room.id)
	if ids != Array(_benches.keys(), TYPE_STRING_NAME, &"", null):
		_rebuild(ids)
	for room: RoomState in rooms:
		_benches[room.id].show_room(state, room)
	if not _benches.has(_target):
		pick(&"")


## Makes [param room_id] the target bench (&"" or a second press of the same one: none).
func pick(room_id: StringName) -> void:
	var next: StringName = room_id if room_id != _target and _benches.has(room_id) else &""
	if next == _target:
		return
	_target = next
	for id: StringName in _benches:
		_benches[id].target = id == _target
	target_changed.emit(_target)


## The target bench's room, or &"".
func get_target() -> StringName:
	return _target


## The benches, in order.
func benches() -> Array[LabBench]:
	return _benches.values()


## The standing research buildings of [param state] (every discipline), in base order.
static func buildings(state: GameState) -> Array[RoomState]:
	var found: Array[RoomState] = []
	for room: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if def != null and not def.research_discipline.is_empty() and PowerRules.is_standing(room):
			found.append(room)
	return found


func _rebuild(ids: Array[StringName]) -> void:
	for bench: LabBench in _benches.values():
		_row.remove_child(bench)
		bench.queue_free()
	_benches.clear()
	for id: StringName in ids:
		var bench: LabBench = LabBench.new()
		bench.picked.connect(pick)
		_row.add_child(bench)
		_benches[id] = bench
