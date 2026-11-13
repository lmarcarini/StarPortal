class_name ConversationRules
extends RefCounted
## Rules of the one running conversation: start one, list the choices at a Choice node, move
## to a node (applying its effects), pick a choice, end it (finished or cut off) and choose the
## best conversation to start for a faction, channel and world. Called only from commands and
## ConversationSystem. A conversation drops the clock to 1× while it runs (the player may
## still pause).
## Bible: docs/content/m4-core-systems.md section 3

## Channels that run over the open wormhole (cut off when it closes).
const WORMHOLE_CHANNELS: Array[StringName] = [&"wormhole", &"incoming"]


## Starts [param conversation_id] on [param channel] at [param world_id]: refuses (false) when
## one is running or the id is unknown. Drops the clock to 1×, posts conversation_started and
## arrives at the start node.
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
	state.conversations.active = active
	drop_to_normal_speed(state.clock)
	state.events.post(&"conversation_started", [conversation_id, channel])
	arrive(state, def.start)
	return true


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
## posts the choices of a Choice, and finishes at an End (applying its effects).
static func arrive(state: GameState, node_id: StringName) -> void:
	var active: ActiveConversation = state.conversations.active
	var def: ConversationDef = active_def(state)
	var node: ConversationNodeDef = def.node(node_id)
	active.node = node_id
	active.node_tick = state.clock.tick
	active.path.append([node_id, -1])
	match node.kind:
		ConversationNodeDef.Kind.LINE:
			StoryRules.apply_all(state, node.effects, def.id)
			state.events.post(&"conversation_line", [node_id])
		ConversationNodeDef.Kind.CHOICE:
			state.events.post(&"conversation_choices", [])
		ConversationNodeDef.Kind.END:
			StoryRules.apply_all(state, node.effects, def.id)
			finish(state, false)


## Ends the running conversation: records the transcript (listed unread in the Archive), counts
## the run, marks a once-only
## conversation used and posts conversation_ended. A cut-off one applies no End effects.
## Returns the transcript uid, or −1 when none was running.
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
	ids.sort()
	for id: StringName in ids:
		var def: ConversationDef = state.conversation_defs[id]
		if not _is_available(def, faction, channel, world_id, state):
			continue
		if best == null or def.priority > best.priority:
			best = def
	return &"" if best == null else best.id


## Sets [param clock] to 1× when it runs faster.
static func drop_to_normal_speed(clock: ClockState) -> void:
	if clock.speed_index > ClockState.NORMAL_SPEED_INDEX:
		clock.speed_index = ClockState.NORMAL_SPEED_INDEX


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
