class_name BaseBuild
extends RefCounted
## Building from the Base tab (docs/content/m2-base.md sections 4 and 6): joins the build
## palette, the placement ghost over the plan and the selected-room panel's action to the
## simulation. Picking a room starts its ghost at the cursor; a click or press submits
## PlaceRoomCommand or PaintCorridorCommand and the ghost stays out for another; the panel
## offers Cancel (a site, 75% back) or Demolish (a room, 50% back) with the refund shown;
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
	_palette.room_picked.connect(start_placing)
	_palette.build_held.connect(_ghost.confirm)
	_palette.back_requested.connect(_plan.grab_focus)
	_palette.get_dig_button().command_held.connect(_submit_dig)
	_panel.action_held.connect(_submit_action)
	_ghost.build_held.connect(_submit_build)
	_ghost.checked.connect(_on_checked)
	_ghost.cancelled.connect(_on_cancelled)


## Builds with [param simulation]; [param defs] holds the RoomDefs by id.
func setup(simulation: Simulation, defs: Dictionary) -> void:
	_simulation = simulation
	_ghost.stop()
	_ghost.attach(_plan, simulation.state)
	_defs.assign(defs)
	_palette.show_rooms(defs, simulation.state.unlocks.rooms)
	_palette.set_placing(false, false)
	refresh()


## Returns the placement ghost.
func get_ghost() -> PlacementGhost:
	return _ghost


## Starts placing [param def_id] at the plan's cursor and gives the plan focus.
func start_placing(def_id: StringName) -> void:
	if _simulation == null:
		return
	_ghost.start(def_id, _plan.cursor)
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
	if _palette.unlocks_changed(_simulation.state.unlocks.rooms):
		_palette.show_rooms(_defs, _simulation.state.unlocks.rooms)
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
		var site: Array[RoomState] = BaseRules.site_rooms(state.base, room.site_key())
		refund_k = (
			LiftShafts.site_cost_k(state, site) * CancelBuildCommand.SITE_REFUND_PERCENT / 100
		)
		text = tr_format(&"BASE_BUILD_CANCEL", refund_k, "")
		_action_message = tr_format(&"BASE_BUILD_CANCELLED", refund_k, _t(def.name_key))
	else:
		command = DemolishRoomCommand.create(room.id)
		refund_k = def.build_cost_k * DemolishRoomCommand.REFUND_PERCENT / 100
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
	var cost_k: int = _ghost.cost_k()
	var result: CommandResult = _simulation.submit(command)
	if not result.is_ok:
		_palette.show_message(BuildText.reason(result, _simulation.state, cost_k))
		return
	_ghost.after_build()
	_palette.show_message(
		_t(&"BASE_BUILD_STARTED").format(
			{"name": _t(def.name_key), "cost": MoneyLabel.format_k(cost_k)}
		)
	)


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
	var text: String = (
		_t(&"BASE_BUILD_PLACING")
		. format(
			{
				"name": _t(def.name_key),
				"cost": MoneyLabel.format_k(_ghost.cost_k()),
				"time": BuildText.duration(def.build_ticks * maxi(1, _ghost.run.size())),
			}
		)
	)
	_palette.show_message(text)


func _on_cancelled() -> void:
	_palette.set_placing(false, false)
	_palette.show_message("")
