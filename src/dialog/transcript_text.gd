class_name TranscriptText
extends RefCounted
## Transcripts in the Archive: a transcript is listed among the documents under the id
## "transcript_<uid>" (its read mark lives in the Archive like a document's), and is rendered
## from its saved path with the current definitions and texts, so later text changes show in
## old transcripts. Saves keep only node ids and answer indices, so a transcript saved before
## M4.8-03 (when lines named a speaker key) reads with today's SpeakerDef names.
## Bible: docs/content/m4-core-systems.md section 3 (Transcripts)

## Prefix of a transcript's Archive id.
const PREFIX: String = "transcript_"
## Text key of each channel.
const CHANNEL_KEYS: Dictionary[StringName, StringName] = {
	&"wormhole": &"TRANSCRIPT_CHANNEL_WORMHOLE",
	&"incoming": &"TRANSCRIPT_CHANNEL_INCOMING",
	&"phone": &"TRANSCRIPT_CHANNEL_PHONE",
}


## The Archive id of transcript [param uid].
static func archive_id(uid: int) -> StringName:
	return StringName(PREFIX + str(uid))


## True when [param document_id] names a transcript.
static func is_transcript(document_id: StringName) -> bool:
	return String(document_id).begins_with(PREFIX)


## The transcript record behind [param document_id], or null.
static func record_of(state: GameState, document_id: StringName) -> TranscriptRecord:
	if not is_transcript(document_id):
		return null
	var uid_text: String = String(document_id).substr(PREFIX.length())
	if not uid_text.is_valid_int():
		return null
	var uid: int = uid_text.to_int()
	for record: TranscriptRecord in state.conversations.transcripts:
		if record.uid == uid:
			return record
	return null


## "Kindred, by incoming wormhole": the faction and the channel.
static func title(state: GameState, record: TranscriptRecord) -> String:
	if record == null:
		return _tr(&"ARCHIVE_UNTITLED")
	var def: ConversationDef = state.conversation_defs.get(record.conversation)
	var faction_name: String = ConversationText.header(state, def)
	if faction_name.is_empty():
		faction_name = String(record.conversation)
	var channel_key: StringName = CHANNEL_KEYS.get(record.channel, &"TRANSCRIPT_CHANNEL_WORMHOLE")
	var channel: String = _tr(channel_key)
	return _tr(&"TRANSCRIPT_TITLE").format({"name": faction_name, "channel": channel})


## The lines of [param record] in order: each Line reached ("Speaker: text") and each answer
## chosen ("You: answer"), then "(signal lost)" when it was cut off.
static func lines(state: GameState, record: TranscriptRecord) -> Array[String]:
	var found: Array[String] = []
	var def: ConversationDef = state.conversation_defs.get(record.conversation)
	if def != null:
		for step: Array in record.path:
			var node_id: StringName = step[0]
			var choice_index: int = step[1]
			var node: ConversationNodeDef = def.node(node_id)
			if node == null:
				continue
			if node.kind == ConversationNodeDef.Kind.LINE:
				found.append(ConversationText.line(state, node))
			elif node.kind == ConversationNodeDef.Kind.CHOICE:
				if choice_index >= 0 and choice_index < node.choices.size():
					var answer: String = _tr(node.choices[choice_index].text_key)
					found.append(_tr(&"TRANSCRIPT_YOU").format({"text": answer}))
	if record.cut_off:
		found.append(_tr(&"CONV_SIGNAL_LOST"))
	return found


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
