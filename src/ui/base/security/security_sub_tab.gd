class_name SecuritySubTab
extends Control
## The Base console's SECURITY tray (M4c-12; restyled in M6-06 after BUILD's layout): HOLD
## and FALL BACK keys, a tile per squad (number, soldiers standing over total, order) and per
## blast door (level, cell, state; a press toggles it). Pick a
## squad by its row, then a cell on the plan (click, or the cursor and Enter / (A))
## to Move it there; Hold and Fall back act at once. The plan previews the path to the cursor.
## A refused order shows its reason. Picking a squad selects its room, so the detail column
## shows that room's camera. Everything works while paused and without a mouse.
## Bible: docs/content/m4c-incursions.md section 7

## A squad was picked (its post's room id), or &"" when none is.
signal squad_picked(squad_id: StringName)

## Width of a door tile: its place line is longer than a squad's.
const DOOR_WIDTH: float = 210.0

## The squad picked, or &"".
var selected: StringName = &""
## The reason the last order was refused, or the last order given.
var message := Label.new()
var hold_button := RefKey.new()
var fall_back_button := RefKey.new()

var _squads := HBoxContainer.new()
var _doors := HBoxContainer.new()
var _scroll := ScrollContainer.new()


func _init() -> void:
	name = &"SecuritySubTab"
	visible = false
	custom_minimum_size = Vector2(0, RoomCardKey.SIZE.y + 16)
	var keys: Dictionary[RefKey, StringName] = {
		hold_button: &"SECURITY_HOLD_KEY", fall_back_button: &"SECURITY_FALL_BACK_KEY"
	}
	var y: float = 8.0
	for key: RefKey in keys:
		key.label = keys[key]
		key.label_size = 14
		key.position = Vector2(8, y)
		key.size = Vector2(96, 60)
		add_child(key)
		y += 68.0
	hold_button.pressed.connect(order.bind(SquadState.Order.HOLD))
	fall_back_button.pressed.connect(order.bind(SquadState.Order.FALL_BACK))
	message.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	message.position = Vector2(4, -40)
	message.add_theme_color_override(&"font_color", RefPaint.AMBER)
	message.add_theme_font_size_override(&"font_size", 17)
	add_child(message)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	_squads.add_theme_constant_override(&"separation", 8)
	_doors.add_theme_constant_override(&"separation", 8)
	row.add_child(_squads)
	row.add_child(_doors)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.add_child(row)
	add_child(_scroll)
	TrayArrow.new().attach(_scroll)
	resized.connect(func() -> void: _scroll.position = Vector2(112, 8))
	resized.connect(func() -> void: _scroll.size = size - Vector2(120, 16))


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
		var tile := SecurityTile.new()
		var parts: PackedStringArray = SecurityText.squad_row(state, squad).split(" · ")
		tile.icon_id = &"threat"
		tile.title = parts[0].to_upper()
		tile.value = parts[1] if parts.size() > 1 else ""
		tile.detail = parts[2].to_upper() if parts.size() > 2 else ""
		tile.lit = squad.post_room == selected
		tile.text = SecurityText.squad_row(state, squad)
		tile.tooltip_text = tile.text
		tile.pressed.connect(pick.bind(squad.post_room))
		_squads.add_child(tile)
	for door: DoorState in state.base.doors:
		var toggle := SecurityTile.new()
		toggle.icon_id = &"cross" if door.mode == DoorState.Mode.SEALED else &"office"
		toggle.title = tr(&"SECURITY_DOOR_KEY")
		toggle.value = SecurityText.door_place(state, door)
		toggle.custom_minimum_size.x = DOOR_WIDTH
		toggle.detail = SecurityText.door_row(door).get_slice(": ", 1).to_upper()
		toggle.lit = door.mode == DoorState.Mode.SEALED
		toggle.disabled = not door.is_built()
		toggle.text = SecurityText.door_row(door)
		toggle.tooltip_text = toggle.text
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
