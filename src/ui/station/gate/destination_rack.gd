class_name DestinationRack
extends Control
## The right panel DESTINATIONS (interface-reference.md section 5, right_panel): a steel
## plate with the header (Ring icon, title 24), the selected destination large (picture
## 328 x 180 framed amber, or blue while its wormhole is open; name 34; one dim line; status
## icons right), every Address Book entry as a 164 x 132 card in a two-column grid in rack
## order (scrolling when there are more than fit) and + NEW ADDRESS at the foot, 64 high.
## The filter (all, with team, unvisited) is kept as a method; the reference has no key for
## it.
## Bible: docs/content/interface-reference.md section 5

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
var _selected_key: String = ""
var _filter_key: IconKey = IconKey.new()
var _scroll: ScrollContainer = ScrollContainer.new()
var _cards: GridContainer = GridContainer.new()
var _new: RefKey = RefKey.new()
var _picture: WorldThumb = WorldThumb.new()
var _selected: GateDestination = null
var _open: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_filter_key.name = "FilterKey"
	_filter_key.visible = false
	_filter_key.pressed.connect(cycle_filter)
	add_child(_filter_key)
	_picture.position = RackLook.PICTURE.position + Vector2(3, 3)
	_picture.size = RackLook.PICTURE.size - Vector2(6, 6)
	add_child(_picture)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.position = RackLook.GRID.position
	_scroll.size = RackLook.GRID.size
	_cards.columns = 2
	_cards.add_theme_constant_override(&"h_separation", 12)
	_cards.add_theme_constant_override(&"v_separation", 12)
	_scroll.add_child(_cards)
	add_child(_scroll)
	_new.name = "NewAddress"
	_new.label = "STATION_NEW_ADDRESS_KEY"
	_new.label_size = 24
	_new.set_help("STATION_NEW_ADDRESS")
	_new.pressed.connect(new_address_requested.emit)
	add_child(_new)
	resized.connect(_layout)
	_layout()
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
	for entry: AddressEntry in DestinationText.ordered(state, _filter):
		var card: DestinationCard = DestinationCard.new()
		card.show_destination(destination_of(entry, state), entry.address_key, entry.pinned)
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
	_selected = card.get_destination()
	_picture.show_world(_selected.world_id)
	queue_redraw()
	for other: DestinationCard in get_cards():
		other.set_pressed_no_signal(other == card)
		other.queue_redraw()
	destination_selected.emit(card.get_destination())


## The destination shown large, or null.
func get_selected() -> GateDestination:
	return _selected


func _layout() -> void:
	_new.position = Vector2(14, size.y - 80)
	_new.size = Vector2(size.x - 28, 64)
	_scroll.size = Vector2(RackLook.GRID.size.x, size.y - 96 - RackLook.GRID.position.y)


func _process(_delta: float) -> void:
	if _simulation != null and _selected != null:
		var open: bool = RackLook.is_open(_simulation.state, _selected)
		if open != _open:
			_open = open
			queue_redraw()


func _draw() -> void:
	var state: GameState = null if _simulation == null else _simulation.state
	RackLook.draw(self, _selected, _open, RackLook.line_of(state, _selected_key))


func _on_flipped(card: DestinationCard) -> void:
	report_requested.emit(card.get_destination().world_id, card.get_key())


func _on_pin(card: DestinationCard) -> void:
	if _simulation != null:
		_simulation.submit(PinAddressCommand.create(card.get_key(), not card.is_pinned()))


func _on_world_changed(_world_id: StringName, _status: int) -> void:
	rebuild()
