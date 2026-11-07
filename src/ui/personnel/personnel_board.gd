class_name PersonnelBoard
extends VBoxContainer
## The left side of the Personnel tab (docs/content/m26-staff-and-money.md section 6): the
## header ("PERSONNEL  Staff 5 · Beds 5/6 · Salaries $5k a day"), the Roster and
## Candidates (4) sub-tabs, and the list of the shown sub-tab, one [PersonnelRow] per person
## or candidate. The list scrolls past ten rows.
## Bible: docs/content/m26-staff-and-money.md section 6

## Emitted when a row takes focus.
signal row_chosen(id: StringName)
## Emitted on (A) or Enter on a row.
signal row_activated(id: StringName)
## Emitted when the other sub-tab is shown.
signal page_changed(page: Page)

## The two sub-tabs.
enum Page { ROSTER, CANDIDATES }

var _title: Label = _label(18)
var _summary: Label = _label(16)
var _tabs: TabBar = TabBar.new()
var _scroll: ScrollContainer = ScrollContainer.new()
var _list: VBoxContainer = VBoxContainer.new()
var _rows: Array[PersonnelRow] = []


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 16)
	header.custom_minimum_size.y = 48
	_summary.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(_title)
	header.add_child(_summary)
	add_child(header)
	add_child(HSeparator.new())
	_tabs.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_tabs.focus_mode = FOCUS_ALL
	_tabs.add_tab()
	_tabs.add_tab()
	_tabs.tab_changed.connect(func(index: int) -> void: page_changed.emit(index as Page))
	add_child(_tabs)
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 0)
	_scroll.add_child(_list)
	add_child(_scroll)


## Shows [param state]: the header, the sub-tab titles and the shown page's rows.
func show_state(state: GameState) -> void:
	_title.text = tr(&"STAFF_HEADING")
	_summary.text = PersonnelText.header(state)
	_tabs.set_tab_title(Page.ROSTER, tr(&"STAFF_TAB_ROSTER"))
	var count: int = state.recruitment.candidates.size()
	_tabs.set_tab_title(Page.CANDIDATES, tr(&"STAFF_TAB_CANDIDATES").format({"n": count}))
	if get_page() == Page.ROSTER:
		_show_rows(state.staff.people.size())
		for index: int in _rows.size():
			_rows[index].show_person(state, state.staff.people[index])
	else:
		_show_rows(count)
		for index: int in _rows.size():
			_rows[index].show_candidate(state.recruitment.candidates[index])


## The sub-tab shown.
func get_page() -> Page:
	return maxi(0, _tabs.current_tab) as Page


## Shows sub-tab [param page].
func show_page(page: Page) -> void:
	_tabs.current_tab = page


## Shows the other sub-tab (Y).
func toggle_page() -> void:
	show_page(Page.CANDIDATES if get_page() == Page.ROSTER else Page.ROSTER)


## Returns the rows shown, top to bottom.
func rows() -> Array[PersonnelRow]:
	return _rows.duplicate()


## Returns the row of [param id], or null.
func row_of(id: StringName) -> PersonnelRow:
	for row: PersonnelRow in _rows:
		if row.id == id:
			return row
	return null


## Returns the sub-tab bar.
func get_tabs() -> TabBar:
	return _tabs


## Returns the header's lines: title and summary.
func header() -> Array[String]:
	return [_title.text, _summary.text]


## Returns the sub-tab titles.
func tab_titles() -> Array[String]:
	return [_tabs.get_tab_title(0), _tabs.get_tab_title(1)]


## Keeps [param count] rows, adding or freeing rows at the end; focus stays on a kept row.
func _show_rows(count: int) -> void:
	while _rows.size() > count:
		var row: PersonnelRow = _rows.pop_back()
		_list.remove_child(row)
		row.queue_free()
	while _rows.size() < count:
		var row := PersonnelRow.new()
		row.chosen.connect(row_chosen.emit)
		row.activated.connect(row_activated.emit)
		_list.add_child(row)
		_rows.append(row)


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	return label
