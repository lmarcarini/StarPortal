class_name PowerText
extends RefCounted
## Text of the Base tab's power controls: the capacitors line, a room's tag on the energy
## layer, the reason a switch is locked and the plain words of a refused power command.
## Bible: docs/content/m2-base.md sections 3 and 6


## "Capacitors 214/400 MWh, full in 7 h" (or full, not charging, draining), or "No capacitors
## installed" when [param state] has no capacity.
static func capacitors(state: GameState) -> String:
	var capacity: float = PowerRules.capacity_mwh(state)
	if capacity <= 0.0:
		return _tr(&"BASE_POWER_CAP_NONE")
	var stored: float = state.power.stored_mwh
	var values: Dictionary = {"stored": floori(stored), "cap": roundi(capacity)}
	var net: float = PowerRules.net_flow_mw(state)
	if stored >= capacity - 0.001:
		return _tr(&"BASE_POWER_CAP_FULL").format(values)
	if net < 0.0:
		return _tr(&"BASE_POWER_CAP_DRAIN").format(values)
	if net <= 0.0:
		return _tr(&"BASE_POWER_CAP_IDLE").format(values)
	values["h"] = ceili((capacity - stored) / net)
	return _tr(&"BASE_POWER_CAP_FILL").format(values)


## Why [param room]'s switch is locked: always on, or the base's last running plant; "" when
## it is not locked.
static func lock_reason(state: GameState, room: RoomState, def: RoomDef) -> String:
	if def == null or room == null:
		return ""
	if def.always_on:
		return _tr(&"BASE_POWER_LOCK_ALWAYS_ON")
	if def.power_output_mw > 0.0 and PowerRules.is_running(room, def):
		var check: CommandResult = SwitchRoomCommand.create(room.id, false).validate(state)
		if check.error_code == &"last_plant":
			return _tr(&"BASE_POWER_LOCK_LAST_PLANT")
	return ""


## The tag the energy layer draws on [param room]: "ON 4", "OFF", "LOCK 2", "+30" or
## "CHG 26"; "" for a room with no power role (lifts, stairs, corridors) or not standing.
static func tag(state: GameState, room: RoomState, def: RoomDef) -> String:
	if def == null or not PowerRules.is_standing(room):
		return ""
	if PowerRules.is_bank(def):
		var rate: int = state.power.charge_rates.get(room.id, 0)
		return _tr(&"BASE_POWER_TAG_CHARGE").format({"mw": rate})
	if def.always_on:
		return _tr(&"BASE_POWER_TAG_LOCK").format({"mw": mw(def.power_draw_mw)})
	if not PowerRules.has_switch(def):
		return ""
	if not room.powered_on:
		return _tr(&"BASE_POWER_TAG_OFF")
	if def.power_output_mw > 0.0:
		return _tr(&"BASE_POWER_TAG_PLANT").format({"mw": mw(def.power_output_mw)})
	return _tr(&"BASE_POWER_TAG_ON").format({"mw": mw(def.power_draw_mw)})


## The plain words of a refused power command with error [param code]: [param need] MW were
## needed with [param spare] MW spare; [param plant_off] when a plant was being switched off.
static func refusal(code: StringName, need: float, spare: float, plant_off: bool) -> String:
	var values: Dictionary = {"need": mw(need), "spare": mw(maxf(spare, 0.0))}
	match code:
		&"no_spare_power":
			var key: StringName = (
				&"BASE_POWER_REFUSED_PLANT_OFF" if plant_off else &"BASE_POWER_REFUSED_SPARE"
			)
			return _tr(key).format(values)
		&"last_plant":
			return _tr(&"BASE_POWER_LOCK_LAST_PLANT")
		&"no_switch":
			return _tr(&"BASE_POWER_REFUSED_NO_SWITCH")
	return _tr(&"BASE_POWER_REFUSED_OTHER")


## [param value] MW as text: whole numbers without decimals.
static func mw(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return "%.1f" % value


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
