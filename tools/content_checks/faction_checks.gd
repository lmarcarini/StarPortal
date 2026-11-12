class_name ContentCheckFactions
extends RefCounted
## Content checks across the faction definitions: exactly one faction (the Committee) uses
## Confidence as its standing, and every contact names a conversation definition. Per-definition
## rules (kinds, ranges, requests, artefacts) live in each definition's get_content_errors().
## Pure functions that return one line per problem.
## Bible: docs/content/m4-core-systems.md sections 2 to 5

## Class name of conversation definitions (added by card M4-08).
const CONVERSATION_CLASS: StringName = &"ConversationDef"


## Returns the problems of [param factions] against [param known] (every loaded definition by
## id). With no factions loaded there is nothing to check.
static func check(
	factions: Array[FactionDef], known: Dictionary[StringName, DefBase]
) -> Array[String]:
	var errors: Array[String] = []
	if factions.is_empty():
		return errors
	var confidence_count: int = 0
	for faction: FactionDef in factions:
		if faction.uses_confidence:
			confidence_count += 1
	if confidence_count != 1:
		errors.append(
			"expected exactly one faction with uses_confidence, found %d" % confidence_count
		)
	if not _conversations_exist():
		return errors
	for faction: FactionDef in factions:
		for contact: StringName in faction.contacts:
			var def: DefBase = known.get(contact, null)
			if not _is_conversation(def):
				errors.append(
					"faction %s: contact '%s' is not a conversation" % [faction.id, contact]
				)
	return errors


## True when [param def] is a ConversationDef.
static func _is_conversation(def: DefBase) -> bool:
	if def == null:
		return false
	var script: Script = def.get_script()
	return script != null and script.get_global_name() == CONVERSATION_CLASS


## True once a ConversationDef class exists in the project.
static func _conversations_exist() -> bool:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry["class"] == CONVERSATION_CLASS:
			return true
	return false
