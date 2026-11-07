## Tests for the Personnel tab: the header, roster and candidate rows, hire, dismiss (hold),
## assign and unassign through the commands with refusals shown plainly, the Assign… list
## with its effect, refreshing while paused and on showing, the D-pad, (A), (B), (Y) and the
## shoulders, the new-candidate dot and "Leaves in",
## and the layout at 1280 × 720 in en and pt_BR with the real fonts.
## Bible: docs/content/m26-staff-and-money.md section 6
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/personnel/personnel_view.tscn"
const VIEW_SIZE: Vector2 = Vector2(1280, 680)

var _root: Control = null
var _view: PersonnelView = null
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
	_view = (load(VIEW_SCENE) as PackedScene).instantiate() as PersonnelView
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


func _rows() -> Array[PersonnelRow]:
	return _view.get_board().rows()


func test_roster_and_header_from_the_start() -> void:
	var board: PersonnelBoard = _view.get_board()
	assert_array(board.header()).is_equal(["PERSONNEL", "Staff 5 · Beds 5/6 · Salaries $5k a day"])
	assert_array(board.tab_titles()).is_equal(["Roster", "Candidates (4)"])
	assert_int(_rows().size()).is_equal(5)
	var first: Array[String] = _rows()[0].texts()
	assert_str(first[1]).is_equal("Scientist")
	assert_str(first[2]).is_equal("***")
	assert_str(first[3]).is_equal("$30k / 30 d")
	assert_str(first[4]).is_equal("Research Lab (Level 1)")
	assert_str(_rows()[0].labels()[2].tooltip_text).is_equal("Skill 3")
	var where: Array[String] = []
	for row: PersonnelRow in _rows():
		where.append(row.texts()[4])
	assert_bool(where.has("Unassigned")).is_true()


func test_candidates_show_fee_and_arrival() -> void:
	_view.get_board().show_page(PersonnelBoard.Page.CANDIDATES)
	assert_int(_rows().size()).is_equal(4)
	assert_str(_rows()[0].texts()[0]).is_equal("Dr Ines Moreau")
	assert_str(_rows()[0].texts()[4]).is_equal(
		"Leaves in 3 d · Academia · Fee: 30 days' pay ($30k) · arrives in 5 d"
	)


## A new candidate puts a dot on the Candidates sub-tab while paused, until it is shown; the
## countdown follows the day (docs/content/m27-daily-rhythm.md section 3).
func test_new_candidate_dot_and_countdown() -> void:
	var board: PersonnelBoard = _view.get_board()
	_state().clock.tick = 3 * TimeMath.TICKS_PER_DAY
	var defs: GameDefs = GameDefs.from_registry(Registry)
	RecruitmentSystem.new(defs.balance, defs.roles, defs.staff_names).on_day(_state())
	_state().events.drain()
	EventBus.candidates_changed.emit()
	assert_array(board.tab_titles()).is_equal(["Roster", "Candidates (4) •"])
	assert_str(_view.get_tab_title()).is_equal("Personnel •")
	var titles: Array[int] = [0]
	_view.title_changed.connect(func() -> void: titles[0] += 1)
	board.show_page(PersonnelBoard.Page.CANDIDATES)
	assert_array(board.tab_titles()).is_equal(["Roster", "Candidates (4)"])
	assert_str(_view.get_tab_title()).is_equal("Personnel")
	assert_int(titles[0]).is_equal(1)
	assert_str(_rows()[0].texts()[4]).starts_with("Leaves in 3 d · ")
	assert_str(_rows()[3].texts()[4]).starts_with("Leaves in 12 d · ")


func test_hire_then_no_free_bed_is_shown_plainly() -> void:
	_view.get_board().show_page(PersonnelBoard.Page.CANDIDATES)
	_rows()[0].grab_focus()
	var hire: Button = _view.get_panel().get_hire_button()
	assert_bool(hire.visible and not hire.disabled).is_true()
	assert_str(hire.text).is_equal("Hire (fee $30k)")
	hire.pressed.emit()
	assert_int(_state().staff.people.size()).is_equal(6)
	assert_int(_rows().size()).is_equal(3)
	assert_str(_view.get_board().header()[1]).contains("Beds 6/6")
	_rows()[0].grab_focus()
	hire = _view.get_panel().get_hire_button()
	assert_bool(hire.disabled).is_true()
	_view.hire(_rows()[0].id)
	assert_int(_state().staff.people.size()).is_equal(6)
	assert_str(_view.get_panel().lines()[5]).is_equal("No free bed. Build Quarters.")


func test_hired_person_shows_arriving_then_arrives_while_paused() -> void:
	_view.hire(&"candidate_3")
	_view.get_board().show_page(PersonnelBoard.Page.ROSTER)
	assert_str(_rows()[5].texts()[4]).is_equal("Arriving in 3 d")
	_state().clock.tick += 3 * TimeMath.TICKS_PER_DAY
	EventBus.staff_arrived.emit(&"person_6")
	assert_str(_rows()[5].texts()[4]).is_equal("Unassigned")


func test_hire_while_running_says_requested_until_applied() -> void:
	_state().clock.is_paused = false
	_view.get_board().show_page(PersonnelBoard.Page.CANDIDATES)
	_rows()[0].grab_focus()
	_view.hire(_rows()[0].id)
	assert_int(_state().staff.people.size()).is_equal(5)
	assert_str(_view.get_panel().lines()[5]).is_equal("Requested. It happens on the next tick.")
	_simulation.advance_tick()
	assert_int(_state().staff.people.size()).is_equal(6)
	assert_str(_view.get_panel().lines()[5]).is_equal("Hired. On the way.")


