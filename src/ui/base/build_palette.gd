class_name BuildPalette
extends VBoxContainer
## The Base tab's build palette (docs/content/m2-base.md section 6): one button per buildable
## room in catalogue order, the Dig button, then a line that shows the hovered or focused
## room's cost, build time and draw, or while placing the ghost's state and a Build button
## (one click), and under it the room's "now" line. A room research still locks shows greyed
## (disabled) and its line reads "Unlock: <project>"; staff-locked rooms are not offered.
## (B) or Esc on a palette button returns focus to the plan.
## Bible: docs/content/m2-base.md sections 4 and 6; docs/content/m25-lean-start.md section 4;
## docs/content/m26-staff-and-money.md section 3 (Quarters buildable from the start)

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
	&"room_research_lab",
	&"room_quarters",
	&"room_workshop",
	&"room_lift",
	&"room_stairs",
	&"room_corridor",
]

## Extra lines shown under a room's "now" line on hover or focus, as {def id: text}; set by
## the Base view (the second Research Lab note, m25-lean-start.md section 3).
var notes: Dictionary[StringName, String] = {}

var _rooms: HFlowContainer = HFlowContainer.new()
var _dig: DigButton = DigButton.new()
var _hint: Label = Label.new()
var _build: Button = Button.new()
var _role: Label = Label.new()
var _buttons: Dictionary[StringName, Button] = {}
var _defs: Dictionary[StringName, RoomDef] = {}
var _message: String = ""
var _shown_unlocks: Array[StringName] = []


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
	_role.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_role.add_theme_font_size_override(&"font_size", 14)
	_role.visible = false
	add_child(_role)


## Fills the palette with the rooms of [param defs] (RoomDef by id) in [constant ROOMS]: those
## in [param unlocked] (UnlockState.rooms) can be picked; those a research project unlocks show
## disabled, saying which project; any other locked room (staff) is not offered.
func show_rooms(defs: Dictionary, unlocked: Array[StringName]) -> void:
	_defs.assign(defs)
	_shown_unlocks = unlocked.duplicate()
	for button: Button in _buttons.values():
		button.queue_free()
	_buttons.clear()
	for def_id: StringName in ROOMS:
		var def: RoomDef = _defs.get(def_id)
		if def == null or not _offered(def_id, unlocked):
			continue
		var button := Button.new()
		button.text = def.name_key
		button.disabled = not def_id in unlocked
		button.pressed.connect(room_picked.emit.bind(def_id))
		button.mouse_entered.connect(_show_summary.bind(def_id))
		button.focus_entered.connect(_show_summary.bind(def_id))
		button.gui_input.connect(_on_button_input)
		_rooms.add_child(button)
		_buttons[def_id] = button
	_refresh_hint()


## The line under the hint for [param def_id]: its "now" line, or "Unlock: <project>" while
## research locks it; "" for a room not shown.
func role_line(def_id: StringName) -> String:
	var button: Button = _buttons.get(def_id)
	if button == null:
		return ""
	if button.disabled:
		return BasePanelText.unlock(UnlockRules.project_for(UnlockRules.EFFECT_UNLOCK_ROOM, def_id))
	return BasePanelText.now(_defs[def_id])


## Returns the line under the hint ("" when hidden).
func get_role() -> String:
	return _role.text if _role.visible else ""


## True when [param unlocked] differs from the unlocks the palette was last filled for.
func unlocks_changed(unlocked: Array[StringName]) -> bool:
	return unlocked != _shown_unlocks


## Returns the Dig button.
func get_dig_button() -> DigButton:
	return _dig


## Returns the Build button shown while placing.
func get_build_button() -> Button:
	return _build


## Returns the button of [param def_id], or null.
func get_room_button(def_id: StringName) -> Button:
	return _buttons.get(def_id)


## Returns the first room button that can be picked, for focus; null when there is none.
func first_button() -> Button:
	for button: Button in _buttons.values():
		if not button.disabled:
			return button
	return null


## Shows [param text] on the hint line until the next hover or message.
func show_message(text: String) -> void:
	_message = text
	_role.visible = false
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
		_role.text = role_line(def_id)
		var note: String = notes.get(def_id, "")
		if not note.is_empty():
			_role.text = "%s\n%s" % [_role.text, note]
		_role.visible = not _role.text.is_empty()


static func _offered(def_id: StringName, unlocked: Array[StringName]) -> bool:
	if def_id in unlocked:
		return true
	return not UnlockRules.project_for(UnlockRules.EFFECT_UNLOCK_ROOM, def_id).is_empty()


func _refresh_hint() -> void:
	_hint.text = _message if not _message.is_empty() else tr(&"BASE_BUILD_HINT")
	_hint.tooltip_text = _hint.text


func _on_button_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		accept_event()
		back_requested.emit()
