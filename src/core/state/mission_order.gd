class_name MissionOrder
extends RefCounted
## A mission ordered from a closed gate (M4.9-12): the base dials the world, sends the planned
## team when the wormhole opens, and closes it once they are through. An explicit state
## machine; saved on the expedition. Saved shape: {"phase", "world_id", "address": address,
## "phase_tick", "reason"}.
## Bible: docs/content/interface-rethink.md section 4 (Gate, A mission order)

## Phases.
enum Phase { NONE, WAIT_CHARGE, DIALLING, SENDING, CLOSING, DONE, FAILED }
## Saved names of the phases.
const PHASE_NAMES: Array[String] = [
	"none", "wait_charge", "dialling", "sending", "closing", "done", "failed"
]

## Current phase.
var phase: Phase = Phase.NONE
## The world ordered.
var world_id: StringName = &""
## The address dialled.
var address: GateAddress = null
## Tick the phase began.
var phase_tick: int = -1
## Why it failed (a command or rule code); &"" otherwise.
var reason: StringName = &""


## True while the order is running.
func is_active() -> bool:
	return phase in [Phase.WAIT_CHARGE, Phase.DIALLING, Phase.SENDING, Phase.CLOSING]


## Moves to [param next] at [param tick].
func enter(next: Phase, tick: int) -> void:
	phase = next
	phase_tick = tick


## JSON-safe data.
func to_dict() -> Dictionary:
	return {
		"phase": PHASE_NAMES[phase],
		"world_id": String(world_id),
		"address": address.to_dict() if address != null else null,
		"phase_tick": phase_tick,
		"reason": String(reason),
	}


## Reads [method to_dict] data (missing or bad data gives no order).
static func from_dict(data: Variant) -> MissionOrder:
	var order: MissionOrder = MissionOrder.new()
	if not data is Dictionary:
		return order
	var d: Dictionary = data
	order.phase = maxi(0, PHASE_NAMES.find(str(d.get("phase", "none")))) as Phase
	order.world_id = StringName(str(d.get("world_id", "")))
	order.phase_tick = type_convert(d.get("phase_tick", -1), TYPE_INT)
	order.reason = StringName(str(d.get("reason", "")))
	var address_data: Dictionary = {}
	if d.get("address") is Dictionary:
		address_data = d["address"]
	if not address_data.is_empty() and GateAddress.validate_dict(address_data).is_empty():
		order.address = GateAddress.from_dict(address_data)
	elif order.is_active():
		order.phase = Phase.FAILED
	return order
