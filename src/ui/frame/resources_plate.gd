class_name ResourcesPlate
extends Control
## The top bar's resources plate (interface-reference.md section 4, top_resources): four
## cells of 240, 180, 160 and 180 px split by 2 px dark rules, each an icon, the value in mono
## 24 and the delta or unit in mono 16 (green rising, red falling, dim for units): funds,
## power used/supply, charge, Confidence. Each cell is a button (the old readouts, their own
## text hidden): hover gives the breakdown, a click opens the owning station.
## Bible: docs/content/interface-reference.md section 4

## Asks to show [param view_id], on [param sub_tab] when not empty.
signal open_view(view_id: StringName, sub_tab: StringName)

## Cell widths, in pixels.
const WIDTHS: Array[float] = [240.0, 180.0, 160.0, 180.0]

var money_label := MoneyLabel.new()
var power_readout := PowerReadout.new()
var charge_readout := Button.new()
var confidence_readout := ConfidenceReadout.new()

var _state: GameState = null


func _init() -> void:
	name = &"ResourcesPlate"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	charge_readout.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var targets: Array[Array] = [
		[ViewSwitcher.COMMAND, &""],
		[ViewSwitcher.BASE, BaseSubTabs.ENERGY],
		[ViewSwitcher.GATE_ROOM, &""],
		[ViewSwitcher.COMMAND, &""],
	]
	var x: float = 0.0
	for i: int in 4:
		var cell: Button = get_buttons()[i]
		cell.flat = true
		cell.self_modulate = Color(1, 1, 1, 0)
		cell.position = Vector2(x, 0)
		cell.size = Vector2(WIDTHS[i], 60)
		cell.custom_minimum_size = Vector2.ZERO
		cell.pressed.connect(open_view.emit.bind(targets[i][0], targets[i][1]))
		cell.focus_entered.connect(queue_redraw)
		cell.focus_exited.connect(queue_redraw)
		add_child(cell)
		x += WIDTHS[i]


func _ready() -> void:
	var hints: Array[String] = [
		"FRAME_FUNDS_HINT", "FRAME_POWER_HINT", "FRAME_CHARGE_HINT", "FRAME_CONFIDENCE_HINT"
	]
	for i: int in 4:
		HoverCard.attach(get_buttons()[i], hints[i])


## Binds [param state] (after a start or a load).
func bind(state: GameState) -> void:
	_state = state
	confidence_readout.setup(state)
	show_state(state)


## Sets every cell from [param state].
func show_state(state: GameState) -> void:
	money_label.show_budget(state.budget.funds_k)
	money_label.show_net(TopBarText.net_per_day(state))
	confidence_readout.refresh()
	show_power(state)


## Power and charge, which change every tick.
func show_power(state: GameState) -> void:
	power_readout.show_state(state)
	charge_readout.text = TopBarText.stored_text(state)
	queue_redraw()


## The cell buttons in focus order.
func get_buttons() -> Array[Button]:
	return [money_label, power_readout, charge_readout, confidence_readout]


func _draw() -> void:
	RefPaint.steel_plate(self, Rect2(Vector2.ZERO, size), false, true)
	if _state == null:
		return
	var cells: Array[ResourceCell] = ResourceCell.of(_state)
	var x: float = 0.0
	for i: int in cells.size():
		if i > 0:
			draw_line(Vector2(x, 10), Vector2(x, size.y - 10), RefPaint.EDGE, 2.0)
		cells[i].draw(self, x)
		if get_buttons()[i].has_focus():
			RefPaint.outline(
				self, Rect2(x + 3, 3, WIDTHS[i] - 6, size.y - 6), RefPaint.AMBER_HI, 2.0
			)
		x += WIDTHS[i]
