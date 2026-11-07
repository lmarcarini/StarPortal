class_name UnlockRules
extends RefCounted
## Pure rules of what research unlocks (docs/content/m25-lean-start.md sections 1-3): the
## effects a project applies to an UnlockState, the M2.5 projects' effects, and whether a room
## may be built or a level dug, with the reason when not. Never touches a Node or an autoload.
## [method apply] and [method apply_project] change only the UnlockState they are given; call
## them from Command.apply() or SimSystem.tick() (the research card), or from a test or bot.
## Bible: docs/content/m25-lean-start.md sections 1-3

## Effect: the room def id in the value (StringName or String) may be built.
const EFFECT_UNLOCK_ROOM: StringName = &"unlock_room"
## Effect: levels down to the whole number in the value may be dug (never lowers it).
const EFFECT_DIG_DEPTH: StringName = &"dig_depth"
## Effect: up to the whole number in the value of Capacitor Banks (never lowers it).
const EFFECT_BANK_CAP: StringName = &"bank_cap"
## Effect: every diesel Power Plant's upkeep per 30 days becomes the whole $k in the value.
const EFFECT_PLANT_UPKEEP: StringName = &"plant_upkeep"
## The Power Plant's def id, the room EFFECT_PLANT_UPKEEP overrides.
const PLANT_DEF: StringName = &"room_power_plant"
## Rooms that stay locked until M3: no research unlocks them (Quarters is unlocked from the
## start in M2.6, docs/content/m26-staff-and-money.md section 3).
const STAFF_LOCKED: Array[StringName] = [&"room_infirmary"]
## The M2.5 projects R1-R7 in list order, by id: each an array of [effect, value] pairs. The
## research card owns costs, days and prerequisites; this is only what finishing one unlocks.
const PROJECTS: Dictionary = {
	&"excavation_survey": [[&"dig_depth", 2], [&"unlock_room", &"room_stairs"]],
	&"lift_shaft": [[&"unlock_room", &"room_lift"]],
	&"deep_excavation": [[&"dig_depth", 4]],
	&"second_plant": [[&"unlock_room", &"room_power_plant"]],
	&"fuel_contracts": [[&"plant_upkeep", 100]],
	&"bank_array": [[&"bank_cap", 3]],
	&"field_engineering": [[&"unlock_room", &"room_workshop"]],
}


## Applies one [param effect] with [param value] to [param unlocks]. Returns false, changing
## nothing, for an unknown effect or a value of the wrong type (a room id must be a non-empty
## StringName or String; the others a whole number of at least 0).
static func apply(unlocks: UnlockState, effect: StringName, value: Variant) -> bool:
	if effect == EFFECT_UNLOCK_ROOM:
		if not (value is StringName or value is String) or str(value).is_empty():
			return false
		var def_id := StringName(str(value))
		if not unlocks.has_room(def_id):
			unlocks.rooms.append(def_id)
		return true
	if not RoomState.is_count(value):
		return false
	var amount: int = RoomState.read_count(value)
	match effect:
		EFFECT_DIG_DEPTH:
			unlocks.dig_depth = maxi(unlocks.dig_depth, amount)
		EFFECT_BANK_CAP:
			unlocks.bank_cap = maxi(unlocks.bank_cap, amount)
		EFFECT_PLANT_UPKEEP:
			unlocks.upkeep_overrides[PLANT_DEF] = amount
		_:
			return false
	return true


## Applies every effect of the project [param project_id] (a key of [constant PROJECTS]) to
## [param unlocks]. Returns false, changing nothing, for an unknown project.
static func apply_project(unlocks: UnlockState, project_id: StringName) -> bool:
	if not PROJECTS.has(project_id):
		return false
	for pair: Array in PROJECTS[project_id]:
		var effect: StringName = pair[0]
		apply(unlocks, effect, pair[1])
	return true


