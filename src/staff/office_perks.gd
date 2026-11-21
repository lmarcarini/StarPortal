class_name OfficePerks
extends RefCounted
## Office research (O01-O14, docs/content/research-and-progression.md section 10) read by the
## rules it changes: squads that fall back by themselves when losing (Squad doctrine, O08),
## faster squads (Rapid response, O09), teams of five (Expedition training, O10), no blind
## penalty (Survival training, O11) and the Committee's emergency funds (Committee liaison,
## O07). The HR tiers (O01-O06) only set flags until the recruitment cards read them. Pure,
## except auto_fall_back(), called from SecuritySystem.tick().
## Bible: docs/content/research-and-progression.md section 10

const SQUAD_DOCTRINE: StringName = &"squad_doctrine"
const RAPID_RESPONSE: StringName = &"rapid_response"
const TEAMS_OF_FIVE: StringName = &"teams_of_five"
const SURVIVAL_TRAINING: StringName = &"survival_training"
const COMMITTEE_LIAISON: StringName = &"committee_liaison"
## Flag stamped with the tick of the last emergency funds.
const LAST_FUNDS: StringName = &"emergency_funds_tick"
## Emergency funds, in $k, and how often they may be asked for.
const FUNDS_K: int = 1000
const FUNDS_EVERY_DAYS: int = 30


## Squad cells per tick in [param state]: the balance's, doubled with Rapid response.
static func squad_cells_per_tick(state: GameState) -> int:
	var cells: int = state.balance.squad_cells_per_tick
	return cells * 2 if ResearchPerks.has(state, RAPID_RESPONSE) else cells


## With Squad doctrine, orders [param squad] to fall back when its soldiers hold less than
## half their health. Returns true when it ordered.
static func auto_fall_back(state: GameState, squad: SquadState) -> bool:
	if not ResearchPerks.has(state, SQUAD_DOCTRINE) or squad.order == SquadState.Order.FALL_BACK:
		return false
	var members: Array[StringName] = SquadRules.members(state, squad.post_room)
	if members.is_empty():
		return false
	var total: int = 0
	for person_id: StringName in members:
		total += state.security.health.get(person_id, state.balance.soldier_health)
	if total * 2 >= members.size() * state.balance.soldier_health:
		return false
	var post: RoomState = state.base.find_room(squad.post_room)
	squad.order = SquadState.Order.FALL_BACK
	squad.target = SquadRules.home_of(post) if post != null else squad.pos
	return true


## True when [param state] may ask the Committee for emergency funds now.
static func can_ask_funds(state: GameState) -> bool:
	if not ResearchPerks.has(state, COMMITTEE_LIAISON):
		return false
	var last: Variant = state.flags.get(LAST_FUNDS, -1)
	var last_tick: int = type_convert(last, TYPE_INT)
	return (
		last_tick < 0 or state.clock.tick - last_tick >= FUNDS_EVERY_DAYS * TimeMath.TICKS_PER_DAY
	)


## The largest expedition team in [param state]: four, five with Expedition training (O10).
## The fifth slot on the mission sheet comes with the recruitment and mission cards.
static func team_size(state: GameState) -> int:
	return 5 if ResearchPerks.has(state, TEAMS_OF_FIVE) else 4
