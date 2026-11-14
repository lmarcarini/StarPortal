class_name ConfidenceReadout
extends Button
## Top bar Committee Confidence readout, beside the funds: "Conf. 61 -0.1 ↓", the whole part of
## Confidence, today's drift and its trend arrow, with a tooltip giving the value with one decimal,
## why it drifts and the last three causes. Red, with the warning in the tooltip, while the
## Committee warns (Confidence 0, days in the red). Refreshes when Confidence or the funds change,
## on showing and on a locale change, so it is right while paused and after a load. Reads state
## only.
## Bible: docs/content/m27-daily-rhythm.md sections 2 and 5

## Font colour while the Committee warns.
const WARNING_COLOR: Color = UiPalette.ALARM
## Causes listed in the tooltip, newest first.
const TOOLTIP_CAUSES: int = 3

var _state: GameState = null


func _ready() -> void:
	refresh()


func _enter_tree() -> void:
	EventBus.confidence_changed.connect(_on_changed)
	EventBus.budget_changed.connect(_on_changed)


func _exit_tree() -> void:
	EventBus.confidence_changed.disconnect(_on_changed)
	EventBus.budget_changed.disconnect(_on_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED or what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_node_ready():
			refresh()


## Reads Confidence from [param state] (after a start or a load).
func setup(state: GameState) -> void:
	_state = state
	refresh()


## Shows the current Confidence, today's drift, the causes and any warning.
func refresh() -> void:
	if _state == null:
		text = ""
		tooltip_text = ""
		return
	text = readout_text(_state.committee.whole(), CommitteeText.drift_of(_state))
	tooltip_text = tooltip_for(_state)
	if is_warning(_state):
		add_theme_color_override(&"font_color", WARNING_COLOR)
		add_theme_color_override(&"font_hover_color", WARNING_COLOR)
		add_theme_color_override(&"font_focus_color", WARNING_COLOR)
	else:
		remove_theme_color_override(&"font_color")
		remove_theme_color_override(&"font_hover_color")
		remove_theme_color_override(&"font_focus_color")


## "Conf. 61 -0.1" for [param confidence] whole points and a drift of [param drift] tenths;
## "Conf. 50" with no drift.
static func readout_text(confidence: int, drift: int) -> String:
	if drift == 0:
		return _tr(&"CONFIDENCE_READOUT").format({"value": confidence})
	return (
		"%s %s"
		% [
			_tr(&"CONFIDENCE_READOUT_DRIFT").format(
				{"value": confidence, "drift": CommitteeText.signed_tenths(drift)}
			),
			trend_arrow(drift),
		]
	)


## The trend arrow of a drift of [param drift] tenths: up, down or "" with no drift. Drawn
## with the data font (IBM Plex Mono has the arrows; the label font does not).
static func trend_arrow(drift: int) -> String:
	if drift == 0:
		return ""
	return char(0x2191) if drift > 0 else char(0x2193)


## The tooltip: Confidence with one decimal, today's drift and why, the last three causes,
## then any warning.
static func tooltip_for(state: GameState) -> String:
	var committee: CommitteeState = state.committee
	var lines: PackedStringArray = [
		(
			_tr(&"CONFIDENCE_TOOLTIP")
			. format(
				{
					"value": CommitteeText.one_decimal(committee.confidence),
					"drift": CommitteeText.signed_tenths(CommitteeText.drift_of(state)),
					"why": CommitteeText.drift_reason(state),
				}
			)
		)
	]
	var shown: int = 0
	for index: int in range(committee.causes.size() - 1, -1, -1):
		if shown >= TOOLTIP_CAUSES:
			break
		lines.append(CommitteeText.cause_line(committee.causes[index], state))
		shown += 1
	lines.append_array(warning_lines(state))
	return "\n".join(lines)


## The warnings in force for [param state]: days in the red (from 7) and Confidence 0.
static func warning_lines(state: GameState) -> PackedStringArray:
	var committee: CommitteeState = state.committee
	var out: PackedStringArray = []
	if committee.days_in_red >= ConfidenceRules.RED_DAYS_WARNING:
		out.append(
			CommitteeText.warning_line(ConfidenceEvents.WARN_RED_DAYS, committee.days_in_red)
		)
	if committee.confidence <= ConfidenceRules.MIN:
		out.append(CommitteeText.warning_line(ConfidenceEvents.WARN_CONFIDENCE_ZERO, 0))
	return out


## True while the Committee warns: Confidence 0 or 7 or more days in the red.
static func is_warning(state: GameState) -> bool:
	return not warning_lines(state).is_empty()


func _on_changed(_value: int) -> void:
	refresh()


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
