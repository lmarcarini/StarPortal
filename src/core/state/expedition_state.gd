class_name ExpeditionState
extends RefCounted
## Saved state of the one expedition of M3: its mode (no plan, planned, away), the plan
## (objective, world, target, team of four by slot), the departure, the field days resolved and
## the expedition documents brought back. The seeded generator is the &"expedition" stream of
## RandomState. Check-ins (card M3-10) and field events (card M3-11) extend the timeline: a
## check-in falls every 24 hours from departure and the return is the last
## ([method check_in_ticks]); each field day leaves one entry in [member day_results].
## A missed check-in (card M3-10) turns AWAY into MISSING: the rescue window opens at
## [member missed_tick] and a Signal waits from [member signal_tick].
## Saved shape: {"mode": "idle" | "planned" | "away" | "missing", "objective": "none" | "survey" |
## "recover", "world_id", "target_id", "team": {slot: person id}, "departed_tick" (-1 unless
## away or missing), "day_results": ["ok" | "wasted" | "missed"], "recalled" (bool, only while
## away), "missed_tick" and "signal_tick" (-1, or ticks while missing), "documents":
## [{"world_id", "kind": "survey_report" or "object", "target_id", "tick"}]}.
## Bible: docs/content/m3-beyond-the-ring.md section 4 (Expeditions) and section 9 (saves)

## IDLE: no plan. PLANNED: a plan is ready to send. AWAY: the team is through the Ring.
## MISSING: the team missed a check-in; the rescue window is open.
enum Mode { IDLE, PLANNED, AWAY, MISSING }
## What the team goes to do; Contact comes with card M3-13.
enum Objective { NONE, SURVEY, RECOVER }

## Saved names of the modes, indexed by Mode value.
const MODE_NAMES: Array[String] = ["idle", "planned", "away", "missing"]
## Saved names of the objectives, indexed by Objective value.
const OBJECTIVE_NAMES: Array[String] = ["none", "survey", "recover"]
## Field days of each objective, indexed by Objective value.
const OBJECTIVE_DAYS: Array[int] = [0, 2, 1]
## Team slots, in order.
const SLOTS: Array[String] = ["leader", "scientist", "soldier", "specialist"]
## Field day results: nothing went wrong, the day was wasted (no finding), or the check-in
## that ends it does not come (a field event's worst setback; card M3-11 sets it).
const DAY_OK: String = "ok"
const DAY_WASTED: String = "wasted"
const DAY_MISSED: String = "missed"
const DAY_RESULTS: Array[String] = [DAY_OK, DAY_WASTED, DAY_MISSED]
## Kinds of expedition document.
const DOCUMENT_KINDS: Array[String] = ["survey_report", "object"]

## The current mode.
var mode: Mode = Mode.IDLE
## The planned objective; NONE while IDLE.
var objective: Objective = Objective.NONE
## The world the plan goes to; &"" while IDLE.
var world_id: StringName = &""
## The target of a Recover; &"" otherwise.
var target_id: StringName = &""
## The team by slot (SLOTS): person ids; empty while IDLE.
var team: Dictionary[String, StringName] = {}
## Tick the team went through; -1 unless AWAY.
var departed_tick: int = -1
## One entry per field day resolved since departure (DAY_RESULTS).
var day_results: Array[String] = []
## True once Recall team turned the next due check-in into the return (AWAY only).
var recalled: bool = false
## Tick of the missed check-in that opened the rescue window; -1 unless MISSING.
var missed_tick: int = -1
## Tick Signal T-1 was given on an open wormhole; -1 when no Signal is waiting.
var signal_tick: int = -1
## Documents teams brought back, oldest first.
var documents: Array[Dictionary] = []
## Blind run (M4c-22): a Survey sent to a world never probed. Its risk rolls read the threat
## one step higher and its first check-in comes delay_ticks later. Optional when loading.
var blind: bool = false
var delay_ticks: int = 0


## Field days of the planned objective.
func days() -> int:
	return OBJECTIVE_DAYS[objective]


## The person ids of the team, in slot order.
func member_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for slot: String in SLOTS:
		if team.has(slot):
			ids.append(team[slot])
	return ids


## True while a team is through the Ring: AWAY or MISSING.
func is_out() -> bool:
	return mode == Mode.AWAY or mode == Mode.MISSING


