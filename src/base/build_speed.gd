class_name BuildSpeed
extends RefCounted
## The Workshop's effect (docs/content/m25-lean-start.md section 4): while a Workshop is built
## and on, every construction site and the dig progress 25% faster; a second Workshop adds
## nothing, and demolition is not sped up.
## Fractions are never stored: on the clock ticks whose number is BONUS_EVERY_TICKS - 1 modulo
## BONUS_EVERY_TICKS (3, 7, 11 ...) a site takes two ticks of progress instead of one, so four
## ticks of a running Workshop give five ticks of work. A job of n ticks whose first tick falls
## on a tick number divisible by 4 finishes after exactly ceil(4n / 5) ticks (a 4-hour site,
## 240 ticks, in 192: 3.2 hours); started at another phase it may finish one tick sooner. The
## result depends only on the saved clock tick and rooms, so it is exact and deterministic
## across saves.
## Bible: docs/content/m25-lean-start.md sections 4 and 5

## Def id of the Workshop.
const WORKSHOP_DEF: StringName = &"room_workshop"
## A bonus tick of progress comes once every this many ticks (25% faster).
const BONUS_EVERY_TICKS: int = 4


## Ticks of progress a site or dig of [param state] makes this tick: 2 on a bonus tick while a
## Workshop is running, else 1.
static func progress(state: GameState) -> int:
	if state.clock.tick % BONUS_EVERY_TICKS != BONUS_EVERY_TICKS - 1:
		return 1
	return 2 if has_running_workshop(state) else 1


## True when a Workshop of [param state]'s base is built, not coming down and switched on.
static func has_running_workshop(state: GameState) -> bool:
	var def: RoomDef = state.room_defs.get(WORKSHOP_DEF)
	if def == null:
		return false
	for room: RoomState in state.base.rooms:
		if room.def_id == WORKSHOP_DEF and PowerRules.is_running(room, def):
			return true
	return false
