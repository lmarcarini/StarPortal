class_name BuildSpeed
extends RefCounted
## The Workshop's effect (docs/content/m26-staff-and-money.md section 3): while a Workshop is
## built and on, every construction site and the dig progress faster by 10% plus 2.5% per skill
## point of the engineers assigned to running Workshops, at most 35% (two skill-3 engineers:
## 25%). Engineers in every running Workshop pool into one bonus, under the one cap, so a second
## Workshop adds slots, not speed. Demolition is not sped up, and there is no other engineer
## bonus. Fractions are never stored: the bonus is kept in fortieths (10% = 4, each skill point
## 1) and RateSteps turns it into whole ticks of progress from the clock tick, so it is exact and
## deterministic across saves (at 25%, two ticks of progress on ticks 3, 7, 11 ... as in M2.5).
## Bible: docs/content/m26-staff-and-money.md section 3, docs/content/m25-lean-start.md section 4

## Def id of the Workshop.
const WORKSHOP_DEF: StringName = &"room_workshop"
## The bonus is counted in 1 / DENOMINATOR of normal speed (2.5% steps).
const DENOMINATOR: int = 40
## Bonus of a running Workshop with no engineers, in fortieths (10%).
const EMPTY_BONUS: int = 4
## Bonus per engineer skill point, in fortieths (2.5%).
const BONUS_PER_SKILL: int = 1
## Largest bonus, in fortieths (35%).
const MAX_BONUS: int = 14


## Ticks of progress a site or dig of [param state] makes this tick, with the bonus as it is.
static func progress(state: GameState) -> int:
	return step_at(state.clock.tick, bonus(state))


## Ticks of progress on clock tick [param tick] with [param bonus_40ths] of bonus.
static func step_at(tick: int, bonus_40ths: int) -> int:
	return RateSteps.step(tick, DENOMINATOR + bonus_40ths, DENOMINATOR)


## The bonus of [param state]'s base, in fortieths of normal speed: 0 with no running Workshop,
## else EMPTY_BONUS plus BONUS_PER_SKILL per skill point of their engineers, at most MAX_BONUS.
static func bonus(state: GameState) -> int:
	var def: RoomDef = state.room_defs.get(WORKSHOP_DEF)
	if def == null:
		return 0
	var running: bool = false
	var skill: int = 0
	for room: RoomState in state.base.rooms:
		if room.def_id == WORKSHOP_DEF and PowerRules.is_running(room, def):
			running = true
			for person: PersonState in StaffRules.assigned(state, room):
				skill += person.skill
	if not running:
		return 0
	return mini(MAX_BONUS, EMPTY_BONUS + BONUS_PER_SKILL * skill)


## The bonus of [param state] as a whole percentage, rounded down (22.5% shows as 22).
static func bonus_percent(state: GameState) -> int:
	return bonus(state) * 100 / DENOMINATOR


## True when a Workshop of [param state]'s base is built, not coming down and switched on.
static func has_running_workshop(state: GameState) -> bool:
	return bonus(state) > 0


## Clock ticks a site or dig with [param work] ticks of progress left needs to finish, when its
## next progress tick is clock tick [param first_tick] (the clock's current tick: systems tick
## before the clock moves) and the bonus is [param bonus_40ths]. Assumes the bonus stays as it
## is. 0 when no work is left.
static func ticks_to_finish(work: int, first_tick: int, bonus_40ths: int) -> int:
	return RateSteps.ticks_to(work, first_tick, DENOMINATOR + bonus_40ths, DENOMINATOR)


## Clock ticks [param state]'s site or dig with [param work] ticks of progress left needs to
## finish, with the bonus as it is now.
static func ticks_left(state: GameState, work: int) -> int:
	return ticks_to_finish(work, state.clock.tick, bonus(state))
