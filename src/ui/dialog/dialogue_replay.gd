class_name DialogueReplay
extends RefCounted
## Rebuilds the dialogue screen's transcript from a conversation already open (after a load):
## every line reached and every answer given, in order, shown whole, with the last speaker on
## the name plate.
## Bible: docs/content/dialogue-screen.md section 2 (saving keeps the current line)


## Shows the path so far of [param state]'s open conversation on [param screen].
static func replay(screen: DialogueScreen, state: GameState) -> void:
	var def: ConversationDef = ConversationRules.active_def(state)
	if def == null:
		return
	for step: Array in state.conversations.active.path:
		var node_id: StringName = step[0]
		var choice_index: int = step[1]
		var node: ConversationNodeDef = def.node(node_id)
		if node == null:
			continue
		if node.kind == ConversationNodeDef.Kind.LINE:
			screen.show_line(node, false)
		elif node.kind == ConversationNodeDef.Kind.CHOICE and choice_index >= 0:
			screen.show_answer(TranslationServer.translate(node.choices[choice_index].text_key))
