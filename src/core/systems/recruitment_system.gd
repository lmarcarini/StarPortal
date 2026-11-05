class_name RecruitmentSystem
extends SimSystem
## Recruitment over time (docs/content/m26-staff-and-money.md section 2): on the 1st of each
## month a new candidate list replaces the old one (unhired candidates leave), drawn with the
## system's own seeded stream; and each hired person posts staff_arrived(person id) on the
## tick they arrive, which writes the Log line "Dr Ana Ferreira (Scientist, skill 4) has
## arrived.". Arrival itself needs no change: a person is on base once
## PersonState.arrives_tick is reached.
## Bible: docs/content/m26-staff-and-money.md section 2

## Id of the system and of its random stream.
const ID: StringName = &"recruitment"

var _balance: BalanceConfig
var _roles: Array[RoleDef] = []
var _names: StaffNameListDef


## Creates the system over [param balance], the [param roles] a drawn candidate may have
## (sorted by id here, so the draw does not depend on load order) and the name list
## [param names].
func _init(balance: BalanceConfig, roles: Array[RoleDef], names: StaffNameListDef) -> void:
	_balance = balance
	_roles.assign(roles)
	_roles.sort_custom(func(a: RoleDef, b: RoleDef) -> bool: return String(a.id) < String(b.id))
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


## Draws the month's list (RecruitmentRules.draw_list()) and posts candidates_changed.
func on_month(state: GameState) -> void:
	if _names == null:
		return
	var rng: RandomNumberGenerator = state.random.stream(ID)
	state.recruitment.replace_list(RecruitmentRules.draw_list(rng, _balance, _roles, _names))
	state.events.post(&"candidates_changed", [])
