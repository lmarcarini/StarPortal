class_name PowerMath
extends RefCounted
## Pure power rules: the open wormhole's drain, net flow, one tick of capacitor charge and
## the ticks until a charge target. One tick is one in-game minute, so a flow in MW moves
## stored energy by flow / 60 MWh per tick. M1 placeholder: the plant's whole output goes to
## the bank; M2 reuses these functions with rooms, demand and priorities.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## game-design.md#base-building-and-power

## Ticks in one hour; converts MW into MWh per tick.
const TICKS_PER_HOUR: float = 60.0
## Longest wait ticks_until_mwh() reports, about 19 years of ticks. Slower charges count as never.
const MAX_TICKS: float = 10_000_000.0
## Most ticks ticks_until_mwh() steps one by one to settle a result the closed form cannot.
const _STEP_LIMIT: int = 100_000
## Upper bound of the relative rounding error of one float addition, with some slack.
const _ROUNDING: float = 3.0e-16


## Returns the power the open wormhole draws, in MW: the 8-seal drain while the Ring is
## LOCKED by our dial, otherwise 0 (an answered incoming wormhole is held open from the far
## side, m4-core-systems.md section 3).
static func drain_mw(gate: GateState, balance: BalanceConfig) -> float:
	if gate.mode != GateState.RingMode.LOCKED or gate.is_incoming_lock():
		return 0.0
	return balance.open_drain_mw_8


## Returns the plant output left for the bank after the drain, in MW. Negative when the drain
## is bigger than the output, so storage covers the rest.
static func net_flow_mw(output_mw: float, drain_mw: float) -> float:
	return output_mw - drain_mw


## Returns the stored energy after one tick at [param net_mw]: stored + net / 60, clamped to
## 0..[param capacity_mwh].
static func step_stored_mwh(stored_mwh: float, capacity_mwh: float, net_mw: float) -> float:
	return clampf(stored_mwh + net_mw / TICKS_PER_HOUR, 0.0, maxf(capacity_mwh, 0.0))


## Returns the whole ticks until the stored energy reaches [param target_mwh] at a steady
## [param net_mw], exactly as step_stored_mwh() would count them. 0 when [param stored_mwh]
## is already at the target; -1 when it never gets there: [param net_mw] is 0 or less, or the
## wait is over MAX_TICKS. Checking that the target fits the capacity is the caller's job.
static func ticks_until_mwh(stored_mwh: float, target_mwh: float, net_mw: float) -> int:
	if stored_mwh >= target_mwh:
		return 0
	if net_mw <= 0.0:
		return -1
	var gain: float = net_mw / TICKS_PER_HOUR
	var exact_ticks: float = (target_mwh - stored_mwh) / gain
	if not is_finite(exact_ticks) or exact_ticks > MAX_TICKS:
		return -1
	var scale: float = maxf(absf(stored_mwh), absf(target_mwh)) / gain
	var doubt: float = _ROUNDING * (exact_ticks + 4.0) * (scale + 1.0)
	if absf(exact_ticks - roundf(exact_ticks)) > doubt:
		return ceili(exact_ticks)
	return _count_steps(stored_mwh, target_mwh, net_mw, ceili(exact_ticks))


## Counts the ticks by stepping from [param stored_mwh] while the closed form
## [param estimate] is too close to a whole number to trust, up to _STEP_LIMIT steps.
## Beyond the limit the estimate stands.
static func _count_steps(stored_mwh: float, target_mwh: float, net_mw: float, estimate: int) -> int:
	if estimate > _STEP_LIMIT:
		return estimate
	var stored: float = stored_mwh
	for tick: int in range(1, _STEP_LIMIT + 1):
		stored = step_stored_mwh(stored, target_mwh, net_mw)
		if stored >= target_mwh:
			return tick
	return estimate
