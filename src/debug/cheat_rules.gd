class_name CheatRules
extends RefCounted
## What each cheat does to the state, for DebugCheatCommand. Pure static functions that change
## only the state they are given; called from the command's apply().
## Bible: docs/bible/technical-architecture.md#testing-and-tooling (M4.6-04)

## The command-line flag that turns cheats on in a release build.
const FLAG: String = "--cheats"


## True in debug builds, or when the game was started with --cheats.
static func enabled() -> bool:
	return (
		OS.is_debug_build()
		or OS.get_cmdline_args().has(FLAG)
		or (OS.get_cmdline_user_args().has(FLAG))
	)


## Adds [param amount_k] to the funds.
static func funds(state: GameState, amount_k: int) -> void:
	state.budget.funds_k += amount_k
	state.events.post(&"budget_changed", [state.budget.funds_k])


## Sets Confidence to [param value] (0 to 100).
static func confidence(state: GameState, value: int) -> void:
	state.committee.confidence = clampi(value, 0, 100)
	state.events.post(&"confidence_changed", [state.committee.confidence])


## Fills the capacitors.
static func charge(state: GameState) -> void:
	state.power.stored_mwh = PowerRules.capacity_mwh(state)


## Finishes every running research project.
static func finish_research(state: GameState) -> void:
	for room_id: StringName in state.research.benches.keys():
		var def: ResearchDef = state.research_defs.get(state.research.benches[room_id].active)
		if def != null:
			ResearchSystem.finish(state, def, room_id)


## Finishes every site and dig on their next tick.
static func finish_sites(state: GameState) -> void:
	for room: RoomState in state.base.rooms:
		if room.build_ticks_left > 1:
			room.build_ticks_left = 1
	for level: LevelState in state.base.levels:
		if level.dig_ticks_left > 1:
			level.dig_ticks_left = 1


## Adds a [param role] person of [param skill] who arrives now; bed rules are ignored.
static func add_staff(state: GameState, role: StringName, skill: int) -> void:
	var person := PersonState.new()
	person.role = role
	person.skill = clampi(skill, PersonState.MIN_SKILL, PersonState.MAX_SKILL)
	person.name = (
		"Cheat %s %d"
		% [String(role).trim_prefix("role_").capitalize(), state.staff.people.size() + 1]
	)
	var balance: BalanceConfig = state.balance if state.balance != null else BalanceConfig.new()
	person.salary_k = balance.salary_base_k + balance.salary_per_skill_k * person.skill
	person.arrives_tick = state.clock.tick
	state.staff.add_person(person)
	state.events.post(&"staff_changed", [&"cheat", &"", 1])


## Brings [param artefact] into holding (or to the gate when holding is full).
static func grant_artefact(state: GameState, artefact: StringName) -> void:
	StoryRulesItems.give_artefact(state, artefact)


## Finishes every research project that is not done, applying its effects.
static func unlock_all_research(state: GameState) -> void:
	var defs: Array[ResearchDef] = []
	defs.assign(state.research_defs.values())
	defs.sort_custom(func(a: ResearchDef, b: ResearchDef) -> bool: return a.order < b.order)
	for def: ResearchDef in defs:
		if not state.research.is_done(def.id):
			StoryRules.apply_all(state, def.effects, def.id)
			state.research.done.append(def.id)
			if not state.research.revealed.has(def.id):
				state.research.revealed.append(def.id)
	state.research.benches.clear()
	state.events.post(&"research_done", [&"", &""])


## Heals every injured person.
static func heal_all(state: GameState) -> void:
	for person: PersonState in state.staff.people:
		person.injury = PersonState.Injury.NONE
		person.recovery_left = 0
	state.events.post(&"staff_changed", [&"cheat", &"", 0])
