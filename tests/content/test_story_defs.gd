## Tests for the story condition and effect Resources (M4-01): a fixture of every class loads
## with its fields and references, and the story checks report unknown ids, unknown modifier
## keys and a ModifierEffect outside research and artefacts.
## Bible: docs/content/m4-core-systems.md sections 1 and 6
extends GdUnitTestSuite

const RegistryScript := preload("res://src/content/registry.gd")
const ENTRIES: String = "res://tests/content/fixtures/story/entries/"
const REGISTRY_FIXTURE: String = "res://tests/content/fixtures/story/registry"


func _entry(file_name: String) -> Resource:
	return load(ENTRIES + file_name + ".tres")


## Every fixture loads as a condition or an effect, and every effect fixture is hidden.
func test_every_fixture_loads() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(ENTRIES)
	var count: int = 0
	for file_name: String in files:
		if not file_name.ends_with(".tres"):
			continue
		var entry: Resource = load(ENTRIES + file_name)
		assert_bool(entry is ConditionDef or entry is EffectDef).is_true()
		if entry is EffectDef:
			assert_bool((entry as EffectDef).hidden).is_true()
		if entry is ConditionDef:
			assert_str(String((entry as ConditionDef).reason_key())).is_not_empty()
		count += 1
	assert_int(count).is_equal(22)


## Conditions keep their typed fields and name the definitions they point at.
func test_condition_fields_and_references() -> void:
	var standing: StandingAtLeastCondition = _entry("standing_at_least_condition")
	assert_int(standing.amount).is_equal(25)
	assert_array(standing.get_references()).is_equal([&"faction_a"])
	var flag: FlagIsCondition = _entry("flag_is_condition")
	assert_int(flag.value).is_equal(7)
	assert_array(flag.get_references()).is_empty()
	var world: WorldStatusAtLeastCondition = _entry("world_status_at_least_condition")
	assert_int(world.status).is_equal(WorldStatusAtLeastCondition.WorldStatus.SURVEYED)
	var request: RequestIsCondition = _entry("request_is_condition")
	assert_int(request.state).is_equal(RequestIsCondition.RequestState.FULFILLED)
	assert_array(request.get_references()).is_equal([&"request_a"])


## Effects keep their typed fields and name the definitions they point at.
func test_effect_fields_and_references() -> void:
	var money: ChangeMoneyEffect = _entry("change_money_effect")
	assert_int(money.amount_k).is_equal(500)
	assert_array(money.get_references()).is_empty()
	var document: AddDocumentEffect = _entry("add_document_effect")
	assert_array(document.get_references()).is_equal([&"doc_a"])
	var modifier: ModifierEffect = _entry("modifier_effect")
	assert_str(String(modifier.key)).is_equal("research_speed_pct")
	assert_int(modifier.amount).is_equal(10)
	assert_int(ModifierEffect.KEYS.size()).is_equal(12)


## The request states match the order of the design.
func test_request_state_values() -> void:
	assert_int(RequestIsCondition.RequestState.OFFERED).is_equal(0)
	assert_int(RequestIsCondition.RequestState.LAPSED).is_equal(5)


## check_registry reports the broken definition's unknown faction and modifier key and the
## modifier outside research, and nothing for the valid one.
func test_registry_check_catches_broken_references() -> void:
	var registry: RegistryScript = auto_free(RegistryScript.new())
	var load_errors: Array[String] = registry.load_all(REGISTRY_FIXTURE).value
	assert_array(load_errors).is_empty()
	var errors: Array[String] = ContentCheckStory.check_registry(registry)
	(
		assert_array(errors)
		. contains_exactly_in_any_order(
			[
				'owner_bad: FactionMetCondition references unknown id "faction_z"',
				'owner_bad: unknown modifier key "warp_speed_pct"',
				"owner_bad: ModifierEffect is only allowed on research and artefacts",
			]
		)
	)


## check_lists allows a known ModifierEffect where modifiers are allowed and reports an empty id.
func test_check_lists_modifier_allowed_and_empty_id() -> void:
	var modifier := ModifierEffect.new()
	modifier.key = &"build_speed_pct"
	var empty := FactionMetCondition.new()
	var known: Dictionary[StringName, DefBase] = {}
	var conditions: Array[ConditionDef] = [empty]
	var effects: Array[EffectDef] = [modifier]
	var errors: Array[String] = ContentCheckStory.check_lists(
		&"research_x", conditions, effects, known, true
	)
	assert_array(errors).contains_exactly(["research_x: FactionMetCondition has an empty id"])


## Nothing under src/content/story/ references the simulation layer (comments aside).
func test_story_content_is_independent_of_simulation() -> void:
	var folders: Array[String] = [
		"res://src/content/story/",
		"res://src/content/story/conditions/",
		"res://src/content/story/effects/",
	]
	for folder: String in folders:
		for file_name: String in DirAccess.get_files_at(folder):
			if file_name.ends_with(".gd"):
				assert_bool(_uses_simulation(folder + file_name)).is_false()


func _uses_simulation(path: String) -> bool:
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		if (
			line.contains("GameState")
			or line.contains("res://src/core")
			or line.contains("WorldsState")
		):
			return true
	return false
