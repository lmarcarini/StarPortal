class_name HorizonPhotoText
extends RefCounted
## Pure text of the horizon photograph: its caption, "Horizon record · <world> · <date>". The
## world is its designation, or "Unknown world"; the date is when the record was taken, from the
## operations log (the current time if the log no longer holds it). Adds no saved state.
## Translates with the TranslationServer so it can stay static.
## Bible: game-design.md#base-building-and-power (pole camera, horizon record)


## Returns the caption of [param world_id]'s horizon record in [param state].
static func caption(state: GameState, world_id: StringName) -> String:
	var name: String = GateRoomFormat.translate(&"GATE_WORMHOLE_UNNAMED")
	var world: WorldRecord = state.galaxy.get_world(world_id) if state.galaxy != null else null
	if world != null and not world.designation.is_empty():
		name = world.designation
	var date: String = GateRoomFormat.date_time(taken_tick(state, world_id))
	return GateRoomFormat.translate(&"GATE_HORIZON_PHOTO_CAPTION").format(
		{"world": name, "date": date}
	)


## Returns the tick of [param world_id]'s newest horizon record in the log, else the clock's.
static func taken_tick(state: GameState, world_id: StringName) -> int:
	var entries: Array[LogEntry] = state.operations_log.entries
	for index: int in range(entries.size() - 1, -1, -1):
		var entry: LogEntry = entries[index]
		if entry.kind == &"horizon" and entry.world_id == world_id:
			return entry.tick
	return state.clock.tick
