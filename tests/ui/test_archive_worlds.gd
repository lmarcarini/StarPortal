## Tests for the Archive's Worlds section and the World Report: after SILL is locked, its horizon
## record taken and its console read, Worlds lists SILL as LOCKED; its report shows the threat as
## a range with its confidence and source, the pole camera's readings as values, the rest
## unknown, and a disabled Plan expedition slot; it refreshes while paused; mouse and gamepad
## reach it; it fits the minimum window in en and pt_BR with no clipped text or missing glyph.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (World Report fields), section 7
## (World Report sketch; gamepad)
extends GdUnitTestSuite

const M15Player := preload("res://tests/gate/m15_player.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
const VIEW_SCENE: String = "res://src/ui/views/archive/archive_view.tscn"
const VIEW_SIZE: Vector2 = Vector2(1280, 600)
const SILL: StringName = &"world_sill"
const LINTEL: StringName = &"world_lintel"
const SLACK: float = 1.0

var _player: M15Player
var _holder: Control = null
var _view: ArchiveView = null
var _real_locale: String = ""


func before() -> void:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var built: Result = GameSetup.build_new(GameState.new_game(20261107, defs.balance), defs)
	var simulation: Simulation = built.value
	_player = M15Player.new(simulation)
	_player.step()
	_player.build_bank()
	var sill: GateAddress = _player.address(M15Player.PUZZLES[0]["glyphs"])
	_player.wait_for_charge(sill)
	_player.dial(sill)
	_player.extend_pole_camera()
	_player.read_console()
	_player.close_wormhole()


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	SimClock.start(_player.simulation)
	_holder = Control.new()
	_holder.size = VIEW_SIZE
	_holder.add_child((load(VIEW_SCENE) as PackedScene).instantiate())
	add_child(_holder)
	_view = _holder.get_child(0) as ArchiveView
	_view.setup(_player.simulation)
	_view.show_worlds()
	await UiInput.settle(_view)


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	TranslationServer.set_locale(_real_locale)


func _worlds() -> WorldsSection:
	return _view.get_worlds()


func _report() -> WorldReportPanel:
	return _worlds().get_report()


## The Archive has Documents, Worlds and Log; Worlds lists SILL with its state.
func test_worlds_lists_the_locked_world() -> void:
	var sections: TabContainer = _view.get_node("%Sections") as TabContainer
	assert_int(sections.get_tab_count()).is_equal(3)
	assert_str(sections.tr(sections.get_tab_title(1))).is_equal("Worlds")
	assert_bool(_worlds().get_world_ids().has(SILL)).is_true()
	var row: Button = _worlds().get_rows()[_worlds().get_world_ids().find(SILL)]
	assert_str(row.text).is_equal("SILL  ·  LOCKED")
	assert_str(_report().get_world_id()).is_empty()


## The report shows each fact as unknown, a range or a value with confidence and source.
func test_report_shows_facts_through_the_rules() -> void:
	_worlds().open_world(SILL)
	var report: WorldReport = _player.state().worlds.report_of(SILL)
	var facts: WorldFacts = WorldFactRules.facts_for_id(_player.state().galaxy, SILL)
	var reading: WorldReportRules.ThreatReading = WorldReportRules.threat_reading(
		SILL, facts.threat, report.confidence_of(WorldReport.Fact.THREAT)
	)
	assert_bool(reading.is_exact()).is_false()
	var threat: String = _report().get_value_text(WorldReport.Fact.THREAT)
	assert_str(threat).contains("–")
	var date: Dictionary = TimeMath.date_of(report.entry_of(WorldReport.Fact.THREAT).tick)
	var month: String = tr(StringName("COMMAND_MONTH_%d" % date["month"]))
	assert_str(_report().get_note_text(WorldReport.Fact.THREAT)).is_equal(
		"confidence poor (pole camera %d %s)" % [date["day"], month]
	)
	assert_str(_report().get_value_text(WorldReport.Fact.TEMPERATURE)).is_equal(
		"%d °C" % facts.temperature_c
	)
	assert_str(_report().get_note_text(WorldReport.Fact.ATMOSPHERE)).starts_with("confidence fair")
	for fact: WorldReport.Fact in [WorldReport.Fact.BIOHAZARD, WorldReport.Fact.LIFE]:
		assert_str(_report().get_value_text(fact)).is_equal("unknown")
		assert_str(_report().get_note_text(fact)).is_empty()
	var plan: Button = _report().get_plan_button()
	assert_bool(plan.is_visible_in_tree()).is_true()
	assert_bool(plan.disabled).is_true()


## A world's state and a fact rising while paused show without reopening the Archive.
func test_refreshes_while_paused() -> void:
	assert_bool(_player.state().clock.is_paused).is_true()
	var simulation: Simulation = _player.simulation
	var lock: CommandResult = simulation.submit(
		RaiseWorldStatusCommand.create(LINTEL, WorldsState.WorldStatus.LOCKED)
	)
	assert_bool(lock.is_ok).is_true()
	await UiInput.settle(_view)
	assert_bool(_worlds().get_world_ids().has(LINTEL)).is_true()
	_worlds().open_world(LINTEL)
	assert_str(_report().get_value_text(WorldReport.Fact.THREAT)).is_equal("UNKNOWN")
	var change := WorldProgress.FactChange.create(
		LINTEL, WorldReport.Fact.THREAT, WorldReport.Confidence.FAIR, &"moth"
	)
	assert_bool(simulation.submit(RaiseWorldFactCommand.create(change)).is_ok).is_true()
	await UiInput.settle(_view)
	assert_str(_report().get_value_text(WorldReport.Fact.THREAT)).is_equal("LOW")
	assert_str(_report().get_note_text(WorldReport.Fact.THREAT)).contains("fair (MOTH ")


## Clicking a row opens its report.
func test_mouse_opens_a_report() -> void:
	var index: int = _worlds().get_world_ids().find(SILL)
	await UiInput.click(_worlds().get_rows()[index])
	assert_str(_report().get_world_id()).is_equal(SILL)


## Down from the section tabs reaches the first row, A opens it, Right reaches Plan expedition.
func test_gamepad_path() -> void:
	var tabs: TabBar = (_view.get_node("%Sections") as TabContainer).get_tab_bar()
	tabs.grab_focus()
	await UiInput.pad(tabs, JOY_BUTTON_DPAD_DOWN)
	var first: Button = _worlds().get_rows()[0]
	assert_object(_view.get_viewport().gui_get_focus_owner()).is_same(first)
	await UiInput.pad(first, JOY_BUTTON_A)
	assert_str(_report().get_world_id()).is_equal(_worlds().get_world_ids()[0])
	await UiInput.pad(first, JOY_BUTTON_DPAD_RIGHT)
	var plan: Button = _report().get_plan_button()
	assert_object(_view.get_viewport().gui_get_focus_owner()).is_same(plan)
	await UiInput.pad(plan, JOY_BUTTON_DPAD_LEFT)
	assert_object(_view.get_viewport().gui_get_focus_owner()).is_same(first)
	await UiInput.pad(first, JOY_BUTTON_DPAD_UP)
	assert_object(_view.get_viewport().gui_get_focus_owner()).is_same(tabs)


@warning_ignore("unused_parameter")
func test_fits_the_minimum_window(
	locale: String, test_parameters: Array = [["en"], ["pt_BR"]]  # gdlint: ignore=unused-argument
) -> void:
	TranslationServer.set_locale(locale)
	_worlds().open_world(SILL)
	await UiInput.settle(_view)
	var needed: Vector2 = _worlds().get_combined_minimum_size()
	assert_float(needed.x).is_less_equal(VIEW_SIZE.x)
	assert_float(needed.y).is_less_equal(VIEW_SIZE.y)
	assert_array(_problems(_worlds())).is_empty()
	_report().get_description_label().text = _longest_description()
	await UiInput.settle(_view)
	needed = _worlds().get_combined_minimum_size()
	assert_float(needed.y).is_less_equal(VIEW_SIZE.y)
	assert_array(_problems(_worlds())).is_empty()


## The longest description the report can show: the longest line of each kind, joined.
func _longest_description() -> String:
	var parts: PackedStringArray = []
	for prefix: String in ["REPORT_BIOME_", "MOTH_SKY_", "MOTH_LIFE_", "MOTH_STRUCTURES_"]:
		parts.append(_longest_with(prefix))
	return " ".join(parts)


func _longest_with(prefix: String) -> String:
	var longest: String = ""
	var translation: Translation = TranslationServer.get_translation_object(
		TranslationServer.get_locale()
	)
	for key: StringName in translation.get_message_list():
		var text: String = tr(key)
		if String(key).begins_with(prefix) and text.length() > longest.length():
			longest = text
	return longest


## Visible single-line labels and buttons narrower than their text, or with a character the
## font lacks.
func _problems(root: Node) -> Array[String]:
	var found: Array[String] = []
	for child: Node in root.get_children():
		found.append_array(_problems(child))
	if not (root is Label or root is Button) or not (root as Control).is_visible_in_tree():
		return found
	var control: Control = root as Control
	var text: String = (root as Label).text if root is Label else (root as Button).text
	text = control.tr(text) if control.can_auto_translate() else text
	var font: Font = control.get_theme_font(&"font")
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code >= 0x20 and not font.has_char(code):
			found.append("%s: no glyph for U+%04X" % [control.name, code])
	var wraps: bool = root is Label and (root as Label).autowrap_mode != TextServer.AUTOWRAP_OFF
	var size: int = control.get_theme_font_size(&"font_size")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var padding: float = 8.0 if root is Button else 0.0
	if not wraps and width + padding > control.size.x + SLACK:
		found.append("%s: '%s' needs %d px, has %d" % [control.name, text, width, control.size.x])
	return found
