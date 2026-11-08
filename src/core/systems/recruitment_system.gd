class_name RecruitmentSystem
extends SimSystem
## Recruitment over time (docs/content/m27-daily-rhythm.md section 3): at each daily
## settlement, candidates whose leave day has come leave the list; every third day
## (RecruitmentRules.is_arrival_day()) one candidate arrives, drawn with the system's own seeded
## stream (soldiers and medics only from the Expeditions unlock, one arrival in four,
## m3-beyond-the-ring.md section 4), replacing the oldest when the list is full, and leaving 12 days later. A change posts
## candidates_changed (no message, no Log line). Each hired person posts staff_arrived(person
## id) on the tick they arrive, which writes the Log line "Dr Ana Ferreira (Scientist, skill 4)
## has arrived.".
## Bible: docs/content/m27-daily-rhythm.md section 3, m26-staff-and-money.md section 2

## Id of the system and of its random stream.
const ID: StringName = &"recruitment"

var _balance: BalanceConfig
var _roles: Array[RoleDef] = []
var _expedition_roles: Array[RoleDef] = []
var _names: StaffNameListDef


## Creates the system over [param balance], the [param roles] a drawn candidate may have
## (sorted by id here, so the draw does not depend on load order) and the name list
## [param names].
func _init(balance: BalanceConfig, roles: Array[RoleDef], names: StaffNameListDef) -> void:
	_balance = balance
	for role: RoleDef in roles:
		if role.id in RecruitmentRules.EXPEDITION_ROLES:
			_expedition_roles.append(role)
		else:
			_roles.append(role)
	var by_id: Callable = func(a: RoleDef, b: RoleDef) -> bool: return String(a.id) < String(b.id)
	_roles.sort_custom(by_id)
	_expedition_roles.sort_custom(by_id)
	_names = names


## Returns &"recruitment".
func get_id() -> StringName:
	return ID


## Posts staff_arrived for each person whose arrival tick is the one this tick moves the clock
## to, in roster order.
func tick(state: GameState) -> void:
	var next: int = state.clock.tick + 1
	for person: PersonState in state.staff.people:
		if person.arrives_tick == next:
			state.events.post(&"staff_arrived", [person.id])


## Removes the candidates leaving today, adds today's arrival (if any) and posts
## candidates_changed when the list changed.
func on_day(state: GameState) -> void:
	var day: int = TimeMath.day_index(state.clock.tick)
	var changed: bool = state.recruitment.remove_leaving(day) > 0
	if _names != null and RecruitmentRules.is_arrival_day(day):
		changed = _arrive(state, day) or changed
	if changed:
		state.events.post(&"candidates_changed", [])


func _arrive(state: GameState, day: int) -> bool:
	if _roles.is_empty():
		return false
	var rng: RandomNumberGenerator = state.random.stream(ID)
	if state.recruitment.candidates.size() >= _balance.candidates_per_list:
		state.recruitment.remove_oldest()
	var list: Array[CandidateState] = state.recruitment.candidates
	var role: RoleDef = null
	if ExpeditionUnlock.is_unlocked(state):
		role = RecruitmentRules.unlocked_arrival_role(rng, _roles, _expedition_roles, list)
	else:
		role = RecruitmentRules.arrival_role(rng, _roles, list)
	if role == null:
		return false
	var candidate: CandidateState = RecruitmentRules.draw_candidate(rng, _balance, role, _names)
	candidate.leaves_day = day + RecruitmentRules.STAY_DAYS
	state.recruitment.add_candidate(candidate)
	return true
