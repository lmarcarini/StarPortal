class_name CommandPanel
extends VBoxContainer
## The Command tab's side panel (docs/content/m27-daily-rhythm.md section 4). Normally the
## COMMITTEE summary: Confidence with one decimal, today's drift and why, and the next
## commendation ("At 70: $1,000k" with a bar, or "Paid. Re-arms below 60."); the lower half is
## left for Committee requests and factions. A money line's breakdown (each room or person)
## replaces it until closed.
## Bible: docs/content/m27-daily-rhythm.md section 4

var _title: Label = _label(18)
var _summary := VBoxContainer.new()
var _confidence: Label = _label(16)
var _today: Label = _label(16)
var _commendation_title: Label = _label(16)
var _commendation: Label = _label(16)
var _bar := ProgressBar.new()
var _later: Label = _label(14)
var _breakdown_scroll := ScrollContainer.new()
var _breakdown := VBoxContainer.new()
var _close_hint: Label = _label(14)
var _showing_breakdown: bool = false


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	_summary.add_theme_constant_override(&"separation", 8)
	_today.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_later.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_later.modulate = Color(1, 1, 1, 0.5)
	_bar.max_value = ConfidenceRules.COMMENDATION_AT / ConfidenceRules.TENTHS
	_bar.custom_minimum_size.y = 20
	_bar.show_percentage = false
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	for part: Control in [_confidence, _today, spacer, _commendation_title, _commendation, _bar]:
		_summary.add_child(part)
	var lower := Control.new()
	lower.custom_minimum_size.y = 32
	_summary.add_child(lower)
	_summary.add_child(_later)
	_breakdown_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_breakdown_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_breakdown.size_flags_horizontal = SIZE_EXPAND_FILL
	_breakdown_scroll.add_child(_breakdown)
	for part: Control in [_title, _summary, _breakdown_scroll, _close_hint]:
		add_child(part)
	_show_mode(false)


## Shows the COMMITTEE summary for [param state].
func show_summary(state: GameState) -> void:
	_show_mode(false)
	_title.text = _tr(&"COMMAND_COMMITTEE")
	var committee: CommitteeState = state.committee
	_confidence.text = _tr(&"COMMAND_CONFIDENCE").format(
		{"value": CommitteeText.one_decimal(committee.confidence)}
	)
	_today.text = (
		_tr(&"COMMAND_TODAY")
		. format(
			{
				"drift": CommitteeText.signed_tenths(CommitteeText.drift_of(state)),
				"why": CommitteeText.drift_reason(state),
			}
		)
	)
	_commendation_title.text = _tr(&"COMMAND_COMMENDATION")
	_commendation.text = CommandText.commendation(state)
	_bar.visible = not committee.commendation_paid
	_bar.value = mini(committee.whole(), int(_bar.max_value))
	_later.text = _tr(&"COMMAND_LATER")


## Shows the breakdown titled [param title], one row per item of [param items].
func show_breakdown(title: String, items: PackedStringArray) -> void:
	_show_mode(true)
	_title.text = title
	for child: Node in _breakdown.get_children():
		_breakdown.remove_child(child)
		child.queue_free()
	for item: String in items:
		var label: Label = _label(16)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = item
		_breakdown.add_child(label)
	_close_hint.text = _tr(&"COMMAND_BREAKDOWN_CLOSE")


## True while a breakdown is shown.
func is_breakdown() -> bool:
	return _showing_breakdown


## The shown texts, top to bottom, for tests.
func texts() -> Array[String]:
	var out: Array[String] = [_title.text]
	var parts: Array[Node] = [_confidence, _today, _commendation_title, _commendation]
	if _showing_breakdown:
		parts = _breakdown.get_children()
	for part: Node in parts:
		out.append((part as Label).text)
	return out


## The commendation bar, for tests.
func get_bar() -> ProgressBar:
	return _bar


func _show_mode(breakdown: bool) -> void:
	_showing_breakdown = breakdown
	_summary.visible = not breakdown
	_breakdown_scroll.visible = breakdown
	_close_hint.visible = breakdown


static func _label(font_size: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override(&"font_size", font_size)
	return label


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
