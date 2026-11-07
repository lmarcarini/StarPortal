class_name ConfidenceRules
extends RefCounted
## Pure rules of Committee Confidence and the daily settlement
## (docs/content/m27-daily-rhythm.md sections 1 and 2): Confidence kept in tenths, the event
## amounts, the daily drift, the daily allocation, the cost carry, the commendation and the
## warning thresholds. No side effects, no autoloads.
## Bible: docs/content/m27-daily-rhythm.md sections 1 and 2

## Starting Confidence and its bounds, in tenths (50.0, 0.0 and 100.0).
const START: int = 500
const MIN: int = 0
const MAX: int = 1000
## Tenths in one whole point.
const TENTHS: int = 10
## Event causes, as saved in the cause list.
const LOCKED: StringName = &"locked"
const SURVEYED: StringName = &"surveyed"
const RESEARCH: StringName = &"research"
const REPORTS: StringName = &"reports"
const CAUSES: Array[StringName] = [LOCKED, SURVEYED, RESEARCH, REPORTS]
## Change per lock, survey, project and analyst, in tenths.
const LOCK_CHANGE: int = 50
const SURVEY_CHANGE: int = 20
const RESEARCH_CHANGE: int = 30
const REPORT_CHANGE: int = 10
## Daily drift in tenths: toward 50 while solvent, and in the red.
const SETTLING_STEP: int = 1
const IN_RED_STEP: int = -2
## Reports are filed every this many days since the start (15 Jan, 30 Jan, ...).
const REPORT_EVERY_DAYS: int = 15
## Days the per-30-days figures (upkeep, salaries) cover.
const PERIOD_DAYS: int = 30
## Causes and daily balances kept in the save.
const CAUSES_KEPT: int = 10
const FUNDS_HISTORY_KEPT: int = 30
## Commendation: paid on reaching this (tenths), re-armed below the second, amount in $k.
const COMMENDATION_AT: int = 700
const COMMENDATION_REARM_BELOW: int = 600
const COMMENDATION_K: int = 1000
## Settlements in a row in the red per warning.
const RED_DAYS_WARNING: int = 7
## The Confidence 0 warning re-arms above this (tenths).
const ZERO_REARM_ABOVE: int = 100
## The room whose analysts file reports, and their role.
const REPORT_ROOM: StringName = &"room_control"
const ANALYST: StringName = &"role_analyst"


## The whole part of [param tenths] (what the top bar and the allocation use).
static func whole(tenths: int) -> int:
	return tenths / TENTHS


## Daily allocation in $k with [param base_k] at Confidence 50 and [param confidence] whole
## points: base × (0.5 + Confidence ÷ 100), i.e. $(50 + Confidence)k for a base of $100k.
static func daily_allocation_k(base_k: int, confidence: int) -> int:
	return base_k * (50 + confidence) / 100


## [param tenths] after [param change], kept within 0..1000.
static func changed(tenths: int, change: int) -> int:
	return clampi(tenths + change, MIN, MAX)


## Today's drift in tenths for [param tenths] with the balance below zero when
## [param in_red]: -0.2 in the red, else 0.1 toward 50.
static func drift(tenths: int, in_red: bool) -> int:
	if in_red:
		return IN_RED_STEP
	return signi(START - tenths) * SETTLING_STEP


## Today's cost charge for [param per_period_k] (costs per 30 days) and the saved
## [param carry]: x is the charge in $k, y the new carry (0 to 29).
static func daily_charge(per_period_k: int, carry: int) -> Vector2i:
	var owed: int = per_period_k + carry
	return Vector2i(owed / PERIOD_DAYS, owed % PERIOD_DAYS)


## True when the settlement of day [param day_index] (days since the start) files reports:
## every 15th day, counting 1 January as day 1.
static func is_report_day(day_index: int) -> bool:
	return day_index > 0 and (day_index + 1) % REPORT_EVERY_DAYS == 0


## Analysts on base assigned to a built Control Room that is on.
static func reporting_analysts(state: GameState) -> int:
	var count: int = 0
	for room: RoomState in state.base.rooms:
		if room.def_id != REPORT_ROOM or not room.is_built() or not room.powered_on:
			continue
		for person: PersonState in StaffRules.assigned(state, room):
			if person.role == ANALYST and person.is_on_base(state.clock.tick):
				count += 1
	return count


## Every world ever locked, in id order.
static func locked_worlds(state: GameState) -> Array[StringName]:
	var ids: Array[StringName] = []
	for world_id: StringName in state.worlds.statuses:
		if state.worlds.statuses[world_id] == WorldsState.WorldStatus.LOCKED:
			ids.append(world_id)
	return sorted(ids)


## Every world surveyed (horizon record taken by the pole camera), in id order.
static func surveyed_worlds(state: GameState) -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(state.worlds.horizon_records.keys())
	return sorted(ids)


## The ids of [param current] not in [param credited], in [param current]'s order.
static func new_ids(current: Array[StringName], credited: Array[StringName]) -> Array[StringName]:
	var fresh: Array[StringName] = []
	for id: StringName in current:
		if not id in credited:
			fresh.append(id)
	return fresh


## [param ids] sorted by name.
static func sorted(ids: Array[StringName]) -> Array[StringName]:
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids
