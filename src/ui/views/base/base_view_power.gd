class_name BaseViewPower
extends Node
## The power part of the Base tab (docs/content/m2-base.md section 6), kept apart from
## [BaseView]: the power strip above the plan, the selected room's switch and charge-rate
## control in the panel, and the energy layer over the plan. The base_energy_layer action
## (P, the gamepad View button) or the strip's button toggles the layer. On the layer a click
## or (A) on a room toggles it; on a bank a click on its left or right half, or left and right
## on the D-pad, steps its charge rate. Every change is a command; refusals are shown plainly,
## and one for lack of power outlines the bar's spare part for a moment.
## Bible: docs/content/m2-base.md sections 3 and 6

var strip: PowerStrip = PowerStrip.new()
var room_switch: RoomSwitch = RoomSwitch.new()
var charge: ChargeControl = ChargeControl.new()
var layer: EnergyLayer = EnergyLayer.new()

var _simulation: Simulation = null
var _plan: BasePlan = null
var _selected: StringName = &""
var _signature: int = 0


## Puts the strip at the top of [param column], the controls at the end of [param panel] and
## the layer over [param plan].
func attach(column: Control, plan: BasePlan, panel: Control) -> void:
	_plan = plan
	column.add_child(strip)
	column.move_child(strip, 0)
	panel.add_child(room_switch)
	panel.add_child(charge)
	plan.add_child(layer)
	strip.energy_pressed.connect(toggle_layer)
	room_switch.toggle_requested.connect(_toggle)
	charge.rate_requested.connect(_set_rate)
	plan.gui_input.connect(_on_plan_input)


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_tick)
	EventBus.power_allocation_changed.connect(refresh)
	EventBus.budget_changed.connect(_on_budget_changed)
	EventBus.room_build_started.connect(_on_room_event)
	EventBus.room_built.connect(_on_room_event)
	EventBus.room_demolished.connect(_on_room_event)
	EventBus.level_dug.connect(_on_level_dug)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_tick)
	EventBus.power_allocation_changed.disconnect(refresh)
	EventBus.budget_changed.disconnect(_on_budget_changed)
	EventBus.room_build_started.disconnect(_on_room_event)
	EventBus.room_built.disconnect(_on_room_event)
	EventBus.room_demolished.disconnect(_on_room_event)
	EventBus.level_dug.disconnect(_on_level_dug)


## A build, demolish, cancel or dig changes rooms: demolish and cancel post only
## budget_changed when they start, so that refreshes too.
func _on_budget_changed(_budget_k: int) -> void:
	refresh()


func _on_room_event(_site_id: StringName) -> void:
	refresh()


func _on_level_dug(_level: int) -> void:
	refresh()


## Reads the power of [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	layer.setup(_plan, simulation.state)
	refresh()


## True while the energy layer is shown.
func is_layer_on() -> bool:
	return layer.visible


## Shows or hides the energy layer.
func toggle_layer() -> void:
	layer.visible = not layer.visible
	layer.mark_refused(&"", 0.0)
	refresh()


## Shows the power controls of [param selected] (a room id or &"") in the panel.
func select(selected: StringName) -> void:
	if selected != _selected:
		room_switch.show_notice("")
		charge.show_notice("")
	_selected = selected
	_show_selection()


## Redraws the strip, the layer and the panel controls from the simulation.
func refresh() -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	strip.show_state(state, layer.visible)
	layer.queue_redraw()
	_show_selection()
	_signature = _power_signature(state)


func _unhandled_input(event: InputEvent) -> void:
	if _simulation == null or not (get_parent() as Control).is_visible_in_tree():
		return
	if InputActions.is_new_press(event, &"base_energy_layer"):
		toggle_layer()
		get_viewport().set_input_as_handled()


func _show_selection() -> void:
	room_switch.visible = false
	charge.visible = false
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	var room: RoomState = state.base.find_room(_selected)
	var def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
	if def == null:
		return
	room_switch.show_room(state, room, def)
	charge.show_room(state, room, def)


func _toggle(room_id: StringName) -> void:
	var refused: String = PowerActions.toggle(_simulation, room_id)
	_after(room_id, refused)
	room_switch.show_notice(refused)


func _set_rate(room_id: StringName, rate_mw: int) -> void:
	var refused: String = PowerActions.set_rate(_simulation, room_id, rate_mw)
	_after(room_id, refused)
	charge.show_notice(refused)


## Refreshes after a power action on [param room_id]; marks the room on the layer when it
## was [param refused].
func _after(room_id: StringName, refused: String) -> void:
	var state: GameState = _simulation.state
	var need: float = 0.0
	var room: RoomState = state.base.find_room(room_id)
	var def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
	if not refused.is_empty() and def != null and not PowerRules.is_bank(def):
		need = def.power_draw_mw
	layer.mark_refused(room_id if need > 0.0 else &"", need)
	refresh()
	var short_of_power: bool = need > PowerRules.spare_mw(state) or PowerRules.is_bank(def)
	if not refused.is_empty() and short_of_power:
		strip.bar.flash_spare()


func _on_plan_input(event: InputEvent) -> void:
	if not layer.visible or _simulation == null:
		return
	var target: StringName = &""
	var step: int = 0
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
			return
		target = _plan.item_at(_plan.cell_at(click.position))
		step = _half_step(target, click.position)
	elif event.is_action_pressed(&"ui_accept"):
		target = _plan.item_at(_plan.cursor)
	elif event.is_action_pressed(&"ui_left", true) or event.is_action_pressed(&"ui_right", true):
		target = _plan.item_at(_plan.cursor)
		if not _is_bank(target):
			return
		step = 1 if event.is_action_pressed(&"ui_right", true) else -1
		_plan.accept_event()
	_act(target, step)


## Toggles [param target], or steps its charge rate by [param step] when it is a bank.
func _act(target: StringName, step: int) -> void:
	if target == &"":
		return
	_plan.select(target)
	if _is_bank(target):
		if step != 0:
			var rate: int = _simulation.state.power.charge_rates.get(target, 0)
			_set_rate(target, rate + step * ChargeControl.STEP_MW)
		return
	if PowerRules.has_switch(_def_of(target)):
		_toggle(target)


## -1 for a click on the left half of bank [param target], +1 on the right half, else 0.
func _half_step(target: StringName, point: Vector2) -> int:
	if not _is_bank(target):
		return 0
	var room: RoomState = _simulation.state.base.find_room(target)
	var cells: Rect2i = BaseRules.footprint(room, _def_of(target))
	var middle: float = (float(cells.position.x) + cells.size.x * 0.5) * BasePlanPainter.CELL
	var plan_x: float = (point.x - _plan.view.offset.x) / _plan.view.scale()
	return -1 if plan_x < middle else 1


func _is_bank(target: StringName) -> bool:
	return PowerRules.is_bank(_def_of(target))


## The RoomDef of room [param target], or null.
func _def_of(target: StringName) -> RoomDef:
	var room: RoomState = _simulation.state.base.find_room(target)
	if room == null:
		return null
	var def: RoomDef = _simulation.state.room_defs.get(room.def_id)
	return def


func _on_tick(_tick: int) -> void:
	if _simulation == null or not (get_parent() as Control).is_visible_in_tree():
		return
	if _power_signature(_simulation.state) != _signature:
		refresh()


## A cheap hash of what the strip and controls show of [param state].
static func _power_signature(state: GameState) -> int:
	var sums: PackedFloat64Array = PowerRules.totals(state)
	return hash([sums, state.power.charge_rates, floori(state.power.stored_mwh)])
