class_name BuildPalette
extends VBoxContainer
## The Base tab's build palette (docs/content/m2-base.md section 6): one button per buildable
## room in catalogue order and the "Dig Level N" entry (greyed with "Unlock: <project>" while
## research locks it; held to dig), then a line that shows the hovered or focused
## room's cost, build time and draw, or while placing the ghost's state and a Build button
## (one click), and under it the room's "now" line. Only rooms research has unlocked are
## offered; one that can't be built right now (a cap reached) shows greyed with the reason.
## While placing, the picked room's entry shows pressed (pressing it again puts the ghost away)
## and a Cancel button sits next to Build. (B) or Esc on a palette button returns to the plan.
## Bible: docs/content/m2-base.md sections 4 and 6; docs/content/m25-lean-start.md section 4;
## docs/content/m26-staff-and-money.md section 3 (Quarters buildable from the start)

## Emitted when the player picks [param def_id] to place.
signal room_picked(def_id: StringName)
## Emitted when the player presses the Build button while placing.
signal build_held
## Emitted when the player presses the Cancel button while placing.
signal cancel_held
## Emitted when the player leaves the palette with (B) or Esc.
signal back_requested
## Emitted with each message shown (the POWER tray shows the power news, M6-04).
signal message_shown(text: String)

## Buildable rooms, in palette order. The Infirmary shows only from the Expeditions unlock
## (m3-beyond-the-ring.md section 9): no research unlocks it.
## The palette entry for a blast door (M4c-04): not a RoomDef; the ghost places one cell.
const DOOR_ID: StringName = &"blast_door"

const ROOMS: Array[StringName] = [
	&"room_quarters",
	&"room_research_lab",
	&"room_power_plant",
	&"room_capacitor_bank",
	&"room_workshop",
	&"room_personnel_office",
	&"room_xenotech_lab",
	&"room_bio_lab",
	&"room_ready_room",
	&"room_infirmary",
	&"room_artefact_vault",
	&"room_containment",
	&"room_security_post",
	&"room_lift",
	&"room_stairs",
	&"room_corridor",
]

## Extra lines shown under a room's "now" line on hover or focus, as {def id: text}; set by
## the Base view (the second Research Lab note, m25-lean-start.md section 3).
var notes: Dictionary[StringName, String] = {}
## The message line: the hint, and the Build and Cancel buttons while placing. The Base view
## moves it out of the palette, so the Energy sub-tab shows it too.
var message_line: HBoxContainer = HBoxContainer.new()

var _rooms: HBoxContainer = HBoxContainer.new()
var _scroll: ScrollContainer = ScrollContainer.new()
var _dig: DigButton = DigButton.new()
var _hint: Label = Label.new()
var _build: Button = Button.new()
var _cancel: Button = Button.new()
var _role: Label = Label.new()
var _buttons: Dictionary[StringName, Button] = {}
var _defs: Dictionary[StringName, RoomDef] = {}
var _message: String = ""
var _shown_unlocks: Array[StringName] = []
var _blocked: Dictionary[StringName, String] = {}
var _picked: StringName = &""


func _init() -> void:
	add_theme_constant_override(&"separation", 4)
	_rooms.add_theme_constant_override(&"separation", 8)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.custom_minimum_size = Vector2(0, RoomCardKey.SIZE.y + 16)
	_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.add_child(_rooms)
	add_child(_scroll)
	TrayArrow.new().attach(_scroll)
	var line := message_line
	add_child(line)
	_hint.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_hint.size_flags_horizontal = SIZE_EXPAND_FILL
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint.clip_text = true
	line.add_child(_hint)
	_build.text = "BASE_BUILD_BUILD"
	_build.visible = false
	_build.pressed.connect(build_held.emit)
	_dig.visible = false
	add_child(_dig)
	_dig.mouse_entered.connect(_show_dig_summary)
	_dig.focus_entered.connect(_show_dig_summary)
	line.add_child(_build)
	_cancel.text = "BASE_BUILD_CANCEL_PLACING"
	_cancel.visible = false
	_cancel.pressed.connect(cancel_held.emit)
	line.add_child(_cancel)
	_role.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_role.add_theme_font_size_override(&"font_size", 14)
	_role.visible = false
	add_child(_role)
	line.visible = false


