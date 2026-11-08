class_name RescueForecast
extends RefCounted
## Pure forecast of the charge a rescue needs (docs/content/m3-beyond-the-ring.md section 4,
## Missed check-in and rescue): the lock energy of the team's world plus 15 minutes of open
## drain, against the stored charge and the charge rate, and the rates Charge at maximum
## sets: every standing bank raised to its highest rate the spare supply allows, lowering
## nothing. The rescue alert (card #233) words these. Reads a GameState whose
## balance and galaxy are set; no side effects.
## Bible: docs/content/m3-beyond-the-ring.md section 1 (Lock energy) and section 4

## The rescue charge is ready in time at the current rate.
const ON_TIME: StringName = &"on_time"
## Too slow at the current rate, but Charge at maximum makes it in time.
const TOO_SLOW: StringName = &"too_slow"
## Charge rates move in blocks of this many MW (docs/content/m3-beyond-the-ring.md section 1).
const RATE_STEP_MW: int = 5
## Not in time even at maximum.
const NOT_ENOUGH: StringName = &"not_enough"


## MWh the rescue dial needs: the world's lock energy plus SIGNAL_TICKS of the 8-seal drain.
static func needed_mwh(state: GameState) -> float:
	var galaxy: GalaxyCatalogue = state.galaxy
	var address: GateAddress = galaxy.address_of(
		state.expedition.world_id, galaxy.home().origin_glyph
	)
	var drain_mwh: float = (
		state.balance.open_drain_mw_8 * ExpeditionRescue.SIGNAL_TICKS / PowerMath.TICKS_PER_HOUR
	)
	return GateQueries.lock_energy_mwh(state, address) + drain_mwh


## Ticks left in the rescue window; 0 when it is not open.
static func window_ticks_left(state: GameState) -> int:
	if state.expedition.mode != ExpeditionState.Mode.MISSING:
		return 0
	return maxi(ExpeditionRescue.window_end_tick(state.expedition) - state.clock.tick, 0)


## Ticks until the bank holds needed_mwh() charging at [param charge_mw]: 0 when it does,
## -1 when it never will (above the capacity, or no charging).
static func ticks_until_ready(state: GameState, charge_mw: float) -> int:
	var needed: float = needed_mwh(state)
	if state.power.stored_mwh >= needed:
		return 0
	if needed > PowerRules.capacity_mwh(state):
		return -1
	return PowerMath.ticks_until_mwh(state.power.stored_mwh, needed, charge_mw)


## ON_TIME, TOO_SLOW or NOT_ENOUGH for [param state]'s open rescue window.
static func status(state: GameState) -> StringName:
	var left: int = window_ticks_left(state)
	if _in_time(ticks_until_ready(state, PowerRules.charge_mw(state)), left):
		return ON_TIME
	if _in_time(ticks_until_ready(state, max_charge_mw(state)), left):
		return TOO_SLOW
	return NOT_ENOUGH


## The charge in MW with max_rates() set.
static func max_charge_mw(state: GameState) -> float:
	var total: float = 0.0
	var rates: Dictionary[StringName, int] = max_rates(state)
	for room_id: StringName in rates:
		total += rates[room_id]
	return total


## Charge at maximum: the rate of every standing bank, each raised in room order by whole
## RATE_STEP_MW blocks to its maximum or as far as the spare supply left allows; never lowered.
static func max_rates(state: GameState) -> Dictionary[StringName, int]:
	var rates: Dictionary[StringName, int] = {}
	var spare: int = floori(PowerRules.spare_mw(state))
	for room: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if not PowerRules.is_bank(def) or not PowerRules.is_standing(room):
			continue
		var rate: int = state.power.charge_rates.get(room.id, 0)
		var raise: int = raise_mw(floori(def.max_charge_rate_mw) - rate, spare)
		spare -= raise
		rates[room.id] = rate + raise
	return rates


## The raise of a bank with [param headroom_mw] left below its maximum given [param spare_mw]
## of spare supply: the largest whole RATE_STEP_MW block within both (27 MW spare gives 25).
static func raise_mw(headroom_mw: int, spare_mw: int) -> int:
	var room_left: int = clampi(headroom_mw, 0, maxi(spare_mw, 0))
	return room_left - room_left % RATE_STEP_MW


static func _in_time(ticks: int, left: int) -> bool:
	return ticks >= 0 and ticks <= left
