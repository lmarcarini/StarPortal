class_name DestinationRack
extends VBoxContainer
## The rack of destination cards on the right wall of the Gate station: a filter key on top
## (all, with team, unvisited), every Address Book entry as a card in rack order, scrolling
## when there are more than fit, and + NEW ADDRESS at the foot.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Destinations)

## A card was chosen: put [param destination] on the monitor.
signal destination_selected(destination: GateDestination)
## + NEW ADDRESS was pressed: open the alien panel.
signal new_address_requested
## A card's TEAM key asked for a mission order to [param destination].
signal order_requested(destination: GateDestination)
## A card was flipped: show the report of [param world_id] (&"" for none) with the note of
## Address Book entry [param key].
signal report_requested(world_id: StringName, key: String)

const _FILTER_ICONS: Array[StringName] = [&"base", &"team", &"probed"]
const _FILTER_HELP: Array[String] = [
	"STATION_FILTER_ALL", "STATION_FILTER_TEAM", "STATION_FILTER_UNVISITED"
]

var _simulation: Simulation = null
var _filter: DestinationText.Filter = DestinationText.Filter.ALL
var _pins: Dictionary[String, bool] = {}
var _selected_key: String = ""
var _filter_key: IconKey = IconKey.new()
var _scroll: ScrollContainer = ScrollContainer.new()
var _cards: VBoxContainer = VBoxContainer.new()
var _new: IconKey = IconKey.new()


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	_filter_key.name = "FilterKey"
	_filter_key.pressed.connect(cycle_filter)
	add_child(_filter_key)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_cards)
	add_child(_scroll)
	_new.name = "NewAddress"
	_new.icon_id = &"new"
	_new.set_help("STATION_NEW_ADDRESS")
	_new.pressed.connect(new_address_requested.emit)
	add_child(_new)
	_show_filter()


func _enter_tree() -> void:
	EventBus.address_book_changed.connect(rebuild)
	EventBus.world_status_changed.connect(_on_world_changed)


func _exit_tree() -> void:
	EventBus.address_book_changed.disconnect(rebuild)
	EventBus.world_status_changed.disconnect(_on_world_changed)


## Reads [param simulation]'s Address Book.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_selected_key = ""
	rebuild()


## Rebuilds the cards from the Address Book.
func rebuild() -> void:
	if _simulation == null or not is_node_ready():
		return
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	var state: GameState = _simulation.state
	for entry: AddressEntry in DestinationText.ordered(state, _pins, _filter):
		var card: DestinationCard = DestinationCard.new()
		card.show_destination(
			destination_of(entry, state), entry.address_key, _pins.has(entry.address_key)
		)
		card.button_pressed = entry.address_key == _selected_key
		card.selected.connect(_on_selected)
		card.flipped.connect(_on_flipped)
		card.pin_toggled.connect(_on_pin)
		card.order_requested.connect(
			func(c: DestinationCard) -> void: order_requested.emit(c.get_destination())
		)
		_cards.add_child(card)


## The cards in order.
func get_cards() -> Array[DestinationCard]:
	var out: Array[DestinationCard] = []
	for child: Node in _cards.get_children():
		if child is DestinationCard and not child.is_queued_for_deletion():
			out.append(child as DestinationCard)
	return out


## Moves to the next filter.
func cycle_filter() -> void:
	_filter = ((_filter + 1) % _FILTER_ICONS.size()) as DestinationText.Filter
	_show_filter()
	rebuild()


## The filter in use.
func get_filter() -> DestinationText.Filter:
	return _filter


## The destination for [param entry].
static func destination_of(entry: AddressEntry, state: GameState) -> GateDestination:
	var d: GateDestination = GateDestination.of(
		DestinationText.address_of(entry), DestinationText.title_of(entry, state), entry.world_id
	)
	d.icons = DestinationText.icons_of(entry, state)
	return d


func _show_filter() -> void:
	_filter_key.icon_id = _FILTER_ICONS[_filter]
	_filter_key.set_help(_FILTER_HELP[_filter])


func _on_selected(card: DestinationCard) -> void:
	_selected_key = card.get_key()
	for other: DestinationCard in get_cards():
		other.set_pressed_no_signal(other == card)
		other.queue_redraw()
	destination_selected.emit(card.get_destination())


func _on_flipped(card: DestinationCard) -> void:
	report_requested.emit(card.get_destination().world_id, card.get_key())


func _on_pin(card: DestinationCard) -> void:
	if _pins.has(card.get_key()):
		_pins.erase(card.get_key())
	else:
		_pins[card.get_key()] = true
	rebuild()


func _on_world_changed(_world_id: StringName, _status: int) -> void:
	rebuild()
