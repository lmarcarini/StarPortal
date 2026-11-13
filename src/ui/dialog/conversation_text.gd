class_name ConversationText
extends RefCounted
## Words of the conversation panel in the current locale: a line ("Elder: Welcome."), a
## choice (with its reason when locked) and the header naming the faction.
## Bible: docs/content/m4-core-systems.md section 3


## "Speaker: text" for the Line [param node] (just the text without a speaker).
static func line(node: ConversationNodeDef) -> String:
	var text: String = _tr(node.text_key)
	if node.speaker_key.is_empty():
		return text
	return _tr(&"CONV_LINE").format({"speaker": _tr(node.speaker_key), "text": text})


## "n. answer", or "n. answer (reason)" when [param choice] (from ConversationRules.choices)
## is locked; [param number] is its place in the list, from 1.
static func choice(choice: Dictionary, number: int) -> String:
	var key: StringName = choice["text_key"]
	var text: String = "%d. %s" % [number, _tr(key)]
	var value: Variant = choice.get("reason")
	if not choice["enabled"] and value is ConditionDef:
		var reason: ConditionDef = value
		text += " (%s)" % StoryText.reason(reason)
	return text


## The header: the faction's name, from [param state]'s definitions.
static func header(state: GameState, conversation: ConversationDef) -> String:
	if conversation == null:
		return ""
	var faction: FactionDef = state.faction_defs.get(conversation.faction)
	return String(conversation.faction) if faction == null else _tr(faction.name_key)


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
