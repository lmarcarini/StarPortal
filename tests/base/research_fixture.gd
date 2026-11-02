class_name ResearchFixture
extends RefCounted
## Shared setup for the research tests: a new game over the real balance, room defs and
## research defs, with a built, switched-on Research Lab on Level 1.
## Bible: docs/content/m25-lean-start.md section 3

const RESEARCH_DIR: String = "res://data/research/"


## A new game (ConstructionFixture.state()) with every real ResearchDef and, when
## [param with_lab], a built Research Lab that is on (PowerFixture.lab()).
static func state(with_lab: bool = true) -> GameState:
	var game: GameState = ConstructionFixture.state()
	load_research_defs(game)
	if with_lab:
		PowerFixture.lab(game)
	return game


## Loads every ResearchDef under data/research/ into [param game].research_defs.
static func load_research_defs(game: GameState) -> void:
	for file: String in DirAccess.get_files_at(RESEARCH_DIR):
		if file.ends_with(".tres"):
			var def: ResearchDef = load(RESEARCH_DIR + file)
			game.research_defs[def.id] = def


## Starts [param project_id] on [param game] (it must be allowed) and ticks a ResearchSystem
## until it is done; returns the ticks it took.
static func finish(game: GameState, project_id: StringName) -> int:
	var result: CommandResult = ConstructionFixture.run(
		game, StartResearchCommand.create(project_id)
	)
	assert(result.is_ok, "ResearchFixture.finish(): %s refused" % result.error_code)
	var system := ResearchSystem.new()
	var ticks: int = 0
	while game.research.is_running():
		system.tick(game)
		ticks += 1
	return ticks
