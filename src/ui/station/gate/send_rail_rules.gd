class_name SendRailRules
extends RefCounted
## What each key of the send rail shows while a wormhole is open: CAMERA, CANISTER, MOTH,
## TEAM and HAIL, each READY, ACTIVE (in progress), USED (done this lock) or UNAVAILABLE with
## the reason as a translation key, plus the command a press submits. An answered incoming
## wormhole shows only HAIL. Pure.
## Bible: docs/content/interface-rethink.md section 4 (Gate, With a wormhole open)

## Rail keys, in order (keys 1 to 5).
const KEYS: Array[StringName] = [&"camera", &"canister", &"moth", &"team", &"hail"]
## Reason when a command code has no text of its own.
const FALLBACK_REASON: StringName = &"STATION_REASON_UNAVAILABLE"


## One key's look.
class KeyLook:
	extends RefCounted
	## Key id (one of KEYS).
	var id: StringName
	## Shown at all.
	var shown: bool = true
	## IconKey.KeyState value.
	var state: int = IconKey.KeyState.READY
	## Hover reason key when UNAVAILABLE, else the key's help.
	var reason: StringName = &""
	## Badge text.
	var badge: String = ""


## True while the rail is up: a wormhole is open.
static func is_shown(state: GameState) -> bool:
	return state.gate.mode == GateState.RingMode.LOCKED


## The look of every key for [param state].
static func looks(state: GameState) -> Array[KeyLook]:
	var out: Array[KeyLook] = [
		camera(state), canister(state), moth(state), team(state), hail(state)
	]
	if state.gate.is_incoming_lock():
		for look: KeyLook in out:
			look.shown = look.id == &"hail"
	return out


## The command a press of [param id] submits, or null when it does nothing now.
static func command_for(state: GameState, id: StringName) -> Command:
	match id:
		&"camera":
			return ExtendPoleCameraCommand.new()
		&"canister":
			return LaunchCanisterCommand.new()
		&"moth":
			return LaunchMothCommand.new()
		&"team":
			if SignalTeamCommand.new().validate(state).is_ok:
				return SignalTeamCommand.new()
			return SendTeamCommand.new()
		&"hail":
			return HailCommand.new()
	return null


## The pole camera key.
static func camera(state: GameState) -> KeyLook:
	var look: KeyLook = _look(&"camera", ExtendPoleCameraCommand.new().validate(state))
	if state.worlds.is_pole_camera_out():
		look.state = IconKey.KeyState.ACTIVE
	elif state.worlds.is_horizon_record_taken(state.gate.connected_world_id):
		look.state = IconKey.KeyState.USED
	return look


## The canister key.
static func canister(state: GameState) -> KeyLook:
	var look: KeyLook = _look(&"canister", LaunchCanisterCommand.new().validate(state))
	if state.probes.is_canister_out():
		look.state = IconKey.KeyState.ACTIVE
	return look


## The MOTH key; its badge is the MOTHs on the rack.
static func moth(state: GameState) -> KeyLook:
	var look: KeyLook = _look(&"moth", LaunchMothCommand.new().validate(state))
	look.badge = str(state.probes.rack) if MothRules.has_rack(state) else ""
	if state.probes.is_moth_out():
		look.state = IconKey.KeyState.ACTIVE
	return look


## The team key: send the planned team, or signal a missing one; ACTIVE with a team there.
static func team(state: GameState) -> KeyLook:
	var command: Command = command_for(state, &"team")
	var look: KeyLook = _look(&"team", command.validate(state))
	var trip: ExpeditionState = state.expedition
	if trip.mode == ExpeditionState.Mode.AWAY and trip.world_id == state.gate.connected_world_id:
		look.state = IconKey.KeyState.ACTIVE
	return look


## The hail key, shown only when someone can be spoken to.
static func hail(state: GameState) -> KeyLook:
	var look: KeyLook = _look(&"hail", HailCommand.new().validate(state))
	look.shown = GateQueries.can_hail(state)
	return look


static func _look(id: StringName, check: CommandResult) -> KeyLook:
	var look: KeyLook = KeyLook.new()
	look.id = id
	if check.is_ok:
		look.reason = StringName("HW_ICON_" + String(id).to_upper())
		return look
	look.state = IconKey.KeyState.UNAVAILABLE
	look.reason = reason_key(check.error_code)
	return look


## Translation key of the reason for command code [param code].
static func reason_key(code: StringName) -> StringName:
	var key: StringName = StringName("GATE_ERR_" + String(code).to_upper())
	if TranslationServer.translate(key) != key:
		return key
	var expedition: StringName = StringName("EXPEDITION_ERR_" + String(code).to_upper())
	if TranslationServer.translate(expedition) != expedition:
		return expedition
	return FALLBACK_REASON
