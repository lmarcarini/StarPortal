## Tests for the faction holding a world (M4-06): the controller is known only once the faction
## is met and the world is Probed; procedural worlds never have one; the World Report shows
## "Held by" in the faction's accent colour.
## Bible: docs/content/m4-core-systems.md section 2
extends GdUnitTestSuite

const WORLD: StringName = &"world_lintel"
const KINDRED: StringName = &"faction_kindred"

var _state: GameState


func before_test() -> void:
	_state = StoryFixture.state()
	_state.galaxy.get_world(WORLD).controller = KINDRED
	var faction := FactionDef.new()
	faction.id = KINDRED
	faction.name_key = &"Kindred"
	faction.accent = Color(0.2, 0.7, 0.4)
	_state.faction_defs[KINDRED] = faction


func test_hidden_until_met_and_probed() -> void:
	_state.worlds.statuses[WORLD] = WorldsState.WorldStatus.LOCKED
	assert_str(String(WorldReportRules.controller(_state, WORLD))).is_empty()
	FactionRules.meet(_state, KINDRED)
	assert_str(String(WorldReportRules.controller(_state, WORLD))).is_empty()
	_state.worlds.statuses[WORLD] = WorldsState.WorldStatus.PROBED
	assert_str(String(WorldReportRules.controller(_state, WORLD))).is_equal("faction_kindred")
	_state.factions.met.clear()
	assert_str(String(WorldReportRules.controller(_state, WORLD))).is_empty()


func test_procedural_worlds_have_none() -> void:
	FactionRules.meet(_state, KINDRED)
	for record: WorldRecord in _state.galaxy.all_worlds():
		if not record.is_authored:
			_state.worlds.statuses[record.id] = WorldsState.WorldStatus.SURVEYED
			assert_str(String(WorldReportRules.controller(_state, record.id))).is_empty()
			return


func test_authored_def_carries_controller() -> void:
	var def := WorldDef.new()
	def.id = &"world_x"
	def.controller = KINDRED
	assert_str(String(WorldRecord.from_def(def).controller)).is_equal("faction_kindred")


func test_report_row_uses_accent() -> void:
	FactionRules.meet(_state, KINDRED)
	_state.worlds.statuses[WORLD] = WorldsState.WorldStatus.PROBED
	var panel: WorldReportPanel = auto_free(WorldReportPanel.new())
	panel.show_world(WORLD, _state)
	var label: Label = panel.get_held_by_label()
	assert_str(label.text).is_equal("Kindred")
	assert_bool((label.get_parent() as Control).visible).is_true()
	assert_that(label.get_theme_color(&"font_color")).is_equal(Color(0.2, 0.7, 0.4))
	_state.worlds.statuses[WORLD] = WorldsState.WorldStatus.LOCKED
	panel.show_world(WORLD, _state)
	assert_bool((label.get_parent() as Control).visible).is_false()


func test_row_key_is_translated() -> void:
	for locale: String in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		assert_str(TranslationServer.translate(&"WORLD_HELD_BY")).is_not_equal("WORLD_HELD_BY")
	TranslationServer.set_locale("en")
