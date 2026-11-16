class_name TeamOrders
extends PaperCard
## The orders the team can be given now through the open gate, as keys on a paper card: on a
## hail Carry on, Come home, Stay longer; on the team's call Come through, Hold on. Each
## submits OrderTeamCommand and the card closes.
## Bible: docs/content/interface-rethink.md section 4 (A team can only talk through an open gate)

var _simulation: Simulation = null
var _row: HBoxContainer = HBoxContainer.new()


func _ready() -> void:
	super()
	z_index = 6
	_row.add_theme_constant_override(&"separation", 10)
	add_child(_row)
	hide()


## Reads [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	hide()


## Shows the orders open now; hides when there are none.
func open() -> void:
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	if _simulation == null:
		return
	var orders: Array[TeamContactRules.Order] = TeamContactRules.open_orders(_simulation.state)
	for order: TeamContactRules.Order in orders:
		var key: BigKey = BigKey.new()
		key.name = "Order_" + TeamContactRules.ORDER_NAMES[order]
		key.text = "STATION_ORDER_" + TeamContactRules.ORDER_NAMES[order].to_upper()
		key.activated.connect(give.bind(order))
		_row.add_child(key)
	visible = not orders.is_empty()
	if visible:
		reset_size()
		(_row.get_child(0) as Control).grab_focus.call_deferred()


## Gives [param order].
func give(order: TeamContactRules.Order) -> void:
	if _simulation != null:
		_simulation.submit(OrderTeamCommand.create(order))
	hide()
