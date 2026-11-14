class_name ConversationSystem
extends SimSystem
## Runs the active conversation each tick (the Simulation syncs its slow reason): cuts a
## wormhole or incoming conversation off when the Ring is no longer locked, and moves on from
## a Line once its minutes have passed. Choices come by ChooseOptionCommand.
## Bible: docs/content/m4-core-systems.md section 3


## Returns &"conversations".
func get_id() -> StringName:
	return &"conversations"


## One tick of the running conversation, if any.
func tick(state: GameState) -> void:
	var active: ActiveConversation = state.conversations.active
	if active == null:
		return
	var on_wormhole: bool = ConversationRules.WORMHOLE_CHANNELS.has(active.channel)
	if on_wormhole and state.gate.mode != GateState.RingMode.LOCKED:
		ConversationRules.finish(state, true)
		return
	var node: ConversationNodeDef = ConversationRules.current_node(state)
	if node == null:
		ConversationRules.finish(state, true)
		return
	if node.kind == ConversationNodeDef.Kind.LINE:
		if state.clock.tick - active.node_tick >= node.minutes:
			ConversationRules.arrive(state, node.next)
