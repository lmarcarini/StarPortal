class_name LogRow
extends Button
## One Dial Log entry: the date and time, the address, the outcome's icon and name, the energy
## spent and, for a lock only, the world's designation. The row is a focusable button so a
## gamepad can step through (and scroll) the log; pressing it does nothing.
## Bible: gate-and-address-spec.md#player-tools

var _entry: DialLogEntry = null
var _designation_text: String = ""

@onready var _date: Label = %Date
@onready var _icon: OutcomeIcon = %Icon
@onready var _outcome: Label = %Outcome
@onready var _strip: AddressStrip = %Strip
@onready var _energy: Label = %Energy
@onready var _designation: Label = %Designation


func _ready() -> void:
	_show()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_show()


## Shows [param entry]. [param designation] is the world's designation; it is shown only when
## the entry is a lock and is ignored for every other outcome.
func setup(entry: DialLogEntry, designation: String) -> void:
	_entry = entry
	_designation_text = designation
	if is_node_ready():
		_show()


## Returns the entry shown.
func get_entry() -> DialLogEntry:
	return _entry


## Returns the designation line; empty unless the entry is a lock.
func get_designation_text() -> String:
	return _designation.text if _designation.visible else ""


func _show() -> void:
	if _entry == null:
		return
	_date.text = GateRoomFormat.date_time(_entry.tick)
	_icon.kind = _entry.outcome
	_outcome.text = GateRoomFormat.outcome_name(_entry.outcome)
	_strip.setup(_entry.address)
	_energy.text = tr("GATE_LOG_ENERGY").format(
		{"energy": GateRoomFormat.energy(_entry.energy_spent_mwh)}
	)
	var is_lock: bool = DialOutcome.is_lock(_entry.outcome)
	_designation.visible = is_lock
	_designation.text = ""
	if is_lock:
		_designation.text = tr("GATE_LOG_DESTINATION").format({"designation": _designation_text})
	tooltip_text = GateRoomFormat.address_text(_entry.address)
