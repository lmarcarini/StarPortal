## Tests that field events are visible: each writes a Log line (title and success or failure
## text, naming who rolled), the check-in line says what the day brought, and the longest
## pt_BR field event line fits a Log row at the minimum window (1280 x 720).
## Bible: docs/content/m3-beyond-the-ring.md section 4 (Risk model),
## technical-architecture.md#input-accessibility-and-localisation
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/archive/archive_view.tscn"
const VIEW_SIZE: Vector2 = Vector2(1280, 600)
const NAME: String = "Maj. Ruth Adair"
const WORLD: StringName = &"world_stillwater"

var _holder: Control = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	TranslationServer.set_locale(_real_locale)


func _args(event_id: StringName, outcome: String) -> Array:
	return [WORLD, event_id, outcome, NAME]


func test_field_event_writes_a_log_line() -> void:
	TranslationServer.set_locale("en")
	var entries: Array[LogEntry] = LogRules.entries_for(
		ExpeditionFieldDay.EVENT, _args(&"thin_ice", "light"), null, 5
	)
	assert_int(entries.size()).is_equal(1)
	assert_str(String(entries[0].kind)).is_equal("expedition")
	var line: String = ExpeditionLogText.line(entries[0].args, "STILLWATER")
	assert_str(line).is_equal("Thin ice: The ice broke under %s: a light injury." % NAME)
	var found: Array[LogEntry] = LogRules.entries_for(
		ExpeditionFieldDay.EVENT, _args(&"thin_ice", "finding"), null, 5
	)
	assert_str(ExpeditionLogText.line(found[0].args, "")).starts_with("Thin ice: The ice was")


func test_longest_pt_br_line_fits_a_log_row() -> void:
	TranslationServer.set_locale("pt_BR")
	var longest: Dictionary = {}
	var longest_line: String = ""
	for def: FieldEventDef in FieldEvents.all():
		for outcome: String in ["finding", FieldEventDef.SETBACK_NAMES[def.setback]]:
			var entry: LogEntry = (
				LogRules.entries_for(ExpeditionFieldDay.EVENT, _args(def.id, outcome), null, 5)[0]
			)
			var text: String = ExpeditionLogText.line(entry.args, "")
			if text.length() > longest_line.length():
				longest_line = text
				longest = entry.args
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var built: Result = GameSetup.build_new(GameState.new_game(231, defs.balance), defs)
	var simulation: Simulation = built.value
	simulation.state.operations_log.entries.append(
		LogEntry.create(5, &"expedition", WORLD, longest)
	)
	SimClock.start(simulation)
	_holder = Control.new()
	_holder.size = VIEW_SIZE
	_holder.add_child((load(VIEW_SCENE) as PackedScene).instantiate())
	add_child(_holder)
	var view: ArchiveView = _holder.get_child(0) as ArchiveView
	view.setup(simulation)
	view.show_section(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var row: ArchiveLogRow = view.get_log_list().get_rows()[0]
	assert_str(row.get_line_text()).is_equal(longest_line)
	var label: Label = row.get_node("%Line") as Label
	assert_float(label.size.x).is_greater(300.0)
	print(
		(
			"longest pt_BR field event line: %d chars, row %d px"
			% [longest_line.length(), label.size.x]
		)
	)
	var font: Font = label.get_theme_font(&"font")
	var size: int = label.get_theme_font_size(&"font_size")
	var width: float = font.get_string_size(longest_line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	(
		assert_float(width)
		. override_failure_message(
			"'%s' needs %d px, row has %d" % [longest_line, width, label.size.x]
		)
		. is_less_equal(label.size.x + 1.0)
	)


func test_departure_and_return_write_log_lines() -> void:
	TranslationServer.set_locale("en")
	var team: Array[String] = [NAME, "Dr Ana Reis"]
	var sent: LogEntry = LogRules.entries_for(&"team_sent", [WORLD, 1, team], null, 5)[0]
	assert_str(String(sent.world_id)).is_equal(String(WORLD))
	assert_str(sent.args["objective"]).is_equal("survey")
	assert_str(ExpeditionLogText.line(sent.args, "STILLWATER")).is_equal(
		"T-1 went through to STILLWATER (survey): %s, Dr Ana Reis." % NAME
	)
	var back: LogEntry = LogRules.entries_for(&"team_returned", [WORLD, 2, true, team], null, 9)[0]
	assert_bool(back.args["success"]).is_true()
	assert_array(LogEntry.validate_dict(back.to_dict())).is_empty()
	assert_str(ExpeditionLogText.line(back.args, "STILLWATER")).is_equal(
		"T-1 came home from STILLWATER (recovery): %s, Dr Ana Reis." % NAME
	)


## The Log names the injury the event actually caused: serious, or kept light by a medic.
func test_injury_line_follows_the_actual_severity() -> void:
	var cases: Array = [
		["en", "serious", "a serious injury"],
		["en", "light", "a serious injury, kept light by the medic"],
		["pt_BR", "serious", "um ferimento grave"],
		["pt_BR", "light", "um ferimento grave, mantido leve pelo médico"],
	]
	for case: Array in cases:
		var locale: String = case[0]
		var outcome: String = case[1]
		TranslationServer.set_locale(locale)
		var entry: LogEntry = (
			LogRules.entries_for(ExpeditionFieldDay.EVENT, _args(&"stalkers", outcome), null, 5)[0]
		)
		var line: String = ExpeditionLogText.line(entry.args, "")
		assert_str(line).ends_with(": %s." % case[2])
		assert_int(line.countn("grave") + line.countn("serious")).is_equal(1)
