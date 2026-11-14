class_name SoakStory
extends RefCounted
## The soak bot's story habits (M4): answers phone calls, answers every other incoming
## wormhole and ignores the rest, accepts offered requests, picks the first enabled answer and
## hails a held world once per lock while its faction has something to say, then looks after
## artefacts (SoakArtefacts). One command per call at most.


## Submits one story command when one applies and no other command is queued.
static func work(simulation: Simulation) -> void:
	var state: GameState = simulation.state
	if simulation.commands.pending_count() > 0:
		return
	var command: Command = _next(state)
	if command != null and command.validate(state).is_ok:
		simulation.submit(command)


static func _next(state: GameState) -> Command:
	if state.conversations.active != null:
		var shown: Array[Dictionary] = ConversationRules.choices(state)
		for choice: Dictionary in shown:
			if choice["enabled"]:
				var index: int = choice["index"]
				return ChooseOptionCommand.new(index)
		return null
	if state.gate.has_incoming():
		if state.gate.incoming_until_tick % 2 == 0:
			return AnswerIncomingCommand.new()
		return IgnoreIncomingCommand.new()
	if ContactRules.next_pending(state, &"phone") >= 0:
		return AnswerCallCommand.new()
	for record: RequestRecord in state.requests.items:
		if record.state == RequestRecord.RequestState.OFFERED:
			return AcceptRequestCommand.new(record.uid)
	if GateQueries.can_hail(state) and _worth_hailing(state):
		return HailCommand.new()
	return SoakArtefacts.next(state)


## True when the held world's faction has a conversation to start and none ran on this lock.
static func _worth_hailing(state: GameState) -> bool:
	var faction: StringName = GateQueries.locked_faction(state)
	var world: StringName = state.gate.connected_world_id
	if faction.is_empty() or ConversationRules.pick(faction, &"wormhole", world, state).is_empty():
		return false
	var transcripts: Array[TranscriptRecord] = state.conversations.transcripts
	return transcripts.is_empty() or transcripts[-1].tick < state.gate.lock_started_tick
