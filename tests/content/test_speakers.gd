## Tests for speakers, moods and portrait data (M4.8-03): every line of the shipped
## conversations names a SpeakerDef, every speaker a PortraitDef (one Committee speaker is a
## still), lines read as before, and the checks catch an unknown speaker, portrait or mood.
## Bible: docs/content/dialogue-screen.md sections 3 and 7
extends GdUnitTestSuite

const TEMP_DIR: String = "user://test_speakers"


func after_test() -> void:
	for file: String in DirAccess.get_files_at(TEMP_DIR):
		DirAccess.remove_absolute(TEMP_DIR.path_join(file))
	DirAccess.remove_absolute(TEMP_DIR)


func _conversations() -> Array[ConversationDef]:
	return GameDefs.from_registry(Registry).conversations


func test_every_line_names_a_known_speaker_with_a_portrait() -> void:
	var lines: int = 0
	for conversation: ConversationDef in _conversations():
		for node: ConversationNodeDef in conversation.nodes:
			if node.kind != ConversationNodeDef.Kind.LINE:
				continue
			lines += 1
			var speaker: SpeakerDef = Registry.speaker(node.speaker)
			assert_object(speaker).override_failure_message(String(node.speaker)).is_not_null()
			assert_object(Registry.portrait(speaker.portrait)).is_not_null()
			assert_bool(node.mood.is_empty() or ConversationNodeDef.MOODS.has(node.mood)).is_true()
	assert_int(lines).is_greater(10)
	assert_int(_conversations().size()).is_equal(9)


func test_speakers_cover_both_portrait_cases_and_the_player() -> void:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var stills: Array[StringName] = []
	for speaker: SpeakerDef in defs.speakers:
		if Registry.portrait(speaker.portrait).still:
			stills.append(speaker.faction)
	assert_array(stills).contains([&"faction_committee"])
	assert_bool(stills.size() < defs.speakers.size()).is_true()
	var player: SpeakerDef = Registry.speaker(&"speaker_player")
	assert_str(String(player.faction)).is_empty()
	assert_bool(Registry.portrait(player.portrait).still).is_false()


func test_game_state_holds_the_defs() -> void:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var state := GameState.new_game(1, defs.balance)
	GameSetup.build_new(state, defs)
	assert_object(state.speaker_defs.get(&"speaker_kindred_elder")).is_not_null()
	assert_object(state.portrait_defs.get(&"portrait_liaison")).is_not_null()


func test_lines_read_as_before() -> void:
	TranslationServer.set_locale("en")
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var state := GameState.new_game(1, defs.balance)
	GameSetup.build_new(state, defs)
	var hail: ConversationDef = state.conversation_defs[&"conv_kindred_first_hail"]
	assert_str(ConversationText.line(state, hail.node(&"l1"))).starts_with("Kindred Elder: ")
	var briefing: ConversationDef = state.conversation_defs[&"conv_committee_briefing"]
	var first: ConversationNodeDef = briefing.node(briefing.start)
	assert_str(ConversationText.line(state, first)).starts_with("Liaison: ")
	assert_str(ConversationText.speaker_title(state, &"speaker_kindred_elder")).is_equal(
		"Speaker for the Kindred"
	)
	assert_str(ConversationText.speaker_name(state, &"speaker_gone")).is_equal("speaker_gone")


func test_unknown_mood_is_an_error() -> void:
	var node := ConversationNodeDef.new()
	node.id = &"a"
	node.text_key = &"K"
	node.mood = &"smug"
	node.next = &"z"
	var end := ConversationNodeDef.new()
	end.id = &"z"
	end.kind = ConversationNodeDef.Kind.END
	var conversation := ConversationDef.new()
	conversation.channels = [&"wormhole"]
	conversation.start = &"a"
	conversation.nodes = [node, end]
	assert_array(ConversationGraph.errors(conversation)).contains(
		["line 'a' has unknown mood 'smug'"]
	)
	node.mood = &"wary"
	assert_array(ConversationGraph.errors(conversation)).is_empty()


func test_speaker_and_portrait_checks() -> void:
	var portrait := PortraitDef.new()
	portrait.id = &"p"
	var speaker := SpeakerDef.new()
	speaker.id = &"s"
	speaker.name_key = &"N"
	speaker.portrait = &"p"
	var defs: Dictionary[StringName, DefBase] = {&"p": portrait, &"s": speaker}
	assert_array(speaker.get_content_errors(defs)).is_empty()
	speaker.portrait = &"s"
	assert_array(speaker.get_content_errors(defs)).contains(["portrait 's' is not a portrait"])
	portrait.kind = &"hologram"
	assert_array(portrait.get_content_errors(defs)).contains(["unknown portrait kind 'hologram'"])
	portrait.kind = &"placeholder"
	portrait.params = {"skin": 3, "build": 2.0, "hat": Color.RED}
	(
		assert_array(portrait.get_content_errors(defs))
		. contains_exactly_in_any_order(
			[
				"param 'skin' is not a colour",
				"param 'build' is not a number from 0 to 1",
				"unknown param 'hat'",
			]
		)
	)
	portrait.params = {"build": 0.2, "accent": Color.RED}
	assert_float(portrait.build()).is_equal(0.2)
	assert_object(portrait.colour("skin", Color.BLUE)).is_equal(Color.BLUE)


func test_the_registry_reports_unknown_speakers_and_portraits() -> void:
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	var speaker := SpeakerDef.new()
	speaker.id = &"speaker_lost"
	speaker.name_key = &"N"
	speaker.portrait = &"portrait_missing"
	ResourceSaver.save(speaker, TEMP_DIR.path_join("speaker_lost.tres"))
	var conversation: ConversationDef = (
		Registry.get_def(&"conv_kindred_first_hail").duplicate(true) as ConversationDef
	)
	conversation.faction = &"speaker_lost"
	conversation.nodes[0].speaker = &"speaker_nobody"
	ResourceSaver.save(conversation, TEMP_DIR.path_join("conv.tres"))
	var registry: ContentSource.RegistryScript = ContentSource.new_registry()
	var errors: Array[String] = registry.load_all(TEMP_DIR).value
	registry.free()
	var joined: String = "\n".join(errors)
	assert_str(joined).contains('references missing id "portrait_missing"')
	assert_str(joined).contains('references missing id "speaker_nobody"')
