class_name AlertEntry
extends RefCounted
## One alert in the top bar's list: what needs the player, how badly, and where to go.
## Built by AlertRules from the state; never saved.
## Bible: docs/content/interface-pass.md section 3 (Alerts)

## Severities, lowest first.
const INFO: StringName = &"info"
const WARN: StringName = &"warn"
const ALARM: StringName = &"alarm"
const SEVERITIES: Array[StringName] = [INFO, WARN, ALARM]

## Kind: lab_idle, research_done, staff_unassigned, beds_full, candidate_waiting, request_due,
## artefact_hazard, artefact_at_gate, wormhole_open, site_finished, team_check_in, funds_red or
## rescue.
var kind: StringName = &""
## One of SEVERITIES.
var severity: StringName = INFO
## Text arguments for AlertText.
var args: Dictionary = {}
## The view and sub-tab that hold the cause; &"" sub-tab for the view's default.
var view_id: StringName = &""
var sub_tab: StringName = &""
## The thing to select on that screen (a project, a request uid, a world), or &"".
var target: StringName = &""
## Tick of the cause, for newest-first order.
var tick: int = 0
## True for event-style alerts the player may dismiss.
var dismissible: bool = false


## A new entry.
static func create(
	kind_id: StringName, level: StringName, view: StringName, at_tick: int
) -> AlertEntry:
	var entry := AlertEntry.new()
	entry.kind = kind_id
	entry.severity = level
	entry.view_id = view
	entry.tick = at_tick
	return entry


## A key that names this alert's cause, for dismissing it: kind, target and tick.
func key() -> String:
	return "%s/%s/%d" % [kind, target, tick]


## The rank of [param level] in SEVERITIES (higher is worse).
static func rank(level: StringName) -> int:
	return SEVERITIES.find(level)
