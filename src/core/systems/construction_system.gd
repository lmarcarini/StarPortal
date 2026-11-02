class_name ConstructionSystem
extends SimSystem
## Builds sites, takes demolished rooms down and digs levels, one tick at a time, while the
## clock runs. Up to MAX_ACTIVE_SITES sites build at once, oldest first; later ones wait in
## the queue. A site is every room sharing a site key (a corridor run, a lift shaft, stairs).
## A dug level gets a level of every lift shaft for free. Draws no power.
## Posts room_built(site id), room_demolished(id) and level_dug(level), each once:
## room_demolished carries the cell's room id for a corridor (each cell is its own demolition
## order) and the site id for any other room.
## Bible: docs/content/m2-base.md section 4

## Sites building at once; later sites queue.
const MAX_ACTIVE_SITES: int = 3

# Memory only: the base and RoomState.revision at which the base was last found idle. A room
# only gets work by setting its build or demolition ticks, which moves the revision.
var _idle_base: int = -1
var _idle_revision: int = -1


## Returns the system id, &"construction".
func get_id() -> StringName:
	return &"construction"


## Advances the dig, the active sites and every demolition by one tick.
func tick(state: GameState) -> void:
	_tick_dig(state)
	if _is_idle(state.base):
		return
	_tick_sites(state)
	_tick_demolitions(state)


## The site keys still building in [param base], oldest first: the first MAX_ACTIVE_SITES are
## active, the rest queued (the UI shows "Queued: 2nd" from the index).
static func site_queue(base: BaseState) -> Array[StringName]:
	var keys: Array[StringName] = []
	for room: RoomState in base.rooms:
		if not room.is_built() and not room.site_key() in keys:
			keys.append(room.site_key())
	return keys


## True when no room of [param base] is building or coming down. Remembers an idle base until
## a room's build or demolition state changes, so an idle tick skips the scan of the rooms.
func _is_idle(base: BaseState) -> bool:
	if _idle_revision == RoomState.revision and _idle_base == base.get_instance_id():
		return true
	if _has_work(base):
		_idle_revision = -1
		return false
	_idle_revision = RoomState.revision
	_idle_base = base.get_instance_id()
	return true


## True when a room of [param base] is building or coming down.
static func _has_work(base: BaseState) -> bool:
	for room: RoomState in base.rooms:
		if room.build_ticks_left > 0 or room.demolish_ticks_left > 0:
			return true
	return false


func _tick_sites(state: GameState) -> void:
	var active: Array[StringName] = site_queue(state.base).slice(0, MAX_ACTIVE_SITES)
	for key: StringName in active:
		var done: bool = true
		for room: RoomState in BaseRules.site_rooms(state.base, key):
			if room.is_built():
				continue
			room.build_ticks_left -= 1
			done = done and room.is_built()
		if done:
			PowerSystem.settle(state)
			state.events.post(&"room_built", [key])


func _tick_demolitions(state: GameState) -> void:
	var finished: Array[RoomState] = []
	for room: RoomState in state.base.rooms:
		if room.is_demolishing():
			room.demolish_ticks_left -= 1
			if not room.is_demolishing():
				finished.append(room)
	var posted: Array[StringName] = []
	for room: RoomState in finished:
		state.base.remove_room(room.id)
		var key: StringName = room.site_key()
		if room.def_id == StartingBase.CORRIDOR_DEF:
			key = room.id
		if not key in posted:
			posted.append(key)
			state.events.post(&"room_demolished", [key])


func _tick_dig(state: GameState) -> void:
	var level: int = state.base.digging_level()
	if level == 0:
		return
	var dug: LevelState = state.base.levels[level - 1]
	dug.dig_ticks_left -= 1
	if not dug.is_dug():
		return
	_extend_lifts(state.base, level)
	state.events.post(&"level_dug", [level])


## Adds a level of every lift shaft of [param base] to [param level], as far built as the
## shaft.
static func _extend_lifts(base: BaseState, level: int) -> void:
	var seen: Array[StringName] = []
	for room: RoomState in base.rooms.duplicate():
		if room.def_id != StartingBase.LIFT_DEF or room.is_demolishing():
			continue
		var shaft: StringName = StringName("%s" % room.origin)
		if shaft in seen:
			continue
		seen.append(shaft)
		var copy: RoomState = base.add_room(room.def_id, level, room.origin)
		copy.site = room.site
		copy.build_ticks_left = room.build_ticks_left
