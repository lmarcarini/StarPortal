class_name SlowLamp
extends HBoxContainer
## The "SLOW · reason" lamp beside the clock (docs/content/event-time.md section 4): hidden
## at cruise speed; while slowed it names the most pressing reason. The lamp is an amber
## triangle when the player can override and a red square when they cannot, so the reason
## is told by shape as well as colour. Presentation only.
## Bible: docs/content/event-time.md section 4

## Reasons the player cannot override come first, then the gate, then waiting items.
const _ORDER: Array[StringName] = [
	&"incursion", &"conversation", &"gate_ops", &"dialling", &"awaiting_answer"
]

var _lamp := StatusLamp.new()
var _label := Label.new()


func _init() -> void:
	name = &"SlowLamp"
	visible = false
	add_child(_lamp)
	_label.name = &"SlowLabel"
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_label)


## Shows the slow of [param clock] (also while paused, so the player sees why it will be
## slow), or hides at cruise speed.
func show_clock(clock: ClockState) -> void:
	var key: StringName = shown_key(clock)
	visible = not key.is_empty()
	if not visible:
		return
	_label.text = tr(&"UI_SLOW").format({"reason": tr(label_key(key))})
	var can_override: bool = TimeControl.OVERRIDABLE.has(TimeControl.reason_of(key))
	_lamp.set_status(&"warn" if can_override else &"alarm")


## The text shown now ("" when hidden).
func get_text() -> String:
	return _label.text if visible else ""


## The lamp's status now.
func get_status() -> StringName:
	return _lamp.get_status()


## The active slow key of [param clock] to name, most pressing first; &"" when none.
static func shown_key(clock: ClockState) -> StringName:
	for reason: StringName in _ORDER:
		for key: StringName in clock.slows:
			if TimeControl.reason_of(key) == reason:
				return key
	return &""


## The translation key naming slow [param key]: gate, dialling, conversation, call waiting,
## decision waiting or intruders.
static func label_key(key: StringName) -> StringName:
	var reason: StringName = TimeControl.reason_of(key)
	if reason == &"awaiting_answer":
		var is_decision: bool = String(key).ends_with("/rescue")
		return &"UI_SLOW_DECISION" if is_decision else &"UI_SLOW_CALL"
	return StringName("UI_SLOW_" + String(reason).to_upper())
