class_name CandidateRow
extends VBoxContainer
## One address that still fits the Address Workbench draft: its eight glyphs, its lock energy,
## whether it is already in the dial queue, and "Send to dial queue".
## Bible: gate-and-address-spec.md#player-tools,
## gate-and-address-spec.md#dialing-outcomes-and-energy

## The player pressed "Send to dial queue" for [param address].
signal send_pressed(address: GateAddress)

## Side of each glyph drawing, in pixels.
const GLYPH_SIZE: Vector2 = Vector2(28, 28)

var _address: GateAddress = null

@onready var _glyph_box: HBoxContainer = %Glyphs
@onready var _energy: Label = %Energy
@onready var _queued: Label = %Queued
@onready var _send: Button = %Send


func _ready() -> void:
	_send.pressed.connect(func() -> void: send_pressed.emit(_address))


## Shows [param address] with [param energy_text] and the tooltip [param names] (its glyph
## names in order).
func show_candidate(address: GateAddress, energy_text: String, names: String) -> void:
	_address = address
	for child: Node in _glyph_box.get_children():
		_glyph_box.remove_child(child)
		child.queue_free()
	for glyph: int in address.seals():
		var icon: GlyphIcon = GlyphIcon.new()
		icon.custom_minimum_size = GLYPH_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.glyph_index = glyph
		_glyph_box.add_child(icon)
	_energy.text = energy_text
	_send.tooltip_text = names


## Shows whether the address is already in the dial queue.
func show_queued(is_queued: bool) -> void:
	_queued.visible = is_queued


## Returns the address shown.
func get_address() -> GateAddress:
	return _address


## Returns the "Send to dial queue" button.
func get_send_button() -> Button:
	return _send


## True when the "in queue" mark shows.
func is_marked_queued() -> bool:
	return _queued.visible
