class_name RingLook
extends RefCounted
## What the Ring should look like now, read from the Gate's state: pure, no animation. The
## Gate station's ring layers animate towards it.
## Bible: docs/content/interface-rethink.md sections 4 (Gate) and 7

## IDLE dark; DIALING seals locking; OPEN a wormhole (own or answered incoming); INCOMING a
## wormhole from the far side waiting for an answer.
enum Phase { IDLE, DIALING, OPEN, INCOMING }

## Seal lamps on the Ring.
const SEALS: int = 8

## The phase.
var phase: Phase = Phase.IDLE
## Seal lamps lit, 0 to SEALS.
var seals: int = 0
## The open wormhole is hostile (tints the horizon to the alarm state).
var hostile: bool = false
## The Shutter is closed over the hole.
var shutter_closed: bool = false


## The look of [param gate] at clock [param tick], a dial taking [param dial_ticks] ticks.
static func of(gate: GateState, tick: int, dial_ticks: int) -> RingLook:
	var look: RingLook = RingLook.new()
	look.shutter_closed = gate.shutter == GateState.Shutter.CLOSED
	match gate.mode:
		GateState.RingMode.DIALING:
			look.phase = Phase.DIALING
			look.seals = seals_at(tick - gate.dial_started_tick, dial_ticks)
		GateState.RingMode.LOCKED:
			look.phase = Phase.OPEN
			look.seals = SEALS
			look.hostile = gate.is_hostile
		_:
			if gate.has_incoming():
				look.phase = Phase.INCOMING
				look.seals = SEALS
	return look


## Seals locked after [param elapsed] of [param total] dialling ticks: the eighth (CAIRN's
## mark) locks as the dial resolves, so a dial still running shows at most seven.
static func seals_at(elapsed: int, total: int) -> int:
	if total <= 0:
		return SEALS - 1
	var share: float = clampf(float(elapsed + 1) / float(total), 0.0, 1.0)
	return mini(SEALS - 1, floori(share * (SEALS - 1) + 0.0001))
