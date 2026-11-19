class_name BaseCapture
extends RefCounted
## The Base states of the reference capture (#534): adds the reference's rooms on L1 to the
## captured game (a research lab with two scientists, a workshop, an unpowered quarters and a
## quarters site), then drives the Base view to BUILD (lab selected, the Quarters card
## picked), POWER and STAFF. Tool only: never in src/.
## Reference: docs/content/interface-reference.md section 8

const LAB: StringName = &"room_ref_lab"
## Rooms added: id, def, origin (cells on L1), powered, build ticks left.
const ROOMS: Array[Array] = [
	[&"room_ref_lab", &"room_research_lab", Vector2i(23, 11), true, 0],
	[&"room_ref_workshop", &"room_workshop", Vector2i(27, 11), true, 0],
	[&"room_ref_quarters", &"room_quarters", Vector2i(32, 11), false, 0],
	[&"room_ref_site", &"room_quarters", Vector2i(24, 14), false, 300],
]


## Adds the reference rooms to [param state] (once) and puts two free people in the lab.
static func furnish(state: GameState) -> void:
	if state.base.find_room(LAB) != null:
		return
	for row: Array in ROOMS:
		var id: StringName = row[0]
		var def_id: StringName = row[1]
		var origin: Vector2i = row[2]
		var room: RoomState = RoomState.create(id, def_id, 1, origin)
		room.powered_on = row[3] == true
		var ticks: int = row[4]
		room.build_ticks_left = ticks
		state.base.rooms.append(room)
	var placed: int = 0
	for person: PersonState in state.staff.people:
		if placed < 2 and person.room_id.is_empty():
			person.room_id = LAB
			placed += 1
	EventBus.room_built.emit(LAB)


## Shows the Base in [param mode] (&"build", &"energy", &"staff") in [param switcher].
static func show(switcher: ViewSwitcher, mode: StringName) -> void:
	switcher.show_station(&"base")
	var base: BaseView = switcher.get_view(ViewSwitcher.BASE) as BaseView
	base.get_sub_tabs().show_tab(mode)
	base.get_plan().select(LAB)
	base.get_plan().centre_on(LAB)
	if mode == BaseSubTabs.BUILD:
		base.get_build().place_at(&"room_quarters", Vector2i(27, 8))
		base.get_plan().centre_on(LAB)
	if mode == BaseSubTabs.STAFF:
		_drag_to_lab(base)
	if mode != BaseSubTabs.STAFF:
		base.get_plan().staff_layer.assign.cancel()
		var line: StaffDragLine = base.find_child("StaffDragLine", true, false) as StaffDragLine
		line.follow(null)
	if mode == BaseSubTabs.SECURITY:
		_arm(SimClock.simulation.state)
		base.get_sub_tabs().show_tab(BaseSubTabs.BUILD)
		base.get_sub_tabs().show_tab(BaseSubTabs.SECURITY)
		base.get_plan().centre_on(LAB)


## A drag in progress: the dashed line from the third face tile (a free engineer) to the
## lab's third slot.
static func _drag_to_lab(base: BaseView) -> void:
	var tray: Node = base.find_child("StaffSubTab", true, false)
	var tiles: Array[Node] = tray.find_children("*", "StaffFaceKey", true, false)
	if tiles.is_empty():
		return
	var pick: Node = tiles[mini(2, tiles.size() - 1)]
	var tile: StaffFaceKey = pick as StaffFaceKey
	tile.button_pressed = true
	tile.drag_started.emit(tile.person_id)
	var plan: BasePlan = base.get_plan()
	var room: RoomState = SimClock.simulation.state.base.find_room(LAB)
	var def: RoomDef = SimClock.simulation.state.room_defs.get(room.def_id)
	var area: Rect2 = PlanTiles.rect_of(plan, BaseRules.footprint(room, def), 4.0)
	var slot: Vector2 = Vector2(area.position.x + 24 + 2 * PlanTiles.SLOT_PITCH, area.end.y - 22)
	var line: StaffDragLine = base.find_child("StaffDragLine", true, false) as StaffDragLine
	line.show_line(tile, plan.get_global_transform() * slot)


## A security post with its soldiers on L1 and a sealed blast door, so the tray has a squad
## and a door (the reference has no SECURITY image; M6-06).
static func _arm(state: GameState) -> void:
	if state.base.find_room(&"room_ref_post") != null:
		return
	state.base.rooms.append(
		RoomState.create(&"room_ref_post", &"room_security_post", 1, Vector2i(33, 8))
	)
	var armed: int = 0
	for person: PersonState in state.staff.people:
		if person.role == SquadRules.SOLDIER and armed < 2:
			person.room_id = &"room_ref_post"
			person.lent = false
			armed += 1
	var door: DoorState = DoorState.new()
	door.level = 1
	door.cell = Vector2i(22, 10)
	door.mode = DoorState.Mode.SEALED
	state.base.doors.append(door)
	SquadRules.sync(state)
