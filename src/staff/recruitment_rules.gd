class_name RecruitmentRules
extends RefCounted
## Pure rules of recruitment (docs/content/m26-staff-and-money.md section 2,
## m27-daily-rhythm.md section 3): the fixed first list, the seeded arrival every 3 days,
## fees, arrival delays, pipelines and the reasons a hire or a
## dismissal is refused. No side effects; the generator is the caller's.
## Bible: docs/content/m26-staff-and-money.md sections 2 and 7,
## docs/content/m27-daily-rhythm.md section 3

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
## Days between two arrivals (docs/content/m27-daily-rhythm.md section 3).
const ARRIVAL_EVERY_DAYS: int = 3
## Days a candidate stays on the list: arrival day + STAY_DAYS is its leave day.
const STAY_DAYS: int = 12
## Roles every list holds at least one of, in list order.
const REQUIRED_ROLES: Array[StringName] = [StartingStaff.SCIENTIST, StartingStaff.ENGINEER]
## Translation key of each role's pipeline.
const PIPELINE_KEYS: Dictionary[StringName, StringName] = {
	StartingStaff.SCIENTIST: &"STAFF_PIPELINE_ACADEMIA",
	StartingStaff.ENGINEER: &"STAFF_PIPELINE_MILITARY",
	StartingStaff.ANALYST: &"STAFF_PIPELINE_INTELLIGENCE",
	StartingStaff.SOLDIER: &"STAFF_PIPELINE_MILITARY",
	StartingStaff.MEDIC: &"STAFF_PIPELINE_ACADEMIA",
}
## Roles that join the draw only from the Expeditions unlock (m3-beyond-the-ring.md section 4).
const EXPEDITION_ROLES: Array[StringName] = [StartingStaff.SOLDIER, StartingStaff.MEDIC]
## From the unlock, one arrival in this many is a soldier or medic.
const EXPEDITION_ROLE_ODDS: int = 4


## The first list of a new game under [param balance] (no ids yet), leaving on days 3, 6, 9
## and 12.
static func first_list(balance: BalanceConfig) -> Array[CandidateState]:
	var list: Array[CandidateState] = []
	for index: int in FIRST_LIST.size():
		var entry: Array = FIRST_LIST[index]
		var display_name: String = entry[0]
		var role: StringName = entry[1]
		var skill: int = entry[2]
		var candidate: CandidateState = _candidate(balance, display_name, role, skill)
		candidate.leaves_day = (index + 1) * ARRIVAL_EVERY_DAYS
		list.append(candidate)
	return list


## The role of the candidate arriving on a list that holds [param list] (after leavers):
## the first REQUIRED_ROLES role the list lacks, with no draw; otherwise one drawn from
## [param roles] (in the given order) with one rng.randi_range(). Null with no roles.
static func arrival_role(
	rng: RandomNumberGenerator, roles: Array[RoleDef], list: Array[CandidateState]
) -> RoleDef:
	if roles.is_empty():
		return null
	for required: StringName in REQUIRED_ROLES:
		if not list.any(func(c: CandidateState) -> bool: return c.role == required):
			for role: RoleDef in roles:
				if role.id == required:
					return role
	return roles[rng.randi_range(0, roles.size() - 1)]


## The role of a drawn arrival after the Expeditions unlock: the first missing REQUIRED_ROLES
## role (no draw), else one in EXPEDITION_ROLE_ODDS a role of [param expedition] and otherwise
## arrival_role() over [param base]; draws with [param rng] only. Null with no roles.
static func unlocked_arrival_role(
	rng: RandomNumberGenerator,
	base: Array[RoleDef],
	expedition: Array[RoleDef],
	list: Array[CandidateState]
) -> RoleDef:
	for required: StringName in REQUIRED_ROLES:
		if not list.any(func(c: CandidateState) -> bool: return c.role == required):
			return arrival_role(rng, base, list)
	if not expedition.is_empty() and rng.randi_range(1, EXPEDITION_ROLE_ODDS) == 1:
		return expedition[rng.randi_range(0, expedition.size() - 1)]
	return arrival_role(rng, base, list)


## A candidate of [param role] drawn with [param rng]: the skill, then the name
## (StaffNames.draw()). No id or leave day yet. Same generator state, same candidate.
static func draw_candidate(
	rng: RandomNumberGenerator, balance: BalanceConfig, role: RoleDef, names: StaffNameListDef
) -> CandidateState:
	var skill: int = draw_skill(rng, balance.candidate_skill_weights)
	var display_name: String = StaffNames.draw(rng, names, role)
	return _candidate(balance, display_name, role.id, skill)


## True when a candidate arrives on the settlement of day [param day]: every
## ARRIVAL_EVERY_DAYS days after the first (4 Jan, 7 Jan, ...).
static func is_arrival_day(day: int) -> bool:
	return day > 0 and day % ARRIVAL_EVERY_DAYS == 0


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
## arriving or not, except a member of the planned or away expedition team).
static func dismiss_error(state: GameState, person_id: StringName) -> StringName:
	if state.staff.find_person(person_id) == null:
		return UNKNOWN_PERSON
	return StaffRules.ON_EXPEDITION if StaffRules.is_on_team(state, person_id) else &""


static func _candidate(
	balance: BalanceConfig, display_name: String, role: StringName, skill: int
) -> CandidateState:
	var candidate := CandidateState.create(
		display_name, role, skill, StaffRules.salary_for_skill(balance, skill)
	)
	candidate.arrival_ticks = arrival_ticks(balance, role)
	return candidate
