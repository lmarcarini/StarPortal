class_name ExpeditionUnlock
extends RefCounted
## The Expeditions unlock and the Directorate's lent soldiers (docs/content/m3-beyond-the-ring.md
## section 4; owner decision 3 in section 9). When the first world is Locked (M4c-22; it was Probed
## before) (or an expedition card calls [method unlock]), the game sets the [constant FLAG] flag,
## the Infirmary joins the Base build palette (not research) and the Directorate lends Maj. Ruth
## Adair and Sgt Owen Hale: soldiers of skill 3, on base at once, with no bed and a normal salary. A
## lent soldier lost ([method lose_person]) is replaced 7 days later ([method lend_due]), with a Log
## line. Changes only the GameState it is given: call it from Command.apply() or SimSystem.tick()
## (StaffCareSystem), or from a test.
## Bible: docs/content/m3-beyond-the-ring.md sections 4 and 9

## Flag set (true) once Expeditions are unlocked; expedition cards read it through
## [method is_unlocked].
const FLAG: StringName = &"expeditions_unlocked"
## The room def the unlock adds to the Base palette.
const INFIRMARY_DEF: StringName = &"room_infirmary"
## Event posted for each lent soldier (args: person id); LogRules writes its Log line.
const LENT_EVENT: StringName = &"soldier_lent"
## Skill of every lent soldier.
const LENT_SKILL: int = 3
## Days from losing a lent soldier to the replacement.
const REPLACEMENT_DAYS: int = 7
## The two soldiers lent at the unlock, in order.
const FIRST_LENT: Array[String] = ["Maj. Ruth Adair", "Sgt Owen Hale"]
## Names of replacements, first one not on the roster (cycling when all are).
const REPLACEMENT_NAMES: Array[String] = [
	"Capt. Lena Okoye", "Sgt Marco Vidal", "Lt Hana Sato", "Sgt Piet de Wit", "Cpl Ada Murray"
]


## True once Expeditions are unlocked in [param state].
static func is_unlocked(state: GameState) -> bool:
	return state.flags.get(FLAG, false) == true


## True when [param state] should unlock now: not yet unlocked and some world Locked.
static func is_due(state: GameState) -> bool:
	if is_unlocked(state):
		return false
	for world_id: StringName in state.worlds.statuses:
		if state.worlds.has_reached(world_id, WorldsState.WorldStatus.LOCKED):
			return true
	return false


## Unlocks Expeditions in [param state]: sets the flag, lets the Infirmary be built and lends
## the two first soldiers. Returns false, changing nothing, when already unlocked.
static func unlock(state: GameState) -> bool:
	if is_unlocked(state):
		return false
	state.flags[FLAG] = true
	UnlockRules.apply_to_game(state, UnlockRules.EFFECT_UNLOCK_ROOM, INFIRMARY_DEF)
	for display_name: String in FIRST_LENT:
		lend(state, display_name)
	return true


## Adds a lent soldier named [param display_name] to [param state]'s roster, on base at once
## and Unassigned, and posts [constant LENT_EVENT]. Returns the person.
static func lend(state: GameState, display_name: String) -> PersonState:
	var balance: BalanceConfig = state.balance if state.balance != null else BalanceConfig.new()
	var person := PersonState.new()
	person.name = display_name
	person.role = StartingStaff.SOLDIER
	person.skill = LENT_SKILL
	person.salary_k = StaffRules.salary_for_skill(balance, LENT_SKILL)
	person.arrives_tick = state.clock.tick
	person.lent = true
	state.staff.add_person(person)
	state.events.post(LENT_EVENT, [person.id])
	return person


## Removes [param person_id] from [param state]'s roster as lost (a lost team or a death in a
## rescue); a lent soldier's replacement falls due [constant REPLACEMENT_DAYS] days later.
## Returns false for an unknown person.
static func lose_person(state: GameState, person_id: StringName) -> bool:
	var person: PersonState = state.staff.find_person(person_id)
	if person == null:
		return false
	state.staff.remove_person(person_id)
	if person.lent:
		state.staff.lent_due.append(state.clock.tick + REPLACEMENT_DAYS * TimeMath.TICKS_PER_DAY)
	return true


## Lends a replacement for every entry of [param state]'s lent_due at or before its clock
## tick, oldest first. Returns how many were lent.
static func lend_due(state: GameState) -> int:
	var count: int = 0
	while not state.staff.lent_due.is_empty() and state.staff.lent_due[0] <= state.clock.tick:
		state.staff.lent_due.remove_at(0)
		lend(state, replacement_name(state))
		count += 1
	return count


## The next replacement's name: the first REPLACEMENT_NAMES name not on [param state]'s
## roster, else one picked by the next person number.
static func replacement_name(state: GameState) -> String:
	for display_name: String in REPLACEMENT_NAMES:
		if not state.staff.people.any(func(p: PersonState) -> bool: return p.name == display_name):
			return display_name
	return REPLACEMENT_NAMES[state.staff.next_person_number % REPLACEMENT_NAMES.size()]
