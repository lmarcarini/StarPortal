## Tests for the team report (M4.9-15): a return opens it by itself and holds the clock, CLOSE
## releases it; with the setting off it waits on the team card, which opens it; a Log return
## row reopens it.
## Bible: docs/content/interface-rethink.md section 4 (Teams come home), issue #478
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const VIEW: PackedScene = preload("res://src/ui/station/gate/gate_station_view.tscn")
const SETTING: StringName = &"auto_open_team_report"

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateStationView = null
var _was_on: bool = true


func before_test() -> void:
	_was_on = Settings.get_bool(&"gameplay", SETTING)
	_simulation = Fixture.simulation()
	SimClock.start(_simulation)
	_holder = Control.new()
	_holder.size = Vector2(1920, 1080)
	_holder.theme = UiThemeBuilder.build(1.0)
	add_child(_holder)
	_view = VIEW.instantiate() as GateStationView
	_holder.add_child(_view)
	_view.setup(_simulation)


func after_test() -> void:
	Settings.set_value(&"gameplay", SETTING, _was_on)
	SimClock.stop()
	_holder.free()


func _return() -> void:
	var summary: Dictionary = {
		"objective": 1, "success": true, "early": false, "team": ["Ana"], "days": 2
	}
	EventBus.team_debrief.emit(Fixture.DialFixture.OPEN_ID, summary)


func test_opens_by_itself_and_holds_the_clock() -> void:
	Settings.set_value(&"gameplay", SETTING, true)
	var opened: Array[bool] = []
	_view.report_opened.connect(func() -> void: opened.append(true))
	_return()
	var report: TeamReportScreen = _view.get_team_report()
	assert_bool(report.visible).is_true()
	assert_array(opened).has_size(1)
	assert_int(SimClock.get_mode()).is_equal(ClockState.Mode.HELD)
	assert_int(report.get_debrief().days).is_equal(2)
	assert_object(report.get_action(&"gate")).is_not_null()
	report.get_close_key().activated.emit()
	assert_bool(report.visible).is_false()
	assert_int(SimClock.get_mode()).is_not_equal(ClockState.Mode.HELD)


func test_setting_off_waits_on_the_team_card() -> void:
	Settings.set_value(&"gameplay", SETTING, false)
	_return()
	var report: TeamReportScreen = _view.get_team_report()
	assert_bool(report.visible).is_false()
	var card: TeamCard = _view.get_team_card()
	assert_bool(card.report_waiting).is_true()
	card.pressed.emit()
	assert_bool(report.visible).is_true()
	assert_bool(card.report_waiting).is_false()
	report.close()


func test_log_return_entry_reopens_it() -> void:
	Settings.set_value(&"gameplay", SETTING, false)
	var details: Dictionary = {
		"reason": "returned", "objective": "survey", "team": "Ana, Ben", "success": true
	}
	var entry: LogEntry = LogEntry.create(10, &"expedition", Fixture.DialFixture.OPEN_ID, details)
	assert_bool(DebriefRules.is_return_entry(entry)).is_true()
	_view.show_log_report(entry)
	var report: TeamReportScreen = _view.get_team_report()
	assert_bool(report.visible).is_true()
	assert_str(report.get_debrief().leader).is_equal("Ana")
	report.close()
