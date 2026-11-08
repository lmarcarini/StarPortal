class_name MothText
extends RefCounted
## Pure text of the MOTH scan screen: the world's name, the REC time, each scan's name and
## state line, the battery lines and the SIGNAL LOST reason. Translates with the
## TranslationServer so it can stay static.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (MOTH) and section 7 (MOTH scan screen)

## Name keys of the scans, indexed by MothRules.Scan.
const SCAN_KEYS: Array[StringName] = [
	&"MOTH_SCAN_LOOK_AROUND",
	&"MOTH_SCAN_CLOSE_LOOK",
	&"MOTH_SCAN_SKY",
	&"MOTH_SCAN_RING",
	&"MOTH_SCAN_RECALL",
]
## Reason keys of a loss, by the moth_lost reason.
const LOSS_KEYS: Dictionary[StringName, StringName] = {
	&"shot_down": &"MOTH_LOST_SHOT_DOWN",
	&"battery": &"MOTH_LOST_BATTERY",
	&"wormhole_closed": &"MOTH_LOST_WORMHOLE",
}


## The designation of [param world_id], or "Unknown world".
static func world_name(state: GameState, world_id: StringName) -> String:
	var world: WorldRecord = state.galaxy.get_world(world_id) if state.galaxy != null else null
	if world != null and not world.designation.is_empty():
		return world.designation
	return GateRoomFormat.translate(&"GATE_WORMHOLE_UNNAMED")


## "REC 00:07": the battery minutes used, as hours and minutes of tape.
static func rec(battery_left: int) -> String:
	var used: int = MothRules.BATTERY_MINUTES - battery_left
	return GateRoomFormat.translate(&"MOTH_REC").format(
		{"time": "%02d:%02d" % [used / 60, used % 60]}
	)


## "5 min", "5 min · done" or "5 min · scanning" for [param scan] in [param run].
static func scan_line(run: MothRun, scan: MothRules.Scan, target_id: StringName = &"") -> String:
	var minutes: String = GateRoomFormat.translate(&"GATE_DURATION_MINUTES").format(
		{"minutes": MothRules.minutes_of(scan)}
	)
	if run == null:
		return minutes
	if run.scan == scan and run.target_id == target_id:
		return GateRoomFormat.translate(&"MOTH_SCAN_RUNNING").format({"minutes": minutes})
	if run.has_done(scan, target_id):
		return GateRoomFormat.translate(&"MOTH_SCAN_DONE").format({"minutes": minutes})
	return minutes


## "[ SCANNING: Iron object ]", or "" while no scan runs.
static func scanning(run: MothRun, target_name: String) -> String:
	if run == null or not run.is_scanning():
		return ""
	var what: String = target_name
	if run.scan != MothRules.Scan.CLOSE_LOOK:
		what = GateRoomFormat.translate(SCAN_KEYS[run.scan])
	return GateRoomFormat.translate(&"MOTH_SCANNING").format({"what": what})


## "11 min left".
static func battery_left(minutes: int) -> String:
	return GateRoomFormat.translate(&"MOTH_BATTERY_LEFT").format({"minutes": minutes})


## The reason a drone was lost.
static func loss_reason(reason: StringName) -> String:
	var key: StringName = LOSS_KEYS.get(reason, &"MOTH_LOST_SHOT_DOWN")
	return GateRoomFormat.translate(key)
