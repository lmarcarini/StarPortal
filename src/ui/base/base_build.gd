class_name BaseBuild
extends RefCounted
## Building from the Base tab (docs/content/m2-base.md sections 4 and 6): joins the build
## palette, the placement ghost over the plan and the selected-room panel's action to the
## simulation. Picking a room starts its ghost at the cursor; a click or press submits
## PlaceRoomCommand or PaintCorridorCommand and the ghost stays out for another; the panel
## offers Cancel (a site, 75% back), Repair (a damaged room, M4c) or Demolish (a room, 50%
## back) with the refund or cost shown;
## the Dig button digs or cancels the dig. The result, or why the command was refused, shows
## on the palette's hint line. Changes no state itself.
## Bible: docs/content/m2-base.md sections 4 and 6

var _simulation: Simulation = null
## RoomDefs by id, to refill the palette when research unlocks a room.
var _defs: Dictionary[StringName, RoomDef] = {}
var _plan: BasePlan = null
var _palette: BuildPalette = null
var _panel: RoomPanel = null
var _ghost: PlacementGhost = PlacementGhost.new()
## What to say when the panel's action applies.
var _action_message: String = ""


## Joins [param plan], [param palette] and [param panel].
func _init(plan: BasePlan, palette: BuildPalette, panel: RoomPanel) -> void:
	_plan = plan
	_palette = palette
	_panel = panel
	_plan.add_child(_ghost)
	_palette.room_picked.connect(_on_room_picked)
	_palette.build_held.connect(_ghost.confirm)
	_palette.cancel_held.connect(_leave_placing)
	_palette.back_requested.connect(_leave_placing)
	_palette.get_dig_button().command_held.connect(_submit_dig)
	_panel.action_held.connect(_submit_action)
	_ghost.build_held.connect(_submit_build)
	_ghost.checked.connect(_on_checked)
	_ghost.cancelled.connect(_on_cancelled)
	_plan.door_toggled.connect(_toggle_door)


## Builds with [param simulation]; [param defs] holds the RoomDefs by id.
func setup(simulation: Simulation, defs: Dictionary) -> void:
	_simulation = simulation
	_ghost.stop()
	_ghost.attach(_plan, simulation.state)
	_defs.assign(defs)
	_palette.show_rooms(defs, simulation.state.unlocks.rooms, blocked(simulation.state))
	_palette.set_placing(false, false)
	refresh()


## Returns the plan it builds on.
func get_plan() -> BasePlan:
	return _plan


## Returns the build palette.
func get_palette() -> BuildPalette:
	return _palette


## Returns the placement ghost.
func get_ghost() -> PlacementGhost:
	return _ghost


## Starts placing [param def_id] at the plan's cursor and gives the plan focus.
func start_placing(def_id: StringName) -> void:
	if _simulation == null:
		return
	_ghost.start(def_id, _plan.cursor)
	_palette.mark_picked(def_id)
	_plan.grab_focus()


## Starts placing [param def_id] at [param cell] of the shown level and centres the plan on it.
func place_at(def_id: StringName, cell: Vector2i) -> void:
	_plan.cursor = cell
	start_placing(def_id)
	var centre: Vector2 = (Vector2(_ghost.area().get_center())) * BasePlanPainter.CELL
	_plan.view.zoom_centred(2.0 / _plan.view.zoom)
	var wanted: Vector2 = _plan.size * 0.5 - centre * _plan.view.scale()
	_plan.view.pan(wanted - _plan.view.offset)
	_plan.queue_redraw()


## Rereads the state: the Dig button, the ghost's check and the panel's action.
func refresh() -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	var now_blocked: Dictionary[StringName, String] = blocked(state)
	if _palette.unlocks_changed(state.unlocks.rooms, now_blocked):
		_palette.show_rooms(_defs, state.unlocks.rooms, now_blocked)
	_palette.get_dig_button().refresh(_simulation.state)
	_ghost.recheck()
	show_action(_plan.selected())


## Moves focus to the palette's first room; true when it could.
func focus_palette() -> bool:
	var first: Button = _palette.first_button()
	if first == null or _ghost.is_placing():
		return false
	first.grab_focus()
	return true


## Offers the action of [param selected] (a room id) on the panel: Cancel for a site,
## Demolish for a room, each with its refund or the reason it is refused.
func show_action(selected: StringName) -> void:
	var room: RoomState = null
	if _simulation != null:
		room = _simulation.state.base.find_room(selected)
	var def: RoomDef = null if room == null else _simulation.state.room_defs.get(room.def_id)
	if def == null:
		_panel.show_action(null, "")
		return
	var state: GameState = _simulation.state
	var command: Command = null
	var refund_k: int = 0
	var text: String = ""
	if not room.is_built():
		command = CancelBuildCommand.create(room.id)
		refund_k = CancelBuildCommand.refund_k(state, room.id)
		text = tr_format(&"BASE_BUILD_CANCEL", refund_k, "")
		_action_message = tr_format(&"BASE_BUILD_CANCELLED", refund_k, _t(def.name_key))
	elif room.damaged:
		command = RepairRoomCommand.create(room.id)
		var time: String = BuildText.duration(RepairRules.ticks(def))
		if room.repair_ticks_left > 0:
			time = BuildText.duration(room.repair_ticks_left)
		text = _t(&"BASE_REPAIR").format(
			{"cost": MoneyLabel.format_k(RepairRules.cost_k(def)), "time": time}
		)
		_action_message = _t(&"BASE_REPAIR_STARTED").format({"name": _t(def.name_key)})
	else:
		command = DemolishRoomCommand.create(room.id)
		refund_k = DemolishRoomCommand.refund_k(state, room)
		text = tr_format(
			&"BASE_BUILD_DEMOLISH", refund_k, BuildText.duration(maxi(1, def.build_ticks / 4))
		)
		_action_message = tr_format(&"BASE_BUILD_DEMOLISHING", refund_k, _t(def.name_key))
	var result: CommandResult = command.validate(state)
	var reason: String = "" if result.is_ok else BuildText.reason(result, state, 0)
	_panel.show_action(command, text, reason)


