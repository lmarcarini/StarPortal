## Tests for the Analysis Board: five cards with the right text, picture, grade and source;
## move, link, unlink, tag, filter and suspect through commands, with the gamepad and keyboard
## path (focus and UI actions, no mouse) and the mouse drag; saving and loading; the redraw
## rules; and a frame-time check with 60 cards.
## Bible: gate-and-address-spec.md#player-tools,
## game-design.md#difficulty-and-accessibility
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/fixtures/board_fixture.gd")
const BOARD_SCENE: String = "res://src/ui/analysis/board/analysis_board.tscn"
const BOARD_DIR: String = "res://src/ui/analysis/board"
const FIRST: StringName = &"clue_0001"
const SECOND: StringName = &"clue_0002"
const THIRD: StringName = &"clue_0003"
const FRAME_COUNT: int = 5

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


## One clue of each kind: five cards with the clue text, source, grade letter, date and a
## picture for the clues that have one.
func test_five_kinds_show_five_cards_with_text_grade_and_image() -> void:
	assert_array(_board.get_card_ids()).has_size(5)
	var texts: Array[String] = [
		"Glyph Heron at seal 2",
		"A sketch: A tall bird with a long curved neck, standing on a single thin leg.",
		"Sky of P3X-118: 7 stars",
		"Seal 3 holds Anvil",
		"Heron sits next to Anvil",
	]
	var images: Array[bool] = [false, true, true, false, false]
	for index: int in 5:
		var card: ClueCard = _board.get_card(_board.get_card_ids()[index])
		assert_str(card.get_clue_text()).is_equal(texts[index])
		assert_str(card.get_grade_text()).is_equal("ABCDE"[index])
		assert_str(card.get_source_text()).is_equal("Test Source")
		assert_bool(card.has_image()).is_equal(images[index])
		assert_bool(card.shows_suspect()).is_false()
	assert_str(_board.get_card(FIRST).get_date_text()).is_equal("2026-01-02")


## The cards sit on the grid in arrival order and the board is wide enough to scroll to them.
func test_cards_take_grid_cells_in_arrival_order() -> void:
	for index: int in 5:
		var card: ClueCard = _board.get_card(_board.get_card_ids()[index])
		assert_object(card.position).is_equal(Vector2(BoardLayout.cell_origin(index)))
	assert_bool(_board.get_card(FIRST).focus_mode == Control.FOCUS_ALL).is_true()


## Suspect without a mouse: focus a card, Accept opens it, the panel's button marks it, and
## the card shows the word and a thicker border.
func test_suspect_by_focus_and_accept() -> void:
	_accept(SECOND)
	var detail: ClueDetail = _board.get_detail()
	assert_bool(detail.visible).is_true()
	assert_str(String(detail.get_clue_id())).is_equal(String(SECOND))
	assert_str(detail.get_clue_text()).is_equal(
		"A sketch: A tall bird with a long curved neck, standing on a single thin leg."
	)
	assert_str(detail.get_grade_text()).is_equal("B")
	detail.get_suspect_button().pressed.emit()
	assert_bool(_note(SECOND).is_suspect).is_true()
	var card: ClueCard = _board.get_card(SECOND)
	assert_bool(card.shows_suspect()).is_true()
	assert_object(card.get_theme_stylebox(&"panel")).is_same(card.suspect_style)
	detail.get_suspect_button().pressed.emit()
	assert_bool(_note(SECOND).is_suspect).is_false()
	assert_object(card.get_theme_stylebox(&"panel")).is_same(card.normal_style)


## Move without a mouse: the panel's Move button, the arrows, then Accept submits once.
func test_move_with_arrows_submits_on_accept() -> void:
	var card: ClueCard = _board.get_card(THIRD)
	var start: Vector2 = card.position
	_accept(THIRD)
	_board.get_detail().get_move_button().pressed.emit()
	assert_int(_board.get_mode()).is_equal(AnalysisBoard.Mode.MOVE)
	assert_bool(card.has_focus()).is_true()
	for action: StringName in [&"ui_right", &"ui_right", &"ui_down"]:
		_press(card, action)
	var step: Vector2 = Vector2(BoardLayout.NUDGE_STEP, BoardLayout.NUDGE_STEP)
	assert_object(card.position).is_equal(start + Vector2(2.0, 1.0) * step)
	assert_bool(_note(THIRD).is_default()).is_true()
	var moves: Array[StringName] = []
	EventBus.clue_note_changed.connect(func(id: StringName) -> void: moves.append(id))
	_press(card, &"ui_accept")
	assert_array(moves).is_equal([THIRD])
	assert_object(_note(THIRD).board_position).is_equal(Vector2i(start + Vector2(2.0, 1.0) * step))
	assert_int(_board.get_mode()).is_equal(AnalysisBoard.Mode.BROWSE)
	assert_object(card.position).is_equal(start + Vector2(2.0, 1.0) * step)


