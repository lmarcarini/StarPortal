## Tests for the Expeditions tab: the plan sheet (world, threat, objective, four slots, risk,
## Ready team greyed with the reason, submitted as a command), the team away (timeline, next
## check-in, Recall team), the latest check-in and the past (what came back, who did not),
## refreshing while paused and on showing, the mouse and gamepad paths, availability at the
## unlock, and the layout at 1280 × 720 in en and pt_BR with the real font.
## Bible: docs/content/m3-beyond-the-ring.md section 7
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const RescueFixture := preload("res://tests/expedition/rescue_fixture.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")

const VIEW_SCENE: String = "res://src/ui/views/expeditions/expeditions_view.tscn"
## 720 less the 56 px top bar and the 40 px tab bar.
const VIEW_SIZE: Vector2 = Vector2(1280, 624)
const DAY: int = TimeMath.TICKS_PER_DAY

var _root: Control = null
var _view: ExpeditionsView = null
var _runner: GdUnitSceneRunner = null
var _simulation: Simulation = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_simulation = RescueFixture.simulation(Fixture.state())
	EventBus.bind_simulation(_simulation)
	_root = Control.new()
	_root.size = VIEW_SIZE
	_view = (load(VIEW_SCENE) as PackedScene).instantiate() as ExpeditionsView
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


func _sheet() -> ExpeditionPlanSheet:
	return _view.get_sheet()


## Picks the fixture team in the sheet's slot pickers, as a player would.
func _pick_team() -> void:
	var team: Dictionary = Fixture.team(_state())
	for slot: String in ExpeditionState.SLOTS:
		var picker: OptionButton = _sheet().get_slot_picker(slot)
		for index: int in picker.item_count:
			if picker.get_item_metadata(index) == team[slot]:
				picker.select(index)
				picker.item_selected.emit(index)


func test_sheet_shows_the_world_threat_and_risk_and_refuses_an_empty_team() -> void:
	assert_bool(_view.is_available()).is_true()
	assert_str(String(_sheet().get_draft().world_id)).is_equal(String(Fixture.WORLD_ID))
	var texts: Array[String] = _sheet().texts()
	assert_str(texts[0]).is_equal(ExpeditionText.threat(_state(), Fixture.WORLD_ID))
	assert_str(texts[1]).starts_with("Risk ").ends_with("2 days")
	assert_str(texts[2]).is_equal("A team slot is empty.")
	assert_bool(_sheet().get_ready_button().disabled).is_true()
	var buttons: Array[Button] = _sheet().get_objective_buttons()
	assert_str(buttons[0].text).is_equal("Survey")
	assert_bool(buttons[0].button_pressed).is_true()


func test_slot_rosters_are_filtered_by_role() -> void:
	var soldiers: OptionButton = _sheet().get_slot_picker("soldier")
	assert_int(soldiers.item_count).is_equal(3)
	assert_str(soldiers.get_item_text(1)).is_equal("Maj. Ruth Adair  3")
	var leaders: OptionButton = _sheet().get_slot_picker("leader")
	assert_int(leaders.item_count).is_equal(_state().staff.people.size() + 1)


func test_injured_member_is_refused_with_the_reason() -> void:
	_pick_team()
	assert_bool(_sheet().get_ready_button().disabled).is_false()
	var soldier: PersonState = _state().staff.find_person(_sheet().get_draft().team["soldier"])
	InjuryRules.injure(soldier, PersonState.Injury.LIGHT)
	EventBus.staff_changed.emit(&"injured", &"", 1)
	assert_str(_sheet().texts()[2]).is_equal("A team member is injured.")
	assert_bool(_sheet().get_ready_button().disabled).is_true()


func test_click_ready_team_plans_the_expedition() -> void:
	_pick_team()
	await UiInput.click(_sheet().get_ready_button())
	assert_int(_state().expedition.mode).is_equal(ExpeditionState.Mode.PLANNED)
	assert_str(String(_state().expedition.world_id)).is_equal(String(Fixture.WORLD_ID))
	assert_str(_sheet().texts()[2]).starts_with("Team ready")
	assert_bool(_sheet().get_ready_button().disabled).is_true()


func test_gamepad_path_opens_a_roster_and_y_readies_the_team() -> void:
	var first: Control = _view.get_default_focus()
	assert_object(first).is_same(_sheet().get_world_picker())
	var leader: OptionButton = _sheet().get_slot_picker("leader")
	await UiInput.pad(leader, JOY_BUTTON_A)
	assert_bool(leader.get_popup().visible).is_true()
	leader.get_popup().hide()
	await UiInput.pad(first, JOY_BUTTON_DPAD_DOWN)
	assert_object(_view.get_viewport().gui_get_focus_owner()).is_not_same(first)
	await UiInput.pad(first, JOY_BUTTON_Y)
	assert_int(_state().expedition.mode).is_equal(ExpeditionState.Mode.IDLE)
	_pick_team()
	await UiInput.pad(first, JOY_BUTTON_Y)
	assert_int(_state().expedition.mode).is_equal(ExpeditionState.Mode.PLANNED)


