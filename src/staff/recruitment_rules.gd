class_name RecruitmentRules
extends RefCounted
## Pure rules of recruitment (docs/content/m26-staff-and-money.md section 2): the fixed first
## list, the seeded monthly draw, fees, arrival delays, pipelines and the reasons a hire or a
## dismissal is refused. No side effects; the generator is the caller's.
## Bible: docs/content/m26-staff-and-money.md sections 2 and 7

## Hire refusal: no candidate with that id on the list.
const UNKNOWN_CANDIDATE: StringName = &"unknown_candidate"
## Hire refusal: every bed is taken or reserved ("No free bed. Build Quarters.").
const NO_FREE_BED: StringName = &"no_free_bed"
## Dismiss refusal: no person with that id.
const UNKNOWN_PERSON: StringName = &"unknown_person"
## staff_changed reason of a hire (count 1, no room).
const HIRED: StringName = &"hired"
## staff_changed reason of a dismissal (count 1; the def of the room left, or empty).
const DISMISSED: StringName = &"dismissed"
## The fixed first list (section 2), as [name, role id, skill].
const FIRST_LIST: Array = [
	["Dr Ines Moreau", StartingStaff.SCIENTIST, 3],
	["Dr Kenji Arai", StartingStaff.SCIENTIST, 3],
	["Sgt Dan Kowalski", StartingStaff.ENGINEER, 3],
	["Cpl Sara Lind", StartingStaff.ENGINEER, 3],
]
## Roles every drawn list holds at least one of, in list order.
const REQUIRED_ROLES: Array[StringName] = [StartingStaff.SCIENTIST, StartingStaff.ENGINEER]
## Translation key of each role's pipeline.
const PIPELINE_KEYS: Dictionary[StringName, StringName] = {
	StartingStaff.SCIENTIST: &"STAFF_PIPELINE_ACADEMIA",
	StartingStaff.ENGINEER: &"STAFF_PIPELINE_MILITARY",
	StartingStaff.ANALYST: &"STAFF_PIPELINE_INTELLIGENCE",
}


## The first list of a new game under [param balance] (no ids yet).
static func first_list(balance: BalanceConfig) -> Array[CandidateState]:
	var list: Array[CandidateState] = []
	for entry: Array in FIRST_LIST:
		var display_name: String = entry[0]
		var role: StringName = entry[1]
		var skill: int = entry[2]
		list.append(_candidate(balance, display_name, role, skill))
	return list


## A list of balance.candidates_per_list candidates drawn with [param rng]: one of each
## REQUIRED_ROLES first, then roles drawn from [param roles] (in the given order). For each
## candidate the draws are, in order: the role (after the required slots only), the skill,
## then the name
## (StaffNames.draw()). Same generator state, same list.
static func draw_list(
	rng: RandomNumberGenerator,
	balance: BalanceConfig,
	roles: Array[RoleDef],
	names: StaffNameListDef
) -> Array[CandidateState]:
	var list: Array[CandidateState] = []
	if roles.is_empty():
		return list
	for index: int in balance.candidates_per_list:
		var role: RoleDef = _role_for_slot(rng, index, roles)
		var skill: int = draw_skill(rng, balance.candidate_skill_weights)
		var display_name: String = StaffNames.draw(rng, names, role)
		list.append(_candidate(balance, display_name, role.id, skill))
	return list


## A skill from 1 drawn with [param rng] under [param weights] (weights[0] is skill 1); one
## call to rng.randi_range(). Skill 1 when the weights are empty or sum to 0.
static func draw_skill(rng: RandomNumberGenerator, weights: Array[int]) -> int:
	var total: int = 0
	for weight: int in weights:
		total += maxi(0, weight)
	if total <= 0:
		return PersonState.MIN_SKILL
	var roll: int = rng.randi_range(1, total)
	for index: int in weights.size():
		roll -= maxi(0, weights[index])
		if roll <= 0:
			return clampi(index + 1, PersonState.MIN_SKILL, PersonState.MAX_SKILL)
	return PersonState.MAX_SKILL


## The hiring fee of [param candidate] in $k: 30 days' salary.
static func fee_k(candidate: CandidateState) -> int:
	return candidate.salary_k


## Ticks from hiring to arrival for [param role] under [param balance] (its pipeline's days);
## one day for a role with no entry.
static func arrival_ticks(balance: BalanceConfig, role: StringName) -> int:
	var days: int = balance.hire_arrival_days.get(role, 1)
	return maxi(1, days) * TimeMath.TICKS_PER_DAY


## Translation key of [param role]'s pipeline ("Academia"), or &"" for an unknown role.
static func pipeline_key(role: StringName) -> StringName:
	return PIPELINE_KEYS.get(role, &"")


## Why [param candidate_id] cannot be hired, or &"" when they can: not on the list
## ([constant UNKNOWN_CANDIDATE]), no free bed counting people still arriving
## ([constant NO_FREE_BED]) or too little money (BudgetState.INSUFFICIENT_FUNDS).
static func hire_error(state: GameState, candidate_id: StringName) -> StringName:
	var candidate: CandidateState = state.recruitment.find_candidate(candidate_id)
	if candidate == null:
		return UNKNOWN_CANDIDATE
	if StaffRules.beds_free(state) <= 0:
		return NO_FREE_BED
	return state.budget.spend_error(fee_k(candidate))


## Why [param person_id] cannot be dismissed, or &"" when they can (anyone on the roster,
## arriving or not).
static func dismiss_error(state: GameState, person_id: StringName) -> StringName:
	return UNKNOWN_PERSON if state.staff.find_person(person_id) == null else &""


## Returns the role of list slot [param index]: a required role first, then one drawn.
static func _role_for_slot(
	rng: RandomNumberGenerator, index: int, roles: Array[RoleDef]
) -> RoleDef:
	if index < REQUIRED_ROLES.size():
		for role: RoleDef in roles:
			if role.id == REQUIRED_ROLES[index]:
				return role
	return roles[rng.randi_range(0, roles.size() - 1)]


static func _candidate(
	balance: BalanceConfig, display_name: String, role: StringName, skill: int
) -> CandidateState:
	var candidate := CandidateState.create(
		display_name, role, skill, StaffRules.salary_for_skill(balance, skill)
	)
	candidate.arrival_ticks = arrival_ticks(balance, role)
	return candidate
