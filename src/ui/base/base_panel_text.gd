class_name BasePanelText
extends RefCounted
## Text of the Base tab's selected-room panel and palette: a room's power, upkeep and status
## lines, its "now" and "later" role lines and what unlocks it.
## Bible: docs/content/m2-base.md section 6; docs/content/m25-lean-start.md section 4


## "Draw 4 MW", "Output +30 MW" or "No power draw" for [param def].
static func power(def: RoomDef) -> String:
	if def.power_output_mw > 0.0:
		return _tr(&"BASE_PANEL_OUTPUT").format({"mw": _mw(def.power_output_mw)})
	if def.power_draw_mw > 0.0:
		return _tr(&"BASE_PANEL_DRAW").format({"mw": _mw(def.power_draw_mw)})
	return _tr(&"BASE_PANEL_NO_DRAW")


## "Upkeep $60k / month", or "No upkeep" when [param upkeep_k] is 0.
static func upkeep(upkeep_k: int) -> String:
	if upkeep_k <= 0:
		return _tr(&"BASE_PANEL_NO_UPKEEP")
	return _tr(&"BASE_PANEL_UPKEEP").format({"k": upkeep_k})


## The status of [param room]: under construction with days left, always on, on or off.
static func status(room: RoomState, def: RoomDef) -> String:
	if not room.is_built():
		var days: int = ceili(float(room.build_ticks_left) / TimeMath.TICKS_PER_DAY)
		return _tr(&"BASE_STATUS_BUILDING").format({"days": days})
	if def.always_on:
		return _tr(&"BASE_STATUS_ALWAYS_ON")
	return _tr(&"BASE_STATUS_ON" if room.powered_on else &"BASE_STATUS_OFF")


## The "now" line of [param def]: what the room does in M2.5.
static func now(def: RoomDef) -> String:
	return _tr(def.description_key)


## "Later: Squads move between levels." for [param def] (its ROOM_*_LATER key, next to its
## name key), or "" when the room has no later line (Quarters, Infirmary).
static func later(def: RoomDef) -> String:
	var key: String = later_key(def)
	var text: String = _tr(StringName(key))
	if key.is_empty() or text == key:
		return ""
	return _tr(&"ROOM_LATER_LINE").format({"text": text})


## The ROOM_*_LATER key of [param def], from its ROOM_*_NAME key; "" for another name key.
static func later_key(def: RoomDef) -> String:
	var name: String = def.name_key
	if not name.ends_with("_NAME"):
		return ""
	return name.trim_suffix("_NAME") + "_LATER"


## "Unlock: Lift shaft" for [param project_id] (an UnlockRules project).
static func unlock(project_id: StringName) -> String:
	var project: String = _tr(UnlockRules.project_name_key(project_id))
	return _tr(&"ROOM_UNLOCK_BY").format({"name": project})


static func _mw(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return "%.1f" % value


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
