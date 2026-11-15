class_name ConversationRules
extends RefCounted
## Rules of the one running conversation: start one, move it on (advance), list the choices at
## a Choice node, move to a node (applying its effects), pick a choice, end the link (by the
## story or cut off), close it and choose the best conversation to start for a faction, channel
## and world. Called only from commands and ConversationSystem. The clock is held (hold
## [constant HOLD]) from the start until the player closes the ended conversation: no tick
## runs while the player talks (docs/content/dialogue-screen.md section 2).
## Bible: docs/content/m4-core-systems.md section 3, docs/content/dialogue-screen.md
## sections 2 and 7

## Channels that run over the open wormhole (cut off when it closes).
const WORMHOLE_CHANNELS: Array[StringName] = [&"wormhole", &"incoming"]
## The clock hold reason while a conversation is open.
const HOLD: StringName = &"conversation"


## Starts [param conversation_id] on [param channel] at [param world_id]: refuses (false) when
## one is running or the id is unknown. Holds the clock, posts conversation_started and waits
## in OPENING for the player to advance to the start node.
static func start(
	state: GameState, conversation_id: StringName, channel: StringName, world_id: StringName
) -> bool:
	var def: ConversationDef = state.conversation_defs.get(conversation_id)
	if def == null or state.conversations.active != null or def.node(def.start) == null:
		return false
	var active := ActiveConversation.new()
	active.conversation = conversation_id
	active.channel = channel
	active.world = world_id
	active.started_tick = state.clock.tick
	active.phase = ActiveConversation.Phase.OPENING
	state.conversations.active = active
	TimeControl.add_hold(state.clock, HOLD)
	state.events.post(&"conversation_started", [conversation_id, channel])
	return true


## Why advancing is refused, or &"" when allowed: &"no_conversation", or &"needs_choice" at a
## choice.
static func advance_error(state: GameState) -> StringName:
	var active: ActiveConversation = state.conversations.active
	if active == null:
		return &"no_conversation"
	if active.phase == ActiveConversation.Phase.CHOICE:
		return &"needs_choice"
	return &""


## Moves the conversation on (checked with advance_error first): OPENING to the start node, a
## Line to its next node, ENDED closes it.
static func advance(state: GameState) -> void:
	var active: ActiveConversation = state.conversations.active
	match active.phase:
		ActiveConversation.Phase.OPENING:
			arrive(state, active_def(state).start)
		ActiveConversation.Phase.LINE:
			var node: ConversationNodeDef = current_node(state)
			if node == null:
				end_link(state, true)
				return
			arrive(state, node.next)
		ActiveConversation.Phase.ENDED:
			finish(state, active.cut_off)


## Ends the link without closing the screen: the phase becomes ENDED ([param cut_off] true for
## signal lost) and conversation_over is posted. Nothing when none runs or it already ended.
static func end_link(state: GameState, cut_off: bool) -> void:
	var active: ActiveConversation = state.conversations.active
	if active == null or active.phase == ActiveConversation.Phase.ENDED:
		return
	active.phase = ActiveConversation.Phase.ENDED
	active.cut_off = cut_off
	state.events.post(&"conversation_over", [cut_off])


## Settles a conversation loaded from a save migrated from v21 (which saved every phase as
## LINE): a running one standing at a Choice node is put at CHOICE.
static func settle_loaded(state: GameState) -> void:
	var active: ActiveConversation = state.conversations.active
	if active == null or active.phase != ActiveConversation.Phase.LINE:
		return
	var node: ConversationNodeDef = current_node(state)
	if node != null and node.kind == ConversationNodeDef.Kind.CHOICE:
		active.phase = ActiveConversation.Phase.CHOICE


## The running conversation's definition, or null.
static func active_def(state: GameState) -> ConversationDef:
	if state.conversations.active == null:
		return null
	return state.conversation_defs.get(state.conversations.active.conversation)


## The node shown now, or null.
static func current_node(state: GameState) -> ConversationNodeDef:
	var def: ConversationDef = active_def(state)
	return null if def == null else def.node(state.conversations.active.node)


## The answers at the current Choice node: {index, text_key, enabled, reason}. A choice whose
## conditions fail is left out unless show_locked (then enabled false with the first reason).
## Empty when not at a choice.
static func choices(state: GameState) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var node: ConversationNodeDef = current_node(state)
	if node == null or node.kind != ConversationNodeDef.Kind.CHOICE:
		return found
	for index: int in node.choices.size():
		var choice: ConversationChoiceDef = node.choices[index]
		var failing: Array[ConditionDef] = StoryRules.failing(state, choice.conditions)
		if not failing.is_empty() and not choice.show_locked:
			continue
		(
			found
			. append(
				{
					"index": index,
					"text_key": choice.text_key,
					"enabled": failing.is_empty(),
					"reason": failing[0] if not failing.is_empty() else null,
				}
			)
		)
	return found


