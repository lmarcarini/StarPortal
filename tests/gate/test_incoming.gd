## Tests for incoming wormholes (M4-11): they start only while the Ring is idle, ask for a
## pause and refuse dialing; unanswered they are ignored after incoming_answer_minutes; Answer
## locks the Ring to the faction's world with no drain, starts the conversation and meets the
## faction, and the open time limit still applies; Ignore costs standing −2; a save while one
## waits restores it; the banner offers Answer and Ignore.
## Bible: docs/content/m4-core-systems.md section 3 (Incoming wormhole)
extends GdUnitTestSuite

const ConversationTests := preload("res://tests/dialog/test_conversation_runner.gd")
const KINDRED: StringName = &"faction_kindred"
const WORLD: StringName = &"world_lintel"

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = StoryFixture.state()
	for record: WorldRecord in _state.galaxy.all_worlds():
		if record.controller == KINDRED:
			record.controller = &""
	_state.galaxy.get_world(WORLD).controller = KINDRED
	var def: ConversationDef = ConversationTests.make_def()
	def.channels = [&"incoming"]
	_state.conversation_defs[def.id] = def
	_state.power.stored_mwh = 10.0
	_state.clock.mode = ClockState.Mode.RUNNING
	var contact := PendingContact.new()
	contact.faction = KINDRED
	contact.conversation = def.id
	_state.factions.pending.append(contact)
	_simulation = Simulation.new(
		_state, [PowerSystem.new(_state.balance), GateSystem.new(), ConversationSystem.new()]
	)


func _ticks(count: int) -> void:
	for index: int in count:
		_simulation.advance_tick()


func test_starts_when_idle_pauses_and_blocks_dialing() -> void:
	var paused: Array[StringName] = []
	_simulation.pause_requested.connect(func(reason: StringName) -> void: paused.append(reason))
	_ticks(1)
	assert_bool(_state.gate.has_incoming()).is_true()
	assert_array(_state.factions.pending).is_empty()
	assert_array(paused).is_equal([&"incoming_wormhole"])
	var dial := DialCommand.create(GateAddress.create([3, 17, 0, 22, 9, 14, 30], 5))
	assert_str(String(dial.validate(_state).error_code)).is_equal("ring_busy")


func test_waits_while_a_conversation_runs() -> void:
	_state.conversations.active = ActiveConversation.new()
	_state.conversations.active.channel = &"phone"
	GateSystem.new().tick(_state)
	assert_bool(_state.gate.has_incoming()).is_false()
	_state.conversations.active = null
	GateSystem.new().tick(_state)
	assert_bool(_state.gate.has_incoming()).is_true()


func test_timeout_ignores() -> void:
	_ticks(1)
	var standing: int = FactionRules.standing(_state, KINDRED)
	_ticks(_state.balance.incoming_answer_minutes)
	assert_bool(_state.gate.has_incoming()).is_false()
	assert_int(FactionRules.standing(_state, KINDRED)).is_equal(standing - 2)
	assert_str(String(_state.gate.incoming_faction)).is_empty()


func test_answer_locks_without_drain_and_starts() -> void:
	_ticks(1)
	assert_bool(_simulation.submit(AnswerIncomingCommand.new()).is_ok).is_true()
	_ticks(1)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_str(String(_state.gate.connected_world_id)).is_equal("world_lintel")
	assert_bool(_state.gate.is_incoming_lock()).is_true()
	assert_float(PowerMath.drain_mw(_state.gate, _state.balance)).is_equal(0.0)
	assert_str(String(_state.conversations.active.channel)).is_equal("incoming")
	assert_array(_state.factions.met).contains([KINDRED])
	assert_array(_state.gate.dial_log).is_empty()
	_state.power.stored_mwh = 0.0
	_ticks(3)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	_ticks(_state.balance.max_open_ticks)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_str(String(_state.gate.incoming_faction)).is_empty()
	assert_bool(_state.conversations.transcripts[0].cut_off).is_true()


func test_ignore_command() -> void:
	assert_str(String(IgnoreIncomingCommand.new().validate(_state).error_code)).is_equal(
		"no_incoming"
	)
	_ticks(1)
	var standing: int = FactionRules.standing(_state, KINDRED)
	assert_bool(_simulation.submit(IgnoreIncomingCommand.new()).is_ok).is_true()
	_ticks(1)
	assert_int(FactionRules.standing(_state, KINDRED)).is_equal(standing - 2)
	assert_bool(_state.gate.has_incoming()).is_false()
	var cause: Dictionary = _state.factions.causes[KINDRED][-1]
	assert_str(str(cause["key"])).is_equal("CAUSE_INCOMING_IGNORED")


func test_save_while_waiting() -> void:
	_ticks(1)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	var loaded: GameState = GameState.from_dict(data)
	assert_bool(loaded.gate.has_incoming()).is_true()
	assert_int(loaded.gate.incoming_until_tick).is_equal(_state.gate.incoming_until_tick)


func test_world_falls_back_to_the_conversation() -> void:
	for record: WorldRecord in _state.galaxy.all_worlds():
		record.controller = &""
	var def: ConversationDef = _state.conversation_defs[ConversationTests.CONV]
	def.worlds = [&"world_x"]
	assert_str(String(IncomingRules.world_of(_state, KINDRED, def.id))).is_equal("world_x")


func test_banner() -> void:
	var banner: IncomingBanner = auto_free(IncomingBanner.new())
	add_child(banner)
	banner.setup(_simulation)
	assert_bool(banner.visible).is_false()
	_ticks(1)
	banner.render(_state)
	assert_bool(banner.visible).is_true()
	banner.get_ignore_button().pressed.emit()
	_ticks(1)
	banner.render(_state)
	assert_bool(banner.visible).is_false()
