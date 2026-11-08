## Tests for FieldCheck and FieldEvents: the check formula, its clamps and difficulty
## modifiers, a simulated success rate, the roller, and the pool of 8 events with texts.
## Bible: docs/content/m3-beyond-the-ring.md section 4 (Risk model)
extends GdUnitTestSuite

const TABLE: String = "res://localization/gate.csv"


func _facts(threat: WorldDef.Threat, biome: WorldDef.Biome = WorldDef.Biome.FOREST) -> WorldFacts:
	var facts := WorldFacts.new()
	facts.threat = threat
	facts.biome = biome
	facts.atmosphere = WorldDef.Atmosphere.BREATHABLE
	facts.temperature_c = 15
	return facts


func _person(role: StringName, skill: int) -> PersonState:
	var person := PersonState.new()
	person.id = StringName("p_%s_%d" % [role, skill])
	person.role = role
	person.skill = skill
	return person


func test_chance_formula_and_clamps() -> void:
	assert_int(FieldCheck.chance(2, 2)).is_equal(50)
	assert_int(FieldCheck.chance(3, 2)).is_equal(65)
	assert_int(FieldCheck.chance(1, 3)).is_equal(20)
	assert_int(FieldCheck.chance(4, 1)).is_equal(95)
	assert_int(FieldCheck.chance(0, 4)).is_equal(10)
	assert_int(FieldCheck.chance(1, 4)).is_equal(10)


func test_difficulty_modifiers() -> void:
	var def: FieldEventDef = FieldEvents.find(&"loose_scree")
	assert_int(FieldCheck.difficulty(def, _facts(WorldDef.Threat.LOW))).is_equal(2)
	assert_int(FieldCheck.difficulty(def, _facts(WorldDef.Threat.MED))).is_equal(3)
	assert_int(FieldCheck.difficulty(def, _facts(WorldDef.Threat.HIGH))).is_equal(4)
	var airless: WorldFacts = _facts(WorldDef.Threat.HIGH)
	airless.atmosphere = WorldDef.Atmosphere.NONE
	assert_int(FieldCheck.difficulty(def, airless)).is_equal(5)
	var cold: WorldFacts = _facts(WorldDef.Threat.LOW)
	cold.temperature_c = -21
	assert_int(FieldCheck.difficulty(def, cold)).is_equal(3)
	cold.temperature_c = -20
	assert_int(FieldCheck.difficulty(def, cold)).is_equal(2)


## 20000 seeded rolls land within 1.5 points of the formula's chance.
func test_simulated_success_rate_matches_formula() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 231
	for case: Vector2i in [Vector2i(3, 2), Vector2i(1, 4), Vector2i(5, 1), Vector2i(2, 3)]:
		var percent: int = FieldCheck.chance(case.x, case.y)
		var passed: int = 0
		for index: int in 20000:
			passed += int(FieldCheck.succeeds(rng.randi_range(0, 99), percent))
		assert_float(passed / 200.0).is_between(percent - 1.5, percent + 1.5)


func test_roller_is_best_in_role_and_serious_counts_as_one() -> void:
	var weak: PersonState = _person(StartingStaff.SOLDIER, 2)
	var strong: PersonState = _person(StartingStaff.SOLDIER, 3)
	var members: Array[PersonState] = [weak, strong, _person(StartingStaff.SCIENTIST, 5)]
	assert_object(FieldCheck.roller(members, StartingStaff.SOLDIER)).is_same(strong)
	InjuryRules.injure(strong, PersonState.Injury.SERIOUS)
	assert_object(FieldCheck.roller(members, StartingStaff.SOLDIER)).is_same(weak)
	assert_int(FieldCheck.skill_of(strong)).is_equal(1)
	assert_object(FieldCheck.roller(members, StartingStaff.MEDIC)).is_null()
	assert_int(FieldCheck.skill_of(null)).is_equal(0)


func test_eight_events_with_valid_rules() -> void:
	var events: Array[FieldEventDef] = FieldEvents.all()
	assert_int(events.size()).is_equal(8)
	for def: FieldEventDef in events:
		assert_int(def.difficulty).is_between(1, 4)
		if def.setback == FieldEventDef.Setback.SERIOUS:
			assert_int(def.difficulty).override_failure_message(def.id).is_equal(4)
	assert_bool(events.any(func(d: FieldEventDef) -> bool: return d.setback == 3)).is_true()


func test_pool_never_empty_and_filters() -> void:
	for objective: int in [ExpeditionState.Objective.SURVEY, ExpeditionState.Objective.RECOVER]:
		for biome: int in WorldDef.Biome.values():
			for threat: int in [WorldDef.Threat.LOW, WorldDef.Threat.MED, WorldDef.Threat.HIGH]:
				var facts: WorldFacts = _facts(threat, biome)
				assert_bool(FieldEvents.pool(objective, facts).is_empty()).is_false()
	var low_ice: Array[FieldEventDef] = FieldEvents.pool(
		ExpeditionState.Objective.SURVEY, _facts(WorldDef.Threat.LOW, WorldDef.Biome.ICE)
	)
	var ids: Array = low_ice.map(func(d: FieldEventDef) -> StringName: return d.id)
	assert_array(ids).contains_exactly(
		[&"dust_front", &"loose_scree", &"thin_ice", &"false_bearings"]
	)


func test_every_event_has_texts_in_en_and_pt_br() -> void:
	var texts: Dictionary[String, PackedStringArray] = {}
	var file := FileAccess.open(TABLE, FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 3:
			texts[row[0]] = row
	for def: FieldEventDef in FieldEvents.all():
		for part: String in FieldEvents.TEXT_PARTS:
			var key: String = def.text_key(part)
			assert_bool(texts.has(key)).override_failure_message(key).is_true()
			if texts.has(key):
				assert_str(texts[key][1]).is_not_empty()
				assert_str(texts[key][2]).is_not_empty()
