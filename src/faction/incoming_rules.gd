class_name IncomingRules
extends RefCounted
## Rules of an incoming wormhole once it waits: answer it (the Ring locks to the faction's
## world from the far side, the faction is met and the conversation starts on channel
## &"incoming") or ignore it (standing −2, the contact is dropped, a Log line).
## Bible: docs/content/m4-core-systems.md section 3 (Incoming wormhole)

## Standing lost for ignoring, and the cause key.
const IGNORE_CHANGE: int = -2
const IGNORE_CAUSE: StringName = &"CAUSE_INCOMING_IGNORED"


## The world the incoming wormhole comes from: the first world (by id) whose controller is
## [param faction], else the first world the conversation lists, else &"".
static func world_of(state: GameState, faction: StringName, conversation: StringName) -> StringName:
	if state.galaxy != null:
		var ids: Array[StringName] = []
		for record: WorldRecord in state.galaxy.all_worlds():
			if record.controller == faction:
				ids.append(record.id)
		ids.sort()
		if not ids.is_empty():
			return ids[0]
	var def: ConversationDef = state.conversation_defs.get(conversation)
	if def != null and not def.worlds.is_empty():
		return def.worlds[0]
	return &""


## Answers the waiting incoming wormhole: locks the Ring, drops the clock to 1×, meets the
## faction, starts the conversation and posts incoming_answered.
static func answer(state: GameState) -> void:
	var gate: GateState = state.gate
	var faction: StringName = gate.incoming_faction
	var conversation: StringName = gate.incoming_conversation
	var world: StringName = world_of(state, faction, conversation)
	RingControl.answer_incoming(gate, world, state.clock.tick)
	if not world.is_empty():
		WorldProgress.raise_status(state, world, WorldsState.WorldStatus.LOCKED)
	FactionRules.meet(state, faction)
	state.events.post(&"incoming_answered", [faction])
	ConversationRules.start(state, conversation, &"incoming", world)


## Ignores the waiting incoming wormhole (by command or timeout): standing −2, the contact is
## dropped and incoming_ignored is posted.
static func ignore(state: GameState) -> void:
	var faction: StringName = state.gate.incoming_faction
	state.gate.clear_incoming()
	FactionRules.change(state, faction, IGNORE_CHANGE, IGNORE_CAUSE)
	state.events.post(&"incoming_ignored", [faction])
