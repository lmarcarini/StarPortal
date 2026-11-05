## Tests for the Confidence readout, the non-blocking month-end message and the report window,
## in the shell: shown at the month-end without pausing, opened by mouse, keyboard and gamepad,
## refreshed while paused and after a setup, warnings in red, and fitting 1280 x 720 in en and
## pt_BR with the real font.
## Bible: docs/content/m26-staff-and-money.md sections 5 and 6
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
const MIN_SIZE: Vector2 = Vector2(1280, 720)

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _real_saves_dir: String = ""
var _real_locale: String = ""


func before_test() -> void:
	_real_saves_dir = SaveService.saves_dir
	_real_locale = TranslationServer.get_locale()
	SaveService.saves_dir = (
		"user://test_month_ui_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	)
	TranslationServer.set_locale("en")
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 12345
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	SaveService.saves_dir = _real_saves_dir
	TranslationServer.set_locale(_real_locale)


func test_before_the_first_month_end() -> void:
	assert_str(_shell.confidence_readout.text).is_equal("Confidence 50")
	assert_str(_shell.confidence_readout.tooltip_text).is_equal(tr(&"CONFIDENCE_TOOLTIP_NONE"))
	assert_bool(_shell.month_notice.visible).is_false()
	_shell.open_month_report()
	assert_bool(_shell.month_panel.visible).is_false()


func test_month_end_shows_the_message_without_pausing() -> void:
	SimClock.resume()
	await _month_end()
	var state: GameState = SimClock.simulation.state
	var report: MonthReport = state.committee.latest_report()
	assert_object(report).is_not_null()
	assert_bool(state.clock.is_paused).is_false()
	assert_bool(_shell.month_notice.visible).is_true()
	assert_str(_shell.month_notice.get_text()).is_equal(MonthReportText.headline(report))
	assert_str(_shell.confidence_readout.text).is_equal(
		ConfidenceReadout.readout_text(state.committee.confidence, report)
	)
	for cause: StringName in report.applied_causes():
		assert_str(_shell.confidence_readout.tooltip_text).contains(
			MonthReportText.cause_line(report, cause, state)
		)
	SimClock.pause()


func test_view_opens_the_full_report_and_cancel_closes_it() -> void:
	await _month_end()
	var state: GameState = SimClock.simulation.state
	var report: MonthReport = state.committee.latest_report()
	_shell.month_notice.get_view_button().pressed.emit()
	assert_bool(_shell.month_panel.visible).is_true()
	assert_bool(_shell.month_notice.visible).is_false()
	var shown: PackedStringArray = _shell.month_panel.get_lines()
	assert_str(shown[0]).is_equal(MonthReportPanel.title_of(report))
	var body: PackedStringArray = MonthReportText.lines(report, state)
	for index: int in range(1, body.size()):
		assert_bool(shown.has(body[index])).override_failure_message(body[index]).is_true()
	assert_object(_focus_owner()).is_same(_shell.month_panel.get_close_button())
	_runner.simulate_action_pressed("ui_cancel")
	await _runner.await_input_processed()
	assert_bool(_shell.month_panel.visible).is_false()


func test_gamepad_reaches_the_readout_and_a_opens_the_report() -> void:
	await _month_end()
	var buttons: Array[Button] = _shell.get_focus_order()
	assert_object(buttons[3]).is_same(_shell.confidence_readout)
	buttons[2].grab_focus()
	_runner.simulate_action_pressed("ui_right")
	await _runner.await_input_processed()
	assert_object(_focus_owner()).is_same(_shell.confidence_readout)
	await _press_joypad(JOY_BUTTON_A)
	assert_bool(_shell.month_panel.visible).is_true()
	await _press_joypad(JOY_BUTTON_B)
	assert_bool(_shell.month_panel.visible).is_false()
	assert_object(_focus_owner()).is_same(_shell.confidence_readout)


func test_warnings_show_in_red_while_paused_and_after_setup() -> void:
	var state: GameState = SimClock.simulation.state
	var report := MonthReport.blank()
	report.year = 2026
	report.month = 4
	report.confidence_before = 5
	report.confidence_after = 0
	report.months_in_red = 3
	report.warn_red_months = true
	report.warn_confidence_zero = true
	state.committee.confidence = 0
	state.committee.add_report(report)
	assert_bool(state.clock.is_paused).is_true()
	EventBus.month_report_filed.emit(2026, 4)
	assert_str(_shell.confidence_readout.text).is_equal("Confidence 0 −5")
	assert_bool(_shell.confidence_readout.has_theme_color_override(&"font_color")).is_true()
	var warnings: PackedStringArray = MonthReportPanel.warning_lines(report)
	assert_int(warnings.size()).is_equal(2)
	for line: String in warnings:
		assert_str(_shell.confidence_readout.tooltip_text).contains(line)
	assert_bool(_shell.month_notice.visible).is_true()
	_shell.open_month_report()
	assert_bool(Array(_shell.month_panel.get_lines()).has(warnings[0])).is_true()
	_shell.month_panel.close()
	state.committee.confidence = 40
	_shell.confidence_readout.setup(state)
	assert_str(_shell.confidence_readout.text).is_equal("Confidence 40 −5")


func test_locale_change_refreshes_the_readout() -> void:
	TranslationServer.set_locale("pt_BR")
	await _runner.simulate_frames(2)
	assert_str(_shell.confidence_readout.text).is_equal("Confiança 50")


@warning_ignore("unused_parameter")
func test_fits_1280_by_720(
	locale: String,
	test_parameters: Array = [  # gdlint: ignore=unused-argument
		["en"],
		["pt_BR"],
	]
) -> void:
	TranslationServer.set_locale(locale)
	_shell.size = MIN_SIZE
	var state: GameState = SimClock.simulation.state
	state.committee.add_report(_busiest_report())
	state.committee.confidence = 0
	EventBus.month_report_filed.emit(2026, 4)
	_shell.open_month_report()
	await _runner.simulate_frames(3)
	# The release top bar: the debug-only flag button is left out (it is freed there).
	var row: Control = _shell.get_node("TopBar/Margin/Row") as Control
	var debug_button: Control = row.get_node_or_null("DebugFlagButton") as Control
	var debug_width: float = 0.0
	if debug_button != null:
		debug_width = debug_button.get_combined_minimum_size().x + 12.0
	var needed: float = row.get_combined_minimum_size().x - debug_width + 32.0
	assert_float(needed).is_less_equal(MIN_SIZE.x)
	var readout: Button = _shell.confidence_readout
	assert_float(_text_width(readout, readout.text) + 8.0).is_less_equal(readout.size.x)
	var panel: MonthReportPanel = _shell.month_panel
	assert_float(panel.get_combined_minimum_size().x).is_less_equal(MIN_SIZE.x - 32.0)
	assert_float(panel.get_combined_minimum_size().y).is_less_equal(MIN_SIZE.y - 56.0)
	var notice: Control = _shell.month_notice
	assert_float(notice.get_combined_minimum_size().x).is_less_equal(MIN_SIZE.x - 32.0)
	for button: Button in [_shell.month_notice.get_view_button(), panel.get_close_button()]:
		var label: String = button.tr(button.text)
		assert_float(_text_width(button, label) + 8.0).is_less_equal(button.size.x)


## A report with every cause, the review, months in the red and both warnings.
static func _busiest_report() -> MonthReport:
	var report := MonthReport.blank()
	report.year = 2026
	report.month = 4
	report.people = 12
	report.allocation_k = 3000
	report.upkeep_k = 1270
	report.salaries_k = 905
	report.funds_before_k = -12390
	report.funds_after_k = -11565
	report.confidence_before = 15
	report.confidence_after = 0
	for index: int in report.amounts.size():
		report.amounts[index] = -5
		report.counts[index] = 4
	report.locked_worlds = [&"world_sill", &"world_cairn"]
	report.surveyed_worlds = [&"world_sill"]
	report.review = ConfidenceRules.QUESTIONS
	report.next_allocation_k = 1500
	report.months_in_red = 4
	report.warn_red_months = true
	report.warn_confidence_zero = true
	return report


func _text_width(control: Control, text: String) -> float:
	var font: Font = control.get_theme_font(&"font")
	var font_size: int = control.get_theme_font_size(&"font_size")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _month_end() -> void:
	SimClock.step_ticks(31 * TimeMath.TICKS_PER_DAY)
	await _runner.simulate_frames(2)


func _focus_owner() -> Control:
	return _shell.get_viewport().gui_get_focus_owner()


func _press_joypad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _runner.await_input_processed()
