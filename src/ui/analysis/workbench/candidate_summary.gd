class_name CandidateSummary
extends RefCounted
## What the workbench's counter and candidate list show for one draft: the origin used, how many
## addresses fit, and, when LIST_LIMIT or fewer do, those addresses with their lock energy.
## Built once per workbench change, never per frame. Reads the state, never writes it.
## Bible: gate-and-address-spec.md#player-tools,
## gate-and-address-spec.md#dialing-outcomes-and-energy

## Most candidates the workbench lists. CandidateCounter.list() is only called at or below it,
## since listing large sets is slow.
const LIST_LIMIT: int = 50

## The origin glyph the count uses: the draft's, or the home Ring's when the draft says -1;
## -1 when neither is known (no galaxy).
var origin: int = -1
## Number of addresses that fit.
var count: int = 0
## The fitting addresses when count <= LIST_LIMIT, else empty.
var addresses: Array[GateAddress] = []
## Lock energy in MWh of each listed address, same order; 0 when the state has no galaxy.
var energies_mwh: Array[float] = []


## Returns the summary of [param state]'s workbench draft.
static func of(state: GameState) -> CandidateSummary:
	var summary := CandidateSummary.new()
	summary.origin = effective_origin(state)
	var constraints: Array[AddressConstraint] = state.workbench.constraints
	summary.count = CandidateCounter.count(constraints, summary.origin)
	if summary.count == 0 or summary.count > LIST_LIMIT:
		return summary
	summary.addresses = CandidateCounter.list(constraints, summary.origin, LIST_LIMIT)
	var can_price: bool = state.galaxy != null and state.balance != null
	for address: GateAddress in summary.addresses:
		summary.energies_mwh.append(
			GateQueries.lock_energy_mwh(state, address) if can_price else 0.0
		)
	return summary


## Returns the draft's origin glyph, or the home Ring's when it is
## WorkbenchState.HOME_ORIGIN; -1 when that is needed and the state has no galaxy.
static func effective_origin(state: GameState) -> int:
	if state.workbench.origin_glyph != WorkbenchState.HOME_ORIGIN:
		return state.workbench.origin_glyph
	return home_origin(state)


## Returns the home Ring's origin glyph, or -1 when the state has no galaxy.
static func home_origin(state: GameState) -> int:
	if state.galaxy == null or state.galaxy.home() == null:
		return -1
	return state.galaxy.home().origin_glyph
