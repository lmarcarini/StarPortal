class_name StartingStaff
extends RefCounted
## Builds the crew a new game starts with (docs/content/m26-staff-and-money.md section 7):
## five people with fixed names, the analyst in the Control Room and the others Unassigned, the
## scientists waiting for the first Research Lab and the engineers for the first Workshop
## (StaffChanges.auto_assign()). Pure: depends only on the base and the BalanceConfig.
## Bible: docs/content/m26-staff-and-money.md section 7

## Scientist role id.
const SCIENTIST: StringName = &"role_scientist"
## Engineer role id.
const ENGINEER: StringName = &"role_engineer"
## Analyst role id.
const ANALYST: StringName = &"role_analyst"
## Room def ids whose first finished room takes the Unassigned people of its role.
const AUTO_ASSIGN_DEFS: Array[StringName] = [&"room_research_lab", &"room_workshop"]
## Def id of the room the analyst starts in.
const CONTROL_ROOM_DEF: StringName = &"room_control"
## The crew, as [name, role id, skill, starts in the Control Room]. The names are fixed by the
## design (section 7), so every new game opens the same way.
const CREW: Array = [
	["Dr Ana Ferreira", SCIENTIST, 3, false],
	["Dr Tom Okafor", SCIENTIST, 3, false],
	["Sgt Lena Brandt", ENGINEER, 3, false],
	["Cpl Raul Mendes", ENGINEER, 2, false],
	["Mira Kovacs", ANALYST, 3, true],
]


## Returns the starting StaffState for [param base] under [param balance]: CREW on base from
## tick 0, salaries from StaffRules.salary_for_skill(), the analyst in [param base]'s Control
## Room (Unassigned when it has none) and AUTO_ASSIGN_DEFS pending.
static func build(base: BaseState, balance: BalanceConfig) -> StaffState:
	var staff := StaffState.new()
	var control_id: StringName = _control_room_id(base)
	for entry: Array in CREW:
		var person := PersonState.new()
		person.name = entry[0]
		person.role = entry[1]
		person.skill = entry[2]
		person.salary_k = StaffRules.salary_for_skill(balance, person.skill)
		var in_control: bool = entry[3]
		if in_control:
			person.room_id = control_id
		staff.add_person(person)
	staff.auto_assign = AUTO_ASSIGN_DEFS.duplicate()
	return staff


static func _control_room_id(base: BaseState) -> StringName:
	for room: RoomState in base.rooms:
		if room.def_id == CONTROL_ROOM_DEF:
			return room.id
	return &""
