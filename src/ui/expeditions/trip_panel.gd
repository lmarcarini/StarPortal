class_name ExpeditionTripPanel
extends VBoxContainer
## The middle column of the Expeditions tab (docs/content/m3-beyond-the-ring.md section 7):
## the team out (header, the timeline of out, check-ins and return, the next one due, the
## trip's Log lines) with **Recall team**, or the rescue state of a missing team, or "No team
## away"; below, the past: what came back and who did not. Reads state only: Recall team emits
## [signal recall_pressed] and the view submits the command.
## Bible: docs/content/m3-beyond-the-ring.md sections 4 and 7

## Emitted when **Recall team** is pressed.
signal recall_pressed

## Past lines shown at most, newest first.
const PAST_SHOWN: int = 6

var _header := Label.new()
var _next := Label.new()
var _timeline := Label.new()
var _log := Label.new()
var _recall := Button.new()
var _notice := Label.new()
var _past := Label.new()


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override(&"separation", 6)
	_header.add_theme_font_size_override(&"font_size", 18)
	add_child(_header)
	add_child(_next)
	add_child(_timeline)
	var log_title := Label.new()
	log_title.text = &"EXPEDITION_LOG"
	add_child(log_title)
	add_child(_log)
	_recall.text = &"EXPEDITION_RECALL"
	_recall.custom_minimum_size.y = ExpeditionPlanSheet.ROW_HEIGHT
	_recall.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_recall.pressed.connect(func() -> void: recall_pressed.emit())
	add_child(_recall)
	add_child(_notice)
	var past_title := Label.new()
	past_title.text = &"EXPEDITION_PAST"
	add_child(past_title)
	add_child(_past)
	for label: Label in [_header, _next, _timeline, _log, _notice, _past]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Rereads [param state].
func show_state(state: GameState) -> void:
	var expedition: ExpeditionState = state.expedition
	if expedition.is_out():
		_header.text = ExpeditionTripText.header(state)
	else:
		_header.text = tr(&"EXPEDITION_NONE_AWAY")
	_next.text = ExpeditionTripText.next_check_in(state)
	_next.visible = not _next.text.is_empty()
	_timeline.text = "\n".join(ExpeditionTripText.timeline(state))
	var log_lines: Array[String] = ExpeditionTripText.trip_log(state)
	_log.text = "\n".join(log_lines) if not log_lines.is_empty() else tr(&"EXPEDITION_LOG_NONE")
	_recall.visible = expedition.mode == ExpeditionState.Mode.AWAY
	_recall.disabled = expedition.recalled
	var past: Array[String] = ExpeditionTripText.past(state)
	past.resize(mini(past.size(), PAST_SHOWN))
	_past.text = "\n".join(past) if not past.is_empty() else tr(&"EXPEDITION_PAST_NONE")
	if not expedition.is_out():
		show_notice("")


## Shows [param text] under Recall team (a refusal), or hides the line for "".
func show_notice(text: String) -> void:
	_notice.text = text
	_notice.visible = not text.is_empty()


## Returns the Recall team button.
func get_recall_button() -> Button:
	return _recall


## Returns the shown texts: header, next check-in, timeline, trip log, notice, past.
func texts() -> Array[String]:
	return [_header.text, _next.text, _timeline.text, _log.text, _notice.text, _past.text]