func test_team_away_shows_the_timeline_and_recall() -> void:
	RescueFixture.send(_simulation)
	await UiInput.settle(_view)
	var texts: Array[String] = _view.get_trip().texts()
	var expedition: ExpeditionState = _state().expedition
	assert_str(texts[0]).contains("T-1").contains("Survey")
	var first_check_in: String = ExpeditionText.date(expedition.check_in_ticks()[0])
	assert_str(texts[1]).is_equal("Next check-in " + first_check_in)
	assert_str(texts[2]).contains("Out  ").contains("Check-in  %s  next" % first_check_in)
	assert_str(texts[2]).contains("Return  " + ExpeditionText.date(expedition.check_in_ticks()[1]))
	assert_bool(_sheet().get_world_picker().disabled).is_true()
	var recall: Button = _view.get_trip().get_recall_button()
	assert_bool(recall.is_visible_in_tree()).is_true()
	await UiInput.click(recall)
	assert_bool(expedition.recalled).is_true()
	assert_bool(recall.disabled).is_true()
	assert_str(_view.get_trip().texts()[2]).contains("Recalled")
	_view.recall_team()
	assert_str(_view.get_trip().texts()[4]).is_equal("T-1 is already recalled.")


func test_past_shows_what_came_back_and_who_did_not() -> void:
	assert_str(_view.get_trip().texts()[5]).is_equal("None yet.")
	_state().expedition.add_document("survey_report", Fixture.WORLD_ID, &"", DAY)
	_state().operations_log.entries.append(
		LogEntry.create(
			2 * DAY, &"expedition", Fixture.WORLD_ID, {"reason": "deceased", "name": "Sgt Hale"}
		)
	)
	EventBus.day_started.emit(2)
	var past: String = _view.get_trip().texts()[5]
	assert_str(past).contains("Survey report from").contains("Sgt Hale (T-1) did not survive")
	assert_int(past.find("Sgt Hale")).is_less(past.find("Survey report"))


func test_tab_appears_when_expeditions_unlock() -> void:
	var locked: GameState = Fixture.ProbeFixture.state()
	var simulation: Simulation = Simulation.new(locked)
	_view.setup(simulation)
	assert_bool(_view.is_available()).is_false()
	ExpeditionUnlock.unlock(locked)
	EventBus.soldier_lent.emit(&"person_x")
	assert_bool(_view.is_available()).is_true()


func test_plan_world_chooses_it() -> void:
	_view.plan_world(&"no_such_world")
	assert_str(String(_sheet().get_draft().world_id)).is_equal(String(Fixture.WORLD_ID))
	_view.plan_world(Fixture.WORLD_ID)
	assert_str(String(_sheet().get_draft().world_id)).is_equal(String(Fixture.WORLD_ID))


@warning_ignore("unused_parameter")
func test_fits_the_minimum_window(
	locale: String, test_parameters: Array = [["en"], ["pt_BR"]]  # gdlint: ignore=unused-argument
) -> void:
	TranslationServer.set_locale(locale)
	_pick_team()
	RescueFixture.send(_simulation)
	var member: PersonState = _state().staff.find_person(_state().expedition.member_ids()[2])
	InjuryRules.injure(member, PersonState.Injury.SERIOUS)
	Fixture.advance(_simulation, _state().expedition.next_day_end_tick() - _state().clock.tick + 1)
	_view.refresh()
	await _runner.simulate_frames(2)
	var columns: Control = _view.get_node("Columns") as Control
	var needed: Vector2 = columns.get_combined_minimum_size()
	assert_float(needed.x).is_less_equal(VIEW_SIZE.x - 32)
	assert_float(needed.y).is_less_equal(VIEW_SIZE.y - 16)
	_assert_glyphs(_view)


func _assert_glyphs(node: Node) -> void:
	for child: Node in node.get_children():
		_assert_glyphs(child)
	var text: String = ""
	if node is Label:
		text = (node as Label).text
	elif node is Button:
		text = (node as Button).text
	if text.is_empty():
		return
	var control: Control = node as Control
	var font: Font = control.get_theme_font(&"font")
	for character: String in control.tr(text) if control.auto_translate_mode != 2 else text:
		if character == "\n":
			continue
		(
			assert_bool(font.has_char(character.unicode_at(0)))
			. override_failure_message("missing glyph '%s' in '%s'" % [character, text])
			. is_true()
		)
