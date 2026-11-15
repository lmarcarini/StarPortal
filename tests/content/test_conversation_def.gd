## Tests for ConversationDef (M4-07): a fixture with each node kind loads; the graph checks
## catch duplicate ids, missing nodes, unreachable nodes, loops, stuck choices and wrong
## channels; text keys need every locale; faction contacts must name conversations.
## Bible: docs/content/m4-core-systems.md section 3
extends GdUnitTestSuite

const RegistryScript := preload("res://src/content/registry.gd")

var _registry: RegistryScript


func before_test() -> void:
	_registry = auto_free(RegistryScript.new())


func _load() -> ConversationDef:
	var errors: Array[String] = (
		_registry.load_all("res://tests/content/fixtures/conversations").value
	)
	assert_array(errors).is_empty()
	return _registry.get_def(&"conv_greeting") as ConversationDef


func _line(id: StringName, next: StringName) -> ConversationNodeDef:
	var node := ConversationNodeDef.new()
	node.id = id
	node.text_key = &"K"
	node.next = next
	return node


func _end(id: StringName) -> ConversationNodeDef:
	var node := ConversationNodeDef.new()
	node.id = id
	node.kind = ConversationNodeDef.Kind.END
	return node


func _conversation(nodes: Array[ConversationNodeDef]) -> ConversationDef:
	var conversation := ConversationDef.new()
	conversation.channels = [&"wormhole"]
	conversation.start = &"a"
	conversation.nodes = nodes
	return conversation


func test_fixture_loads_every_node_kind() -> void:
	var conversation: ConversationDef = _load()
	assert_int(conversation.nodes.size()).is_equal(4)
	assert_int(conversation.node(&"hello").kind).is_equal(ConversationNodeDef.Kind.LINE)
	assert_int(conversation.node(&"ask").kind).is_equal(ConversationNodeDef.Kind.CHOICE)
	assert_bool(conversation.node(&"ask").choices[0].show_locked).is_true()
	assert_int(conversation.node(&"end_good").effects.size()).is_equal(1)
	assert_object(conversation.node(&"nowhere")).is_null()
	assert_int(conversation.all_conditions().size()).is_equal(1)
	assert_int(conversation.all_effects().size()).is_equal(1)


func test_graph_errors() -> void:
	var good: Array[ConversationNodeDef] = [_line(&"a", &"z"), _end(&"z")]
	assert_array(ConversationGraph.errors(_conversation(good))).is_empty()
	var repeated: Array[ConversationNodeDef] = [_line(&"a", &"z"), _end(&"z"), _end(&"z")]
	assert_array(ConversationGraph.errors(_conversation(repeated))).contains(
		["node 'z' is repeated"]
	)
	var missing: Array[ConversationNodeDef] = [_line(&"a", &"q")]
	assert_array(ConversationGraph.errors(_conversation(missing))).contains(
		["node 'a' leads to unknown 'q'"]
	)
	var orphan: Array[ConversationNodeDef] = [_line(&"a", &"z"), _end(&"z"), _end(&"lost")]
	assert_array(ConversationGraph.errors(_conversation(orphan))).contains(
		["node 'lost' cannot be reached from start"]
	)
	var loop: Array[ConversationNodeDef] = [_line(&"a", &"b"), _line(&"b", &"a")]
	assert_array(ConversationGraph.errors(_conversation(loop))).contains(
		["the nodes form a loop, so a path never ends"]
	)
	var no_start: ConversationDef = _conversation(good)
	no_start.start = &"x"
	assert_array(ConversationGraph.errors(no_start)).contains(["start 'x' is not a node"])


func test_choice_needs_a_free_answer() -> void:
	var choice := ConversationNodeDef.new()
	choice.id = &"a"
	choice.kind = ConversationNodeDef.Kind.CHOICE
	var locked := ConversationChoiceDef.new()
	locked.next = &"z"
	locked.conditions.append(FactionMetCondition.new())
	choice.choices.append(locked)
	var nodes: Array[ConversationNodeDef] = [choice, _end(&"z")]
	assert_array(ConversationGraph.errors(_conversation(nodes))).contains(
		["choice 'a' needs an answer without conditions"]
	)


func test_channels_match_the_faction_kind() -> void:
	var earth := FactionDef.new()
	earth.id = &"faction_earth"
	earth.kind = &"earth"
	var nodes: Array[ConversationNodeDef] = [_line(&"a", &"z"), _end(&"z")]
	var conversation: ConversationDef = _conversation(nodes)
	conversation.faction = earth.id
	var defs: Dictionary[StringName, DefBase] = {earth.id: earth}
	assert_array(conversation.get_content_errors(defs)).contains(
		["wormhole is only for alien factions"]
	)
	conversation.channels = [&"phone"]
	assert_array(conversation.get_content_errors(defs)).is_empty()
	earth.kind = &"alien"
	assert_array(conversation.get_content_errors(defs)).contains(
		["phone is only for earth factions"]
	)
	conversation.channels = [&"radio"]
	assert_array(conversation.get_content_errors(defs)).contains(["unknown channel 'radio'"])


func test_text_keys_need_every_locale() -> void:
	var conversation: ConversationDef = _load()
	var known: Dictionary[StringName, DefBase] = {}
	for def: DefBase in _registry.get_all_of(DefBase):
		known[def.id] = def
	var table: Dictionary[String, PackedStringArray] = {
		"CONV_TEST_ELDER": PackedStringArray(["Elder", "Ancião"]),
		"CONV_TEST_HELLO": PackedStringArray(["Hello", ""]),
		"CONV_TEST_ANSWER_FRIEND": PackedStringArray(["Friend", "Amigo"]),
		"CONV_TEST_ANSWER_BYE": PackedStringArray(["Bye", "Tchau"]),
	}
	var conversations: Array[ConversationDef] = [conversation]
	assert_array(ContentCheckConversations.check(conversations, known, table)).is_equal(
		["conversation conv_greeting: key 'CONV_TEST_HELLO' has no pt_BR text in conversations.csv"]
	)


func test_contacts_must_name_conversations() -> void:
	_load()
	var known: Dictionary[StringName, DefBase] = {}
	for def: DefBase in _registry.get_all_of(DefBase):
		known[def.id] = def
	var committee := FactionDef.new()
	committee.uses_confidence = true
	committee.contacts = [&"conv_greeting", &"faction_kindred"]
	committee.id = &"faction_committee"
	var factions: Array[FactionDef] = [committee]
	assert_array(ContentCheckFactions.check(factions, known)).is_equal(
		["faction faction_committee: contact 'faction_kindred' is not a conversation"]
	)


func test_game_defs_gathers_conversations() -> void:
	_load()
	assert_int(GameDefs.from_registry(_registry).conversations.size()).is_equal(1)
