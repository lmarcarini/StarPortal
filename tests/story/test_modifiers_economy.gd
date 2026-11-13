## Tests for the economy, research and construction modifiers (M4-23): research_speed_pct,
## build_speed_pct, allocation_k and upkeep_pct at 0, positive and negative, staying whole
## numbers, and the Command breakdown's Modifiers line.
## Bible: docs/content/m4-core-systems.md section 6
extends GdUnitTestSuite

var _state: GameState


func before_test() -> void:
	_state = StoryFixture.state()


func _give(key: StringName, amount: int) -> void:
	var modifier := ModifierEffect.new()
	modifier.key = key
	modifier.amount = amount
	var project := ResearchDef.new()
	project.id = StringName("project_" + String(key))
	project.effects = [modifier]
	_state.research_defs[project.id] = project
	_state.research.done.erase(project.id)
	if amount != 0:
		_state.research.done.append(project.id)
	_state.modifiers.signature = []


func test_research_speed() -> void:
	assert_int(ResearchRules.with_modifier(_state, 40)).is_equal(40)
	_give(&"research_speed_pct", 50)
	assert_int(ResearchRules.with_modifier(_state, 40)).is_equal(60)
	_give(&"research_speed_pct", -90)
	assert_int(ResearchRules.with_modifier(_state, 40)).is_equal(4)
	_give(&"research_speed_pct", -90)
	assert_int(ResearchRules.with_modifier(_state, 5)).is_equal(1)


func test_build_speed() -> void:
	assert_int(BuildSpeed.with_modifier(0, 0)).is_equal(0)
	assert_int(BuildSpeed.with_modifier(4, 50)).is_equal(26)
	assert_int(BuildSpeed.with_modifier(0, -50)).is_equal(-20)
	assert_int(BuildSpeed.with_modifier(0, -90)).is_equal(-36)
	_give(&"build_speed_pct", 100)
	var expected: int = BuildSpeed.with_modifier(BuildSpeed.bonus(_state), 100)
	assert_int(BuildSpeed.effective_bonus(_state)).is_equal(expected)
	var ticks: int = 0
	for tick: int in 40:
		ticks += BuildSpeed.step_at(tick, BuildSpeed.effective_bonus(_state))
	assert_int(ticks).is_equal(80 + BuildSpeed.bonus(_state) * 2)


func test_allocation_and_upkeep() -> void:
	var room_defs: Array[RoomDef] = []
	room_defs.assign(_state.room_defs.values())
	var system := EconomySystem.new(_state.balance, room_defs)
	var base_costs: int = system.costs_k(_state)
	assert_int(base_costs).is_greater(0)
	_give(&"upkeep_pct", -50)
	var upkeep: int = EconomySystem.upkeep_k(_state.base, _state.room_defs, _state.unlocks)
	assert_int(system.costs_k(_state)).is_equal(base_costs - upkeep + upkeep / 2)
	_give(&"upkeep_pct", 0)
	_give(&"allocation_k", 20)
	var funds: int = _state.budget.funds_k
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	var plain := GameState.from_dict(data)
	plain.research_defs = _state.research_defs
	plain.research.done.clear()
	plain.room_defs = _state.room_defs
	plain.balance = _state.balance
	system.on_day(_state)
	system.on_day(plain)
	assert_int(_state.budget.funds_k - plain.budget.funds_k).is_equal(20)
	assert_int(funds).is_not_equal(_state.budget.funds_k)
	_give(&"allocation_k", -20)
	system.on_day(_state)
	system.on_day(plain)
	assert_int(_state.budget.funds_k - plain.budget.funds_k).is_equal(0)


func test_command_breakdown_line() -> void:
	TranslationServer.set_locale("en")
	for line: CommandLine in CommandLedger.lines(_state):
		assert_int(line.kind).is_not_equal(CommandLine.Kind.MODIFIERS)
	_give(&"allocation_k", 10)
	var lines: Array[CommandLine] = CommandLedger.lines(_state)
	var modifier: CommandLine = lines[-2]
	assert_int(modifier.kind).is_equal(CommandLine.Kind.MODIFIERS)
	assert_int(modifier.per_period_k).is_equal(300)
	assert_str(CommandText.line_name(_state, modifier)).is_equal("Modifiers")
