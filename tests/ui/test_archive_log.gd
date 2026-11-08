## Tests for the Archive's Log section: after a played session (SILL dialed after a miss, locked,
## horizon record, console, close) the Log lists every entry newest first with its date, icon and
## line; the kind filter and the text search narrow it; new entries appear at the top; the
## gamepad reaches it; and it fits the minimum window in en and pt_BR without clipped text.
## Bible: game-design.md#core-loop (Archive: the operations log),
## technical-architecture.md#input-accessibility-and-localisation
extends GdUnitTestSuite

const M15Player := preload("res://tests/gate/m15_player.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
const VIEW_SCENE: String = "res://src/ui/views/archive/archive_view.tscn"
const VIEW_SIZE: Vector2 = Vector2(1280, 600)
const MISS_GLYPHS: Array[int] = [35, 24, 29, 10, 19, 22, 3]
const SLACK: float = 1.0

var _player: M15Player
var _holder: Control = null
var _view: ArchiveView = null
var _real_locale: String = ""


func before() -> void:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var built: Result = GameSetup.build_new(GameState.new_game(20261026, defs.balance), defs)
	var simulation: Simulation = built.value
	_player = M15Player.new(simulation)
	_player.step()
	_player.build_bank()
	var miss: GateAddress = _player.address(MISS_GLYPHS)
	_player.wait_for_charge(miss)
	_player.dial(miss)
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
	_view.show_section(true)
	await UiInput.settle(_view)


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	TranslationServer.set_locale(_real_locale)


func _list() -> LogList:
	return _view.get_log_list()


func _lines() -> Array[String]:
	var lines: Array[String] = []
	for row: ArchiveLogRow in _list().get_visible_rows():
		lines.append(row.get_line_text())
	return lines


## The Archive has a Documents and a Log section; the Log lists every entry newest first.
func test_log_lists_every_entry_newest_first() -> void:
	var sections: TabContainer = _view.get_node("%Sections") as TabContainer
	assert_int(sections.get_tab_count()).is_equal(3)
	assert_str(sections.get_tab_bar().tr(sections.get_tab_title(2))).is_equal("Log")
	var entries: Array[LogEntry] = _player.state().operations_log.entries
	assert_int(_list().get_rows().size()).is_equal(entries.size())
	var lines: Array[String] = _lines()
	assert_str(lines[0]).is_equal("Closed the wormhole to SILL")
	assert_str(lines[1]).is_equal("Read the console of SILL")
	assert_bool(lines.has("Locked SILL")).is_true()
	assert_bool(lines.has("Horizon record taken: SILL")).is_true()
	assert_bool(lines.has("Dialed: Lock")).is_true()
	assert_str(lines.back()).is_equal("Received: Gallow Commission, Order No. 1")
	assert_str(_list().get_count_text()).is_equal("%d entries" % entries.size())
	var newest: ArchiveLogRow = _list().get_rows()[0]
	assert_str(newest.tooltip_text).is_equal("Closes")
	var date: Label = newest.find_child("Date", true, false) as Label
	assert_str(date.text).is_equal(GateRoomFormat.date_time(newest.get_entry().tick))
	assert_object(_view.get_default_focus()).is_same(newest)


## A dial row shows its address as glyphs; other rows show none.
func test_dial_rows_show_the_address() -> void:
	for row: ArchiveLogRow in _list().get_rows():
		var strip: AddressStrip = row.find_child("Strip", true, false) as AddressStrip
		assert_bool(strip.visible).is_equal(row.get_entry().kind == &"dial")
		if strip.visible:
			assert_str(strip.get_address().key()).is_equal(row.get_entry().args["address"])


## The kind filter and the search narrow the rows; nothing matching shows a message.
func test_filter_and_search() -> void:
	var documents: int = 0
	for entry: LogEntry in _player.state().operations_log.entries:
		documents += 1 if entry.kind == &"document" else 0
	_list().set_kind_filter(&"document")
	assert_int(_list().get_visible_rows().size()).is_equal(documents)
	assert_str(_list().get_count_text()).is_equal("%d entries" % documents)
	_list().set_search("order")
	assert_int(_list().get_visible_rows().size()).is_equal(1)
	assert_str(_list().get_count_text()).is_equal("1 entry")
	_list().set_kind_filter(&"lock")
	assert_array(_list().get_visible_rows()).is_empty()
	assert_str(_list().get_empty_text()).is_equal("No entry matches.")
	_list().set_kind_filter(LogList.ANY_KIND)
	_list().set_search("SILL")
	assert_array(_lines()).contains(
		["Locked SILL", "Horizon record taken: SILL", "Read the console of SILL"]
	)
	assert_array(_lines()).not_contains(["Dialed: Lock"])
	var glyph: String = GateRoomFormat.glyph_name(MISS_GLYPHS[6])
	_list().set_search(glyph)
	for row: ArchiveLogRow in _list().get_visible_rows():
		assert_str(String(row.get_entry().kind)).is_equal("dial")
	assert_int(_list().get_visible_rows().size()).is_greater(0)


## A new event adds its row at the top, keeping the filter.
func test_new_entries_appear_at_the_top() -> void:
	var before: int = _list().get_rows().size()
	_player.simulation.submit(DeliverDocumentCommand.create(&"doc_lintel_dossier"))
	await UiInput.settle(_view)
	assert_int(_list().get_rows().size()).is_equal(before + 1)
	assert_str(_list().get_rows()[0].get_line_text()).starts_with("Received: ")


## Gamepad: Right twice from the section tabs (past Worlds) opens the Log; Down reaches the kind filter, Right the
## search, Down the rows; Up and Left lead back the same way.
func test_gamepad_reaches_the_log() -> void:
	_view.show_section(false)
	await UiInput.settle(_view)
	var tabs: TabBar = (_view.get_node("%Sections") as TabContainer).get_tab_bar()
	await UiInput.pad(tabs, JOY_BUTTON_DPAD_RIGHT)
	await UiInput.pad(tabs, JOY_BUTTON_DPAD_RIGHT)
	assert_bool(_list().is_visible_in_tree()).is_true()
	var filter: Control = _list().get_filter_button()
	var search: Control = _list().get_search_field()
	await _expect(tabs, JOY_BUTTON_DPAD_DOWN, filter)
	await _expect(filter, JOY_BUTTON_DPAD_RIGHT, search)
	await _expect(search, JOY_BUTTON_DPAD_DOWN, _list().get_visible_rows()[0])
	var first: Control = _focused()
	await UiInput.pad(first, JOY_BUTTON_DPAD_DOWN)
	assert_object(_focused()).is_instanceof(ArchiveLogRow)
	assert_object(_focused()).is_not_same(first)
	await _expect(_focused(), JOY_BUTTON_DPAD_UP, first)
	await _expect(first, JOY_BUTTON_DPAD_UP, search)
	await _expect(search, JOY_BUTTON_DPAD_LEFT, filter)
	await _expect(filter, JOY_BUTTON_DPAD_DOWN, first)
	await _expect(filter, JOY_BUTTON_DPAD_UP, tabs)
	await _expect(search, JOY_BUTTON_DPAD_UP, tabs)


func _focused() -> Control:
	return _holder.get_viewport().gui_get_focus_owner()


func _expect(from: Control, button: JoyButton, to: Control) -> void:
	from.grab_focus()
	await UiInput.pad(from, button)
	assert_object(_focused()).is_same(to)


## The Log fits the minimum window and no single-line text is clipped, in en and pt_BR.
@warning_ignore("unused_parameter")
func test_log_fits_the_minimum_window(
	locale: String, test_parameters: Array = [["en"], ["pt_BR"]]  # gdlint: ignore=unused-argument
) -> void:
	TranslationServer.set_locale(locale)
	await UiInput.settle(_view)
	var needed: Vector2 = (_view.get_node("%Sections") as Control).get_combined_minimum_size()
	assert_float(needed.x).is_less_equal(VIEW_SIZE.x)
	assert_float(needed.y).is_less_equal(VIEW_SIZE.y)
	assert_array(_clipped(_list())).is_empty()


## Visible single-line labels and drop-downs narrower than their text.
func _clipped(root: Node) -> Array[String]:
	var found: Array[String] = []
	for child: Node in root.get_children():
		found.append_array(_clipped(child))
	if not (root is Control) or not (root as Control).is_visible_in_tree():
		return found
	if root is Label:
		var label: Label = root as Label
		var trims: bool = label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF and not trims:
			_check(label, label.text, 0.0, found)
	elif root is OptionButton:
		_check(root as Control, (root as OptionButton).text, 28.0, found)
	return found


func _check(control: Control, text: String, padding: float, found: Array[String]) -> void:
	if text.is_empty():
		return
	var font: Font = control.get_theme_font(&"font")
	var size: int = control.get_theme_font_size(&"font_size")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if width + padding > control.size.x + SLACK:
		found.append("%s: '%s' needs %d px, has %d" % [control.name, text, width, control.size.x])
