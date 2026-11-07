class_name CommandBoard
extends VBoxContainer
## The left column of the Command tab (docs/content/m27-daily-rhythm.md section 4), in 32 px
## rows: the header (funds, today's net, Confidence), the money lines, the trend and its
## sparkline, the recent causes (two visible, scrolling with the focus) and the warnings.
## Money lines and causes are focusable rows; the D-pad moves along them.
## Bible: docs/content/m27-daily-rhythm.md section 4

## Emitted when a money line row takes focus, with its index in [method lines].
signal line_chosen(index: int)
## Emitted on (A), Enter or a click on a money line.
signal line_activated(index: int)
## Emitted when a cause row takes focus.
signal cause_chosen

## Cause rows visible at once.
const CAUSES_VISIBLE: int = 2
## Width of the section titles beside the warnings.
const TITLE_WIDTH: int = 120

var _title: Label = _label(18)
var _funds: Label = _label(16)
var _confidence: Label = _label(16)
var _money_header := CommandRow.new(false)
var _money: VBoxContainer = _list()
var _trend := CommandRow.new(false)
var _sparkline := FundsSparkline.new()
var _causes_header := CommandRow.new(false)
var _causes_scroll := ScrollContainer.new()
var _causes: VBoxContainer = _list()
var _warnings_title: Label = _label(16)
var _warnings: VBoxContainer = _list()
var _lines: Array[CommandLine] = []


func _init() -> void:
	add_theme_constant_override(&"separation", 0)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = CommandRow.HEIGHT
	header.add_theme_constant_override(&"separation", 24)
	_funds.size_flags_horizontal = SIZE_EXPAND_FILL
	for fixed: Label in [_title, _confidence, _warnings_title]:
		fixed.clip_text = false
		fixed.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	for part: Label in [_title, _funds, _confidence]:
		header.add_child(part)
	_causes_scroll.custom_minimum_size.y = CommandRow.HEIGHT * CAUSES_VISIBLE
	_causes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_causes_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_causes_scroll.follow_focus = true
	_causes.size_flags_horizontal = SIZE_EXPAND_FILL
	_causes_scroll.add_child(_causes)
	var warnings := HBoxContainer.new()
	_warnings_title.custom_minimum_size = Vector2(TITLE_WIDTH, CommandRow.HEIGHT)
	_warnings_title.size_flags_vertical = SIZE_SHRINK_BEGIN
	_warnings.size_flags_horizontal = SIZE_EXPAND_FILL
	warnings.add_child(_warnings_title)
	warnings.add_child(_warnings)
	for part: Control in [
		header, _money_header, _money, _trend, _sparkline, _causes_header, _causes_scroll, warnings
	]:
		add_child(part)


## Rereads every figure from [param state]; keeps the focused row while it stays.
func show_state(state: GameState) -> void:
	_lines = CommandLedger.lines(state)
	_title.text = _tr(&"COMMAND_HEADING")
	_funds.text = CommandText.funds_line(state)
	_confidence.text = _tr(&"COMMAND_CONFIDENCE_SHORT").format(
		{"value": CommitteeText.one_decimal(state.committee.confidence)}
	)
	_money_header.show_texts(
		_tr(&"COMMAND_MONEY"), _tr(&"COMMAND_PER_DAY"), _tr(&"COMMAND_PER_PERIOD")
	)
	_show_lines(state)
	_trend.show_texts(CommandText.trend_line(state), "", "")
	_sparkline.show_balances(state.committee.funds_history)
	_causes_header.show_texts(_tr(&"COMMAND_CAUSES"), "", "")
	_show_causes(state)
	_show_warnings(state)
	_link_focus()


## The money lines shown, top to bottom.
func lines() -> Array[CommandLine]:
	return _lines


## The money line rows, top to bottom.
func line_rows() -> Array[CommandRow]:
	return _rows_of(_money)


## The cause rows, newest first (empty when there are none).
func cause_rows() -> Array[CommandRow]:
	var rows: Array[CommandRow] = _rows_of(_causes)
	return rows.filter(func(row: CommandRow) -> bool: return row.focus_mode != FOCUS_NONE)


## The warning rows' texts ("none" when there is no warning).
func warning_texts() -> Array[String]:
	var out: Array[String] = []
	for row: CommandRow in _rows_of(_warnings):
		out.append(row.texts()[0])
	return out


