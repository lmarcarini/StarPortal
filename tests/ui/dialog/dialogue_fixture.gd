class_name DialogueFixture
extends RefCounted
## Test helper (M4.8): a real game with the Ring locked to LINTEL, its Simulation bound to the
## EventBus, and a dialogue screen in a 1280 × 720 root.
## Bible: docs/content/dialogue-screen.md

var state: GameState
var simulation: Simulation
var root := Control.new()
var screen := DialogueScreen.new()


func _init(parent: Node) -> void:
	TranslationServer.set_locale("en")
	var defs: GameDefs = GameDefs.from_registry(Registry)
	state = GameState.new_game(5, defs.balance)
	simulation = GameSetup.build_new(state, defs).value
	state.gate.mode = GateState.RingMode.LOCKED
	state.clock.mode = ClockState.Mode.RUNNING
	state.factions.met.append(&"faction_kindred")
	EventBus.bind_simulation(simulation)
	root.size = Vector2(1280, 720)
	root.add_child(screen)
	parent.add_child(root)
	screen.bind(simulation)


## Starts [param conversation] on [param channel] at LINTEL and lets its events out.
func start(conversation: StringName, channel: StringName = &"wormhole") -> void:
	var world: StringName = &"" if channel == &"phone" else &"world_lintel"
	ConversationRules.start(state, conversation, channel, world)
	flush()


## Lets posted events out: a command that applies at once while the clock is held.
func flush() -> void:
	simulation.submit(SetFlagCommand.create(&"dialogue_fixture", 1))


## Unbinds the EventBus and frees the root.
func dispose() -> void:
	EventBus.bind_simulation(null)
	root.free()
