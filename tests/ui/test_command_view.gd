## Tests for the Command tab: every figure read from the state, refreshing while paused on
## events and on showing, the money line breakdown by (A), click and hover with (B) closing it,
## the D-pad along the rows with the causes scrolling, and the worst case (10 money lines, 2
## visible causes, both warnings) fitting 1280 × 720 in en and pt_BR with the real font.
## Bible: docs/content/m27-daily-rhythm.md section 4
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/command/command_view.tscn"
## 720 less the 56 px top bar and the 40 px tab bar.
const VIEW_SIZE: Vector2 = Vector2(1280, 624)

var _root: Control = null
var _view: CommandView = null
var _runner: GdUnitSceneRunner = null
var _simulation: Simulation = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var state: GameState = ResearchFixture.state()
	state.clock.is_paused = true
	_simulation = Simulation.new(state)
	EventBus.bind_simulation(_simulation)
	_root = Control.new()
	_root.size = VIEW_SIZE
	_view = (load(VIEW_SCENE) as PackedScene).instantiate() as CommandView
	_view.size = VIEW_SIZE
	_root.add_child(_view)
	_runner = scene_runner(_root)
	_view.setup(_simulation)
	await _runner.simulate_frames(2)


func after_test() -> void:
	EventBus.bind_simulation(null)
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.set_locale(_real_locale)


func _state() -> GameState:
	return _simulation.state


func _board() -> CommandBoard:
	return _view.get_board()


func test_shows_figures_from_the_state() -> void:
	var texts: Array[String] = _board().texts()
	assert_str(texts[0]).is_equal("COMMAND")
	assert_str(texts[1]).is_equal(CommandText.funds_line(_state()))
	assert_str(texts[2]).is_equal("Conf. 50.0")
	var rows: Array[CommandRow] = _board().line_rows()
	assert_int(rows.size()).is_equal(_board().lines().size())
	assert_array(rows[0].texts()).is_equal(["Allocation (Conf. 50)", "+100", "+3,000"])
	assert_str(rows[rows.size() - 1].texts()[0]).is_equal("Net")
	assert_array(_board().warning_texts()).is_equal(["none"])
	assert_array(_board().cause_rows()).is_empty()
	assert_array(_view.get_panel().texts()).is_equal(
		["COMMITTEE", "Confidence 50.0", "Today 0: steady at 50", "Commendation", "At 70: $1,000k"]
	)


func test_refreshes_while_paused_on_events_and_on_showing() -> void:
	_state().budget.funds_k = 4125
	_state().committee.confidence = 614
	EventBus.confidence_changed.emit(614)
	assert_str(_board().texts()[2]).is_equal("Conf. 61.4")
	assert_str(_board().texts()[1]).starts_with("Funds $4,125k")
	assert_str(_view.get_panel().texts()[2]).is_equal("Today -0.1: settling toward 50")
	_view.visible = false
	_state().committee.add_funds_record(4125)
	_state().committee.add_cause(
		ConfidenceCause.create(0, ConfidenceRules.RESEARCH, &"", Vector2i(1, 30))
	)
	_view.visible = true
	assert_array(_board().get_sparkline().get_balances()).is_equal([4125])
	assert_int(_board().cause_rows().size()).is_equal(1)
	assert_str(_board().cause_rows()[0].texts()[0]).starts_with("1 Jan  Research finished")


func test_a_opens_breakdown_b_closes_and_click_and_hover_do_the_same() -> void:
	var rows: Array[CommandRow] = _board().line_rows()
	var salaries: int = _index_of(CommandLine.Kind.SALARIES)
	rows[salaries].grab_focus()
	await _press_joypad(JOY_BUTTON_A)
	var panel: CommandPanel = _view.get_panel()
	assert_bool(panel.is_breakdown()).is_true()
	assert_int(panel.texts().size()).is_equal(1 + _state().staff.people.size())
	assert_str(panel.texts()[1]).contains(_state().staff.people[0].name)
	await _press_joypad(JOY_BUTTON_B)
	assert_bool(panel.is_breakdown()).is_false()
	assert_object(_root.get_viewport().gui_get_focus_owner()).is_same(rows[salaries])
	var room: int = _index_of(CommandLine.Kind.ROOM_TYPE)
	await _click(rows[room])
	assert_bool(panel.is_breakdown()).is_true()
	assert_str(panel.texts()[0]).is_equal(rows[room].texts()[0])
	assert_str(rows[room].tooltip_text).is_equal("\n".join(panel.texts().slice(1)))


