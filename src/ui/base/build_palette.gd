class_name BuildPalette
extends VBoxContainer
## The Base tab's build palette (docs/content/m2-base.md section 6): one button per buildable
## room in catalogue order, the Dig button, then a line that shows the hovered or focused
## room's cost, build time and draw, or while placing the ghost's state and a Build button
## (one click). (B) or Esc on a palette button returns focus to the plan.
## Bible: docs/content/m2-base.md sections 4 and 6

## Emitted when the player picks [param def_id] to place.
signal room_picked(def_id: StringName)
## Emitted when the player presses the Build button while placing.
signal build_held
## Emitted when the player leaves the palette with (B) or Esc.
signal back_requested

## Buildable rooms, in palette order.
const ROOMS: Array[StringName] = [
	&"room_power_plant",
	&"room_capacitor_bank",
	&"room_quarters",
	&"room_archive",
	&"room_physics_lab",
	&"room_workshop",
	&"room_infirmary",
	&"room_lift",
	&"room_stairs",
	&"room_corridor",
]

var _rooms: HFlowContainer = HFlowContainer.new()
var _dig: DigButton = DigButton.new()
var _hint: Label = Label.new()
var _build: Button = Button.new()
var _buttons: Dictionary[StringName, Button] = {}
var _defs: Dictionary = {}
var _message: String = ""


func _init() -> void:
	add_theme_constant_override(&"separation", 4)
	_rooms.add_theme_constant_override(&"h_separation", 4)
	_rooms.add_theme_constant_override(&"v_separation", 4)
	add_child(_rooms)
	var title := Label.new()
	title.text = "BASE_BUILD_TITLE"
	_rooms.add_child(title)
	var line := HBoxContainer.new()
	add_child(line)
	_hint.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_hint.size_flags_horizontal = SIZE_EXPAND_FILL
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint.clip_text = true
	line.add_child(_hint)
	_build.text = "BASE_BUILD_BUILD"
	_build.visible = false
	_build.pressed.connect(build_held.emit)
	line.add_child(_dig)
	line.add_child(_build)


## Fills the palette with the rooms of [param defs] (RoomDef by id) that are in [constant ROOMS].
func show_rooms(defs: Dictionary) -> void:
	_defs = defs
	for button: Button in _buttons.values():
		button.queue_free()
	_buttons.clear()
	for def_id: StringName in ROOMS:
		var def: RoomDef = defs.get(def_id)
		if def == null:
			continue
		var button := Button.new()
		button.text = def.name_key
		button.pressed.connect(room_picked.emit.bind(def_id))
		button.mouse_entered.connect(_show_summary.bind(def_id))
		button.focus_entered.connect(_show_summary.bind(def_id))
		button.gui_input.connect(_on_button_input)
		_rooms.add_child(button)
		_buttons[def_id] = button
	_refresh_hint()


## Returns the Dig button.
func get_dig_button() -> DigButton:
	return _dig


## Returns the Build button shown while placing.
func get_build_button() -> Button:
	return _build


## Returns the button of [param def_id], or null.
func get_room_button(def_id: StringName) -> Button:
	return _buttons.get(def_id)


## Returns the first room button, for focus; null when there is none.
func first_button() -> Button:
	return null if _buttons.is_empty() else _buttons.values()[0]


## Shows [param text] on the hint line until the next hover or message.
func show_message(text: String) -> void:
	_message = text
	_refresh_hint()


## Returns the hint line's text.
func get_hint() -> String:
	return _hint.text


## Shows or hides the Build button; [param valid] enables it.
func set_placing(on: bool, valid: bool) -> void:
	_build.visible = on
	_build.disabled = not valid
	_dig.visible = not on


func _show_summary(def_id: StringName) -> void:
	var def: RoomDef = _defs.get(def_id)
	if def != null:
		show_message(BuildText.summary(def))


func _refresh_hint() -> void:
	_hint.text = _message if not _message.is_empty() else tr(&"BASE_BUILD_HINT")
	_hint.tooltip_text = _hint.text


func _on_button_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		accept_event()
		back_requested.emit()
