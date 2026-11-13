class_name SiteProgress
extends RefCounted
## How far a construction site, a demolition or the dig has come, for the Base tab's bars, the
## SELECTED panel and the level tabs (docs/content/m2-base.md section 6). Pure reads of the
## state: [member fraction] from the work done, [member ticks_left] the real clock ticks still
## needed, with a running Workshop's bonus from its engineers (BuildSpeed; demolition is never sped
## up). A site waiting for a free building slot is QUEUED, with an empty bar and no time.
## Bible: docs/content/m2-base.md sections 4 and 6, docs/content/m26-staff-and-money.md section 3

## What the progress is of.
enum Kind { NONE, BUILDING, QUEUED, DEMOLISHING, DIGGING }

## What is in progress.
var kind: Kind = Kind.NONE
## Work done, 0 to 1.
var fraction: float = 0.0
## Real clock ticks left; -1 while queued.
var ticks_left: int = -1
## Place in the building queue, 1 the next to start; 0 unless queued.
var queue_place: int = 0


## The progress of every room of [param rooms] (of [param state]'s base) that is building,
## queued or coming down, by room id. Reads the queue and the Workshop bonus once.
static func for_rooms(state: GameState, rooms: Array[RoomState]) -> Dictionary:
	var queue: Array[StringName] = ConstructionSystem.site_queue(state.base)
	var workshop: int = BuildSpeed.bonus(state)
	var found: Dictionary = {}
	for room: RoomState in rooms:
		var progress: SiteProgress = _of(state, room, queue, workshop)
		if progress.kind != Kind.NONE:
			found[room.id] = progress
	return found


## The progress of [param room] of [param state]'s base; kind NONE when built and standing.
static func of_room(state: GameState, room: RoomState) -> SiteProgress:
	var queue: Array[StringName] = ConstructionSystem.site_queue(state.base)
	return _of(state, room, queue, BuildSpeed.bonus(state))


## The progress of the level being dug in [param state]; kind NONE when no dig runs.
static func of_dig(state: GameState) -> SiteProgress:
	var level: int = state.base.digging_level()
	if level == 0:
		return SiteProgress.new()
	var work: int = state.base.levels[level - 1].dig_ticks_left
	var total: int = work
	if state.balance != null:
		var index: int = level - state.balance.starting_levels - 1
		if index >= 0 and index < state.balance.dig_level_ticks.size():
			total = state.balance.dig_level_ticks[index]
	return _make(Kind.DIGGING, work, total, BuildSpeed.ticks_left(state, work))


static func _of(
	state: GameState, room: RoomState, queue: Array[StringName], workshop: int
) -> SiteProgress:
	var def: RoomDef = state.room_defs.get(room.def_id)
	var build: int = 1 if def == null else maxi(1, def.build_ticks)
	if room.is_demolishing():
		var left: int = room.demolish_ticks_left
		return _make(Kind.DEMOLISHING, left, maxi(1, build / 4), left)
	if room.is_built():
		return SiteProgress.new()
	var key: StringName = room.site_key()
	var index: int = queue.find(key)
	if index >= ConstructionSystem.MAX_ACTIVE_SITES:
		var queued := SiteProgress.new()
		queued.kind = Kind.QUEUED
		queued.queue_place = index - ConstructionSystem.MAX_ACTIVE_SITES + 1
		return queued
	var site: Array[RoomState] = BaseRules.site_rooms(state.base, key)
	var work: int = 0
	for part: RoomState in site:
		work = maxi(work, part.build_ticks_left)
	var total: int = build
	if room.def_id == StartingBase.CORRIDOR_DEF:
		total = build * site.size()
	elif state.balance != null and LiftShafts.is_segment(state.base, room):
		total = maxi(1, state.balance.lift_segment_ticks)
	var bonus: int = BuildSpeed.with_modifier(
		workshop, ModifierRules.total(state, &"build_speed_pct")
	)
	var ticks: int = BuildSpeed.ticks_to_finish(work, state.clock.tick, bonus)
	return _make(Kind.BUILDING, work, total, ticks)


static func _make(kind: Kind, work: int, total: int, ticks: int) -> SiteProgress:
	var progress := SiteProgress.new()
	progress.kind = kind
	progress.fraction = clampf(1.0 - float(work) / maxi(1, maxi(total, work)), 0.0, 1.0)
	progress.ticks_left = ticks
	return progress
