class_name ConversationDef
extends DefBase
## Definition of a conversation with a faction: where and how it can run (channels, worlds,
## conditions, priority, once) and its Line, Choice and End nodes from a start node. Read only
## at runtime; running one is ConversationRunner's job (M4-08).
## Bible: docs/content/m4-core-systems.md section 3

## Valid channels.
const CHANNELS: Array[StringName] = [&"wormhole", &"incoming", &"phone"]

## Id of the FactionDef spoken with.
@export var faction: StringName = &""
## Channels it may run on: &"wormhole" (a hail), &"incoming", &"phone".
@export var channels: Array[StringName] = []
## Worlds it may run at; empty = any of the faction's worlds.
@export var worlds: Array[StringName] = []
## Conditions that must all hold to start it.
@export var conditions: Array[ConditionDef] = []
## Higher runs first when several are available.
@export var priority: int = 0
## True when it can run only once.
@export var once: bool = false
## Id of the first node.
@export var start: StringName = &""
## Every node.
@export var nodes: Array[ConversationNodeDef] = []


## The node with [param node_id], or null.
func node(node_id: StringName) -> ConversationNodeDef:
	for each: ConversationNodeDef in nodes:
		if each != null and each.id == node_id:
			return each
	return null


## The faction, the worlds and every line's speaker.
func get_references() -> Array[StringName]:
	var found: Array[StringName] = [faction]
	found.append_array(worlds)
	for speaker: StringName in speakers():
		found.append(speaker)
	return found


## Every speaker named by a line, once each, in node order.
func speakers() -> Array[StringName]:
	var found: Array[StringName] = []
	for each: ConversationNodeDef in nodes:
		if each != null and not each.speaker.is_empty() and not found.has(each.speaker):
			found.append(each.speaker)
	return found


## Every condition of the conversation, its choices included.
func all_conditions() -> Array[ConditionDef]:
	var found: Array[ConditionDef] = conditions.duplicate()
	for each: ConversationNodeDef in nodes:
		if each == null:
			continue
		for choice: ConversationChoiceDef in each.choices:
			if choice != null:
				found.append_array(choice.conditions)
	return found


## Every effect of the conversation's nodes and choices.
func all_effects() -> Array[EffectDef]:
	var found: Array[EffectDef] = []
	for each: ConversationNodeDef in nodes:
		if each == null:
			continue
		found.append_array(each.effects)
		for choice: ConversationChoiceDef in each.choices:
			if choice != null:
				found.append_array(choice.effects)
	return found


## Problems of the graph and of the channels against [param defs]: see
## ConversationGraph.errors().
func get_content_errors(defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = ConversationGraph.errors(self)
	for speaker: StringName in speakers():
		var def: DefBase = defs.get(speaker)
		if def != null and not def is SpeakerDef:
			errors.append("speaker '%s' is not a speaker" % speaker)
	var owner: DefBase = defs.get(faction)
	if owner != null and not owner is FactionDef:
		errors.append("faction '%s' is not a faction" % faction)
	elif owner != null:
		var kind: StringName = (owner as FactionDef).kind
		for channel: StringName in channels:
			if channel == &"phone" and kind != &"earth":
				errors.append("phone is only for earth factions")
			elif channel != &"phone" and kind != &"alien":
				errors.append("%s is only for alien factions" % channel)
	return errors
