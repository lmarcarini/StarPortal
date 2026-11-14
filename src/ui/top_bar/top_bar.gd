class_name TopBar
extends PanelContainer
## The bar on every screen (docs/content/interface-pass.md section 3), left to right: clock
## and speed (with the call lamp), funds with today's net change, Confidence, power and
## stored energy, the gate chip, the alerts button, then quick save, quick load and (debug)
## the flag button. Items wrap onto a second row when the window is narrow. Each figure is a
## button that opens its screen through [signal open_view]. Redraws on EventBus signals only
## and on [method bind], so it is right while paused and after a load. Reads state only.
## Bible: docs/content/interface-pass.md section 3

## Asks the shell to show [param view_id], on [param sub_tab] when not empty.
signal open_view(view_id: StringName, sub_tab: StringName)
## The alerts button was pressed.
signal alerts_pressed

const _TIME_BAR_SCENE: String = "res://src/ui/time_bar/time_bar.tscn"
const _ITEM_HEIGHT: float = 40.0

## Clock, speed and the call lamp.
var time_bar: TimeBar = (load(_TIME_BAR_SCENE) as PackedScene).instantiate() as TimeBar
## Funds and today's net change.
var money_label := MoneyLabel.new()
## Committee Confidence and its trend.
var confidence_readout := ConfidenceReadout.new()
## Switched-on power over supply and stored energy.
var power_readout := PowerReadout.new()
## The gate's state.
var gate_chip := GateChip.new()
## Opens the alert list.
var alerts_button := Button.new()
## Quick save and quick load.
var quick_save_button := Button.new()
var quick_load_button := Button.new()
## Debug only: submits a SetFlagCommand (the shell frees it in release builds).
var debug_flag_button := Button.new()
## The flowing row that holds every item.
var row := HFlowContainer.new()

var _state: GameState = null


func _init() -> void:
	name = &"TopBar"
	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)
	row.add_theme_constant_override(&"h_separation", 12)
	margin.add_child(row)
	money_label.flat = true
	confidence_readout.flat = true
	money_label.theme_type_variation = &"ReadoutButton"
	confidence_readout.theme_type_variation = &"ReadoutButton"
	money_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	confidence_readout.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	quick_save_button.text = &"UI_SAVE"
	quick_load_button.text = &"UI_LOAD"
	debug_flag_button.text = &"UI_DEBUG_SET_FLAG"
	alerts_button.text = &"TOPBAR_ALERTS"
	for item: Control in _items():
		item.custom_minimum_size.y = _ITEM_HEIGHT
		row.add_child(item)
	_connect_items()


func _enter_tree() -> void:
	for signal_name: StringName in _redraw_signals():
		EventBus.connect(signal_name, _on_event)
	EventBus.tick_advanced.connect(_on_tick)


func _exit_tree() -> void:
	for signal_name: StringName in _redraw_signals():
		EventBus.disconnect(signal_name, _on_event)
	EventBus.tick_advanced.disconnect(_on_tick)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Reads [param simulation]'s state (after a start or a load) and redraws every item.
func bind(simulation: Simulation) -> void:
	_state = simulation.state
	confidence_readout.setup(_state)
	refresh()


## Redraws every item from the bound state.
func refresh() -> void:
	if _state == null:
		return
	money_label.show_budget(_state.budget.funds_k)
	money_label.show_net(TopBarText.net_per_day(_state))
	confidence_readout.refresh()
	_refresh_live()


## Puts [param control] in the row just after the clock (the shell's alert stack).
func add_after_clock(control: Control) -> void:
	row.add_child(control)
	row.move_child(control, time_bar.get_index() + 1)


## The buttons in focus order: the time bar's, [param extra] (the shell's alert stack
## entries), the figures, the alerts button, save, load and the debug button while it exists.
func get_focus_buttons(extra: Array[Button]) -> Array[Button]:
	var buttons: Array[Button] = time_bar.get_buttons()
	buttons.append_array(extra)
	(
		buttons
		. append_array(
			[
				money_label,
				confidence_readout,
				power_readout,
				gate_chip,
				alerts_button,
				quick_save_button,
				quick_load_button,
			]
		)
	)
	if is_instance_valid(debug_flag_button) and not debug_flag_button.is_queued_for_deletion():
		buttons.append(debug_flag_button)
	return buttons


func _items() -> Array[Control]:
	return [
		time_bar,
		money_label,
		confidence_readout,
		power_readout,
		gate_chip,
		alerts_button,
		quick_save_button,
		quick_load_button,
		debug_flag_button,
	]


func _connect_items() -> void:
	money_label.pressed.connect(open_view.emit.bind(ViewSwitcher.COMMAND, &""))
	confidence_readout.pressed.connect(open_view.emit.bind(ViewSwitcher.COMMAND, &""))
	power_readout.pressed.connect(open_view.emit.bind(ViewSwitcher.BASE, BaseSubTabs.ENERGY))
	gate_chip.pressed.connect(open_view.emit.bind(ViewSwitcher.GATE_ROOM, &""))
	alerts_button.pressed.connect(alerts_pressed.emit)


## Power and the gate change every tick (stored energy, time left).
func _refresh_live() -> void:
	power_readout.show_state(_state)
	gate_chip.show_state(_state)


static func _redraw_signals() -> Array[StringName]:
	return [
		&"budget_changed",
		&"day_started",
		&"confidence_changed",
		&"room_built",
		&"room_demolished",
		&"staff_changed",
		&"power_allocation_changed",
		&"dial_started",
		&"dial_resolved",
		&"wormhole_closed",
		&"incoming_wormhole",
		&"incoming_answered",
		&"incoming_ignored",
		&"game_loaded",
	]


func _on_event(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	refresh()


func _on_tick(_tick: int) -> void:
	if _state != null:
		_refresh_live()
