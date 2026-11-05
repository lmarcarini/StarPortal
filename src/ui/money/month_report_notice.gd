class_name MonthReportNotice
extends PanelContainer
## The non-blocking month-end message (docs/content/m26-staff-and-money.md section 5): at each
## month-end it shows "Month-end report: Confidence 50 → 65", any Committee warning in red, and
## View (opens the report) and Dismiss. The game never pauses for it, nothing takes focus from
## the player, and it stays until dismissed, viewed or replaced by the next month-end. Reads
## state only.
## Bible: docs/content/m26-staff-and-money.md sections 5 and 6

## Emitted when View is pressed.
signal view_requested
## Emitted after the message hides while one of its buttons had focus, so the shell can move
## focus somewhere visible.
signal focus_left

## Font colour of a warning line.
const WARNING_COLOR: Color = Color(0.9, 0.25, 0.2)

var _state: GameState = null

@onready var _headline: Label = %Headline
@onready var _warning: Label = %Warning
@onready var _view: Button = %ViewButton
@onready var _dismiss: Button = %DismissButton


func _ready() -> void:
	hide()
	_warning.add_theme_color_override(&"font_color", WARNING_COLOR)
	_view.pressed.connect(_on_view_pressed)
	_dismiss.pressed.connect(dismiss)
	_view.focus_neighbor_right = _view.get_path_to(_dismiss)
	_dismiss.focus_neighbor_left = _dismiss.get_path_to(_view)


func _enter_tree() -> void:
	EventBus.month_report_filed.connect(_on_month_report_filed)


func _exit_tree() -> void:
	EventBus.month_report_filed.disconnect(_on_month_report_filed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		refresh()


## Reads reports from [param state] (after a start or a load); any message shown is dropped.
func setup(state: GameState) -> void:
	_state = state
	dismiss()


## Shows the message for the latest report; hides it when there is none.
func refresh() -> void:
	var report: MonthReport = null if _state == null else _state.committee.latest_report()
	if report == null:
		hide()
		return
	_headline.text = MonthReportText.headline(report)
	_warning.text = "\n".join(MonthReportPanel.warning_lines(report))
	_warning.visible = not _warning.text.is_empty()
	show()
	reset_size()


## Hides the message.
func dismiss() -> void:
	var had_focus: bool = _view.has_focus() or _dismiss.has_focus()
	hide()
	if had_focus:
		focus_left.emit()


## Returns the message line, or "" when hidden.
func get_text() -> String:
	return _headline.text if visible else ""


## Returns the View button.
func get_view_button() -> Button:
	return _view


func _on_view_pressed() -> void:
	view_requested.emit()
	dismiss()


func _on_month_report_filed(_year: int, _month: int) -> void:
	refresh()
