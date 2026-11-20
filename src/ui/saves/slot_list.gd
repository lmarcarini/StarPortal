class_name SlotList
extends VBoxContainer
## The list of save slots (SaveService.list_all_slots, newest first), in LOAD or SAVE mode.
## LOAD: choosing a usable row emits [signal slot_chosen]; unusable rows are greyed with the
## reason. SAVE: choosing a row asks to confirm the overwrite (choose it again); a new name can
## be typed (checked by SaveService.is_valid_slot_name). Back emits [signal cancelled].
## Bible: docs/bible/technical-architecture.md#save-and-load (M4.6-02)

## The player chose [param slot] (to load, or to save into).
signal slot_chosen(slot: StringName)
## The player backed out.
signal cancelled

## LOAD or SAVE.
enum Mode { LOAD, SAVE }

## The name field for a new save, and its Save key.
var name_field := LineEdit.new()
var save_new_button := RefKey.new()
## A hint or the confirm question.
var note := Label.new()
## Goes back.
var back_button := RefKey.new()

var _mode: Mode = Mode.LOAD
var _rows := VBoxContainer.new()
var _confirming: StringName = &""
var _new_row := HBoxContainer.new()


func _init() -> void:
	name = &"SlotList"
	add_theme_constant_override(&"separation", 10)
	_rows.add_theme_constant_override(&"separation", 8)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	SlotListLook.well(scroll)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	add_child(scroll)
	name_field.placeholder_text = "SAVES_NEW_NAME"
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SlotListLook.field(name_field)
	_new_row.add_theme_constant_override(&"separation", 10)
	name_field.text_submitted.connect(func(_text: String) -> void: save_new())
	_new_row.add_child(name_field)
	SlotListLook.key(save_new_button, &"SAVES_SAVE_NEW", 200.0)
	save_new_button.pressed.connect(save_new)
	_new_row.add_child(save_new_button)
	add_child(_new_row)
	SlotListLook.note(note)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	SlotListLook.key(back_button, &"SAVES_BACK", 520.0)
	back_button.pressed.connect(cancelled.emit)
	add_child(back_button)


## LOAD or SAVE, as last shown.
func mode() -> Mode:
	return _mode


## Fills the list for [param mode] from the save folder.
func show_mode(mode: Mode) -> void:
	_mode = mode
	_confirming = &""
	note.text = ""
	_new_row.visible = mode == Mode.SAVE
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for entry: Dictionary in SaveService.list_all_slots():
		_rows.add_child(_row(entry))


## The row buttons, newest first.
func rows() -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in _rows.get_children():
		if child is Button and not child.is_queued_for_deletion():
			found.append(child as Button)
	return found


## The first control to focus: the first usable row, or the name field, or Back.
func first_focus() -> Control:
	for button: Button in rows():
		if not button.disabled:
			return button
	return name_field if _new_row.visible else back_button


## Saves under the typed name when it is valid, else says why.
func save_new() -> void:
	var slot := StringName(name_field.text.strip_edges())
	if not SaveService.is_valid_slot_name(slot):
		note.text = tr(&"SAVES_BAD_NAME")
		return
	choose(slot)


## Chooses [param slot]: loads it, or saves into it (asking first when it exists).
func choose(slot: StringName) -> void:
	var exists: bool = FileAccess.file_exists(SaveService.slot_path(slot))
	if _mode == Mode.SAVE and exists and _confirming != slot:
		_confirming = slot
		note.text = tr(&"SAVES_CONFIRM_OVERWRITE").format({"slot": slot})
		return
	_confirming = &""
	slot_chosen.emit(slot)


func _row(entry: Dictionary) -> Button:
	var button := SlotRow.new()
	button.text = SlotText.row(entry)
	var slot: StringName = entry["slot"]
	var usable: bool = StringName(str(entry.get("error", ""))) == &""
	button.disabled = _mode == Mode.LOAD and not usable
	button.pressed.connect(choose.bind(slot))
	return button
