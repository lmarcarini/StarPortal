class_name CommandLedger
extends RefCounted
## The figures of the Command tab (docs/content/m27-daily-rhythm.md section 4), read from the
## simulation state with no side effects: the money lines (allocation, the 6 most expensive
## room types, Other rooms, salaries, net), each room's upkeep as the settlement charges it,
## and the balance trend over the last 7 and 30 days.
## Bible: docs/content/m27-daily-rhythm.md sections 1 and 4

## Room types shown on their own line; the rest go to Other rooms.
const ROOM_TYPES_SHOWN: int = 6
## Days of the two trend figures.
const TREND_SHORT_DAYS: int = 7
const TREND_LONG_DAYS: int = 30


## The money lines of [param state], top to bottom; room lines with no room are left out, so
## there are at most 10.
static func lines(state: GameState) -> Array[CommandLine]:
	var allocation: int = allocation_k(state)
	var out: Array[CommandLine] = [
		CommandLine.create(CommandLine.Kind.ALLOCATION, allocation * ConfidenceRules.PERIOD_DAYS)
	]
	out.append_array(room_lines(state))
	var salaries := CommandLine.create(CommandLine.Kind.SALARIES, -StaffRules.salaries_k(state))
	for person: PersonState in state.staff.people:
		salaries.add_item(person.id, -StaffRules.salary_k(person))
	salaries.count = salaries.item_ids.size()
	if salaries.count > 0:
		out.append(salaries)
	var modifier: int = modifiers_k(state)
	if modifier != 0:
		out.append(CommandLine.create(CommandLine.Kind.MODIFIERS, modifier))
	var costs: int = costs_k(state)
	var income: int = allocation * ConfidenceRules.PERIOD_DAYS + modifier
	var net := CommandLine.create(CommandLine.Kind.NET, income - costs)
	net.per_day_tenths = roundi((income - costs) * 10.0 / ConfidenceRules.PERIOD_DAYS)
	out.append(net)
	return out


## Today's allocation in $k, from Confidence's whole part.
static func allocation_k(state: GameState) -> int:
	if state.balance == null:
		return 0
	return ConfidenceRules.daily_allocation_k(
		state.balance.daily_allocation_k, state.committee.whole()
	)


## Room upkeep plus salaries per 30 days, in $k (what the settlement charges ÷ 30), with no
## modifier.
static func costs_k(state: GameState) -> int:
	return (
		EconomySystem.upkeep_k(state.base, state.room_defs, state.unlocks)
		+ StaffRules.salaries_k(state)
	)


## What the modifiers add per 30 days, in $k: the allocation_k modifier for 30 days, less
## the upkeep_pct modifier's change to the room upkeep (M4).
static func modifiers_k(state: GameState) -> int:
	var upkeep: int = EconomySystem.upkeep_k(state.base, state.room_defs, state.unlocks)
	var upkeep_change: int = EconomySystem.modified_upkeep_k(state, upkeep) - upkeep
	return ModifierRules.total(state, &"allocation_k") * ConfidenceRules.PERIOD_DAYS - upkeep_change


## One line per room type, the most expensive first (by name on a tie), with the types past
## [constant ROOM_TYPES_SHOWN] merged into Other rooms.
static func room_lines(state: GameState) -> Array[CommandLine]:
	var by_type: Dictionary[StringName, CommandLine] = {}
	var upkeeps: Dictionary[StringName, int] = room_upkeeps(state)
	for room_id: StringName in upkeeps:
		var room: RoomState = state.base.find_room(room_id)
		if not by_type.has(room.def_id):
			by_type[room.def_id] = CommandLine.create(CommandLine.Kind.ROOM_TYPE, 0)
			by_type[room.def_id].def_id = room.def_id
		by_type[room.def_id].add_item(room_id, -upkeeps[room_id])
	var types: Array[CommandLine] = []
	types.assign(by_type.values())
	types.sort_custom(_costlier)
	var out: Array[CommandLine] = []
	var other := CommandLine.create(CommandLine.Kind.OTHER_ROOMS, 0)
	for index: int in types.size():
		var line: CommandLine = types[index]
		if index < ROOM_TYPES_SHOWN:
			out.append(_totalled(line))
			continue
		for item: int in line.item_ids.size():
			other.add_item(line.item_ids[item], line.item_amounts[item])
	if not other.item_ids.is_empty():
		out.append(_totalled(other))
	return out


## Each built room that pays upkeep, as {room id: upkeep per 30 days in $k}, as
## EconomySystem.upkeep_k() charges it: half (rounded down) when switched off, a lift shaft
## once, a research override applied, unknown defs left out.
static func room_upkeeps(state: GameState) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	var shafts_seen: Dictionary[String, bool] = {}
	for room: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if def == null or not room.is_built():
			continue
		if room.def_id in EconomySystem.SHAFT_DEFS:
			var shaft: String = "%s@%s" % [room.def_id, room.origin]
			if shafts_seen.has(shaft):
				continue
			shafts_seen[shaft] = true
		var upkeep: int = UnlockRules.upkeep_k(state.unlocks, def)
		out[room.id] = upkeep if room.powered_on else upkeep / 2
	return out


## The balance change over the last [param days] settlements, in $k: today's funds less the
## balance [param days] settlements ago, or less the starting balance until that many have
## passed (with the oldest kept balance once the history is full).
static func trend_k(state: GameState, days: int) -> int:
	var history: Array[int] = state.committee.funds_history
	var index: int = history.size() - 1 - days
	var before: int = starting_k(state)
	if index >= 0:
		before = history[index]
	elif history.size() >= ConfidenceRules.FUNDS_HISTORY_KEPT:
		before = history[0]
	return state.budget.funds_k - before


## The starting balance the trend compares against before enough history.
static func starting_k(state: GameState) -> int:
	return 6000 if state.balance == null else state.balance.starting_budget_k


static func _totalled(line: CommandLine) -> CommandLine:
	var total: int = 0
	for amount: int in line.item_amounts:
		total += amount
	var out := CommandLine.create(line.kind, total)
	out.def_id = line.def_id
	out.item_ids = line.item_ids
	out.item_amounts = line.item_amounts
	out.count = line.item_ids.size()
	return out


static func _costlier(a: CommandLine, b: CommandLine) -> bool:
	var cost_a: int = 0
	var cost_b: int = 0
	for amount: int in a.item_amounts:
		cost_a -= amount
	for amount: int in b.item_amounts:
		cost_b -= amount
	if cost_a != cost_b:
		return cost_a > cost_b
	return String(a.def_id) < String(b.def_id)