func test_d_pad_moves_along_rows_and_causes_scroll() -> void:
	_add_causes(10)
	_view.refresh()
	await _runner.simulate_frames(2)
	var chain: Array[CommandRow] = _board().line_rows()
	chain.append_array(_board().cause_rows())
	assert_int(_board().cause_rows().size()).is_equal(10)
	chain[0].grab_focus()
	for index: int in range(1, chain.size()):
		await _press_action(&"ui_down")
		assert_object(_root.get_viewport().gui_get_focus_owner()).is_same(chain[index])
	await _runner.simulate_frames(2)
	var last: CommandRow = chain[chain.size() - 1]
	var scroll: ScrollContainer = last.get_parent().get_parent() as ScrollContainer
	assert_int(scroll.scroll_vertical).is_greater(0)
	await _press_action(&"ui_up")
	assert_object(_root.get_viewport().gui_get_focus_owner()).is_same(chain[chain.size() - 2])


func test_worst_case_fits_in_both_languages() -> void:
	_add_room_types()
	_add_causes(10)
	_state().committee.confidence = 0
	_state().committee.days_in_red = 7
	_state().budget.funds_k = -1234567
	for locale: String in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		_view.refresh()
		await _runner.simulate_frames(2)
		assert_int(_board().lines().size()).is_equal(10)
		assert_int(_board().warning_texts().size()).is_equal(2)
		var columns: Control = _view.get_node("Columns") as Control
		var needed: Vector2 = columns.get_combined_minimum_size()
		assert_float(needed.x).is_less_equal(VIEW_SIZE.x - 32)
		assert_float(needed.y).is_less_equal(VIEW_SIZE.y - 16)
		for label: Label in _board().all_labels():
			_assert_fits(label, locale)


func _add_room_types() -> void:
	var index: int = 0
	for def_id: StringName in _state().room_defs:
		var room := RoomState.new()
		room.id = StringName("test_room_%d" % index)
		room.def_id = def_id
		room.origin = Vector2i(100 + index * 10, 0)
		_state().base.rooms.append(room)
		index += 1
	assert_int(CommandLedger.lines(_state()).size()).is_equal(10)


func _assert_fits(label: Label, locale: String) -> void:
	if not label.is_visible_in_tree() or label.text.is_empty():
		return
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	for character: String in label.text:
		(
			assert_bool(font.has_char(character.unicode_at(0)))
			. override_failure_message("%s: no glyph for '%s'" % [locale, character])
			. is_true()
		)
	var width: float = font.get_string_size(label.text, 0, -1, font_size).x
	(
		assert_float(width)
		. override_failure_message(
			"%s: '%s' is cut (%.0f > %.0f)" % [locale, label.text, width, label.size.x]
		)
		. is_less_equal(label.size.x + 0.5)
	)


func _add_causes(count: int) -> void:
	for index: int in count:
		_state().committee.add_cause(
			ConfidenceCause.create(
				index * TimeMath.TICKS_PER_DAY, ConfidenceRules.REPORTS, &"", Vector2i(3, 30)
			)
		)


func _index_of(kind: CommandLine.Kind) -> int:
	var lines: Array[CommandLine] = _board().lines()
	for index: int in lines.size():
		if lines[index].kind == kind:
			return index
	return -1


func _press_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await _runner.simulate_frames(2)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await _runner.simulate_frames(1)


func _press_joypad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await _runner.simulate_frames(2)
	event = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = false
	Input.parse_input_event(event)
	await _runner.simulate_frames(1)


## Clicks the left mouse button over the centre of [param control].
func _click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		control.get_viewport().push_input(event, true)
	await _runner.simulate_frames(2)
