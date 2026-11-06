class_name SoakStaff
extends RefCounted
## The soak bot's staff moves: now and then it hires the first candidate on the list and,
## once every bed is taken, dismisses its newest hire again. A hire who has arrived is
## assigned to the first room with a free slot of their role (scientists to the lab, analysts
## to the Control Room; engineers wait, as the bot builds no Workshop).
## Bible: technical-architecture.md#testing-and-tooling (Soak test),
## docs/content/m26-staff-and-money.md section 2

## The bot considers a staff move once every this many ticks (ten days).
const EVERY_TICKS: int = 14400
## Offset of the move inside that period, so it never falls on a month start.
const AT_TICK: int = 7000
## The bot looks for someone to assign once every this many ticks (an hour), at minute 30.
const ASSIGN_EVERY_TICKS: int = 60
const ASSIGN_AT_TICK: int = 30
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


## Assigns the first Unassigned person on base to the first standing room with a free slot of
## their role, once an hour while the clock runs; true when it sent the command.
static func assign(simulation: Simulation) -> bool:
	var state: GameState = simulation.state
	if state.clock.is_paused or state.clock.tick % ASSIGN_EVERY_TICKS != ASSIGN_AT_TICK:
		return false
	for person: PersonState in state.staff.people:
		if person.is_assigned() or not person.is_on_base(state.clock.tick):
			continue
		for room: RoomState in state.base.rooms:
			if StaffRules.slots(state, room) <= 0:
				continue
			if StaffRules.assign_error(state, person.id, room.id).is_empty():
				simulation.submit(AssignStaffCommand.create(person.id, room.id))
				return true
	return false
