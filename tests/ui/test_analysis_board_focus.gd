## Tests for the Analysis Board's command counts and keyboard and gamepad focus: one command
## per link, no command for a move that ends in place, Tab order, and focus kept in the panel.
## Bible: gate-and-address-spec.md#player-tools,
## game-design.md#difficulty-and-accessibility
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/fixtures/board_fixture.gd")
const BOARD_SCENE: String = "res://src/ui/analysis/board/analysis_board.tscn"
const FIRST: StringName = &"clue_0001"
const SECOND: StringName = &"clue_0002"
const THIRD: StringName = &"clue_0003"

var _translation: Translation = null
var _real_locale: String = ""
var _simulation: Simulation = null
var _board: AnalysisBoard = null


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_translation = Fixture.add_translation()
	await _open(Fixture.state(5))


func after_test() -> void:
	if is_instance_valid(_board):
		_board.free()
	EventBus.bind_simulation(null)
	Fixture.remove_translation(_translation)
	TranslationServer.set_locale(_real_locale)
	CommandFactory.reset()


func _open(game_state: GameState) -> void:
	_simulation = Fixture.simulation(game_state)
	if is_instance_valid(_board):
		_board.free()
	_board = (load(BOARD_SCENE) as PackedScene).instantiate() as AnalysisBoard
	_board.size = Vector2(1000, 700)
	add_child(_board)
	_board.setup(_simulation)
	await await_idle_frame()


func _note(clue_id: StringName) -> ClueNote:
	return _simulation.state.intel.note_for(clue_id)


## Presses a UI action on [param target] the way the focus system hands it over.
func _press(target: Control, action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	target._gui_input(event)


func _accept(clue_id: StringName) -> void:
	var card: ClueCard = _board.get_card(clue_id)
	card.grab_focus()
	_press(card, &"ui_accept")


func _button(parent: Node, key: String) -> Button:
	for node: Node in parent.find_children("*", "Button", true, false):
		if (node as Button).text == key:
			return node as Button
	return null


## Linking is one command, on the first card's note; linking the pair again changes nothing.
func test_link_is_one_command() -> void:
	var changes: Array[StringName] = []
	EventBus.clue_note_changed.connect(func(id: StringName) -> void: changes.append(id))
	_accept(FIRST)
	_board.get_detail().get_link_button().pressed.emit()
	_accept(SECOND)
	assert_array(changes).is_equal([FIRST])
	_accept(SECOND)
	_board.get_detail().get_link_button().pressed.emit()
	_accept(FIRST)
	assert_array(changes).is_equal([FIRST])


## A move that ends where it started submits nothing.
func test_move_that_ends_in_place_submits_nothing() -> void:
	var changes: Array[StringName] = []
	EventBus.clue_note_changed.connect(func(id: StringName) -> void: changes.append(id))
	var card: ClueCard = _board.get_card(SECOND)
	_accept(SECOND)
	_board.get_detail().get_move_button().pressed.emit()
	_press(card, &"ui_right")
	_press(card, &"ui_left")
	_press(card, &"ui_accept")
	assert_array(changes).is_empty()
	assert_int(_board.get_mode()).is_equal(AnalysisBoard.Mode.BROWSE)


## Tab (focus_next) walks the cards in arrival order.
func test_focus_next_walks_cards_in_arrival_order() -> void:
	var ids: Array[StringName] = _board.get_card_ids()
	for index: int in ids.size() - 1:
		var next: Control = _board.get_card(ids[index]).find_next_valid_focus()
		assert_object(next).is_same(_board.get_card(ids[index + 1]))


## After removing a tag by keyboard or gamepad, focus moves to the next chip, then the
## previous one, then the tag field: never nowhere.
func test_focus_survives_removing_tags() -> void:
	_accept(FIRST)
	var detail: ClueDetail = _board.get_detail()
	var edit: LineEdit = detail.get_tag_edit()
	for tag: String in ["a", "b"]:
		edit.text = tag
		edit.text_submitted.emit(tag)
	var first_chip: Button = _button(detail, "a ×")
	first_chip.grab_focus()
	first_chip.pressed.emit()
	await await_idle_frame()
	var owner_now: Button = get_viewport().gui_get_focus_owner() as Button
	assert_object(owner_now).is_same(_button(detail, "b ×"))
	owner_now.pressed.emit()
	await await_idle_frame()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(edit)


## After unlinking, focus stays inside the panel.
func test_focus_survives_unlinking() -> void:
	_accept(FIRST)
	_board.get_detail().get_link_button().pressed.emit()
	_accept(SECOND)
	_accept(FIRST)
	var detail: ClueDetail = _board.get_detail()
	var unlink: Button = _button(detail, "BOARD_UNLINK")
	unlink.grab_focus()
	unlink.pressed.emit()
	await await_idle_frame()
	var owner_now: Control = get_viewport().gui_get_focus_owner()
	assert_object(owner_now).is_not_null()
	assert_bool(detail.is_ancestor_of(owner_now)).is_true()
