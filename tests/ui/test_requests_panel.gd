## Tests for the Command tab's Requests sub-tab (M4-16): groups with status lines, objective
## marks, previews (hidden as "?"), Accept and Decline submitting commands, and "(!)" on the
## tab title until the offer is seen.
## Bible: docs/content/m4-core-systems.md section 4
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/command/command_view.tscn"
const REQUEST: StringName = &"request_survey"

var _state: GameState
var _simulation: Simulation
var _root: Control
var _view: CommandView


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = StoryFixture.state()
	var def := RequestDef.new()
	def.id = REQUEST
	def.offer_days = 2
	def.deadline_days = 5
	var flag := FlagIsCondition.new()
	flag.flag = &"surveyed"
	def.objective.append(flag)
	var money := ChangeMoneyEffect.new()
	money.amount_k = 500
	var secret := ChangeStandingEffect.new()
	secret.hidden = true
	def.reward = [money, secret]
	_state.request_defs[REQUEST] = def
	_simulation = Simulation.new(_state, [RequestSystem.new()])
	EventBus.bind_simulation(_simulation)
	_root = Control.new()
	_root.size = Vector2(1280, 624)
	_view = (load(VIEW_SCENE) as PackedScene).instantiate() as CommandView
	_view.size = _root.size
	_root.add_child(_view)
	add_child(_root)
	_view.setup(_simulation)


func after_test() -> void:
	EventBus.bind_simulation(null)
	_root.free()


func _panel() -> RequestsPanel:
	return _view.get_requests()


func test_offer_shows_and_marks_the_tab() -> void:
	StoryRulesItems.offer_request(_state, REQUEST)
	assert_bool(_view.has_new_offer()).is_true()
	assert_str(_view.get_tab_title()).ends_with("(!)")
	_view.get_requests_button().pressed.emit()
	assert_bool(_view.has_new_offer()).is_false()
	assert_bool(_panel().visible).is_true()
	var rows: Array[Button] = _panel().get_rows()
	assert_int(rows.size()).is_equal(1)
	assert_str(rows[0].text).contains("Offer ends in 2 days")
	var detail: String = _panel().get_detail_text()
	assert_str(detail).contains("[ ] Requires an earlier event")
	assert_str(detail).contains("Reward: ")
	assert_str(detail).contains(", ?")
	assert_bool(_panel().get_accept_button().visible).is_true()


func test_accept_and_decline() -> void:
	StoryRulesItems.offer_request(_state, REQUEST)
	_view.show_requests(true)
	_panel().get_accept_button().pressed.emit()
	assert_int(_state.requests.items[0].state).is_equal(RequestRecord.RequestState.ACTIVE)
	assert_str(_panel().get_detail_text()).contains("5 days left")
	assert_bool(_panel().get_accept_button().visible).is_false()
	_state.flags[&"surveyed"] = true
	_panel().refresh()
	assert_str(_panel().get_detail_text()).contains("[x] ")
	RequestRules.check_all(_state)
	_state.requests.items.clear()
	_state.requests.next_uid = 5
	StoryRulesItems.offer_request(_state, REQUEST)
	_panel().refresh()
	_panel().select(5)
	_panel().get_decline_button().pressed.emit()
	assert_int(_state.requests.items[0].state).is_equal(RequestRecord.RequestState.DECLINED)
	assert_str(_panel().get_rows()[0].text).contains("Declined")


func test_overview_is_back_by_default() -> void:
	_view.show_requests(true)
	_view.show_requests(false)
	assert_bool(_panel().visible).is_false()
	assert_bool(_view.get_board().visible).is_true()
