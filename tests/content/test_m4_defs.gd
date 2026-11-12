## Tests for FactionDef, RequestDef and ArtefactDef (M4-02), the new WorldDef.controller and
## WorldTargetDef.artefact_id fields, their content errors, the faction checks, and GameDefs.
## Bible: docs/content/m4-core-systems.md sections 2, 4 and 5
extends GdUnitTestSuite

const RegistryScript := preload("res://src/content/registry.gd")
const FIXTURES: String = "res://tests/content/fixtures/"

var _registry: RegistryScript


func before_test() -> void:
	_registry = auto_free(RegistryScript.new())


func _load(fixture: String) -> Array[String]:
	var errors: Array[String] = _registry.load_all(FIXTURES + fixture).value
	return errors


func _known() -> Dictionary[StringName, DefBase]:
	var known: Dictionary[StringName, DefBase] = {}
	for def: DefBase in _registry.get_all_of(DefBase):
		known[def.id] = def
	return known


## A valid set loads with every field and no errors, and passes the story and faction checks.
func test_valid_defs_load_with_every_field() -> void:
	assert_array(_load("m4_valid")).is_empty()
	var kindred: FactionDef = _registry.get_def(&"faction_kindred")
	assert_str(String(kindred.kind)).is_equal("alien")
	assert_int(kindred.start_standing).is_equal(10)
	assert_bool(kindred.uses_confidence).is_false()
	var request: RequestDef = _registry.get_def(&"request_survey")
	assert_int(request.objective.size()).is_equal(1)
	assert_int(request.deadline_days).is_equal(10)
	assert_int(request.offer_days).is_equal(3)
	var relic: ArtefactDef = _registry.get_def(&"artefact_relic")
	assert_str(String(relic.storage)).is_equal("containment")
	assert_int(relic.modifiers[0].amount).is_equal(10)
	assert_int(relic.hazard.size()).is_equal(1)
	var world: WorldDef = _registry.get_def(&"world_hearth")
	assert_str(String(world.controller)).is_equal("faction_kindred")
	assert_str(String(world.targets[0].artefact_id)).is_equal("artefact_relic")
	assert_array(ContentCheckStory.check_registry(_registry)).is_empty()
	var factions: Array[FactionDef] = [_registry.get_def(&"faction_committee"), kindred]
	assert_array(ContentCheckFactions.check(factions, _known())).is_empty()


## Broken definitions report every rule they break.
func test_bad_defs_report_their_errors() -> void:
	var errors: Array[String] = _load("m4_bad")
	var text: String = "\n".join(errors)
	for expected: String in [
		"has kind 'robot'",
		"start standing 150",
		"has storage 'shelf'",
		"hazard effects must be present exactly when",
		"faction 'artefact_odd' is not a faction",
		"needs at least one objective condition",
		"deadline_succeeds needs a deadline",
		"offer days must be at least 1",
		"controller 'artefact_odd' is not a faction",
	]:
		assert_str(text).contains(expected)


## A missing controller or target artefact is a broken reference.
func test_world_references() -> void:
	var world := WorldDef.new()
	world.controller = &"faction_x"
	var target := WorldTargetDef.new()
	target.artefact_id = &"artefact_x"
	world.targets.append(target)
	assert_array(world.get_references()).is_equal([&"faction_x", &"artefact_x"])
	assert_array(WorldDef.new().get_references()).is_empty()


## Exactly one faction must use Confidence; none loaded is fine.
func test_exactly_one_committee() -> void:
	var known: Dictionary[StringName, DefBase] = {}
	var none: Array[FactionDef] = []
	assert_array(ContentCheckFactions.check(none, known)).is_empty()
	var first := FactionDef.new()
	first.uses_confidence = true
	var second := FactionDef.new()
	second.uses_confidence = true
	var two: Array[FactionDef] = [first, second]
	assert_array(ContentCheckFactions.check(two, known)).contains(
		["expected exactly one faction with uses_confidence, found 2"]
	)
	var zero: Array[FactionDef] = [FactionDef.new()]
	assert_array(ContentCheckFactions.check(zero, known)).contains(
		["expected exactly one faction with uses_confidence, found 0"]
	)


## A ModifierEffect in an artefact's hazard is an error.
func test_modifier_in_hazard_is_rejected() -> void:
	var artefact := ArtefactDef.new()
	artefact.name_key = &"A"
	artefact.description_key = &"B"
	artefact.hazard_chance_pct = 10
	artefact.hazard.append(ModifierEffect.new())
	var errors: Array[String] = artefact.get_content_errors({})
	assert_array(errors).contains(["a ModifierEffect belongs in modifiers, not hazard"])


## GameDefs gathers the new definitions from the Registry.
func test_game_defs_gathers_story_defs() -> void:
	_load("m4_valid")
	var defs: GameDefs = GameDefs.from_registry(_registry)
	assert_int(defs.factions.size()).is_equal(2)
	assert_int(defs.requests.size()).is_equal(1)
	assert_int(defs.artefacts.size()).is_equal(1)
