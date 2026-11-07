class_name EconomySystem
extends SimSystem
## Daily money and Committee Confidence (docs/content/m27-daily-rhythm.md sections 1 and 2).
## Each tick it credits new locks, surveys and finished projects at once
## (ConfidenceEvents.credit_new()). At each day start, from 2 January, it runs the daily
## settlement (DailySettlement.settle()): the allocation set by Confidence, every built room's
## upkeep (half, rounded down, for a room switched off) and every salary, arriving people
## included, charged per 30 days with a carried remainder; then, every 15th day, the analysts'
## reports. Rooms under construction pay nothing. A lift is one RoomState per level at the
## same cells, but one shaft pays its upkeep once.
## Bible: docs/content/m2-base.md section 5, docs/content/m27-daily-rhythm.md sections 1 and 2

## Defs whose rooms stack into one shaft across levels: same def and origin pay once.
const SHAFT_DEFS: Array[StringName] = [&"room_lift"]

var _balance: BalanceConfig
## Dial Log, horizon record and finished project counts at the last credit check: a lock,
## survey or project changes one of them, so other ticks skip the check. Transient: a new
## system checks on its first tick, and crediting is idempotent.
var _seen: Vector3i = Vector3i(-1, -1, -1)
## RoomDef by id.
var _room_defs: Dictionary[StringName, RoomDef] = {}


func _init(balance: BalanceConfig, room_defs: Array[RoomDef]) -> void:
	_balance = balance
	for def: RoomDef in room_defs:
		_room_defs[def.id] = def


## Returns the system id, &"economy".
func get_id() -> StringName:
	return &"economy"


## Credits any new lock, survey or finished project.
func tick(state: GameState) -> void:
	var counts := Vector3i(
		state.gate.dial_log.size(),
		state.worlds.horizon_records.size(),
		state.research.done.size(),
	)
	if counts == _seen:
		return
	_seen = counts
	ConfidenceEvents.credit_new(state)


## Runs the daily settlement, then files reports on every 15th day.
func on_day(state: GameState) -> void:
	DailySettlement.settle(state, _balance.daily_allocation_k, costs_k(state))
	if ConfidenceRules.is_report_day(TimeMath.day_index(state.clock.tick)):
		ConfidenceEvents.file_reports(state)


## Today's costs per 30 days in $k: room upkeep plus salaries (arrivals included).
func costs_k(state: GameState) -> int:
	return upkeep_k(state.base, _room_defs, state.unlocks) + StaffRules.salaries_k(state)


## Total upkeep per 30 days of [param base]'s built rooms, in $k, with [param room_defs] by
## id: a room switched off pays half (rounded down), a lift shaft pays once and unknown defs
## pay nothing. With [param unlocks], a research upkeep override replaces the def's upkeep
## (UnlockRules.upkeep_k(), e.g. Fuel contracts).
static func upkeep_k(
	base: BaseState, room_defs: Dictionary[StringName, RoomDef], unlocks: UnlockState = null
) -> int:
	var total: int = 0
	var shafts_seen: Dictionary[String, bool] = {}
	for room: RoomState in base.rooms:
		var def: RoomDef = room_defs.get(room.def_id)
		if def == null or not room.is_built():
			continue
		if room.def_id in SHAFT_DEFS:
			var shaft: String = "%s@%s" % [room.def_id, room.origin]
			if shafts_seen.has(shaft):
				continue
			shafts_seen[shaft] = true
		var upkeep: int = def.upkeep_k if unlocks == null else UnlockRules.upkeep_k(unlocks, def)
		total += upkeep if room.powered_on else upkeep / 2
	return total