func test_dismiss_is_a_hold_button() -> void:
	_rows()[4].grab_focus()
	var id: StringName = _rows()[4].id
	var dismiss: Button = _view.get_panel().get_dismiss_button()
	assert_bool(dismiss is HoldButton).is_true()
	assert_str(dismiss.text).is_equal("Dismiss (hold)")
	(dismiss as HoldButton).begin_hold()
	(dismiss as HoldButton).advance(HoldButton.HOLD_SECONDS + 0.1)
	assert_object(_state().staff.find_person(id)).is_null()
	assert_int(_rows().size()).is_equal(4)
	assert_str(_view.get_panel().lines()[5]).is_equal("Dismissed.")


func test_assign_lists_rooms_with_effect_then_unassign() -> void:
	var lab: RoomState = PowerFixture.first_room(_state(), ResearchRules.LAB_DEF)
	var person: PersonState = _new_scientist(2)
	_view.refresh()
	var row: PersonnelRow = _view.get_board().row_of(person.id)
	row.grab_focus()
	_view._on_activated(person.id)
	var panel: PersonnelPanel = _view.get_panel()
	assert_bool(panel.is_picking()).is_true()
	var picks: Array[Button] = panel.room_buttons()
	assert_int(picks.size()).is_equal(2)
	assert_str(picks[0].text).is_equal("Research Lab (Level 1): 2/4 · speed 100% to 133%")
	assert_str(picks[1].text).is_equal("Back")
	picks[0].pressed.emit()
	assert_str(person.room_id).is_equal(lab.id)
	assert_bool(panel.is_picking()).is_false()
	_view.get_board().row_of(person.id).grab_focus()
	var unassign: Button = panel.buttons()[1]
	assert_bool(unassign.visible).is_true()
	unassign.pressed.emit()
	assert_bool(person.is_assigned()).is_false()


func test_full_room_is_not_offered_and_refusal_is_plain() -> void:
	var lab: RoomState = PowerFixture.first_room(_state(), ResearchRules.LAB_DEF)
	StaffFixture.scientists(_state(), lab, [1, 1])
	var person: PersonState = _new_scientist(3)
	_view.refresh()
	_view.get_board().row_of(person.id).grab_focus()
	var panel: PersonnelPanel = _view.get_panel()
	assert_bool(panel.buttons()[0].disabled).is_true()
	assert_str(panel.lines()[5]).is_equal("No room has a free slot for this role.")
	_view.assign(person.id, lab.id)
	assert_str(panel.lines()[5]).is_equal("The room is full.")


func test_b_backs_out_and_y_toggles_pages() -> void:
	var person: PersonState = _new_scientist(2)
	_view.refresh()
	_view.get_board().row_of(person.id).grab_focus()
	_view._on_activated(person.id)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	_view._unhandled_input(cancel)
	assert_bool(_view.get_panel().is_picking()).is_false()
	assert_object(_root.get_viewport().gui_get_focus_owner()).is_same(
		_view.get_board().row_of(person.id)
	)
	var y := InputEventJoypadButton.new()
	y.button_index = JOY_BUTTON_Y
	y.pressed = true
	_view._unhandled_input(y)
	assert_int(_view.get_board().get_page()).is_equal(PersonnelBoard.Page.CANDIDATES)
	_view._unhandled_input(y)
	assert_int(_view.get_board().get_page()).is_equal(PersonnelBoard.Page.ROSTER)


func test_refreshes_while_paused_and_on_showing() -> void:
	_view.visible = false
	var person: PersonState = _new_scientist(2)
	_state().clock.tick += 1
	EventBus.tick_advanced.emit(_state().clock.tick)
	_view.visible = true
	assert_object(_view.get_board().row_of(person.id)).is_not_null()
	_state().budget.funds_k = 0
	EventBus.budget_changed.emit(0)
	_view.get_board().show_page(PersonnelBoard.Page.CANDIDATES)
	_rows()[0].grab_focus()
	assert_bool(_view.get_panel().get_hire_button().disabled).is_true()


func test_layout_fits_in_both_languages() -> void:
	_view.hire(&"candidate_3")
	for locale: String in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		for page: PersonnelBoard.Page in [
			PersonnelBoard.Page.ROSTER, PersonnelBoard.Page.CANDIDATES
		]:
			_view.get_board().show_page(page)
			_rows()[0].grab_focus()
			await _runner.simulate_frames(2)
			var columns: Control = _view.get_node("Columns") as Control
			var needed: Vector2 = columns.get_combined_minimum_size()
			assert_bool(needed.x <= VIEW_SIZE.x - 32 and needed.y <= VIEW_SIZE.y).is_true()
			for row: PersonnelRow in _rows():
				_assert_row_fits(row, locale)


func _assert_row_fits(row: PersonnelRow, locale: String) -> void:
	for label: Label in row.labels():
		var font: Font = label.get_theme_font(&"font")
		var font_size: int = label.get_theme_font_size(&"font_size")
		for character: String in label.text:
			assert_bool(font.has_char(character.unicode_at(0))).is_true()
		var width: float = font.get_string_size(label.text, 0, -1, font_size).x
		(
			assert_float(width)
			. override_failure_message(
				"%s: '%s' is cut (%.0f > %.0f)" % [locale, label.text, width, label.size.x]
			)
			. is_less_equal(label.size.x)
		)


func _new_scientist(skill: int) -> PersonState:
	var person := PersonState.new()
	person.name = "Dr Test Person"
	person.role = StartingStaff.SCIENTIST
	person.skill = skill
	person.salary_k = 25
	_state().staff.add_person(person)
	return person
