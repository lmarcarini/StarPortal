class_name ConversationDriver
extends RefCounted
## Test helper (M4.8-02): plays the running conversation through the rules, as the player
## would by Continue and answers, without a Simulation.
## Bible: docs/content/dialogue-screen.md section 2


## Moves on from the opening and every line, picks [param answers] in order at choices
## (stops at a choice when none are left), and closes the conversation once it has ended
## when [param close] is true.
static func play(state: GameState, answers: Array = [], close: bool = true) -> void:
	var left: Array = answers.duplicate()
	while state.conversations.active != null:
		var active: ActiveConversation = state.conversations.active
		if active.phase == ActiveConversation.Phase.CHOICE:
			if left.is_empty():
				return
			var answer: int = left.pop_front()
			ConversationRules.choose(state, answer)
		elif active.phase == ActiveConversation.Phase.ENDED and not close:
			return
		else:
			ConversationRules.advance(state)
