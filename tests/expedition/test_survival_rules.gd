## Tests for SurvivalRules: the owner's formula (threat, conditions, serious injury, days
## waited, soldiers who survived rolled first, 10% to 99%) and its seeded rolls.
## Bible: docs/content/m3-beyond-the-ring.md section 4 (A rescue is not a sure thing)
extends GdUnitTestSuite


func _facts(threat: WorldDef.Threat, harsh: bool = false) -> WorldFacts:
	var facts := WorldFacts.new()
	facts.threat = threat
	facts.atmosphere = WorldDef.Atmosphere.NONE if harsh else WorldDef.Atmosphere.BREATHABLE
	facts.temperature_c = 15
	return facts


func _person(id: StringName, role: StringName) -> PersonState:
	var person := PersonState.new()
	person.id = id
	person.role = role
	return person


func test_base_chance_by_true_threat() -> void:
	assert_int(SurvivalRules.chance(_facts(WorldDef.Threat.LOW), false, 0, 0)).is_equal(95)
	assert_int(SurvivalRules.chance(_facts(WorldDef.Threat.MED), false, 0, 0)).is_equal(85)
	assert_int(SurvivalRules.chance(_facts(WorldDef.Threat.HIGH), false, 0, 0)).is_equal(70)


func test_conditions_injury_and_days() -> void:
	var med: WorldFacts = _facts(WorldDef.Threat.MED, true)
	assert_int(SurvivalRules.chance(med, false, 0, 0)).is_equal(75)
	assert_int(SurvivalRules.chance(med, true, 0, 0)).is_equal(60)
	assert_int(SurvivalRules.chance(med, true, 2, 0)).is_equal(50)
	var cold: WorldFacts = _facts(WorldDef.Threat.MED)
	cold.temperature_c = -21
	assert_int(SurvivalRules.chance(cold, false, 0, 0)).is_equal(75)
	cold.temperature_c = -20
	assert_int(SurvivalRules.chance(cold, false, 0, 0)).is_equal(85)


func test_soldiers_bonus_capped_and_bounds() -> void:
	var high: WorldFacts = _facts(WorldDef.Threat.HIGH)
	assert_int(SurvivalRules.chance(high, false, 0, 1)).is_equal(75)
	assert_int(SurvivalRules.chance(high, false, 0, 3)).is_equal(80)
	assert_int(SurvivalRules.chance(_facts(WorldDef.Threat.LOW), false, 0, 2)).is_equal(99)
	assert_int(SurvivalRules.chance(_facts(WorldDef.Threat.HIGH, true), true, 10, 0)).is_equal(10)


func test_soldiers_roll_first() -> void:
	var members: Array[PersonState] = [
		_person(&"a", StartingStaff.SCIENTIST),
		_person(&"b", StartingStaff.SOLDIER),
		_person(&"c", StartingStaff.ENGINEER),
		_person(&"d", StartingStaff.SOLDIER),
	]
	var order: Array[StringName] = []
	for person: PersonState in SurvivalRules.roll_order(members):
		order.append(person.id)
	assert_array(order).is_equal([&"b", &"d", &"a", &"c"])


func test_rolls_are_seeded() -> void:
	var members: Array[PersonState] = [
		_person(&"a", StartingStaff.SCIENTIST), _person(&"b", StartingStaff.SOLDIER)
	]
	var facts: WorldFacts = _facts(WorldDef.Threat.HIGH, true)
	var first := RandomNumberGenerator.new()
	first.seed = 7
	var second := RandomNumberGenerator.new()
	second.seed = 7
	assert_array(SurvivalRules.roll(members, facts, 2, first)).is_equal(
		SurvivalRules.roll(members, facts, 2, second)
	)