## Cancel in move mode puts the card back and submits nothing.
func test_cancel_move_restores_the_card() -> void:
	var card: ClueCard = _board.get_card(SECOND)
	var start: Vector2 = card.position
	_accept(SECOND)
	_board.get_detail().get_move_button().pressed.emit()
	_press(card, &"ui_left")
	_press(card, &"ui_cancel")
	assert_object(card.position).is_equal(start)
	assert_bool(_note(SECOND).is_default()).is_true()
	assert_int(_board.get_mode()).is_equal(AnalysisBoard.Mode.BROWSE)


## A mouse drag moves the card and submits once, on drop; a click opens the panel.
func test_mouse_drag_and_click() -> void:
	var card: ClueCard = _board.get_card(FIRST)
	var start: Vector2 = card.position
	_mouse_button(card, true)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(60, 40)
	card._gui_input(motion)
	assert_bool(_note(FIRST).is_default()).is_true()
	_mouse_button(card, false)
	assert_object(_note(FIRST).board_position).is_equal(Vector2i(start + Vector2(60, 40)))
	assert_bool(_board.get_detail().visible).is_false()
	_mouse_button(card, true)
	_mouse_button(card, false)
	assert_bool(_board.get_detail().visible).is_true()


func _mouse_button(card: ClueCard, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	card._gui_input(event)


## Link without a mouse: pick card A, choose Link, pick card B. Both cards hold the link and
## one string is drawn; unlinking from the panel removes it from both.
func test_link_and_unlink_without_a_mouse() -> void:
	_accept(FIRST)
	_board.get_detail().get_link_button().pressed.emit()
	assert_int(_board.get_mode()).is_equal(AnalysisBoard.Mode.LINK)
	_accept(THIRD)
	assert_int(_board.get_mode()).is_equal(AnalysisBoard.Mode.BROWSE)
	assert_array(_note(FIRST).links).is_equal([THIRD])
	assert_array(_note(THIRD).links).is_equal([FIRST])
	assert_int(_board.get_link_layer().get_segments().size()).is_equal(2)
	_accept(FIRST)
	assert_array(_board.get_detail().get_link_ids()).is_equal([THIRD])
	var unlink: Button = _button(_board.get_detail(), "BOARD_UNLINK")
	assert_object(unlink).is_not_null()
	unlink.pressed.emit()
	assert_array(_note(FIRST).links).is_empty()
	assert_array(_note(THIRD).links).is_empty()
	assert_int(_board.get_link_layer().get_segments().size()).is_equal(0)


## Picking the same card again leaves link mode without a link.
func test_link_mode_can_be_left() -> void:
	_accept(FIRST)
	_board.get_detail().get_link_button().pressed.emit()
	_accept(FIRST)
	assert_int(_board.get_mode()).is_equal(AnalysisBoard.Mode.BROWSE)
	assert_array(_note(FIRST).links).is_empty()


## Tags are added and removed in the panel; a filter then shows only the cards with a tag.
func test_tags_and_filter() -> void:
	_accept(FIRST)
	var edit: LineEdit = _board.get_detail().get_tag_edit()
	edit.text = "  water  "
	edit.text_submitted.emit(edit.text)
	_accept(SECOND)
	edit.text = "water"
	edit.text_submitted.emit(edit.text)
	_accept(THIRD)
	edit.text = "ruins"
	edit.text_submitted.emit(edit.text)
	assert_array(_note(FIRST).tags).is_equal(["water"])
	assert_array(_board.get_card(THIRD).get_chip_texts()).is_equal(["ruins"])
	var filter: OptionButton = _board.get_filter_button()
	assert_int(filter.item_count).is_equal(3)
	assert_str(filter.get_item_text(0)).is_equal("All tags")
	filter.select(1)
	filter.item_selected.emit(1)
	var shown: Array[StringName] = []
	for clue_id: StringName in _board.get_card_ids():
		if _board.get_card(clue_id).visible:
			shown.append(clue_id)
	assert_array(shown).is_equal([THIRD])
	filter.select(0)
	filter.item_selected.emit(0)
	assert_bool(_board.get_card(FIRST).visible).is_true()
	_accept(SECOND)
	var remove: Button = _button(_board.get_detail(), "water ×")
	assert_object(remove).is_not_null()
	remove.pressed.emit()
	assert_array(_note(SECOND).tags).is_empty()


## An invalid or repeated tag submits nothing.
func test_bad_tags_are_ignored() -> void:
	_accept(FIRST)
	var edit: LineEdit = _board.get_detail().get_tag_edit()
	edit.text = "   "
	edit.text_submitted.emit(edit.text)
	assert_bool(_note(FIRST).is_default()).is_true()
	edit.text = "one"
	edit.text_submitted.emit(edit.text)
	var count: Array[int] = [0]
	EventBus.clue_note_changed.connect(func(_id: StringName) -> void: count[0] += 1)
	edit.text = "one"
	edit.text_submitted.emit(edit.text)
	assert_int(count[0]).is_equal(0)


## Every change survives a save and a load: a new board over the loaded state shows it all.
func test_notes_survive_save_and_load() -> void:
	_accept(FIRST)
	_board.get_detail().get_suspect_button().pressed.emit()
	var edit: LineEdit = _board.get_detail().get_tag_edit()
	edit.text = "keep"
	edit.text_submitted.emit(edit.text)
	_board.get_detail().get_move_button().pressed.emit()
	_press(_board.get_card(FIRST), &"ui_down")
	_press(_board.get_card(FIRST), &"ui_accept")
	_accept(SECOND)
	_board.get_detail().get_link_button().pressed.emit()
	_accept(FIRST)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_simulation.state.to_dict()))
	assert_array(GameState.validate_dict(saved)).is_empty()
	await _open(GameState.from_dict(saved))
	var card: ClueCard = _board.get_card(FIRST)
	assert_bool(card.shows_suspect()).is_true()
	assert_array(card.get_chip_texts()).is_equal(["keep"])
	assert_object(card.position).is_equal(Vector2(_note(FIRST).board_position))
	assert_array(_note(FIRST).links).is_equal([SECOND])
	assert_int(_board.get_link_layer().get_segments().size()).is_equal(2)


