class_name RescueAlertText
extends RefCounted
## Words of the rescue alert and its entry on the top bar's alert stack
## (docs/content/m3-beyond-the-ring.md section 4, Missed check-in and rescue, and section 7):
## the title, the window left, how to rescue, the world's threat as the report knows it with
## the plain warning that the outcome is not certain and waiting lowers the odds (never a
## percentage), the charge forecast and its verdict. Pure: reads the state.
## Bible: docs/content/m3-beyond-the-ring.md sections 4 and 7


## "T-1 MISSED ITS CHECK-IN (STILLWATER)".
static func title(state: GameState) -> String:
	return _tr(&"RESCUE_ALERT_TITLE").format({"world": _world(state)})


## "Window: 71 h 58 min".
static func window(state: GameState) -> String:
	return _tr(&"RESCUE_ALERT_WINDOW").format({"time": _window_left(state)})


## "Rescue: dial STILLWATER, then Signal T-1 from the Ring.", or, once signalled, when T-1
## reaches the Ring.
static func how(state: GameState) -> String:
	var sent: int = state.expedition.signal_tick
	if sent >= 0:
		var left: int = sent + ExpeditionRescue.SIGNAL_TICKS - state.clock.tick
		return _tr(&"RESCUE_ALERT_SIGNALLED").format({"left": GateRoomFormat.duration(left)})
	return _tr(&"EXPEDITION_TIMELINE_RESCUE").format({"world": _world(state)})


## The threat as the report knows it and the warning that the outcome is uncertain and that
## waiting lowers the odds. No percentages (owner, 2026-11-07).
static func odds(state: GameState) -> String:
	var threat: String = ExpeditionText.threat(state, state.expedition.world_id)
	return _tr(&"RESCUE_ALERT_ODDS").format({"threat": threat})


## "Charge needed 371.6 MWh   Stored 0.0 MWh   Charging 5 MW: ready in 74 h 0 min".
static func charge(state: GameState) -> String:
	var rate: float = PowerRules.charge_mw(state)
	return (
		_tr(&"RESCUE_ALERT_CHARGE")
		. format(
			{
				"needed": GateRoomFormat.energy(RescueForecast.needed_mwh(state)),
				"stored": GateRoomFormat.energy(state.power.stored_mwh),
				"rate": String.num(rate, 1).trim_suffix(".0"),
				"ready": _ready_in(RescueForecast.ticks_until_ready(state, rate)),
			}
		)
	)


## The verdict for RescueForecast.status(): on time (needed, ready in, window), too slow at
## the current rate, or not enough even at maximum.
static func verdict(state: GameState) -> String:
	match RescueForecast.status(state):
		RescueForecast.ON_TIME:
			var ready: int = RescueForecast.ticks_until_ready(state, PowerRules.charge_mw(state))
			return (
				_tr(&"RESCUE_ALERT_ON_TIME")
				. format(
					{
						"needed": GateRoomFormat.energy(RescueForecast.needed_mwh(state)),
						"ready": _ready_in(ready),
						"window": _window_left(state),
					}
				)
			)
		RescueForecast.TOO_SLOW:
			return _tr(&"RESCUE_ALERT_TOO_SLOW")
	return _tr(&"RESCUE_ALERT_NOT_ENOUGH")


## The alert stack's entry: "T-1 missing  71 h 58 min".
static func stack_entry(state: GameState) -> String:
	return _tr(&"ALERT_RESCUE_ENTRY").format({"time": _window_left(state)})


static func _window_left(state: GameState) -> String:
	return GateRoomFormat.duration(RescueForecast.window_ticks_left(state))


static func _ready_in(ticks: int) -> String:
	if ticks < 0:
		return _tr(&"RESCUE_ALERT_NEVER")
	if ticks == 0:
		return _tr(&"RESCUE_ALERT_READY_NOW")
	return _tr(&"RESCUE_ALERT_READY_IN").format({"time": GateRoomFormat.duration(ticks)})


static func _world(state: GameState) -> String:
	return AddressBookText.name_of_world(state.expedition.world_id, state)


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
