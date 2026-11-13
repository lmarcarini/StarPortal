class_name MothRules
extends RefCounted
## The numbers and pure rules of the probes: the sample canister's cost and time, the MOTH's
## battery, each scan's battery minutes, the seeded loss chance by the world's true threat
## (doubled for a Close look), the rack and its automatic reorder, and the Ring scan's older
## console log. One tick is one minute. Pure static.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (Probes)

## The MOTH's scans. RECALL flies the drone back.
enum Scan { LOOK_AROUND, CLOSE_LOOK, SKY, RING, RECALL }

## Saved names of the scans, indexed by Scan value.
const SCAN_NAMES: Array[String] = ["look_around", "close_look", "sky", "ring", "recall"]
## Battery minutes (ticks) of each scan, indexed by Scan value.
const SCAN_MINUTES: Array[int] = [5, 4, 2, 4, 2]
## A full MOTH battery, in minutes.
const BATTERY_MINUTES: int = 20
## Percent chance a scan loses the drone, by true threat (indexed by WorldDef.Threat;
## UNKNOWN as LOW).
const LOSS_PERCENT_BY_THREAT: Array[int] = [0, 0, 5, 20]
## A Close look multiplies the loss chance by this.
const CLOSE_LOOK_LOSS_FACTOR: int = 2
## MOTHs the rack holds: in the rack, out, or on order.
const RACK_SIZE: int = 2
## A replacement MOTH's cost, in $k.
const REORDER_COST_K: int = 150
## Ticks from a loss to the replacement's arrival: 1 day.
const REORDER_TICKS: int = TimeMath.TICKS_PER_DAY
## A sample canister's cost, in $k; canisters never run out.
const CANISTER_COST_K: int = 10
## Ticks from throwing the canister to reeling it back.
const CANISTER_TICKS: int = 10
## Fewest and most addresses the Ring scan reads from the console's older log.
const RING_MIN_ADDRESSES: int = 1
const RING_MAX_ADDRESSES: int = 2


## Battery minutes of [param scan].
static func minutes_of(scan: Scan) -> int:
	return SCAN_MINUTES[scan]


## Percent chance that [param scan] loses the drone on a world whose true threat is
## [param threat].
static func loss_percent(threat: WorldDef.Threat, scan: Scan) -> int:
	var percent: int = LOSS_PERCENT_BY_THREAT[threat]
	if scan == Scan.CLOSE_LOOK:
		percent *= CLOSE_LOOK_LOSS_FACTOR
	return percent


## True when a drone with [param battery_left] minutes can still be recalled.
static func can_recall(battery_left: int) -> bool:
	return battery_left >= minutes_of(Scan.RECALL)


## The worlds the Ring scan of [param world_id] reads from the console's older log: the next
## 1 or 2 (stable per world) of the nearest procedural worlds after those the console lists.
static func older_log_worlds(world_id: StringName, galaxy: GalaxyCatalogue) -> Array[StringName]:
	var listed: int = ConsoleLog.entry_count(world_id)
	var spread: int = RING_MAX_ADDRESSES - RING_MIN_ADDRESSES + 1
	var extra: int = RING_MIN_ADDRESSES + WorldFactRules.roll(String(world_id), "ring", spread)
	var nearest: Array[StringName] = ConsoleLog.nearest_worlds(world_id, galaxy, listed + extra)
	return nearest.slice(mini(listed, nearest.size()))


## The threat confidence after a drone is shot down at [param current]: one step up, never
## above FAIR (a lost MOTH gives fair, section 2), never down.
static func confidence_after_loss(current: WorldReport.Confidence) -> WorldReport.Confidence:
	if current >= WorldReport.Confidence.FAIR:
		return current
	return (current + 1) as WorldReport.Confidence


## The MOTH's battery in minutes with the moth_battery_pct modifier (M4), at least 1.
static func battery_minutes(state: GameState) -> int:
	return maxi(1, floori(ModifierRules.percent(state, &"moth_battery_pct", BATTERY_MINUTES)))


## The most battery a saved MOTH run may hold: the battery at the highest modifier (+300 %).
static func max_battery_minutes() -> int:
	return BATTERY_MINUTES * (100 + ModifierRules.PERCENT_MAX) / 100
