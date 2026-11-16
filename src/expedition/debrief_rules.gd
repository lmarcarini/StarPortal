class_name DebriefRules
extends RefCounted
## What a team's debrief says, read from the state when it comes home (or is lost): the
## outcome, the world, who went and how they are, and what the trip brought (the world's
## status, documents and artefacts filed at the return). Pure.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Teams come home)

## Outcomes.
enum Outcome { SUCCESS, FAILED, EARLY, RESCUED, LOST }


## One debrief.
class Debrief:
	extends RefCounted
	## The outcome.
	var outcome: Outcome = Outcome.SUCCESS
	## The world.
	var world_id: StringName = &""
	## The objective (ExpeditionState.Objective).
	var objective: int = 0
	## Members still on the roster, by name.
	var people: Array[PersonState] = []
	## Finding icons (HardwareIcons ids).
	var findings: Array[StringName] = []
	## The leader's name ("" when unknown).
	var leader: String = ""
	## Field days done (0 when unknown).
	var days: int = 0
	## True when an object (an artefact) came back.
	var brought_object: bool = false


## The debrief of a return to [param world] in [param state] from the team_debrief event's
## [param summary] ({objective, success, early, team names}).
static func of_return(state: GameState, world: StringName, summary: Dictionary) -> Debrief:
	var d: Debrief = Debrief.new()
	d.world_id = world
	d.objective = type_convert(summary.get("objective", 0), TYPE_INT)
	if summary.get("early", false) == true:
		d.outcome = Outcome.EARLY
	else:
		d.outcome = Outcome.SUCCESS if summary.get("success", false) == true else Outcome.FAILED
	var team: Variant = summary.get("team", [])
	var names: Array = team if team is Array else []
	d.people = people_named(state, names)
	d.leader = str(names[0]) if not names.is_empty() else ""
	d.days = type_convert(summary.get("days", 0), TYPE_INT)
	if state.worlds.has_reached(world, WorldsState.WorldStatus.SURVEYED):
		d.findings.append(&"surveyed")
	for document: Dictionary in state.expedition.documents:
		var same_world: bool = StringName(str(document.get("world_id", ""))) == world
		var tick: int = type_convert(document.get("tick", -1), TYPE_INT)
		if same_world and tick >= state.clock.tick - 1:
			var survey: bool = str(document.get("kind", "")) == "survey_report"
			d.findings.append(&"office" if survey else &"canister")
			d.brought_object = d.brought_object or not survey
	return d


## The debrief of the Log's return entry [param entry] (reopened later): outcome, world,
## objective and team from the entry; findings as the world stands now.
static func of_log(state: GameState, entry: LogEntry) -> Debrief:
	var team: String = str(entry.args.get("team", ""))
	var names: Array = Array(team.split(", ", false))
	var summary: Dictionary = {
		"objective":
		maxi(0, ExpeditionState.OBJECTIVE_NAMES.find(str(entry.args.get("objective", "")))),
		"success": entry.args.get("success", false) == true,
		"team": names,
	}
	var d: Debrief = of_return(state, entry.world_id, summary)
	d.findings.assign(d.findings.filter(func(id: StringName) -> bool: return id == &"surveyed"))
	return d


## True when [param entry] is a team's return in the Log.
static func is_return_entry(entry: LogEntry) -> bool:
	return entry.kind == &"expedition" and str(entry.args.get("reason", "")) == "returned"


## The debrief of a rescue or a loss.
static func of_end(world: StringName, lost: bool) -> Debrief:
	var d: Debrief = Debrief.new()
	d.world_id = world
	d.outcome = Outcome.LOST if lost else Outcome.RESCUED
	return d


## The people of [param state] called [param names].
static func people_named(state: GameState, names: Array) -> Array[PersonState]:
	var found: Array[PersonState] = []
	for person: PersonState in state.staff.people:
		if names.has(person.name):
			found.append(person)
	return found
