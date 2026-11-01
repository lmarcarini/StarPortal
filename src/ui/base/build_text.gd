class_name BuildText
extends RefCounted
## Text of building in the Base tab: build times, a palette entry's cost, draw and time, and
## the reason a placement, cancel, demolition or dig is refused, from the command's error.
## Bible: docs/content/m2-base.md sections 4 and 6


## "6 h", "2 d" or "45 min" for [param ticks] in-game minutes; whole days only when exact.
static func duration(ticks: int) -> String:
	if ticks >= TimeMath.TICKS_PER_DAY and ticks % TimeMath.TICKS_PER_DAY == 0:
		return _tr(&"BASE_BUILD_DAYS").format({"n": ticks / TimeMath.TICKS_PER_DAY})
	if ticks >= 60:
		return _tr(&"BASE_BUILD_HOURS").format({"n": ceili(ticks / 60.0)})
	return _tr(&"BASE_BUILD_MINUTES").format({"n": maxi(0, ticks)})


## "Physics Lab: $800k, 5 d, draw 4 MW" for [param def]; a corridor is priced per cell.
static func summary(def: RoomDef) -> String:
	var key: StringName = &"BASE_BUILD_SUMMARY"
	if def.id == StartingBase.CORRIDOR_DEF:
		key = &"BASE_BUILD_SUMMARY_CELL"
	return (
		_tr(key)
		. format(
			{
				"name": _tr(def.name_key),
				"cost": MoneyLabel.format_k(def.build_cost_k),
				"time": duration(def.build_ticks),
				"power": BasePanelText.power(def),
			}
		)
	)


## Why [param result] refused an action, in words, for [param state]; [param cost_k] is the
## action's cost, for the money reason. An overlap reads [method overlap_reason] instead.
static func reason(result: CommandResult, state: GameState, cost_k: int) -> String:
	if result.error_code == &"insufficient_funds":
		return (
			_tr(&"BASE_BUILD_NEEDS_MONEY")
			. format(
				{
					"cost": MoneyLabel.format_k(cost_k),
					"have": MoneyLabel.format_k(state.budget.funds_k),
				}
			)
		)
	var key: String = "BASE_BUILD_ERR_%s" % String(result.error_code).to_upper()
	var text: String = _tr(StringName(key))
	return _tr(&"BASE_BUILD_ERR_OTHER") if text == key else text


## "Overlaps the Archive." for the first room on [param level] covering part of [param area];
## with [param other_level] true, "Overlaps the Archive on Level 2." (a lift's blocking level).
static func overlap_reason(
	state: GameState, level: int, area: Rect2i, other_level: bool = false
) -> String:
	for room: RoomState in BaseRules.rooms_on_level(state.base, level):
		var def: RoomDef = state.room_defs.get(room.def_id)
		if def != null and BaseRules.footprint(room, def).intersects(area):
			var key: StringName = (
				&"BASE_BUILD_OVERLAP_LEVEL" if other_level else &"BASE_BUILD_OVERLAP"
			)
			return _tr(key).format({"name": _tr(def.name_key), "level": level})
	return _tr(&"BASE_BUILD_OVERLAP_ANY")


## The level number of a command detail such as "level 2", or 0.
static func level_of(detail: String) -> int:
	var parts: PackedStringArray = detail.split(" ")
	if parts.size() == 2 and parts[0] == "level" and parts[1].is_valid_int():
		return parts[1].to_int()
	return 0


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
