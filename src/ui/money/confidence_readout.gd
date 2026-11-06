class_name ConfidenceReadout
extends Button
## Top bar Committee Confidence readout, beside the funds: "Conf. 62 +4", the last
## month-end's change, with a tooltip listing its causes. Red, with the warning in the
## tooltip, while the Committee warns (Confidence 0, months in the red). Pressing it opens the
## latest month-end report. Refreshes on each month-end, on showing and on a locale change, so
## it is right while paused and after a load. Reads state only.
## Bible: docs/content/m26-staff-and-money.md sections 4, 5 and 6

## Emitted when the player asks for the latest report.
signal report_requested

## Font colour while the Committee warns.
const WARNING_COLOR: Color = Color(0.9, 0.25, 0.2)

var _state: GameState = null


func _ready() -> void:
	pressed.connect(report_requested.emit)
	refresh()


func _enter_tree() -> void:
	EventBus.month_report_filed.connect(_on_month_report_filed)


func _exit_tree() -> void:
	EventBus.month_report_filed.disconnect(_on_month_report_filed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED or what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_node_ready():
			refresh()


## Reads Confidence and the latest report from [param state] (after a start or a load).
func setup(state: GameState) -> void:
	_state = state
	refresh()


## Shows the current Confidence, its last change, the causes and any warning.
func refresh() -> void:
	if _state == null:
		text = ""
		tooltip_text = ""
		return
	var report: MonthReport = _state.committee.latest_report()
	text = readout_text(_state.committee.confidence, report)
	tooltip_text = tooltip_for(report, _state)
	if is_warning(report, _state.committee.confidence):
		add_theme_color_override(&"font_color", WARNING_COLOR)
		add_theme_color_override(&"font_hover_color", WARNING_COLOR)
		add_theme_color_override(&"font_focus_color", WARNING_COLOR)
	else:
		remove_theme_color_override(&"font_color")
		remove_theme_color_override(&"font_hover_color")
		remove_theme_color_override(&"font_focus_color")


## "Conf. 62 +4" (or "-4"; no change before the first month-end or for a flat month).
static func readout_text(confidence: int, report: MonthReport) -> String:
	var change: int = 0 if report == null else report.confidence_after - report.confidence_before
	var key: StringName = &"CONFIDENCE_READOUT"
	if change > 0:
		key = &"CONFIDENCE_READOUT_UP"
	elif change < 0:
		key = &"CONFIDENCE_READOUT_DOWN"
	return _tr(key).format({"value": confidence, "change": absi(change)})


## The tooltip: the Confidence line and each cause of [param report], then the warnings.
static func tooltip_for(report: MonthReport, state: GameState) -> String:
	if report == null:
		return _tr(&"CONFIDENCE_TOOLTIP_NONE")
	var lines: PackedStringArray = [
		_tr(&"MONTH_REPORT_CONFIDENCE").format(
			{"before": report.confidence_before, "after": report.confidence_after}
		)
	]
	for cause: StringName in report.applied_causes():
		lines.append(MonthReportText.cause_line(report, cause, state))
	lines.append_array(MonthReportPanel.warning_lines(report))
	return "\n".join(lines)


## True while the Committee warns: Confidence 0 or the latest report's warnings.
static func is_warning(report: MonthReport, confidence: int) -> bool:
	if confidence <= ConfidenceRules.MIN:
		return true
	return report != null and (report.warn_red_months or report.warn_confidence_zero)


func _on_month_report_filed(_year: int, _month: int) -> void:
	refresh()


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
