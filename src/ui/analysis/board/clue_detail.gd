class_name ClueDetail
extends PanelContainer
## The detail panel of the Analysis Board, M1's stand-in for the Archive: one clue in full
## (text, source, grade, date, tags, links) with the player's tools for it: mark suspect, add
## and remove tags, unlink, and start a move or a link. The panel changes nothing itself: it
## emits the note the player wants and the board submits it.
## Bible: gate-and-address-spec.md#player-tools

## Emitted with the whole new note when the player changes tags or the suspect mark.
signal note_edited(clue_id: StringName, note: ClueNote)
## Emitted when the player unlinks clue [param other_id] from [param clue_id].
signal unlink_requested(clue_id: StringName, other_id: StringName)
## Emitted when the player asks to move the card with the arrows.
signal move_requested(clue_id: StringName)
## Emitted when the player asks to link the card to another one.
signal link_requested(clue_id: StringName)
## Emitted when the panel is closed, by its button or by Cancel.
signal closed

var _clue_id: StringName = &""
var _note: ClueNote = ClueNote.new()

@onready var _grade_label: Label = %GradeLabel
@onready var _source_label: Label = %SourceLabel
@onready var _date_label: Label = %DateLabel
@onready var _text_label: Label = %TextLabel
@onready var _tags_box: HFlowContainer = %TagsBox
@onready var _tag_edit: LineEdit = %TagEdit
@onready var _tag_add: Button = %TagAddButton
@onready var _links_box: VBoxContainer = %LinksBox
@onready var _suspect_button: Button = %SuspectButton
@onready var _move_button: Button = %MoveButton
@onready var _link_button: Button = %LinkButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	_tag_edit.max_length = ClueNote.MAX_TAG_LENGTH
	_tag_edit.text_submitted.connect(_on_tag_submitted)
	_tag_add.pressed.connect(_on_tag_add_pressed)
	_suspect_button.pressed.connect(_on_suspect_pressed)
	_move_button.pressed.connect(func() -> void: move_requested.emit(_clue_id))
	_link_button.pressed.connect(func() -> void: link_requested.emit(_clue_id))
	_close_button.pressed.connect(func() -> void: closed.emit())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


## Shows clue [param record] with the filled-in [param text] and the player's [param note].
## [param link_texts] maps each linked clue id to the text to show for it.
func show_clue(
	record: ClueRecord, text: String, note: ClueNote, link_texts: Dictionary[StringName, String]
) -> void:
	_clue_id = record.id
	_note = ClueNote.from_dict(note.to_dict())
	_grade_label.text = ClueCard.grade_letter(record.grade)
	_source_label.text = tr(&"BOARD_DETAIL_SOURCE").format({"source": tr(record.source_key)})
	_date_label.text = tr(&"BOARD_DETAIL_DATE").format(
		{"date": ClueCard.date_text(record.received_tick)}
	)
	_text_label.text = text
	_suspect_button.text = &"BOARD_SUSPECT_CLEAR" if note.is_suspect else &"BOARD_SUSPECT_SET"
	_tag_add.disabled = false
	_fill_tags()
	_fill_links(link_texts)
	show()


## Returns the id of the clue shown.
func get_clue_id() -> StringName:
	return _clue_id


## Returns the full clue text shown.
func get_clue_text() -> String:
	return _text_label.text


## Returns the grade letter shown.
func get_grade_text() -> String:
	return _grade_label.text


## Returns the tags shown, in order.
func get_tag_texts() -> Array[String]:
	return _note.tags.duplicate()


## Returns the ids of the linked clues shown, in order.
func get_link_ids() -> Array[StringName]:
	return _note.links.duplicate()


## Returns the button that marks or clears the suspect mark.
func get_suspect_button() -> Button:
	return _suspect_button


## Returns the button that starts a move.
func get_move_button() -> Button:
	return _move_button


## Returns the button that starts a link.
func get_link_button() -> Button:
	return _link_button


## Returns the field new tags are typed in.
func get_tag_edit() -> LineEdit:
	return _tag_edit


## Returns the control that takes focus when the panel opens.
func get_default_focus() -> Control:
	return _close_button


func _fill_tags() -> void:
	_clear(_tags_box)
	for tag: String in _note.tags:
		var chip: Button = Button.new()
		chip.text = tag + " ×"
		chip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		chip.tooltip_text = tr(&"BOARD_TAG_REMOVE")
		chip.pressed.connect(_on_tag_removed.bind(tag))
		_tags_box.add_child(chip)


func _fill_links(link_texts: Dictionary[StringName, String]) -> void:
	_clear(_links_box)
	for other_id: StringName in _note.links:
		var row: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.text = link_texts.get(other_id, String(other_id))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var unlink: Button = Button.new()
		unlink.text = &"BOARD_UNLINK"
		unlink.pressed.connect(func() -> void: unlink_requested.emit(_clue_id, other_id))
		row.add_child(label)
		row.add_child(unlink)
		_links_box.add_child(row)


func _clear(box: Container) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _on_tag_submitted(_text: String) -> void:
	_on_tag_add_pressed()


func _on_tag_add_pressed() -> void:
	var tag: String = _tag_edit.text.strip_edges()
	_tag_edit.clear()
	if tag.is_empty() or _note.tags.has(tag):
		return
	var edited: ClueNote = ClueNote.from_dict(_note.to_dict())
	edited.tags.append(tag)
	if ClueNote.validate_dict(edited.to_dict()).is_empty():
		note_edited.emit(_clue_id, edited)


func _on_tag_removed(tag: String) -> void:
	var edited: ClueNote = ClueNote.from_dict(_note.to_dict())
	edited.tags.erase(tag)
	note_edited.emit(_clue_id, edited)


func _on_suspect_pressed() -> void:
	var edited: ClueNote = ClueNote.from_dict(_note.to_dict())
	edited.is_suspect = not edited.is_suspect
	note_edited.emit(_clue_id, edited)
