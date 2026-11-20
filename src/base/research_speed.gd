class_name ResearchSpeed
extends RefCounted
## Pure progress rules of one research bench (docs/content/research-and-progression.md
## section 3): a building works while it is built and on and has staff of its own field
## present; its speed is max(25%, their total skill ÷ 6), at most 200%, with the
## research_speed_pct modifier. No staff, no progress. The listed hours are the time for a
## standard crew (total skill 6, 100%).
## Bible: docs/content/research-and-progression.md section 3,
## docs/content/m26-staff-and-money.md section 3

## Speed is counted in 1 / SPEED_DENOMINATOR of the standard crew's (one skill point = 2).
const SPEED_DENOMINATOR: int = 12
## Speed per skill point, in twelfths (skill ÷ 6).
const SPEED_PER_SKILL: int = 2
## Slowest speed with any staff present, in twelfths (25%).
const MIN_SPEED: int = 3
## Fastest speed, in twelfths (200%).
const MAX_SPEED: int = 24


## Total skill of [param room]'s present staff of its own field (on or off).
static func skill(state: GameState, room: RoomState) -> int:
	var def: RoomDef = state.room_defs.get(room.def_id)
	if def == null:
		return 0
	var total: int = 0
	for person: PersonState in StaffRules.working(state, room):
		if person.role == def.staff_role:
			total += person.skill
	return total


## Speed of [param room] from [param total_skill] in twelfths: 0 with no staff, else
## between MIN_SPEED and MAX_SPEED, with the modifier.
static func from_skill(state: GameState, total_skill: int) -> int:
	if total_skill <= 0:
		return 0
	var base: int = clampi(SPEED_PER_SKILL * total_skill, MIN_SPEED, MAX_SPEED)
	var percent: int = ModifierRules.total(state, &"research_speed_pct")
	return maxi(1, base * (100 + percent) / 100)


## Speed of [param room] now in twelfths: 0 while it is off or has no staff of its field.
static func speed(state: GameState, room: RoomState) -> int:
	var def: RoomDef = state.room_defs.get(room.def_id)
	if def == null or not PowerRules.is_running(room, def):
		return 0
	return from_skill(state, skill(state, room))


## Speed of [param room] as a whole percentage (0 to 200).
static func percent(state: GameState, room: RoomState) -> int:
	return speed(state, room) * 100 / SPEED_DENOMINATOR


## Ticks of work [param room]'s project gets on the current tick (RateSteps: exact across saves).
static func step(state: GameState, room: RoomState) -> int:
	var rate: int = speed(state, room)
	if rate <= 0:
		return 0
	return RateSteps.step(state.clock.tick, rate, SPEED_DENOMINATOR)


## Share of [param room]'s running project done, 0.0 to 1.0; 0.0 when none runs.
static func progress(state: GameState, room_id: StringName) -> float:
	var bench: ResearchBench = state.research.bench_of(room_id)
	if bench == null or not bench.is_running():
		return 0.0
	var def: ResearchDef = state.research_defs.get(bench.active)
	if def == null:
		return 0.0
	return clampf(float(bench.ticks_done) / float(ResearchRules.total_ticks(def)), 0.0, 1.0)


## Clock ticks until [param room]'s project finishes at its current speed (or, while it is
## off, at the speed its staff would give); -1 when it would never finish (no staff), 0
## when none runs.
static func ticks_left(state: GameState, room: RoomState) -> int:
	var bench: ResearchBench = state.research.bench_of(room.id)
	if bench == null or not bench.is_running():
		return 0
	var def: ResearchDef = state.research_defs.get(bench.active)
	if def == null:
		return 0
	var rate: int = from_skill(state, skill(state, room))
	if rate <= 0:
		return -1
	var left: int = maxi(0, ResearchRules.total_ticks(def) - bench.ticks_done)
	return RateSteps.ticks_to(left, state.clock.tick, rate, SPEED_DENOMINATOR)
