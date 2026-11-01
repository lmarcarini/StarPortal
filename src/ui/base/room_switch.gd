class_name RoomSwitch
extends VBoxContainer
## The selected room's on/off switch in the Base tab's panel (docs/content/m2-base.md
## section 6). A room with a switch shows "ON — switch off" or "OFF — switch on"; an always-on
## room and the base's last running plant show a locked switch with the reason. Rooms with no
## switch (banks, lifts, stairs, corridors) hide it. Pressing it asks for the change through
## [signal toggle_requested]; a refusal is shown under it in plain words.
## Bible: docs/content/m2-base.md sections 3 and 6

## Emitted when the player presses the switch of room [param room_id].
signal toggle_requested(room_id: StringName)

var _room_id: StringName = &""
var _button: Button = Button.new()
var _note: Label = Label.new()


func _ready() -> void:
	_button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_button.pressed.connect(func() -> void: toggle_requested.emit(_room_id))
	add_child(_button)
	_note.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override(&"font_size", 14)
	add_child(_note)
	visible = false


## Shows the switch of [param room] built from [param def] in [param state]; hides it for a
## room with none.
func show_room(state: GameState, room: RoomState, def: RoomDef) -> void:
	var locked: String = PowerText.lock_reason(state, room, def)
	visible = PowerRules.is_standing(room) and (PowerRules.has_switch(def) or def.always_on)
	if not visible:
		return
	var on: bool = PowerRules.is_running(room, def)
	_room_id = room.id
	_button.disabled = not locked.is_empty()
	if locked.is_empty():
		_button.text = tr(&"BASE_POWER_SWITCH_ON" if on else &"BASE_POWER_SWITCH_OFF")
	else:
		_button.text = tr(&"BASE_POWER_SWITCH_LOCKED")
	_show_note(locked)


## Shows [param text] (a refusal) under the switch; "" clears it.
func show_notice(text: String) -> void:
	_show_note(text)


## Returns the switch button, for tests.
func get_button() -> Button:
	return _button


## Returns the text under the switch: the lock reason or a refusal.
func get_note() -> String:
	return _note.text


func _show_note(text: String) -> void:
	_note.text = text
	_note.visible = not text.is_empty()
