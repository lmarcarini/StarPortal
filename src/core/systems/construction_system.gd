class_name ConstructionSystem
extends SimSystem
## Builds sites, takes demolished rooms down and digs levels, one tick at a time, while the
## clock runs. Up to MAX_ACTIVE_SITES sites build at once, oldest first; later ones wait in
## the queue. A site is every room sharing a site key (a corridor run, a lift shaft, stairs).
## A lift segment (LiftShafts) builds outside the slots. A dug level extends every lift shaft
## (LiftShafts.extend()). A finished room switches on taking power from charging first
## (FinishingPower). A running Workshop speeds sites and the dig up by 25% (BuildSpeed).
## Draws no power.
## Posts room_built(site id), room_demolished(id) and level_dug(level), each once:
## room_demolished carries the cell's room id for a corridor (each cell is its own demolition
## order) and the site id for any other room.
## Bible: docs/content/m2-base.md section 4, docs/content/m25-lean-start.md sections 2 to 4

## Sites building at once; later sites queue.
const MAX_ACTIVE_SITES: int = 3

# Memory only: the base and RoomState.revision at which the base was last found idle. A room
# only gets work by setting its build or demolition ticks, which moves the revision.
var _idle_base: int = -1
var _idle_revision: int = -1


## Returns the system id, &"construction".
func get_id() -> StringName:
	return &"construction"


## Advances the active sites, every demolition and then the dig by one tick (a lift segment
## started by the dig begins building on the next tick).
func tick(state: GameState) -> void:
	var step: int = BuildSpeed.progress(state)
	if not _is_idle(state.base):
		_tick_sites(state, step)
		_tick_demolitions(state)
	_tick_dig(state, step)


## The site keys still building in [param base], oldest first, lift segments left out: the
## first MAX_ACTIVE_SITES are active, the rest queued (the UI shows "Queued: 2nd" from the
## index).
static func site_queue(base: BaseState) -> Array[StringName]:
	return _sites(base, false)


## The keys of the lift segments still building in [param base]: they take no slot.
static func segment_sites(base: BaseState) -> Array[StringName]:
	return _sites(base, true)


static func _sites(base: BaseState, segments: bool) -> Array[StringName]:
	var keys: Array[StringName] = []
	for room: RoomState in base.rooms:
		if room.is_built() or room.site_key() in keys:
			continue
		if LiftShafts.is_segment(base, room) == segments:
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


func _tick_sites(state: GameState, step: int) -> void:
	var active: Array[StringName] = site_queue(state.base).slice(0, MAX_ACTIVE_SITES)
	active.append_array(segment_sites(state.base))
	for key: StringName in active:
		var done: bool = true
		var rooms: Array[RoomState] = BaseRules.site_rooms(state.base, key)
		for room: RoomState in rooms:
			if room.is_built():
				continue
			room.build_ticks_left = maxi(room.build_ticks_left - step, 0)
			done = done and room.is_built()
		if done:
			LiftShafts.join_shaft(state.base, rooms)
			for room: RoomState in rooms:
				FinishingPower.switch_on(state, room)
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


func _tick_dig(state: GameState, step: int) -> void:
	var level: int = state.base.digging_level()
	if level == 0:
		return
	var dug: LevelState = state.base.levels[level - 1]
	dug.dig_ticks_left = maxi(dug.dig_ticks_left - step, 0)
	if not dug.is_dug():
		return
	LiftShafts.extend(state, level)
	state.events.post(&"level_dug", [level])
