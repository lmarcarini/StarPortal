class_name BaseMessages
extends Node
## Shows the simulation's building and power news on the Base tab's message line (the build
## palette's hint, under the plan on both sub-tabs): a finished room that lowered charging or
## stayed off (docs/content/m25-lean-start.md section 3) and a lift segment refused for lack
## of funds (section 2). The same finished-room lines go to the operations log (LogRules).
## Bible: docs/content/m25-lean-start.md sections 2 and 3

var _palette: BuildPalette = null
var _state: GameState = null


## Shows the messages on [param palette], naming rooms from [param state].
func setup(palette: BuildPalette, state: GameState) -> void:
	_palette = palette
	_state = state


func _enter_tree() -> void:
	EventBus.charging_lowered.connect(_on_charging_lowered)
	EventBus.room_finished_off.connect(_on_room_finished_off)
	EventBus.supply_dropped.connect(_on_supply_dropped)
	EventBus.lift_segment_refused.connect(_on_lift_segment_refused)


func _exit_tree() -> void:
	EventBus.charging_lowered.disconnect(_on_charging_lowered)
	EventBus.room_finished_off.disconnect(_on_room_finished_off)
	EventBus.supply_dropped.disconnect(_on_supply_dropped)
	EventBus.lift_segment_refused.disconnect(_on_lift_segment_refused)


## Returns the line for [param event_name] with [param args], as the palette shows it.
func line_for(event_name: StringName, args: Array) -> String:
	if event_name == &"lift_segment_refused":
		var cost_k: int = args[1]
		return tr(&"BASE_MSG_LIFT_SEGMENT_REFUSED").format(
			{"n": args[0], "cost": MoneyLabel.format_k(cost_k)}
		)
	var details: Dictionary = {"room": _def_id(args[0])}
	if event_name == &"supply_dropped":
		details["charge_mw"] = args[1]
		details["rooms_off"] = args[2]
	elif event_name == &"charging_lowered":
		details["charge_mw"] = args[1]
	else:
		details["need_mw"] = args[1]
		details["spare_mw"] = args[2]
	return ArchiveLogRow.finished_room_line(details)


func _on_charging_lowered(room_id: StringName, charge_mw: int) -> void:
	_show(line_for(&"charging_lowered", [room_id, charge_mw]))


func _on_room_finished_off(room_id: StringName, need_mw: int, spare_mw: int) -> void:
	_show(line_for(&"room_finished_off", [room_id, need_mw, spare_mw]))


func _on_supply_dropped(room_id: StringName, charge_mw: int, rooms_off: int) -> void:
	_show(line_for(&"supply_dropped", [room_id, charge_mw, rooms_off]))


func _on_lift_segment_refused(level: int, cost_k: int) -> void:
	_show(line_for(&"lift_segment_refused", [level, cost_k]))


func _show(text: String) -> void:
	if _palette != null:
		_palette.show_message(text)


## The def id of room [param room_id], as a String; empty when it is gone.
func _def_id(room_id: Variant) -> String:
	if _state == null:
		return ""
	var room: RoomState = _state.base.find_room(StringName(str(room_id)))
	return "" if room == null else String(room.def_id)