## Fills the palette with the rooms of [param defs] (RoomDef by id) in [constant ROOMS] that
## are in [param unlocked] (UnlockState.rooms): a room whose plan is not known is not shown
## at all (M7-02: no locked cards). A room in [param blocked] (def id: reason) is unlocked
## but can't be built right now
## (the Capacitor Bank cap, say): it shows greyed, its line giving the reason (owner change
## 2026-11-14).
func show_rooms(
	defs: Dictionary, unlocked: Array[StringName], blocked: Dictionary[StringName, String] = {}
) -> void:
	_defs.assign(defs)
	_shown_unlocks = unlocked.duplicate()
	_blocked = blocked.duplicate()
	for button: Button in _buttons.values():
		button.queue_free()
	_buttons.clear()
	for def_id: StringName in ROOMS:
		var def: RoomDef = _defs.get(def_id)
		if def == null or not def_id in unlocked:
			continue
		var button: RoomCardKey = _card(def_id, def)
		button.disabled = _blocked.has(def_id)
		if _blocked.has(def_id):
			button.set_help(_blocked[def_id])
		else:
			button.set_help(BuildText.summary(def))
		button.set_pressed_no_signal(def_id == _picked)
		button.pressed.connect(room_picked.emit.bind(def_id))
		button.mouse_entered.connect(_show_summary.bind(def_id))
		button.focus_entered.connect(_show_summary.bind(def_id))
		button.gui_input.connect(_on_button_input)
		_rooms.add_child(button)
		_buttons[def_id] = button
	_add_door_button()
	_refresh_hint()


func _card(def_id: StringName, def: RoomDef) -> RoomCardKey:
	var card := RoomCardKey.new()
	card.name = String(def_id)
	card.def_id = def_id
	card.text = def.name_key
	card.title = BuildCardText.title(def)
	card.price = BaseTableSetup.short_money(def.build_cost_k)
	card.cells = "%d×%d" % [def.size_cells.x, def.size_cells.y]
	return card


func _add_door_button() -> void:
	var button := RoomCardKey.new()
	button.text = &"BASE_DOOR_NAME"
	button.title = tr(&"BASE_DOOR_NAME").to_upper()
	button.def_id = DOOR_ID
	button.cells = "1×1"
	button.set_help(tr(&"BASE_DOOR_SUMMARY"))
	button.set_pressed_no_signal(_picked == DOOR_ID)
	button.pressed.connect(room_picked.emit.bind(DOOR_ID))
	button.mouse_entered.connect(show_message.bind(tr(&"BASE_DOOR_SUMMARY")))
	button.focus_entered.connect(show_message.bind(tr(&"BASE_DOOR_SUMMARY")))
	button.gui_input.connect(_on_button_input)
	_rooms.add_child(button)
	_buttons[DOOR_ID] = button


## The line under the hint for [param def_id]: its "now" line, or "Unlock: <project>" while
## research locks it; "" for a room not shown.
func role_line(def_id: StringName) -> String:
	var button: Button = _buttons.get(def_id)
	if button == null:
		return ""
	if button.disabled:
		return _blocked.get(def_id, "")
	return BasePanelText.now(_defs[def_id])


## Returns the line under the hint ("" when hidden).
func get_role() -> String:
	return _role.text if _role.visible else ""


## True when [param unlocked] or [param blocked] differs from what the palette was last
## filled for.
func unlocks_changed(
	unlocked: Array[StringName], blocked: Dictionary[StringName, String] = {}
) -> bool:
	return unlocked != _shown_unlocks or blocked != _blocked


## Returns the Dig button.
func get_dig_button() -> DigButton:
	return _dig


## Returns the Build button shown while placing.
func get_build_button() -> Button:
	return _build


## Returns the Cancel button shown while placing.
func get_cancel_button() -> Button:
	return _cancel


## Shows the entry of [param def_id] pressed and the others not (&"" for none).
func mark_picked(def_id: StringName) -> void:
	_picked = def_id
	for id: StringName in _buttons:
		_buttons[id].set_pressed_no_signal(id == def_id)


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
	message_shown.emit(text)
	_role.visible = false
	_refresh_hint()


## Returns the hint line's text.
func get_hint() -> String:
	return _hint.text


## Shows or hides the Build button; [param valid] enables it.
func set_placing(on: bool, valid: bool) -> void:
	_build.visible = on
	_build.disabled = not valid
	_cancel.visible = on


func _show_summary(def_id: StringName) -> void:
	var def: RoomDef = _defs.get(def_id)
	if def != null:
		show_message(BuildText.summary(def))
		_role.text = role_line(def_id)
		var note: String = notes.get(def_id, "")
		if not note.is_empty():
			_role.text = "%s\n%s" % [_role.text, note]
		_role.visible = not _role.text.is_empty()


## Hovering or focusing the Dig entry: its reason ("Unlock: Excavation survey") under the hint.
func _show_dig_summary() -> void:
	_role.text = _dig.get_reason()
	_role.visible = not _role.text.is_empty()


func _refresh_hint() -> void:
	_hint.text = _message if not _message.is_empty() else tr(&"BASE_BUILD_HINT")
	_hint.tooltip_text = _hint.text


func _on_button_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		accept_event()
		back_requested.emit()
