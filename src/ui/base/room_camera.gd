class_name RoomCamera
extends VBoxContainer
## The selected room's security camera in the Base detail column: the room's set, a camera
## number and the room name, with an Expand button that grows the feed over the board (Esc or
## (B) shrinks it first). People in the feed are the staff tokens inside the room, read from
## the plan's StaffLayer, so the feed and the plan agree even while people walk. One feed;
## it renders only while shown and the Base tab is visible.
## Bible: docs/content/interface-pass.md section 5 (Camera inset)

## Seconds between refreshes of the people in the feed.
const PEOPLE_SECONDS: float = 0.2
## The inset's size in the column.
const INSET_SIZE: Vector2 = Vector2(320, 240)

## The feed.
var feed := RoomCameraFeed.new()
## Grows the feed over the board, or shrinks it back.
var expand_button := Button.new()

var _plan: BasePlan = null
var _room_id: StringName = &""
var _expanded: bool = false
var _since_people: float = 0.0
var _people_key: String = ""


func _init() -> void:
	name = &"RoomCamera"
	feed.custom_minimum_size = INSET_SIZE
	add_child(feed)
	expand_button.text = &"CAMERA_EXPAND"
	expand_button.pressed.connect(func() -> void: set_expanded(not _expanded))
	add_child(expand_button)
	visible = false
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree():
		_update_live()


## Reads people and room states from [param plan].
func setup(plan: BasePlan) -> void:
	_plan = plan


## Shows the camera of room [param room_uid]; &"" hides the inset.
func show_room(room_uid: StringName) -> void:
	_room_id = room_uid
	var simulation: Simulation = SimClock.simulation
	var room: RoomState = null
	if simulation != null and room_uid != &"":
		room = simulation.state.base.find_room(room_uid)
	if room == null:
		_room_id = &""
		set_expanded(false)
		feed.show_no_signal()
		visible = false
		_update_live()
		return
	var state: GameState = simulation.state
	var def: RoomDef = state.room_defs.get(room.def_id)
	var name_text: String = String(room.def_id) if def == null else tr(def.name_key)
	feed.show_set(RoomSetCatalogue.for_room(room.def_id), label_text(state, room, name_text))
	feed.set_room_state(_set_state(room, def))
	_people_key = ""
	visible = true
	_refresh_people()
	_update_live()


## "CAM 03 RESEARCH LAB": the room's place in the base's list and its name.
static func label_text(state: GameState, room: RoomState, name_text: String) -> String:
	var number: int = state.base.rooms.find(room) + 1
	return "CAM %02d %s" % [number, name_text.to_upper()]


## The room shown, or &"".
func room_id() -> StringName:
	return _room_id


## Grows the feed over the board ([param on]) or puts it back in the column.
func set_expanded(on: bool) -> void:
	var grow: bool = on and _room_id != &"" and _plan != null
	_expanded = grow
	feed.top_level = grow
	if grow:
		var board: Rect2 = _plan.get_global_rect()
		feed.global_position = board.position
		feed.size = board.size
		expand_button.grab_focus.call_deferred()
	else:
		feed.size = INSET_SIZE
		feed.position = Vector2.ZERO
	expand_button.text = &"CAMERA_SHRINK" if grow else &"CAMERA_EXPAND"
	queue_sort()


## True while the feed covers the board.
func is_expanded() -> bool:
	return _expanded


func _process(delta: float) -> void:
	_since_people += delta
	if _since_people >= PEOPLE_SECONDS:
		_since_people = 0.0
		_refresh_people()


## The people in the feed: tokens on the room's level inside its floor.
func people() -> Array[FeedPerson]:
	var found: Array[FeedPerson] = []
	var simulation: Simulation = SimClock.simulation
	if _plan == null or simulation == null or _room_id == &"":
		return found
	var room: RoomState = simulation.state.base.find_room(_room_id)
	var def: RoomDef = null if room == null else simulation.state.room_defs.get(room.def_id)
	if def == null:
		return found
	var cells: Rect2i = BaseRules.footprint(room, def)
	var area := Rect2(
		Vector2(cells.position) * BasePlanPainter.CELL, Vector2(cells.size) * BasePlanPainter.CELL
	)
	var tokens: Array[StaffToken] = _plan.staff_layer.tokens()
	tokens.append_array(_plan.staff_layer.walker.leaving())
	for token: StaffToken in tokens:
		if token.level == room.level and area.has_point(token.position):
			var at: Vector2 = (token.position - area.position) / area.size
			found.append(FeedPerson.create(StringName(String(token.role).trim_prefix("role_")), at))
	return found


func _refresh_people() -> void:
	var room_set: RoomSet = feed.get_set()
	if room_set == null:
		return
	var found: Array[FeedPerson] = people()
	var key: String = ""
	for person: FeedPerson in found:
		key += "%s%.2f%.2f;" % [person.role, person.position.x, person.position.y]
	if key == _people_key:
		return
	_people_key = key
	room_set.set_people(found)


func _update_live() -> void:
	var live: bool = _room_id != &"" and is_visible_in_tree()
	feed.set_live(live)
	set_process(live)


static func _set_state(room: RoomState, def: RoomDef) -> StringName:
	match BasePlanPainter.state_of(room, def):
		BasePlanPainter.SITE, BasePlanPainter.COMING_DOWN:
			return RoomSet.STATE_SITE
		BasePlanPainter.OFF:
			return RoomSet.STATE_OFF
	return RoomSet.STATE_ON
