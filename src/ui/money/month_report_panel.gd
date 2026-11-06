class_name MonthReportPanel
extends PanelContainer
## The month-end report window (docs/content/m26-staff-and-money.md section 5): the date, then
## every line of a MonthReport (money, Confidence and its causes, the review, the next
## allocation) and the Committee's warnings in red. It never pauses the game: the clock runs on
## behind it. A new month-end while it is open shows the new report. Close, B or Esc
## dismisses it and gives focus back. Reads state only.
## Bible: docs/content/m26-staff-and-money.md sections 5 and 6

## Emitted when the window closes.
signal closed

## Font colour of a warning line.
const WARNING_COLOR: Color = Color(0.9, 0.25, 0.2)
## Tallest the report lines grow before they scroll, in pixels.
const MAX_LINES_HEIGHT: float = 470.0

var _report: MonthReport = null
var _state: GameState = null
var _return_focus: Control = null

@onready var _title: Label = %Title
@onready var _lines: VBoxContainer = %Lines
@onready var _scroll: ScrollContainer = %LinesScroll
@onready var _close: Button = %CloseButton


func _ready() -> void:
	hide()
	_close.pressed.connect(close)
	_close.focus_neighbor_left = _close.get_path_to(_close)
	_close.focus_neighbor_right = _close.get_path_to(_close)
	_close.focus_neighbor_top = _close.get_path_to(_close)
	_close.focus_neighbor_bottom = _close.get_path_to(_close)


func _enter_tree() -> void:
	EventBus.month_report_filed.connect(_on_month_report_filed)


func _exit_tree() -> void:
	EventBus.month_report_filed.disconnect(_on_month_report_filed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		_fill()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Shows [param report], naming worlds from [param state], with focus on Close. Does nothing
## when [param report] is null.
func open(report: MonthReport, state: GameState) -> void:
	if report == null:
		return
	_report = report
	_state = state
	var owner_now: Control = get_viewport().gui_get_focus_owner()
	if owner_now != null and not is_ancestor_of(owner_now):
		_return_focus = owner_now
	_fill()
	show()
	_close.grab_focus()


## Hides the window and gives focus back to what had it.
func close() -> void:
	if not visible:
		return
	hide()
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	_return_focus = null
	closed.emit()


## Returns the lines shown, title first.
func get_lines() -> PackedStringArray:
	var shown: PackedStringArray = [_title.text]
	for child: Node in _lines.get_children():
		if not child.is_queued_for_deletion():
			shown.append((child as Label).text)
	return shown


## Returns the Close button.
func get_close_button() -> Button:
	return _close


## The window's title: "Month-end 2026-02-01".
static func title_of(report: MonthReport) -> String:
	var date: String = "%04d-%02d-01" % [report.year, report.month]
	return String(TranslationServer.translate(&"MONTH_PANEL_TITLE")).format({"date": date})


## The warning lines [param report] raised, plainly worded.
static func warning_lines(report: MonthReport) -> PackedStringArray:
	var out: PackedStringArray = []
	if report.warn_red_months:
		out.append(MonthReportText.warning_line(MonthEnd.WARN_RED_MONTHS, report.months_in_red))
	if report.warn_confidence_zero:
		out.append(
			MonthReportText.warning_line(MonthEnd.WARN_CONFIDENCE_ZERO, report.months_in_red)
		)
	return out


func _on_month_report_filed(_year: int, _month: int) -> void:
	if not visible or _state == null or _state.committee.latest_report() == null:
		return
	_report = _state.committee.latest_report()
	_fill()


func _fill() -> void:
	for child: Node in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	_title.text = title_of(_report)
	var body: PackedStringArray = MonthReportText.lines(_report, _state)
	for index: int in range(1, body.size()):
		_add_line(body[index], false)
	for line: String in warning_lines(_report):
		_add_line(line, true)
	_scroll.custom_minimum_size.y = minf(_lines.get_combined_minimum_size().y, MAX_LINES_HEIGHT)
	reset_size()


func _add_line(text: String, is_warning: bool) -> void:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	if is_warning:
		label.add_theme_color_override(&"font_color", WARNING_COLOR)
	_lines.add_child(label)
