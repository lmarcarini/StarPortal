class_name ResultCard
extends Control
## The short card after a dial that did not open a wormhole (No gate, Blocked, Origin
## rejected): the outcome's icon and name, what the player learns, a caption line, the energy
## the dial spent and OK. It never names the world. OK, accept or cancel (Escape, gamepad B)
## dismisses it. Reads a Dial Log entry; changes nothing.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## gate-and-address-spec.md#dialing-outcomes-and-energy,
## game-design.md#difficulty-and-accessibility (status by shape, captions)

## The player dismissed the card.
signal dismissed

## The entry shown; null while the card is closed.
var _entry: DialLogEntry = null

@onready var _icon: OutcomeIcon = %Icon
@onready var _name_label: Label = %Name
@onready var _meaning: Label = %Meaning
@onready var _caption: Label = %Caption
@onready var _energy: Label = %Energy
@onready var _ok: Button = %OkButton


func _ready() -> void:
	_ok.pressed.connect(dismiss)
	OverlayFocus.trap(_ok)
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_render()


func _unhandled_input(event: InputEvent) -> void:
	if _entry == null or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		dismiss()


## Shows the result of [param entry] and focuses OK when the card is on screen.
func show_entry(entry: DialLogEntry) -> void:
	if entry == null:
		return
	_entry = entry
	_render()
	show()
	if is_visible_in_tree():
		_ok.grab_focus()


## Hides the card and emits [signal dismissed]. Does nothing while closed.
func dismiss() -> void:
	if _entry == null:
		return
	close()
	dismissed.emit()


## Hides the card without emitting, e.g. when a new dial starts or a game is loaded.
func close() -> void:
	_entry = null
	hide()


## True while the card shows a result.
func is_open() -> bool:
	return _entry != null


## Returns the OK button.
func get_ok_button() -> Button:
	return _ok


## Returns the outcome shown (a DialOutcome.Kind value), or -1 while closed.
func get_shown_kind() -> int:
	return _entry.outcome if _entry != null else -1


## Returns the outcome's name line.
func get_name_text() -> String:
	return _name_label.text


## Returns what the player learns.
func get_meaning_text() -> String:
	return _meaning.text


## Returns the caption line.
func get_caption_text() -> String:
	return _caption.text


## Returns the energy line, e.g. "Energy spent: 30.0 MWh".
func get_energy_text() -> String:
	return _energy.text


func _render() -> void:
	if _entry == null:
		return
	var kind: int = _entry.outcome
	_icon.kind = kind
	_name_label.text = GateRoomFormat.outcome_name(kind)
	_icon.accessibility_name = _name_label.text
	_meaning.text = GateRoomFormat.outcome_meaning(kind)
	_caption.text = GateRoomFormat.outcome_caption(kind)
	var spent: String = GateRoomFormat.energy(_entry.energy_spent_mwh)
	_energy.text = tr("GATE_LOG_ENERGY").format({"energy": spent})