## The people out of CAIRN: the team while AWAY or MISSING, else none.
func away_ids() -> Array[StringName]:
	if not is_out():
		return []
	return member_ids()


## The ticks of every check-in from departure, the return last: one each 24 hours.
func check_in_ticks() -> Array[int]:
	var ticks: Array[int] = []
	if mode != Mode.AWAY:
		return ticks
	for day: int in range(1, days() + 1):
		ticks.append(departed_tick + delay_ticks + day * TimeMath.TICKS_PER_DAY)
	return ticks


## The tick the current field day ends at (its check-in); -1 unless AWAY.
func next_day_end_tick() -> int:
	if mode != Mode.AWAY:
		return -1
	return departed_tick + delay_ticks + (day_results.size() + 1) * TimeMath.TICKS_PER_DAY


## Sets the plan, replacing any earlier one.
func set_plan(
	plan_objective: Objective, world: StringName, target: StringName, members: Dictionary
) -> void:
	mode = Mode.PLANNED
	objective = plan_objective
	world_id = world
	target_id = target
	team.clear()
	for slot: String in SLOTS:
		team[slot] = StringName(str(members.get(slot, "")))


## Drops the plan and the trip: back to IDLE. Documents stay.
func clear() -> void:
	mode = Mode.IDLE
	objective = Objective.NONE
	world_id = &""
	target_id = &""
	team.clear()
	departed_tick = -1
	day_results.clear()
	recalled = false
	blind = false
	delay_ticks = 0
	missed_tick = -1
	signal_tick = -1


## Records a document of [param kind] brought back from [param world] at [param tick].
func add_document(kind: String, world: StringName, target: StringName, tick: int) -> void:
	documents.append(
		{"world_id": String(world), "kind": kind, "target_id": String(target), "tick": tick}
	)


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	var team_data: Dictionary = {}
	for slot: String in team:
		team_data[slot] = String(team[slot])
	return {
		"mode": MODE_NAMES[mode],
		"objective": OBJECTIVE_NAMES[objective],
		"world_id": String(world_id),
		"target_id": String(target_id),
		"team": team_data,
		"departed_tick": departed_tick,
		"day_results": day_results.duplicate(),
		"recalled": recalled,
		"missed_tick": missed_tick,
		"signal_tick": signal_tick,
		"documents": documents.duplicate(true),
		"blind": blind,
		"delay_ticks": delay_ticks,
	}


## Builds the expedition from saved [param data]. Call validate_dict() first.
static func from_dict(data: Dictionary) -> ExpeditionState:
	var expedition := ExpeditionState.new()
	expedition.mode = maxi(0, MODE_NAMES.find(str(data.get("mode", "idle")))) as Mode
	var objective_index: int = OBJECTIVE_NAMES.find(str(data.get("objective", "none")))
	expedition.objective = maxi(0, objective_index) as Objective
	expedition.world_id = StringName(str(data.get("world_id", "")))
	expedition.target_id = StringName(str(data.get("target_id", "")))
	var team_data: Variant = data.get("team", {})
	if team_data is Dictionary:
		var team_dict: Dictionary = team_data
		for slot: Variant in team_dict:
			expedition.team[str(slot)] = StringName(str(team_dict[slot]))
	expedition.departed_tick = type_convert(data.get("departed_tick", -1), TYPE_INT)
	var results: Variant = data.get("day_results", [])
	if results is Array:
		var result_list: Array = results
		for result: Variant in result_list:
			expedition.day_results.append(str(result))
	expedition.recalled = data.get("recalled", false) == true
	expedition.blind = data.get("blind", false) == true
	var delay: int = type_convert(data.get("delay_ticks", 0), TYPE_INT)
	expedition.delay_ticks = maxi(0, delay)
	expedition.missed_tick = type_convert(data.get("missed_tick", -1), TYPE_INT)
	expedition.signal_tick = type_convert(data.get("signal_tick", -1), TYPE_INT)
	var documents_data: Variant = data.get("documents", [])
	if documents_data is Array:
		var document_list: Array = documents_data
		for entry: Variant in document_list:
			if entry is Dictionary:
				var entry_dict: Dictionary = entry
				expedition.documents.append(ExpeditionSaveChecks.document_from(entry_dict))
	return expedition


## Errors for saved [param data], empty when valid (ExpeditionSaveChecks).
static func validate_dict(data: Dictionary) -> Array[String]:
	return ExpeditionSaveChecks.errors(data)
