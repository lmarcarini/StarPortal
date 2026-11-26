class_name HireCommand
extends Command
## The player hires a candidate from the rolling candidate list (docs/content/m26-staff-and-money.md
## section 2): the fee (30 days' salary) is paid at once, a bed is reserved and the person
## joins the roster Unassigned, arriving after their pipeline's delay. Posts budget_changed,
## candidates_changed and staff_changed(&"hired", &"", 1).
## Bible: docs/content/m26-staff-and-money.md section 2, m27-daily-rhythm.md section 3

## The command's stable type id.
const TYPE: StringName = &"hire"

## Id of the candidate to hire.
var candidate_id: StringName = &""


## Returns a command that hires [param candidate].
static func create(candidate: StringName) -> HireCommand:
	var command := HireCommand.new()
	command.candidate_id = candidate
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "candidate_id" is not a String.
static func from_dict(data: Dictionary) -> Result:
	var candidate: Variant = data.get("candidate_id")
	if not candidate is String:
		return Result.fail(&"malformed_command", "%s needs a string candidate_id" % TYPE)
	return Result.ok(create(StringName(str(candidate))))


## Returns &"hire".
func get_type() -> StringName:
	return TYPE


## RecruitmentRules.hire_error(): &"unknown_candidate", &"no_free_bed" or
## &"insufficient_funds".
func validate(state: GameState) -> CommandResult:
	var error: StringName = RecruitmentRules.hire_error(state, candidate_id)
	if not error.is_empty():
		return CommandResult.fail(error)
	return CommandResult.ok()


## Pays the fee, adds the person (arriving at the clock tick plus the candidate's delay) and
## takes the candidate off the list.
func apply(state: GameState) -> void:
	var candidate: CandidateState = state.recruitment.find_candidate(candidate_id)
	state.budget.spend(RecruitmentRules.fee_k(candidate))
	var person := PersonState.new()
	person.name = candidate.name
	person.role = candidate.role
	person.skill = candidate.skill
	person.salary_k = candidate.salary_k
	person.appearance = candidate.appearance.duplicate()
	person.arrives_tick = state.clock.tick + candidate.arrival_ticks
	state.staff.add_person(person)
	state.recruitment.remove_candidate(candidate_id)
	state.events.post(&"budget_changed", [state.budget.funds_k])
	state.events.post(&"candidates_changed", [])
	state.events.post(&"staff_changed", [RecruitmentRules.HIRED, &"", 1])


## Returns JSON-safe data: the type and "candidate_id".
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "candidate_id": String(candidate_id)}
