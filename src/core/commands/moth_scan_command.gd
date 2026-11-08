class_name MothScanCommand
extends Command
## The player orders the MOTH out on a scan (MothRules.Scan), one at a time: Look around, a
## Close look at a listed target, Sky, Ring or Recall. ProbeSystem runs it for its battery
## minutes, then rolls the loss and gives its result. Posts moth_scan_started(scan, target id).
## Bible: docs/content/m3-beyond-the-ring.md section 2 (MOTH scans)

## The command's stable type id.
const TYPE: StringName = &"moth_scan"

## The scan.
var scan: MothRules.Scan = MothRules.Scan.LOOK_AROUND
## The target of a Close look; &"" for any other scan.
var target_id: StringName = &""


## Returns a command running [param scan_value] (on [param target] for a Close look).
static func create(scan_value: MothRules.Scan, target: StringName = &"") -> MothScanCommand:
	var command := MothScanCommand.new()
	command.scan = scan_value
	command.target_id = target
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "scan" is not a scan name or "target_id" is not a string.
static func from_dict(data: Dictionary) -> Result:
	var scan_index: int = MothRules.SCAN_NAMES.find(str(data.get("scan")))
	var target: Variant = data.get("target_id", "")
	if scan_index < 0 or not target is String:
		return Result.fail(&"malformed_command", "moth_scan needs a scan name and a target id")
	return Result.ok(create(scan_index as MothRules.Scan, StringName(str(target))))


## Returns &"moth_scan".
func get_type() -> StringName:
	return TYPE


## Rejects no MOTH out (&"no_moth"), a scan already running (&"scan_running"), too little
## battery (&"battery_low"), a scan done on this run (&"already_done"), a Ring scan of a world
## already read deeper (&"already_done"), and a Close look at a target the report does not list
## (&"unknown_target").
func validate(state: GameState) -> CommandResult:
	var run: MothRun = state.probes.moth
	if run == null:
		return CommandResult.fail(&"no_moth")
	if run.is_scanning():
		return CommandResult.fail(&"scan_running")
	if run.battery_left < MothRules.minutes_of(scan):
		return CommandResult.fail(&"battery_low")
	if scan == MothRules.Scan.CLOSE_LOOK and not _is_listed(state, run.world_id):
		return CommandResult.fail(&"unknown_target", String(target_id))
	var is_ring_read: bool = (
		scan == MothRules.Scan.RING and state.probes.ring_scanned.has(run.world_id)
	)
	if run.has_done(scan, target_id) or is_ring_read:
		return CommandResult.fail(&"already_done")
	return CommandResult.ok()


## Starts the scan.
func apply(state: GameState) -> void:
	var run: MothRun = state.probes.moth
	run.scan = scan
	run.target_id = target_id if scan == MothRules.Scan.CLOSE_LOOK else &""
	run.scan_ticks_left = MothRules.minutes_of(scan)
	state.events.post(&"moth_scan_started", [scan as int, run.target_id])


## Returns JSON-safe data: type, scan name and target id.
func to_dict() -> Dictionary:
	return {
		"type": String(TYPE),
		"scan": MothRules.SCAN_NAMES[scan],
		"target_id": String(target_id),
	}


## True when the report of [param world_id] lists the target.
func _is_listed(state: GameState, world_id: StringName) -> bool:
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, world_id)
	if facts == null:
		return false
	var report: WorldReport = state.worlds.report_of(world_id)
	for target: WorldTarget in WorldReportRules.shown_targets(facts, report):
		if target.id == target_id:
			return true
	return false
