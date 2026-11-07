## Tests for the Command tab's figures: the money lines match what the settlement charges,
## room types beyond six go to Other rooms, rows with nobody are left out, the trend against
## the history or the starting balance, and today's drift in the settlement's order.
## Bible: docs/content/m27-daily-rhythm.md sections 1 and 4
extends GdUnitTestSuite

const SEED: int = 20260101

var _defs: GameDefs
var _real_locale: String = ""


func before() -> void:
	_defs = GameDefs.from_registry(Registry)


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale(_real_locale)


func _new_game() -> GameState:
	var state := GameState.new_game(SEED, _defs.balance)
	assert_bool(GameSetup.build(state, _defs).is_ok).is_true()
	state.events.drain()
	return state


func test_lines_add_up_to_what_the_settlement_charges() -> void:
	var state: GameState = _new_game()
	var economy := EconomySystem.new(_defs.balance, _defs.rooms)
	var lines: Array[CommandLine] = CommandLedger.lines(state)
	assert_int(lines[0].kind).is_equal(CommandLine.Kind.ALLOCATION)
	assert_int(lines[0].per_day_tenths).is_equal(1000)
	assert_str(CommandText.per_day(lines[0])).is_equal("+100")
	assert_str(CommandText.signed_number(lines[0].per_period_k)).is_equal("+3,000")
	var net: CommandLine = lines.back()
	assert_int(net.kind).is_equal(CommandLine.Kind.NET)
	assert_int(net.per_period_k).is_equal(3000 - economy.costs_k(state))
	var rooms: int = 0
	var salaries: int = 0
	for line: CommandLine in lines:
		if line.kind in [CommandLine.Kind.ROOM_TYPE, CommandLine.Kind.OTHER_ROOMS]:
			rooms += line.per_period_k
			assert_int(line.count).is_greater(0)
		elif line.kind == CommandLine.Kind.SALARIES:
			salaries = line.per_period_k
			assert_int(line.count).is_equal(state.staff.people.size())
	assert_int(-rooms).is_equal(EconomySystem.upkeep_k(state.base, state.room_defs, state.unlocks))
	assert_int(-salaries).is_equal(StaffRules.salaries_k(state))


func test_six_room_types_then_other_rooms_at_most_ten_lines() -> void:
	var state: GameState = _new_game()
	_add_every_room_type(state)
	var lines: Array[CommandLine] = CommandLedger.lines(state)
	assert_int(lines.size()).is_equal(10)
	var types: int = 0
	var previous_cost: int = 1 << 30
	for line: CommandLine in lines:
		if line.kind != CommandLine.Kind.ROOM_TYPE:
			continue
		types += 1
		assert_int(-line.per_period_k).is_less_equal(previous_cost)
		previous_cost = -line.per_period_k
	assert_int(types).is_equal(CommandLedger.ROOM_TYPES_SHOWN)
	assert_int(lines[7].kind).is_equal(CommandLine.Kind.OTHER_ROOMS)
	assert_str(CommandText.line_name(state, lines[7])).starts_with("Other rooms ×")
	var breakdown: PackedStringArray = CommandText.breakdown(state, lines[7])
	assert_int(breakdown.size()).is_equal(lines[7].count)


func test_no_staff_hides_salaries_and_switched_off_room_pays_half() -> void:
	var state: GameState = _new_game()
	state.staff.people.clear()
	for line: CommandLine in CommandLedger.lines(state):
		assert_int(line.kind).is_not_equal(CommandLine.Kind.SALARIES)
	var room: RoomState = state.base.rooms[0]
	for other: RoomState in state.base.rooms:
		if state.room_defs[other.def_id].upkeep_k > state.room_defs[room.def_id].upkeep_k:
			room = other
	var full: int = CommandLedger.room_upkeeps(state)[room.id]
	room.powered_on = false
	assert_int(CommandLedger.room_upkeeps(state)[room.id]).is_equal(full / 2)


func test_trend_uses_starting_balance_then_history() -> void:
	var state: GameState = _new_game()
	state.budget.funds_k = 5000
	assert_int(CommandLedger.trend_k(state, 7)).is_equal(-1000)
	for day: int in 10:
		state.committee.add_funds_record(6000 + day * 100)
	assert_int(CommandLedger.trend_k(state, 7)).is_equal(5000 - 6200)
	assert_int(CommandLedger.trend_k(state, 30)).is_equal(-1000)
	for day: int in 30:
		state.committee.add_funds_record(4000 + day)
	assert_int(CommandLedger.trend_k(state, 30)).is_equal(1000)
	assert_str(CommandText.trend_line(state)).is_equal("TREND   7 d +$978k   30 d +$1,000k")


## The settlement pays the allocation and charges today's costs before it checks the red: a
## small positive balance that today's costs will sink already drifts -0.2.
func test_drift_follows_the_settlement_order() -> void:
	var state: GameState = _new_game()
	state.committee.confidence = 0
	state.budget.funds_k = 10
	state.staff.people[0].salary_k = 30000
	assert_bool(CommitteeText.settles_in_red(state)).is_true()
	assert_int(CommitteeText.drift_of(state)).is_equal(ConfidenceRules.IN_RED_STEP)
	state.staff.people[0].salary_k = 0
	state.budget.funds_k = -10
	assert_bool(CommitteeText.settles_in_red(state)).is_false()
	assert_str(CommitteeText.drift_reason(state)).is_equal("settling toward 50")


func test_header_dates_and_commendation() -> void:
	var state: GameState = _new_game()
	state.budget.funds_k = 4125
	assert_str(CommandText.funds_line(state)).starts_with("Funds $4,125k (")
	assert_str(CommandText.short_date(8 * TimeMath.TICKS_PER_DAY)).is_equal("9 Jan")
	assert_str(CommandText.commendation(state)).is_equal("At 70: $1,000k")
	state.committee.commendation_paid = true
	assert_str(CommandText.commendation(state)).is_equal("Paid. Re-arms below 60.")
	TranslationServer.set_locale("pt_BR")
	assert_str(CommandText.short_date(40 * TimeMath.TICKS_PER_DAY)).is_equal("10 fev")


## Adds one built, switched-on room of every known room type to [param state].
static func _add_every_room_type(state: GameState) -> void:
	var index: int = 0
	for def_id: StringName in state.room_defs:
		var room := RoomState.new()
		room.id = StringName("test_room_%d" % index)
		room.def_id = def_id
		room.origin = Vector2i(100 + index * 10, 0)
		state.base.rooms.append(room)
		index += 1
