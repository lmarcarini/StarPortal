class_name AlertStack
extends HBoxContainer
## The top bar's alert stack (docs/content/m3-beyond-the-ring.md section 4): one entry per
## standing alert. In M3 the only one is the rescue window, "T-1 missing  71 h 58 min", shown
## while it is open; pressing it opens the rescue alert again. Redraws on every tick and rescue
## event and when the alert opens or closes, so it updates while paused.
## Bible: docs/content/m3-beyond-the-ring.md sections 4 and 7

var _alert: RescueAlert = null
var _rescue_button := Button.new()


func _init() -> void:
	_rescue_button.custom_minimum_size = Vector2(0, 40)
	_rescue_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_rescue_button.visible = false
	add_child(_rescue_button)
	_rescue_button.pressed.connect(_on_rescue_pressed)


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_event)
	EventBus.check_in_missed.connect(_on_event)
	EventBus.team_rescued.connect(_on_event)
	EventBus.team_lost.connect(_on_event)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_event)
	EventBus.check_in_missed.disconnect(_on_event)
	EventBus.team_rescued.disconnect(_on_event)
	EventBus.team_lost.disconnect(_on_event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		refresh()


## Shows the entries of [param alert]'s rescue window and opens it when pressed.
func setup(alert: RescueAlert) -> void:
	_alert = alert
	if not alert.changed.is_connected(refresh):
		alert.changed.connect(refresh)
	refresh()


## Redraws the entries from the state.
func refresh() -> void:
	var shown: bool = _alert != null and _alert.is_window_open()
	_rescue_button.visible = shown
	if shown:
		_rescue_button.text = _alert.stack_entry()


## Returns the rescue window's entry.
func get_rescue_button() -> Button:
	return _rescue_button


func _on_rescue_pressed() -> void:
	if _alert != null:
		_alert.open()


func _on_event(_a: Variant = null, _b: Variant = null) -> void:
	refresh()
