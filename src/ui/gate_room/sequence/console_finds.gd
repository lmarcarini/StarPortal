class_name ConsoleFinds
extends VBoxContainer
## The far Ring's console among the open wormhole's actions: Read the far Ring's console (posts
## a ReadConsoleCommand) while it is unread; once read, what it added to the Address Book as
## glyph rows (never a world's name: those stay unknown until locked). Open the Address Book is
## an action of its own beside it.
## Changes no state itself beyond submitting the command.
## Bible: gate-and-address-spec.md#where-addresses-come-from (Ring consoles),
## gate-and-address-spec.md#probing-the-unknown

## The buttons that can take focus changed (the console was read).
signal focus_changed

const _STRIP_SCENE: PackedScene = preload("res://src/ui/gate_room/address_strip.tscn")
const _ICON_SIZE: int = 24

var _simulation: Simulation = null

@onready var _read_button: Button = %ReadButton
@onready var _note: Label = %ConsoleNote
@onready var _found: VBoxContainer = %Found


func _ready() -> void:
	_read_button.pressed.connect(read)
	render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		render()


## Connects the panel to [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	render()


## Reads the console of the connected world (a ReadConsoleCommand), then shows what it added.
func read() -> void:
	if _simulation == null or _read_button.disabled:
		return
	_simulation.submit(ReadConsoleCommand.new())
	render()
	focus_changed.emit()


## True once the connected world's console has been read.
func is_read() -> bool:
	if _simulation == null:
		return false
	var state: GameState = _simulation.state
	return state.worlds.is_console_read(state.gate.connected_world_id)


## Returns the buttons that can take focus now, in order.
func get_focusables() -> Array[Control]:
	var found: Array[Control] = []
	if not _read_button.disabled:
		found.append(_read_button)
	return found


## Returns the Read the far Ring's console button.
func get_read_button() -> Button:
	return _read_button


## Returns the note under the button.
func get_note_text() -> String:
	return _note.text


## Returns the address strips of the addresses the console added, in log order.
func get_strips() -> Array[AddressStrip]:
	var strips: Array[AddressStrip] = []
	for child: Node in _found.get_children():
		if child is AddressStrip and not child.is_queued_for_deletion():
			strips.append(child as AddressStrip)
	return strips


## Shows the button and note for the connected world's console.
func render() -> void:
	if not is_node_ready():
		return
	var read_done: bool = is_read()
	_read_button.disabled = _simulation == null or read_done
	_read_button.focus_mode = Control.FOCUS_NONE if _read_button.disabled else Control.FOCUS_ALL
	var added: Array[String] = []
	if read_done:
		added = _added_keys()
	_show_strips(added)
	_note.text = _note_for(read_done, added.size())


## The addresses the console of the connected world put in the book, in log order.
func _added_keys() -> Array[String]:
	var state: GameState = _simulation.state
	var world_id: StringName = state.gate.connected_world_id
	var added: Array[String] = []
	for key: String in ReadConsoleCommand.listed_keys(state, world_id):
		var entry: AddressEntry = state.address_book.find(key)
		var is_ours: bool = entry != null and entry.source == AddressEntry.Source.CONSOLE
		if is_ours and entry.source_id == world_id:
			added.append(key)
	return added


func _show_strips(keys: Array[String]) -> void:
	for child: Node in _found.get_children():
		_found.remove_child(child)
		child.queue_free()
	for key: String in keys:
		var strip: AddressStrip = _STRIP_SCENE.instantiate() as AddressStrip
		strip.icon_size = _ICON_SIZE
		_found.add_child(strip)
		strip.setup(AddressBookRow.address_of(key))
	_found.visible = not keys.is_empty()


func _note_for(read_done: bool, added: int) -> String:
	if not read_done:
		return tr(&"GATE_CONSOLE_HINT")
	if added == 0:
		return tr(&"GATE_CONSOLE_NOTHING_NEW")
	if added == 1:
		return tr(&"GATE_CONSOLE_ADDED_ONE")
	return tr(&"GATE_CONSOLE_ADDED").format({"count": added})
