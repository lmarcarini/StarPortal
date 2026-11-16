class_name GaugePlate
extends SteelPanel
## The frame's top-right plate: four analogue gauges, one number each: funds (with today's
## net change), power used over supply, capacitor charge and Committee Confidence. Each is a
## button: hover shows the detail, a click asks to open the station that owns it.
## Bible: docs/content/interface-rethink.md section 3

## Asks to show [param view_id], on [param sub_tab] when not empty.
signal open_view(view_id: StringName, sub_tab: StringName)

## Funds needle top, in thousands of dollars.
const FUNDS_TOP_K: float = 20000.0

## The number under each gauge (the funds and Confidence ones are the old readouts).
var money_label := MoneyLabel.new()
var confidence_readout := ConfidenceReadout.new()
var power_readout := PowerReadout.new()
var charge_readout := Button.new()
## The needles.
var funds_gauge := AnalogGauge.new()
var power_gauge := AnalogGauge.new()
var charge_gauge := AnalogGauge.new()
var confidence_gauge := AnalogGauge.new()

var _row: HBoxContainer = HBoxContainer.new()


func _init() -> void:
	super()
	name = &"GaugePlate"
	_row.add_theme_constant_override(&"separation", 10)
	add_child(_row)
	charge_readout.theme_type_variation = &"ReadoutButton"
	charge_readout.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for button: Button in [money_label, confidence_readout]:
		button.flat = true
		button.theme_type_variation = &"ReadoutButton"
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_unit(funds_gauge, money_label, ViewSwitcher.COMMAND, &"")
	_unit(power_gauge, power_readout, ViewSwitcher.BASE, BaseSubTabs.ENERGY)
	_unit(charge_gauge, charge_readout, ViewSwitcher.GATE_ROOM, &"")
	_unit(confidence_gauge, confidence_readout, ViewSwitcher.COMMAND, &"")
	confidence_gauge.max_value = float(ConfidenceRules.MAX)
	funds_gauge.max_value = FUNDS_TOP_K


func _ready() -> void:
	HoverCard.attach(funds_gauge, "FRAME_FUNDS_HINT")
	HoverCard.attach(power_gauge, "FRAME_POWER_HINT")
	HoverCard.attach(charge_gauge, "FRAME_CHARGE_HINT")
	HoverCard.attach(confidence_gauge, "FRAME_CONFIDENCE_HINT")


## Binds [param state] (after a start or a load).
func bind(state: GameState) -> void:
	confidence_readout.setup(state)
	show_state(state)


## Sets every needle and number from [param state].
func show_state(state: GameState) -> void:
	money_label.show_budget(state.budget.funds_k)
	money_label.show_net(TopBarText.net_per_day(state))
	funds_gauge.set_value(float(state.budget.funds_k))
	confidence_readout.refresh()
	confidence_gauge.set_value(float(state.committee.confidence))
	show_power(state)


## Power and charge, which change every tick.
func show_power(state: GameState) -> void:
	power_readout.show_state(state)
	var supply: float = PowerRules.supply_mw(state)
	power_gauge.max_value = maxf(supply, 1.0)
	power_gauge.red_from = maxf(supply, 1.0) * 0.9
	power_gauge.set_value(PowerRules.allocated_mw(state))
	var capacity: float = PowerRules.capacity_mwh(state)
	charge_gauge.max_value = maxf(capacity, 1.0)
	charge_gauge.set_value(state.power.stored_mwh)
	charge_readout.text = TopBarText.stored_text(state)
	charge_readout.visible = capacity > 0.0


## The number buttons in focus order.
func get_buttons() -> Array[Button]:
	return [money_label, power_readout, charge_readout, confidence_readout]


func _unit(gauge: AnalogGauge, number: Button, view_id: StringName, sub_tab: StringName) -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	gauge.custom_minimum_size = Vector2(96, 84)
	column.add_child(gauge)
	column.add_child(number)
	number.pressed.connect(open_view.emit.bind(view_id, sub_tab))
	gauge.gui_input.connect(_on_gauge_input.bind(view_id, sub_tab))
	_row.add_child(column)


func _on_gauge_input(event: InputEvent, view_id: StringName, sub_tab: StringName) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		open_view.emit(view_id, sub_tab)