## The translation key of [param project_id]'s name, e.g. RESEARCH_BANK_ARRAY_NAME.
static func project_name_key(project_id: StringName) -> StringName:
	return StringName("RESEARCH_%s_NAME" % String(project_id).to_upper())


## The first project whose [param effect] covers [param value] (the room id for
## EFFECT_UNLOCK_ROOM, at least the number for the others), or &"" when none does.
static func project_for(effect: StringName, value: Variant) -> StringName:
	for project_id: StringName in PROJECTS:
		for pair: Array in PROJECTS[project_id]:
			if pair[0] != effect:
				continue
			if effect == EFFECT_UNLOCK_ROOM and str(pair[1]) == str(value):
				return project_id
			if (
				effect != EFFECT_UNLOCK_ROOM
				and RoomState.read_count(pair[1]) >= RoomState.read_count(value)
			):
				return project_id
	return &""


## Whether [param state] may build a room of [param def_id] now, as far as unlocks go:
## ok, or failed with &"unknown_room", &"needs_staff" (Infirmary),
## &"needs_research" (detail: the project id that unlocks it), &"not_buildable" (locked and
## no project unlocks it) or &"bank_cap" (detail: the project that raises the cap, or "").
## Placement and money are the commands' checks.
static func can_build_room(state: GameState, def_id: StringName) -> CommandResult:
	if not state.room_defs.has(def_id):
		return CommandResult.fail(&"unknown_room", String(def_id))
	if not state.unlocks.has_room(def_id):
		if def_id in STAFF_LOCKED:
			return CommandResult.fail(&"needs_staff", String(def_id))
		var project: StringName = project_for(EFFECT_UNLOCK_ROOM, def_id)
		if project.is_empty():
			return CommandResult.fail(&"not_buildable", String(def_id))
		return CommandResult.fail(&"needs_research", String(project))
	if (
		def_id == StartingBase.CAPACITOR_BANK_DEF
		and bank_count(state.base) >= state.unlocks.bank_cap
	):
		return CommandResult.fail(
			&"bank_cap", String(project_for(EFFECT_BANK_CAP, state.unlocks.bank_cap + 1))
		)
	return CommandResult.ok()


## Whether [param state] may dig its next level now, as far as unlocks go: ok, or failed with
## &"needs_research" (detail: the project that allows it) or &"level_limit" (no project does).
## A running dig, the balance's own limit and money are DigLevelCommand's checks.
static func can_dig(state: GameState) -> CommandResult:
	var next: int = state.base.level_count + 1
	if next <= state.unlocks.dig_depth:
		return CommandResult.ok()
	var project: StringName = project_for(EFFECT_DIG_DEPTH, next)
	if project.is_empty():
		return CommandResult.fail(&"level_limit")
	return CommandResult.fail(&"needs_research", String(project))


## Capacitor Banks in [param base] that count against the cap: built, building or a site, but
## not one being demolished.
static func bank_count(base: BaseState) -> int:
	var count: int = 0
	for room: RoomState in base.rooms:
		if room.def_id == StartingBase.CAPACITOR_BANK_DEF and not room.is_demolishing():
			count += 1
	return count


## The upkeep per 30 days of a room of [param def] in $k under [param unlocks]: its override when
## research set one, else the def's upkeep_k.
static func upkeep_k(unlocks: UnlockState, def: RoomDef) -> int:
	return unlocks.upkeep_overrides.get(def.id, def.upkeep_k)


## Like [method apply], on [param state]'s unlocks, and also drops [param state]'s cached power
## totals and powered-rooms list (PowerRules.totals()), so an effect can never leave the cache
## stale. The research card calls this one; [method apply] stays for bare UnlockStates.
static func apply_to_game(state: GameState, effect: StringName, value: Variant) -> bool:
	if not apply(state.unlocks, effect, value):
		return false
	state.power.totals_revision = -1
	state.power.powered_rooms_base = -1
	return true