## [param key] translated, with {refund} as money from [param refund_k] and {extra}.
static func tr_format(key: StringName, refund_k: int, extra: String) -> String:
	var text: String = TranslationServer.translate(key)
	return text.format({"refund": MoneyLabel.format_k(refund_k), "extra": extra})


static func _t(key: StringName) -> String:
	return TranslationServer.translate(key)


func _submit_build(command: Command) -> void:
	var def: RoomDef = _simulation.state.room_defs.get(_ghost.def_id)
	var name_key: StringName = &"BASE_DOOR_NAME" if def == null else def.name_key
	var cost_k: int = _ghost.cost_k()
	var result: CommandResult = _simulation.submit(command)
	if not result.is_ok:
		_palette.show_message(BuildText.reason(result, _simulation.state, cost_k))
		return
	_ghost.after_build()
	_palette.show_message(
		_t(&"BASE_BUILD_STARTED").format(
			{"name": _t(name_key), "cost": MoneyLabel.format_k(cost_k)}
		)
	)


## Seals an open door, opens a sealed one (M4c-04); works while paused.
func _toggle_door(level: int, cell: Vector2i) -> void:
	var door: DoorState = DoorRules.find(_simulation.state.base, level, cell)
	if door == null:
		return
	var sealed: bool = door.mode == DoorState.Mode.SEALED
	var to_mode: DoorState.Mode = DoorState.Mode.OPEN if sealed else DoorState.Mode.SEALED
	var result: CommandResult = _simulation.submit(SetDoorCommand.create(level, cell, to_mode))
	var key: StringName = &"BASE_DOOR_OPENED" if sealed else &"BASE_DOOR_SEALED"
	_palette.show_message(
		_t(key) if result.is_ok else BuildText.reason(result, _simulation.state, 0)
	)
	_plan.queue_redraw()


func _submit_action(command: Command) -> void:
	var result: CommandResult = _simulation.submit(command)
	var message: String = _action_message
	if not result.is_ok:
		message = BuildText.reason(result, _simulation.state, 0)
	_palette.show_message(message)
	refresh()


func _submit_dig(command: Command) -> void:
	var state: GameState = _simulation.state
	var level: int = state.base.digging_level()
	var cancelling: bool = level != 0
	if not cancelling:
		level = state.base.level_count + 1
	var cost_k: int = DigLevelCommand.cost_k(state, level)
	var result: CommandResult = _simulation.submit(command)
	if not result.is_ok:
		_palette.show_message(BuildText.reason(result, state, cost_k))
		return
	var refund_k: int = cost_k * CancelBuildCommand.DIG_REFUND_PERCENT / 100
	var key: StringName = &"BASE_BUILD_DIG_CANCELLED" if cancelling else &"BASE_BUILD_DIG_STARTED"
	_palette.show_message(tr_format(key, refund_k, str(level)))
	refresh()


func _on_checked(reason: String) -> void:
	_palette.set_placing(true, reason.is_empty())
	if not reason.is_empty():
		_palette.show_message(reason)
		return
	var def: RoomDef = _simulation.state.room_defs.get(_ghost.def_id)
	var name_key: StringName = &"BASE_DOOR_NAME" if def == null else def.name_key
	var key: StringName = &"BASE_BUILD_PLACING"
	if _ghost.is_corridor():
		key = &"BASE_BUILD_CORRIDOR_END" if _ghost.has_start() else &"BASE_BUILD_CORRIDOR_START"
	var text: String = (
		_t(key)
		. format(
			{
				"name": _t(name_key),
				"cost": MoneyLabel.format_k(_ghost.cost_k()),
				"time": BuildText.duration(_ghost.build_ticks()),
			}
		)
	)
	_palette.show_message(text)


## The palette's entry: the one being placed puts the ghost away, any other starts placing it.
func _on_room_picked(def_id: StringName) -> void:
	if _ghost.is_placing() and _ghost.def_id == def_id:
		_ghost.stop(true)
		return
	start_placing(def_id)


## The palette's Cancel button, or (B) or Esc on the palette: puts the ghost away, back to the plan.
func _leave_placing() -> void:
	if _ghost.is_placing():
		_ghost.stop(true)
	_plan.grab_focus()


func _on_cancelled() -> void:
	_palette.mark_picked(&"")
	_palette.set_placing(false, false)
	_palette.show_message("")


## Unlocked rooms that can't be built right now, with the reason (the bank cap, say).
static func blocked(state: GameState) -> Dictionary[StringName, String]:
	var found: Dictionary[StringName, String] = {}
	for def_id: StringName in state.unlocks.rooms:
		var result: CommandResult = UnlockRules.can_build_room(state, def_id)
		if not result.is_ok:
			found[def_id] = BuildText.unlock_reason(result, state)
	return found
