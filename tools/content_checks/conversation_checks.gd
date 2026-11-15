class_name ContentCheckConversations
extends RefCounted
## Content checks of conversations that need more than the definition itself: the conditions
## and effects nested in nodes and choices (unknown ids, modifiers) and every text key having a
## text in every locale of the conversations table. Pure functions; one line per problem.
## Bible: docs/content/m4-core-systems.md section 3

## The translation table of conversation texts.
const TABLE: String = "conversations.csv"
const LOCALES: Array[String] = ["en", "pt_BR"]


## The problems of [param conversations] against [param known] (every definition by id) and
## [param table] (key -> texts per locale, as ContentCheckDocuments.read_table returns).
static func check(
	conversations: Array[ConversationDef],
	known: Dictionary[StringName, DefBase],
	table: Dictionary[String, PackedStringArray]
) -> Array[String]:
	var errors: Array[String] = []
	for conversation: ConversationDef in conversations:
		errors.append_array(
			ContentCheckStory.check_lists(
				conversation.id,
				conversation.all_conditions(),
				conversation.all_effects(),
				known,
				false
			)
		)
		for key: StringName in text_keys(conversation):
			errors.append_array(_key_errors(conversation.id, key, table))
	return errors


## Every line and answer key of [param conversation] (speaker names live on SpeakerDefs).
static func text_keys(conversation: ConversationDef) -> Array[StringName]:
	var keys: Array[StringName] = []
	for node: ConversationNodeDef in conversation.nodes:
		if node == null:
			continue
		if not node.text_key.is_empty() and not keys.has(node.text_key):
			keys.append(node.text_key)
		for choice: ConversationChoiceDef in node.choices:
			if choice != null and not choice.text_key.is_empty() and not keys.has(choice.text_key):
				keys.append(choice.text_key)
	return keys


## The problems of [param speaker]'s name and title keys against [param table].
static func check_speaker(
	speaker: SpeakerDef, table: Dictionary[String, PackedStringArray]
) -> Array[String]:
	var errors: Array[String] = []
	for key: StringName in [speaker.name_key, speaker.title_key]:
		if not key.is_empty():
			errors.append_array(_key_errors(speaker.id, key, table))
	return errors


static func _key_errors(
	owner: StringName, key: StringName, table: Dictionary[String, PackedStringArray]
) -> Array[String]:
	var errors: Array[String] = []
	var texts: PackedStringArray = table.get(String(key), PackedStringArray())
	for column: int in LOCALES.size():
		var text: String = texts[column] if column < texts.size() else ""
		if text.strip_edges().is_empty():
			errors.append(
				(
					"conversation %s: key '%s' has no %s text in %s"
					% [owner, key, LOCALES[column], TABLE]
				)
			)
	return errors
