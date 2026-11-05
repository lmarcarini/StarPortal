class_name ConfidenceRules
extends RefCounted
## Pure rules of Committee Confidence (docs/content/m26-staff-and-money.md section 4): the
## causes and their amounts, the ±15 monthly cap, the allocation formula, the quarterly review
## and what counts as new this month. No side effects, no autoloads.
## Bible: docs/content/m26-staff-and-money.md sections 4, 5 and 8

## Starting Confidence, and its bounds.
const START: int = 50
const MIN: int = 0
const MAX: int = 100
## Largest change in one month, either way.
const MONTHLY_CAP: int = 15
## Causes, in report order. "cap" is the line that takes the excess over ±15 off; "bounds"
## the part the 0..100 range cut.
const CAUSES: Array[StringName] = [
	&"locked",
	&"surveyed",
	&"research",
	&"reports",
	&"within_budget",
	&"in_red",
	&"idle",
	&"cap",
	&"bounds",
]
## Change per lock, survey, project and analyst, and per month for the month causes.
const LOCK: int = 5
const SURVEY: int = 2
const RESEARCH: int = 3
const REPORT: int = 1
const WITHIN_BUDGET: int = 2
const IN_RED: int = -5
const IDLE: int = -4
## Review keys: 70 or more, 30 to 69, below 30.
const PLEASED: StringName = &"pleased"
const NOTES: StringName = &"notes"
const QUESTIONS: StringName = &"questions"
const REVIEWS: Array[StringName] = [PLEASED, NOTES, QUESTIONS]
## Confidence for the grant, and below which the Committee questions the programme.
const GRANT_AT: int = 70
const QUESTION_BELOW: int = 30
## The review's one-off grant, in $k.
const GRANT_K: int = 1000
## Month-ends in a row in the red that raise the warning.
const RED_MONTHS_WARNING: int = 3
## Month-end reports kept in the save.
const REPORTS_KEPT: int = 6
## The room whose analysts file reports, and their role.
const REPORT_ROOM: StringName = &"room_control"
const ANALYST: StringName = &"role_analyst"


## Allocation for [param confidence] with [param base_k] at 50:
## base × (0.5 + Confidence ÷ 100), in $k (exact for $3,000k: 1,500 + 30 × Confidence).
static func allocation_k(base_k: int, confidence: int) -> int:
	return base_k * (50 + confidence) / 100


## [param total] limited to ±[constant MONTHLY_CAP].
static func capped(total: int) -> int:
	return clampi(total, -MONTHLY_CAP, MONTHLY_CAP)


## [param confidence] after [param change], kept within 0..100.
static func changed(confidence: int, change: int) -> int:
	return clampi(confidence + change, MIN, MAX)


## True when the month-end on 1 [param month] holds a quarterly review (Jan, Apr, Jul, Oct).
static func is_review_month(month: int) -> bool:
	return month in [1, 4, 7, 10]


## The review key for [param confidence] after the month's change.
static func review_of(confidence: int) -> StringName:
	if confidence >= GRANT_AT:
		return PLEASED
	return NOTES if confidence >= QUESTION_BELOW else QUESTIONS


## The grant of review [param review], in $k.
static func grant_k(review: StringName) -> int:
	return GRANT_K if review == PLEASED else 0


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
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## Every world surveyed (horizon record taken by the pole camera), in id order.
static func surveyed_worlds(state: GameState) -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(state.worlds.horizon_records.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## The ids of [param current] not in [param credited], in [param current]'s order.
static func new_ids(current: Array[StringName], credited: Array[StringName]) -> Array[StringName]:
	var fresh: Array[StringName] = []
	for id: StringName in current:
		if not id in credited:
			fresh.append(id)
	return fresh
