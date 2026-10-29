class_name AddressBookRow
extends Button
## One Address Book entry, readable at a glance: the address as large glyph icons, then one line
## with the last outcome's icon, where the address came from and the world's name when known.
## The outcome's name is in the tooltip, and the player's note shows only while the row is
## selected. Pressing the row selects it (it shows pressed); the panel's Load button then fills
## the console's slots.
## Bible: gate-and-address-spec.md#the-dial-console (Address Book),
## game-design.md#difficulty-and-accessibility (status by shape as well as colour)

## The player pressed this row.
signal chosen(address_key: String)

var _entry: AddressEntry = null
var _state: GameState = null

@onready var _content: Control = %Content
@onready var _strip: AddressStrip = %Strip
@onready var _icon: OutcomeIcon = %Icon
@onready var _details: Label = %Details
@onready var _note: Label = %Note


func _ready() -> void:
	pressed.connect(func() -> void: chosen.emit(get_address_key()))
	_content.minimum_size_changed.connect(update_minimum_size)
	_show()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_show()


func _get_minimum_size() -> Vector2:
	if _content == null:
		return Vector2.ZERO
	return _content.get_combined_minimum_size() + Vector2(16, 8)


## Shows [param entry]; [param state] names its source and world.
func setup(entry: AddressEntry, state: GameState) -> void:
	_entry = entry
	_state = state
	if is_node_ready():
		_show()


## Returns the entry shown, or null.
func get_entry() -> AddressEntry:
	return _entry


## Returns the shown entry's address key, or "".
func get_address_key() -> String:
	return _entry.address_key if _entry != null else ""


## Shows the row as selected (pressed, its note shown) or not.
func set_selected(selected: bool) -> void:
	set_pressed_no_signal(selected)
	_note.visible = selected and not _note.text.is_empty()


## Returns the line naming the source and, when known, the world.
func get_details_text() -> String:
	return _details.text


## Returns the note line; empty when the entry has no note.
func get_note_text() -> String:
	return _note.text


func _show() -> void:
	if _entry == null:
		return
	_strip.setup(address_of(_entry.address_key))
	_icon.kind = _entry.last_outcome
	var outcome: String = tr(&"BOOK_NOT_DIALED")
	if _entry.last_outcome >= 0:
		outcome = GateRoomFormat.outcome_name(_entry.last_outcome)
	var source: String = AddressBookText.source_text(_entry, _state)
	var world: String = AddressBookText.world_text(_entry, _state)
	if world.is_empty():
		world = tr(&"BOOK_WORLD_UNKNOWN")
	_details.text = tr(&"BOOK_ROW_DETAILS").format({"source": source, "world": world})
	_note.text = _entry.note
	_note.visible = button_pressed and not _entry.note.is_empty()
	tooltip_text = (
		"%s\n%s" % [GateRoomFormat.address_text(address_of(_entry.address_key)), outcome]
	)


## Returns the address of valid key [param key].
static func address_of(key: String) -> GateAddress:
	var seals: Array[int] = AddressEntry.glyphs_of(key)
	var origin: int = seals.pop_back()
	return GateAddress.create(seals, origin)
