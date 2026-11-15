class_name ConversationSystem
extends SimSystem
## Watches the active conversation each tick: cuts a wormhole or incoming conversation off when
## the Ring is no longer locked, or one whose node is gone. Ticks do not run while a
## conversation holds the clock, so this matters only to ticks run by hand (tools, tests).
## Lines move on by AdvanceConversationCommand and choices by ChooseOptionCommand.
## Bible: docs/content/m4-core-systems.md section 3, docs/content/dialogue-screen.md section 2


## Returns &"conversations".
func get_id() -> StringName:
	return &"conversations"


## One tick of the running conversation, if any.
func tick(state: GameState) -> void:
	var active: ActiveConversation = state.conversations.active
	if active == null or active.phase == ActiveConversation.Phase.ENDED:
		return
	var on_wormhole: bool = ConversationRules.WORMHOLE_CHANNELS.has(active.channel)
	if on_wormhole and state.gate.mode != GateState.RingMode.LOCKED:
		ConversationRules.end_link(state, true)
		return
	var opening: bool = active.phase == ActiveConversation.Phase.OPENING
	if not opening and ConversationRules.current_node(state) == null:
		ConversationRules.end_link(state, true)
