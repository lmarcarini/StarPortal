## Shared setup for the story tests: a game built from the real content, plus a test request.
class_name StoryFixture
extends RefCounted


## A new game built from data/ without its factions, conversations and requests (each test
## adds its own), with request &"request_test" (offer 3 days) registered.
static func state() -> GameState:
	var state := GameState.new_game(11)
	GameSetup.build(state, GameDefs.from_registry(Registry))
	state.conversation_defs.clear()
	state.request_defs.clear()
	state.faction_defs.clear()
	var request := RequestDef.new()
	request.id = &"request_test"
	request.offer_days = 3
	state.request_defs[request.id] = request
	state.factions.standing[&"faction_kindred"] = 0
	state.events.drain()
	return state


## Names of the events posted since the last drain.
static func event_names(state: GameState) -> Array[StringName]:
	var names: Array[StringName] = []
	for event: SimEvent in state.events.drain():
		names.append(event.name)
	return names