## The board redraws on the two events and on setup, not on a silent state change.
func test_redraws_only_on_events_and_setup() -> void:
	var state: GameState = _simulation.state
	var note: ClueNote = ClueNote.new()
	note.is_suspect = true
	state.intel.notes[FIRST] = note
	await await_idle_frame()
	assert_bool(_board.get_card(FIRST).shows_suspect()).is_false()
	state.events.post(&"clue_note_changed", [FIRST])
	_simulation.advance_tick()
	assert_bool(_board.get_card(FIRST).shows_suspect()).is_true()
	state.intel.add_clue(Fixture.clue(6))
	assert_object(_board.get_card(&"clue_0006")).is_null()
	state.events.post(&"clue_received", [&"clue_0006"])
	_simulation.advance_tick()
	assert_object(_board.get_card(&"clue_0006")).is_not_null()
	assert_array(_board.get_card_ids()).has_size(6)
	_board.setup(_simulation)
	assert_array(_board.get_card_ids()).has_size(6)


## Two zoom levels: the second shrinks the board and back.
func test_zoom_toggles_between_two_levels() -> void:
	assert_float(_board.get_zoom()).is_equal(1.0)
	_board.get_zoom_button().pressed.emit()
	assert_float(_board.get_zoom()).is_equal(AnalysisBoard.ZOOM_LEVELS[1])
	assert_str(_board.get_zoom_button().text).is_equal("BOARD_ZOOM_IN")
	_board.get_zoom_button().pressed.emit()
	assert_float(_board.get_zoom()).is_equal(1.0)


## The board shows only what the player may know: the view never reads a hidden clue field.
func test_view_never_reads_hidden_fields() -> void:
	var hidden: Array[String] = ["target_world_id", "is_true", "constraints", "dossier_id"]
	for file_name: String in DirAccess.get_files_at(BOARD_DIR):
		if file_name.get_extension() != "gd":
			continue
		var code: String = FileAccess.get_file_as_string(BOARD_DIR.path_join(file_name))
		for field: String in hidden:
			(
				assert_bool(code.contains(field))
				. override_failure_message("%s reads %s" % [file_name, field])
				. is_false()
			)


## With 60 cards a few headless frames stay quick; the times are printed, not asserted tightly.
func test_sixty_cards_stay_smooth() -> void:
	await _open(Fixture.state(60))
	assert_array(_board.get_card_ids()).has_size(60)
	var times: Array[float] = []
	for _frame: int in FRAME_COUNT:
		var started: int = Time.get_ticks_usec()
		await await_idle_frame()
		times.append((Time.get_ticks_usec() - started) / 1000.0)
	print("AnalysisBoard, 60 cards: frame times in ms ", times)
	assert_float(times.max()).is_less(1000.0)
