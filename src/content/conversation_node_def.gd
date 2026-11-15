class_name ConversationNodeDef
extends Resource
## One node of a conversation: a Line (a speaker says something; the player moves on to
## next), a Choice (the player picks an answer) or an End (applies its effects and ends the
## link; the player then closes the screen).
## Read only at runtime.
## Bible: docs/content/m4-core-systems.md section 3, docs/content/dialogue-screen.md section 7

## What the node is.
enum Kind { LINE, CHOICE, END }

## Id, unique within the conversation.
@export var id: StringName = &""
## What the node is.
@export var kind: Kind = Kind.LINE
## Line: translation key of the speaker's name.
@export var speaker_key: StringName = &""
## Line: translation key of what is said.
@export var text_key: StringName = &""
## Line and End: effects applied when the node is reached.
@export var effects: Array[EffectDef] = []
## End: the story cuts the link here (shown as SIGNAL LOST).
@export var signal_lost: bool = false
## Line: id of the next node.
@export var next: StringName = &""
## Choice: the answers, in order.
@export var choices: Array[ConversationChoiceDef] = []


## The ids this node can lead to: next for a Line, every choice's next for a Choice, none for
## an End.
func next_ids() -> Array[StringName]:
	var found: Array[StringName] = []
	match kind:
		Kind.LINE:
			found.append(next)
		Kind.CHOICE:
			for choice: ConversationChoiceDef in choices:
				if choice != null:
					found.append(choice.next)
	return found
