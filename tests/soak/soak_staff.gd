class_name SoakStaff
extends RefCounted
## The soak bot's staff moves: now and then it hires the first candidate on the list and,
## once every bed is taken, dismisses its newest hire again.
## Bible: technical-architecture.md#testing-and-tooling (Soak test),
## docs/content/m26-staff-and-money.md section 2

## The bot considers a staff move once every this many ticks (ten days).
const EVERY_TICKS: int = 14400
## Offset of the move inside that period, so it never falls on a month start.
const AT_TICK: int = 7000
## People of the starting crew; anyone after them was hired by the bot.
const CREW_SIZE: int = 5


## Sends at most one hire or dismissal on the bot's staff tick while the clock runs; true
## when it sent one.
static func work(simulation: Simulation) -> bool:
	var state: GameState = simulation.state
	if state.clock.is_paused or state.clock.tick % EVERY_TICKS != AT_TICK:
		return false
	var next: Command = null
	if StaffRules.beds_free(state) <= 0 and state.staff.people.size() > CREW_SIZE:
		var newest: PersonState = state.staff.people.back()
		next = DismissCommand.create(newest.id)
	elif not state.recruitment.candidates.is_empty():
		var first: CandidateState = state.recruitment.candidates[0]
		next = HireCommand.create(first.id)
	if next == null or not next.validate(state).is_ok:
		return false
	simulation.submit(next)
	return true
