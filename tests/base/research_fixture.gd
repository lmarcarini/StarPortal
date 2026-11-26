class_name ResearchFixture
extends RefCounted
## Shared setup for the research tests: a new game over the real balance, room defs and
## research defs, with a built, switched-on Research Lab on Level 1 staffed by the starting
## scientists (two skill-3: 100%, the listed time); workshop() adds an Engineering bench.
## Bible: docs/content/m25-lean-start.md section 3, docs/content/m26-staff-and-money.md section 3

const RESEARCH_DIR: String = "res://data/research/"
## Where bench_for() puts the other research buildings.
const BENCH_ORIGINS: Dictionary[StringName, Vector2i] = {
	&"office": Vector2i(30, 2), &"xenotech": Vector2i(30, 12), &"xenobiology": Vector2i(34, 12)
}
## Where workshop() puts the Workshop: Level 1, east of the Control Room, on the spine.
const WORKSHOP_ORIGIN: Vector2i = Vector2i(24, 11)


## A new game (ConstructionFixture.state()) with every real ResearchDef and, when
## [param with_lab], a built Research Lab that is on (PowerFixture.lab()), which takes the
## waiting scientists.
static func state(with_lab: bool = true) -> GameState:
	var game: GameState = ConstructionFixture.state()
	load_research_defs(game)
	if with_lab:
		StaffChanges.auto_assign(game, PowerFixture.lab(game))
		game.events.drain()
	return game


## Loads every ResearchDef under data/research/ into [param game].research_defs.
static func load_research_defs(game: GameState) -> void:
	for file: String in DirAccess.get_files_at(RESEARCH_DIR):
		if file.ends_with(".tres"):
			var def: ResearchDef = load(RESEARCH_DIR + file)
			game.research_defs[def.id] = def


## Returns [param game]'s first Workshop, adding a built, switched-on one staffed with the
## waiting engineers when there is none (the Engineering bench).
static func workshop(game: GameState) -> RoomState:
	PowerFixture.load_room_defs(game)
	var found: RoomState = PowerFixture.first_room(game, &"room_workshop")
	if found == null:
		found = game.base.add_room(&"room_workshop", 1, WORKSHOP_ORIGIN)
		StaffChanges.auto_assign(game, found)
		game.events.drain()
	return found


## Returns a standing, staffed research building of [param discipline] in [param game],
## adding one (with two staff of its field when none wait) when there is none.
static func bench_for(game: GameState, discipline: StringName) -> RoomState:
	PowerFixture.load_room_defs(game)
	var rooms: Array[RoomState] = ResearchRules.buildings(game, discipline)
	if not rooms.is_empty():
		return rooms[0]
	if discipline == &"engineering":
		return workshop(game)
	for def: RoomDef in game.room_defs.values():
		if def.research_discipline != discipline:
			continue
		var origin: Vector2i = BENCH_ORIGINS.get(discipline, Vector2i(30, 2))
		var room: RoomState = game.base.add_room(def.id, 1, origin)
		for index: int in 2:
			var person := PersonState.new()
			person.id = StringName("bench_%s_%d" % [discipline, index])
			person.name = "Bench %d" % index
			person.role = def.staff_role
			person.skill = 3
			person.room_id = room.id
			person.appearance = AppearanceRules.roll_seeded(
				String(person.id), AppearanceRules.field_for_role(person.role)
			)
			game.staff.people.append(person)
		return room
	return null


## Starts [param project_id] on [param game] (it must be allowed) and ticks a ResearchSystem
## and the clock until it is done; returns the ticks it took.
static func finish(game: GameState, project_id: StringName) -> int:
	var def: ResearchDef = game.research_defs.get(project_id)
	if def != null:
		bench_for(game, def.discipline)
	var result: CommandResult = ConstructionFixture.run(
		game, StartResearchCommand.create(project_id)
	)
	assert(result.is_ok, "ResearchFixture.finish(): %s refused" % result.error_code)
	var system := ResearchSystem.new()
	var ticks: int = 0
	while not game.research.room_running(project_id).is_empty():
		system.tick(game)
		game.clock.tick += 1
		ticks += 1
	return ticks


## Starts Excavation survey (E01) in [param game] through the command, adding a staffed
## Workshop first (M7: Engineering runs in the Workshop). For the older flows that used to
## start it from the old Research tab.
static func start_survey(game: GameState) -> CommandResult:
	workshop(game)
	return ConstructionFixture.run(game, StartResearchCommand.create(&"excavation_survey"))