## The texts of the header, trend and every row title, top to bottom, for tests.
func texts() -> Array[String]:
	return [_title.text, _funds.text, _confidence.text, _trend.texts()[0], _warnings_title.text]


## The sparkline, for tests.
func get_sparkline() -> FundsSparkline:
	return _sparkline


## Every label of the column, for layout tests.
func all_labels() -> Array[Label]:
	var out: Array[Label] = [_title, _funds, _confidence, _warnings_title]
	for row: CommandRow in [_money_header, _trend, _causes_header]:
		out.append_array(row.labels())
	for list: VBoxContainer in [_money, _causes, _warnings]:
		for row: CommandRow in _rows_of(list):
			out.append_array(row.labels())
	return out


func _show_lines(state: GameState) -> void:
	_resize(_money, _lines.size(), true)
	var rows: Array[CommandRow] = line_rows()
	for index: int in _lines.size():
		var line: CommandLine = _lines[index]
		rows[index].index = index
		rows[index].show_texts(
			CommandText.line_name(state, line),
			CommandText.per_day(line),
			CommandText.signed_number(line.per_period_k)
		)
		rows[index].tooltip_text = "\n".join(CommandText.breakdown(state, line))


func _show_causes(state: GameState) -> void:
	var causes: Array[ConfidenceCause] = state.committee.causes
	if causes.is_empty():
		_resize(_causes, 0, true)
		_resize(_causes, 1, false)
		_rows_of(_causes)[0].show_texts(_tr(&"COMMAND_CAUSES_NONE"), "", "")
		return
	if not cause_rows().size() == _rows_of(_causes).size():
		_resize(_causes, 0, true)
	_resize(_causes, causes.size(), true)
	var rows: Array[CommandRow] = _rows_of(_causes)
	for index: int in causes.size():
		var cause: ConfidenceCause = causes[causes.size() - 1 - index]
		var line: String = (
			"%s  %s" % [CommandText.short_date(cause.tick), CommitteeText.cause_line(cause, state)]
		)
		rows[index].index = index
		rows[index].show_texts(line, "", "")
		rows[index].tooltip_text = line


func _show_warnings(state: GameState) -> void:
	_warnings_title.text = _tr(&"COMMAND_WARNINGS")
	var found: PackedStringArray = ConfidenceReadout.warning_lines(state)
	if found.is_empty():
		found.append(_tr(&"COMMAND_WARNINGS_NONE"))
	_resize(_warnings, found.size(), false)
	var rows: Array[CommandRow] = _rows_of(_warnings)
	for index: int in found.size():
		rows[index].show_texts(found[index], "", "")
		rows[index].tooltip_text = found[index]
		rows[index].mouse_filter = MOUSE_FILTER_PASS


## Keeps [param count] rows in [param list], adding (focusable when [param focusable]) or
## freeing rows at the end only, so a focused row stays.
func _resize(list: VBoxContainer, count: int, focusable: bool) -> void:
	while list.get_child_count() > count:
		var last: Node = list.get_child(list.get_child_count() - 1)
		list.remove_child(last)
		last.queue_free()
	while list.get_child_count() < count:
		var row := CommandRow.new(focusable)
		if focusable and list == _money:
			row.chosen.connect(func(r: CommandRow) -> void: line_chosen.emit(r.index))
			row.activated.connect(func(r: CommandRow) -> void: line_activated.emit(r.index))
		elif focusable:
			row.chosen.connect(func(_r: CommandRow) -> void: cause_chosen.emit())
		list.add_child(row)


## Chains the focusable rows top to bottom for the D-pad.
func _link_focus() -> void:
	var chain: Array[CommandRow] = line_rows()
	chain.append_array(cause_rows())
	for index: int in chain.size():
		var row: CommandRow = chain[index]
		if index > 0:
			row.focus_neighbor_top = row.get_path_to(chain[index - 1])
		if index < chain.size() - 1:
			row.focus_neighbor_bottom = row.get_path_to(chain[index + 1])
		else:
			row.focus_neighbor_bottom = NodePath(".")


static func _rows_of(list: VBoxContainer) -> Array[CommandRow]:
	var rows: Array[CommandRow] = []
	for child: Node in list.get_children():
		if child is CommandRow and not child.is_queued_for_deletion():
			rows.append(child as CommandRow)
	return rows


static func _list() -> VBoxContainer:
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 0)
	return list


static func _label(font_size: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override(&"font_size", font_size)
	return label


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
