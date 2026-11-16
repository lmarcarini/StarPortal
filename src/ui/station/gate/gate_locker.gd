class_name GateLocker
extends HBoxContainer
## The locker high on the left of the Gate station: HOLDING (a crate, badged with the
## artefacts held; opens the artefact list on a paper card) and the MOTH order key (badged
## with the MOTHs owned of two; submits OrderMothCommand). Each key hides while it means
## nothing (no artefact yet, no MOTH rack); a refusal is the key's hover reason. The paper
## card is not the locker's child: its host adds it beside the locker (same parent).
## Bible: docs/content/interface-rethink.md section 4 (Gate), m4-core-systems.md (artefacts)

var _simulation: Simulation = null
var _holding: IconKey = IconKey.new()
var _order: IconKey = IconKey.new()
var _card: PaperCard = PaperCard.new()
var _artefacts: ArtefactPanel = ArtefactPanel.new()


func _ready() -> void:
	add_theme_constant_override(&"separation", 10)
	_holding.name = "HoldingKey"
	_holding.icon_id = &"crate"
	_holding.set_help("HW_ICON_CRATE")
	_holding.pressed.connect(toggle_holding)
	add_child(_holding)
	_order.name = "MothOrderKey"
	_order.icon_id = &"moth"
	_order.pressed.connect(order_moth)
	add_child(_order)
	_card.name = "HoldingCard"
	_card.visible = false
	_card.z_index = 6
	_card.custom_minimum_size = Vector2(520, 0)
	_card.add_child(_artefacts)
	_card.minimum_size_changed.connect(func() -> void: _card.reset_size())


## Reads [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_artefacts.setup(simulation)
	_card.visible = false
	refresh()


## Rereads the state.
func refresh() -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	_holding.visible = not state.artefacts.items.is_empty()
	_holding.badge_text = str(ArtefactRules.holding(state).size())
	if not _holding.visible:
		_card.visible = false
	_order.visible = MothRules.has_rack(state)
	_order.badge_text = "%d/2" % MothRules.owned(state)
	var check: CommandResult = OrderMothCommand.new().validate(state)
	_order.set_state(IconKey.KeyState.READY if check.is_ok else IconKey.KeyState.UNAVAILABLE)
	var reason: String = "GATE_ERR_" + String(check.error_code).to_upper()
	_order.set_help("STATION_ORDER_MOTH" if check.is_ok else reason)


## Opens or closes the artefact list.
func toggle_holding() -> void:
	_card.visible = not _card.visible and _holding.visible
	if _card.visible:
		_artefacts.refresh()
		_card.reset_size()
		_card.position = position + Vector2(0, size.y + 8.0)


## Orders a MOTH.
func order_moth() -> void:
	if _simulation != null:
		_simulation.submit(OrderMothCommand.new())
	refresh()


## The HOLDING key.
func get_holding_key() -> IconKey:
	return _holding


## The MOTH order key.
func get_order_key() -> IconKey:
	return _order


## The artefact list.
func get_artefacts() -> ArtefactPanel:
	return _artefacts


## The paper card holding the artefact list (the host adds it to the tree).
func get_card() -> PaperCard:
	return _card


func _process(_delta: float) -> void:
	refresh()
