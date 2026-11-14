class_name SecuritySubTab
extends VBoxContainer
## The Base tab's Security strip (M4c-12), under the plan: a row per squad (number, soldiers
## standing over total, order, where) and per blast door (level, cell, state, toggle). Pick a
## squad by its row, then a cell on the plan (click, or the cursor and Enter / (A))
## to Move it there; Hold and Fall back act at once. The plan previews the path to the cursor.
## A refused order shows its reason. Picking a squad selects its room, so the detail column
## shows that room's camera. Everything works while paused and without a mouse.
## Bible: docs/content/m4c-incursions.md section 7

## A squad was picked (its post's room id), or &"" when none is.
signal squad_picked(squad_id: StringName)

## The squad picked, or &"".
var selected: StringName = &""
## The reason the last order was refused, or the last order given.
var message := Label.new()
var hold_button := Button.new()
var fall_back_button := Button.new()

var _squads := HFlowContainer.new()
var _doors := HFlowContainer.new()


func _init() -> void:
	name = &"SecuritySubTab"
	visible = false
	add_child(_squads)
	var actions := HBoxContainer.new()
	hold_button.text = &"SECURITY_HOLD"
	hold_button.pressed.connect(order.bind(SquadState.Order.HOLD))
	fall_back_button.text = &"SECURITY_FALL_BACK"
	fall_back_button.pressed.connect(order.bind(SquadState.Order.FALL_BACK))
	actions.add_child(hold_button)
	actions.add_child(fall_back_button)
	message.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	actions.add_child(message)
	add_child(actions)
	add_child(_doors)


func _enter_tree() -> void:
	EventBus.squad_changed.connect(_on_changed)
	EventBus.door_changed.connect(_on_door_changed)


func _exit_tree() -> void:
	EventBus.squad_changed.disconnect(_on_changed)
	EventBus.door_changed.disconnect(_on_door_changed)


func _on_changed(_id: StringName) -> void:
	if is_visible_in_tree():
		_refresh()


func _on_door_changed(_level: int, _cell: Vector2i) -> void:
	if is_visible_in_tree():
		_refresh()


## Shows the squads and doors of [param state].
func show_state(state: GameState) -> void:
	if state.security.squad_of(selected) == null:
		selected = &""
	for child: Node in _squads.get_children() + _doors.get_children():
		child.queue_free()
	for squad: SquadState in state.security.squads:
		var button := Button.new()
		button.toggle_mode = true
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.text = SecurityText.squad_row(state, squad)
		button.set_pressed_no_signal(squad.post_room == selected)
		button.pressed.connect(pick.bind(squad.post_room))
		_squads.add_child(button)
	for door: DoorState in state.base.doors:
		var toggle := Button.new()
		toggle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		toggle.text = SecurityText.door_row(door)
		toggle.disabled = not door.is_built()
		toggle.pressed.connect(_toggle_door.bind(door.level, door.cell))
		_doors.add_child(toggle)
	hold_button.disabled = selected.is_empty()
	fall_back_button.disabled = selected.is_empty()


## Picks squad [param squad_id] (again: drops it).
func pick(squad_id: StringName) -> void:
	selected = &"" if squad_id == selected else squad_id
	squad_picked.emit(selected)
	_refresh()


## Gives the picked squad [param what], to [param to] for a move; shows the result.
func order(what: SquadState.Order, to: Vector3i = Vector3i.ZERO) -> CommandResult:
	var simulation: Simulation = SimClock.simulation
	if simulation == null or selected.is_empty():
		return CommandResult.fail(&"no_squad")
	var result: CommandResult = simulation.submit(OrderSquadCommand.create(selected, what, to))
	message.text = SecurityText.result(result, what)
	_refresh()
	return result


func _toggle_door(level: int, cell: Vector2i) -> void:
	var simulation: Simulation = SimClock.simulation
	var door: DoorState = DoorRules.find(simulation.state.base, level, cell)
	if door == null:
		return
	var sealed: bool = door.mode == DoorState.Mode.SEALED
	var to_mode: DoorState.Mode = DoorState.Mode.OPEN if sealed else DoorState.Mode.SEALED
	simulation.submit(SetDoorCommand.create(level, cell, to_mode))
	_refresh()


func _refresh() -> void:
	var simulation: Simulation = SimClock.simulation
	if simulation != null:
		show_state(simulation.state)
