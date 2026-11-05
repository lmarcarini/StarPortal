class_name StaffFixture
extends RefCounted
## Shared setup for the staff-effect tests: people of a role and skill assigned straight to a
## room (no slot or bed checks), so a test sets the exact total skill it needs.
## Bible: docs/content/m26-staff-and-money.md section 3


## Adds one person of [param role] per entry of [param skills] to [param state]'s roster, on
## base and assigned to [param room]. Returns them.
static func assign(
	state: GameState, room: RoomState, role: StringName, skills: Array[int]
) -> Array[PersonState]:
	var added: Array[PersonState] = []
	for skill: int in skills:
		var person := PersonState.new()
		person.name = "Test %d" % state.staff.next_person_number
		person.role = role
		person.skill = skill
		person.salary_k = 15 + 5 * skill
		person.room_id = room.id
		state.staff.add_person(person)
		added.append(person)
	return added


## Assigns engineers of [param skills] to [param workshop].
static func engineers(state: GameState, workshop: RoomState, skills: Array[int]) -> void:
	assign(state, workshop, StartingStaff.ENGINEER, skills)


## Assigns scientists of [param skills] to [param lab].
static func scientists(state: GameState, lab: RoomState, skills: Array[int]) -> void:
	assign(state, lab, StartingStaff.SCIENTIST, skills)