## Why choosing [param index] is refused, or &"" when it is allowed.
static func choose_error(state: GameState, index: int) -> StringName:
	var node: ConversationNodeDef = current_node(state)
	if node == null:
		return &"no_conversation"
	if node.kind != ConversationNodeDef.Kind.CHOICE:
		return &"not_at_choice"
	if index < 0 or index >= node.choices.size():
		return &"no_such_choice"
	if not StoryRules.check_all(state, node.choices[index].conditions):
		return &"choice_locked"
	return &""


## Picks answer [param index] (checked with choose_error first): records it in the path,
## applies its effects and moves to its next node.
static func choose(state: GameState, index: int) -> void:
	var def: ConversationDef = active_def(state)
	var choice: ConversationChoiceDef = current_node(state).choices[index]
	var path: Array[Array] = state.conversations.active.path
	path[path.size() - 1][1] = index
	StoryRules.apply_all(state, choice.effects, def.id)
	arrive(state, choice.next)


## Moves to [param node_id]: adds it to the path, applies a Line's effects and posts its line,
## posts the choices of a Choice, and ends the link at an End (applying its effects; an End
## marked signal_lost ends it as cut off).
static func arrive(state: GameState, node_id: StringName) -> void:
	var active: ActiveConversation = state.conversations.active
	var def: ConversationDef = active_def(state)
	var node: ConversationNodeDef = def.node(node_id)
	active.node = node_id
	active.node_tick = state.clock.tick
	active.path.append([node_id, -1])
	match node.kind:
		ConversationNodeDef.Kind.LINE:
			active.phase = ActiveConversation.Phase.LINE
			StoryRules.apply_all(state, node.effects, def.id)
			state.events.post(&"conversation_line", [node_id])
		ConversationNodeDef.Kind.CHOICE:
			active.phase = ActiveConversation.Phase.CHOICE
			state.events.post(&"conversation_choices", [])
		ConversationNodeDef.Kind.END:
			StoryRules.apply_all(state, node.effects, def.id)
			end_link(state, node.signal_lost)


## Closes the running conversation: records the transcript (listed unread in the Archive),
## counts the run, marks a once-only conversation used, releases the clock hold and posts
## conversation_ended. A cut-off one applies no End effects. Returns the transcript uid, or −1
## when none was running.
static func finish(state: GameState, cut_off: bool) -> int:
	var active: ActiveConversation = state.conversations.active
	if active == null:
		return -1
	var record := TranscriptRecord.new()
	record.uid = state.conversations.next_uid
	state.conversations.next_uid += 1
	record.conversation = active.conversation
	record.channel = active.channel
	record.world = active.world
	record.tick = active.started_tick
	record.path = active.path
	record.cut_off = cut_off
	state.conversations.transcripts.append(record)
	state.archive.add(TranscriptText.archive_id(record.uid), state.clock.tick)
	var conversation_id: StringName = active.conversation
	state.conversations.count[conversation_id] = (
		state.conversations.count.get(conversation_id, 0) + 1
	)
	var def: ConversationDef = state.conversation_defs.get(conversation_id)
	if def != null and def.once and not state.factions.used.has(conversation_id):
		state.factions.used.append(conversation_id)
	state.conversations.active = null
	TimeControl.release_hold(state.clock, HOLD)
	state.events.post(&"conversation_ended", [record.uid, cut_off])
	return record.uid


## The best conversation of [param faction] for [param channel] at [param world_id]: highest
## priority (then id order), its channel listed, its worlds empty or holding the world, its
## conditions passing and not used up. &"" when none.
static func pick(
	faction: StringName, channel: StringName, world_id: StringName, state: GameState
) -> StringName:
	var best: ConversationDef = null
	var ids: Array = state.conversation_defs.keys()
	IdOrder.sort(ids)
	for id: StringName in ids:
		var def: ConversationDef = state.conversation_defs[id]
		if not _is_available(def, faction, channel, world_id, state):
			continue
		if best == null or def.priority > best.priority:
			best = def
	return &"" if best == null else best.id


static func _is_available(
	def: ConversationDef,
	faction: StringName,
	channel: StringName,
	world_id: StringName,
	state: GameState
) -> bool:
	if def.faction != faction or not def.channels.has(channel):
		return false
	if not def.worlds.is_empty() and not def.worlds.has(world_id):
		return false
	if def.once and state.conversations.count.get(def.id, 0) > 0:
		return false
	return StoryRules.check_all(state, def.conditions)
