class_name OutcomeBanner
extends HBoxContainer
## Shows the result of the last dial: a shape icon per outcome, the outcome's name, what it
## means for the player (the bible's "what the player learns") and a short caption line for
## screen readers and the future captions setting. While seals engage it says so. It never
## names the world; the designation belongs to the wormhole panel and the log, and only for a
## lock.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## game-design.md#difficulty-and-accessibility (captions)

var _simulation: Simulation = null
## The outcome shown: a DialOutcome.Kind value, or -1 for none.
var _kind: int = -1
var _is_dialing: bool = false

@onready var _icon: OutcomeIcon = %Icon
@onready var _name_label: Label = %Name
@onready var _meaning: Label = %Meaning
@onready var _caption: Label = %Caption


func _ready() -> void:
	_render()


func _enter_tree() -> void:
	EventBus.dial_started.connect(_on_dial_started)
	EventBus.dial_resolved.connect(_on_dial_resolved)


func _exit_tree() -> void:
	EventBus.dial_started.disconnect(_on_dial_started)
	EventBus.dial_resolved.disconnect(_on_dial_resolved)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_render()


## Connects the banner to [param simulation] and shows its latest outcome, if any.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	var gate: GateState = simulation.state.gate
	_is_dialing = gate.mode == GateState.RingMode.DIALING
	_kind = -1
	if not gate.dial_log.is_empty():
		_kind = gate.dial_log[gate.dial_log.size() - 1].outcome
	if is_node_ready():
		_render()


## Returns the outcome shown (a DialOutcome.Kind value), or -1 when none is.
func get_shown_kind() -> int:
	return _kind


## Returns the outcome's name line.
func get_name_text() -> String:
	return _name_label.text


## Returns the meaning line.
func get_meaning_text() -> String:
	return _meaning.text


## Returns the caption line.
func get_caption_text() -> String:
	return _caption.text


## Returns the icon.
func get_icon() -> OutcomeIcon:
	return _icon


func _render() -> void:
	_icon.kind = _kind
	if _is_dialing:
		_set_texts(tr("GATE_BANNER_DIALING"), tr("GATE_BANNER_DIALING_MEANING"), "")
	elif _kind < 0:
		_set_texts(tr("GATE_BANNER_NONE"), tr("GATE_BANNER_NONE_MEANING"), "")
	else:
		_set_texts(
			GateRoomFormat.outcome_name(_kind),
			GateRoomFormat.outcome_meaning(_kind),
			GateRoomFormat.outcome_caption(_kind)
		)
	_icon.accessibility_name = _name_label.text
	_caption.visible = not _caption.text.is_empty()


func _set_texts(name_text: String, meaning_text: String, caption_text: String) -> void:
	_name_label.text = name_text
	_meaning.text = meaning_text
	_caption.text = caption_text


func _on_dial_started(_address_key: String) -> void:
	_is_dialing = true
	_kind = -1
	_render()


func _on_dial_resolved(outcome: int, _address_key: String) -> void:
	_is_dialing = false
	_kind = outcome
	_render()
