class_name ConversationText
extends RefCounted
## Words of the conversation panel in the current locale: a line ("Elder: Welcome."), a
## speaker's name and title (from the SpeakerDef), a choice (with its reason when locked) and
## the header naming the faction.
## Bible: docs/content/m4-core-systems.md section 3, docs/content/dialogue-screen.md sections 1
## and 3

## Text key of each channel's strip label.
const CHANNEL_KEYS: Dictionary[StringName, StringName] = {
	&"wormhole": &"DIALOG_CHANNEL_RING",
	&"incoming": &"DIALOG_CHANNEL_INCOMING",
	&"phone": &"DIALOG_CHANNEL_PHONE",
}
## Smallest contrast a speaker's name may have against its ground (WCAG AA).
const MIN_CONTRAST: float = 4.5


## "Speaker: text" for the Line [param node] (just the text without a speaker), with the
## speaker's name from [param state]'s SpeakerDefs.
static func line(state: GameState, node: ConversationNodeDef) -> String:
	var text: String = _tr(node.text_key)
	if node.speaker.is_empty():
		return text
	return _tr(&"CONV_LINE").format({"speaker": speaker_name(state, node.speaker), "text": text})


## The name of speaker [param speaker_id]; the id itself when it has no SpeakerDef.
static func speaker_name(state: GameState, speaker_id: StringName) -> String:
	var def: SpeakerDef = state.speaker_defs.get(speaker_id)
	return String(speaker_id) if def == null else _tr(def.name_key)


## The title of speaker [param speaker_id]; "" when none.
static func speaker_title(state: GameState, speaker_id: StringName) -> String:
	var def: SpeakerDef = state.speaker_defs.get(speaker_id)
	return "" if def == null or def.title_key.is_empty() else _tr(def.title_key)


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


## The dialogue screen's channel: "TRANSMISSION · RING · LINTEL", "INCOMING WORMHOLE ·
## LINTEL" or "SECURE LINE · EARTH".
static func channel(state: GameState, active: ActiveConversation) -> String:
	var world: String = (
		"" if active.world.is_empty() else AddressBookText.name_of_world(active.world, state)
	)
	var key: StringName = CHANNEL_KEYS.get(active.channel, &"DIALOG_CHANNEL_RING")
	return _tr(key).format({"world": world.to_upper()})


## "STANDING +10  Neutral", or "CONFIDENCE 62" for a faction that uses Confidence; "" when
## [param faction_id] is empty or unknown (the player's side).
static func standing(state: GameState, faction_id: StringName) -> String:
	var faction: FactionDef = state.faction_defs.get(faction_id)
	if faction == null:
		return ""
	var value: int = FactionRules.standing(state, faction_id)
	if faction.uses_confidence:
		return _tr(&"DIALOG_CONFIDENCE").format({"value": value})
	var attitude: String = _tr(FactionRules.attitude_key(FactionRules.attitude(state, faction_id)))
	return _tr(&"DIALOG_STANDING").format({"value": "%+d" % value, "attitude": attitude})


## The accent of [param faction_id] made readable on [param ground]: the faction's colour
## when it reaches 4.5:1, else lightened towards the body text until it does (the body text
## when nothing else works). The player's side and unknown factions use the dim text.
static func readable_accent(state: GameState, faction_id: StringName, ground: Color) -> Color:
	var faction: FactionDef = state.faction_defs.get(faction_id)
	var accent: Color = UiPalette.TEXT_DIM if faction == null else faction.accent
	for step: int in 11:
		var tried: Color = accent.lerp(UiPalette.TEXT, step / 10.0)
		if UiPalette.contrast(tried, ground) >= MIN_CONTRAST:
			return tried
	return UiPalette.TEXT


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
