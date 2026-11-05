class_name ResearchRules
extends RefCounted
## Pure rules of research (docs/content/m25-lean-start.md section 3): the project list, whether
## a lab is on, whether a project may start (with the reason when not), its length, progress
## and refund. One project runs at a time. Its speed comes from the scientists in every lab
## that is on (docs/content/m26-staff-and-money.md section 3): max(25%, total skill ÷ 6), at
## most 200%, so a second lab adds scientist slots, not a second project or a higher cap. The
## listed days are the time for a standard crew (total skill 6, 100%). Never touches a Node or
## an autoload, and never changes the state.
## Bible: docs/content/m25-lean-start.md section 3, docs/content/m26-staff-and-money.md section 3

## The Research Lab's def id.
const LAB_DEF: StringName = &"room_research_lab"
## Share of the cost a cancel refunds, in percent.
const REFUND_PERCENT: int = 50
## Speed is counted in 1 / SPEED_DENOMINATOR of the standard crew's (one skill point = 2).
const SPEED_DENOMINATOR: int = 12
## Speed per scientist skill point, in twelfths (skill ÷ 6).
const SPEED_PER_SKILL: int = 2
## Slowest speed, an empty lab, in twelfths (25%).
const MIN_SPEED: int = 3
## Fastest speed, in twelfths (200%).
const MAX_SPEED: int = 24


## Every ResearchDef of [param state], projects and locked slots, in list order (by order,
## then id).
static func projects(state: GameState) -> Array[ResearchDef]:
	var list: Array[ResearchDef] = []
	list.assign(state.research_defs.values())
	list.sort_custom(_before)
	return list


## True when [param state]'s base has a Research Lab that is built, not being demolished and
## switched on.
static func has_lab_on(state: GameState) -> bool:
	var def: RoomDef = state.room_defs.get(LAB_DEF)
	for room: RoomState in state.base.rooms:
		if room.def_id == LAB_DEF and PowerRules.is_running(room, def):
			return true
	return false


## Whether [param project_id] may start now: ok, or failed with &"unknown_project",
## &"project_locked" (detail: the lock), &"project_done", &"needs_lab" ("Needs a Research Lab
## that is on."), &"research_running" (detail: the running project; "One project at a
## time."), &"needs_project" (detail: the first unmet need) or &"insufficient_funds"
## (detail: the cost in $k).
static func can_start(state: GameState, project_id: StringName) -> CommandResult:
	var def: ResearchDef = state.research_defs.get(project_id)
	if def == null:
		return CommandResult.fail(&"unknown_project", String(project_id))
	if def.is_locked():
		return CommandResult.fail(&"project_locked", String(def.lock))
	if state.research.is_done(project_id):
		return CommandResult.fail(&"project_done", String(project_id))
	if not has_lab_on(state):
		return CommandResult.fail(&"needs_lab")
	if state.research.is_running():
		return CommandResult.fail(&"research_running", String(state.research.active))
	for need: StringName in def.needs:
		if not state.research.is_done(need):
			return CommandResult.fail(&"needs_project", String(need))
	var funds_error: StringName = state.budget.spend_error(def.cost_k)
	if not funds_error.is_empty():
		return CommandResult.fail(funds_error, "%d" % def.cost_k)
	return CommandResult.ok()


## Ticks of work [param def] needs: its days in ticks, the time at 100% (a standard crew).
static func total_ticks(def: ResearchDef) -> int:
	return def.days * TimeMath.TICKS_PER_DAY


## Total skill of the scientists assigned to [param state]'s labs that are on; with
## [param standing], of every lab standing, on or off.
static func scientist_skill(state: GameState, standing: bool = false) -> int:
	var def: RoomDef = state.room_defs.get(LAB_DEF)
	var total: int = 0
	for room: RoomState in state.base.rooms:
		if room.def_id != LAB_DEF:
			continue
		if PowerRules.is_running(room, def) or (standing and PowerRules.is_standing(room)):
			for person: PersonState in StaffRules.assigned(state, room):
				total += person.skill
	return total


## Research speed of [param state] in twelfths of the standard crew's: 2 per skill point,
## between MIN_SPEED (25%) and MAX_SPEED (200%).
static func speed(state: GameState) -> int:
	return clampi(SPEED_PER_SKILL * scientist_skill(state), MIN_SPEED, MAX_SPEED)


## Research speed of [param state] as a whole percentage, rounded down (25 to 200).
static func speed_percent(state: GameState) -> int:
	return speed(state) * 100 / SPEED_DENOMINATOR


## Ticks of work the active project gets on [param state]'s current clock tick while a lab
## is on (RateSteps: whole ticks, exact across saves).
static func step(state: GameState) -> int:
	return RateSteps.step(state.clock.tick, speed(state), SPEED_DENOMINATOR)


## Ticks of work left on [param state]'s active project; 0 when none runs or its def is unknown.
static func work_left(state: GameState) -> int:
	var def: ResearchDef = state.research_defs.get(state.research.active)
	if def == null:
		return 0
	return maxi(0, total_ticks(def) - state.research.ticks_done)


## Clock ticks until [param state]'s active project finishes at the current speed, the lab
## staying on; while no lab is on (paused), at the speed the standing labs' scientists would
## give once switched back on. 0 when none runs.
static func ticks_left(state: GameState) -> int:
	var rate: int = speed(state)
	if not has_lab_on(state):
		rate = clampi(SPEED_PER_SKILL * scientist_skill(state, true), MIN_SPEED, MAX_SPEED)
	return RateSteps.ticks_to(work_left(state), state.clock.tick, rate, SPEED_DENOMINATOR)


## Share of the active project done, 0.0 to 1.0; 0.0 when none runs.
static func progress(state: GameState) -> float:
	var def: ResearchDef = state.research_defs.get(state.research.active)
	if def == null:
		return 0.0
	return clampf(float(state.research.ticks_done) / float(total_ticks(def)), 0.0, 1.0)


## What cancelling [param def] refunds, in $k: half its cost, rounded down.
static func refund_k(def: ResearchDef) -> int:
	return def.cost_k * REFUND_PERCENT / 100


static func _before(a: ResearchDef, b: ResearchDef) -> bool:
	if a.order != b.order:
		return a.order < b.order
	return String(a.id) < String(b.id)
