class_name ConversationNodeDef
extends Resource
## One node of a conversation: a Line (a speaker says something; the player moves on to
## next), a Choice (the player picks an answer) or an End (applies its effects and ends the
## link; the player then closes the screen).
## Read only at runtime.
## Bible: docs/content/m4-core-systems.md section 3, docs/content/dialogue-screen.md section 7

## What the node is.
enum Kind { LINE, CHOICE, END }

## Moods a line may carry; empty means neutral.
const MOODS: Array[StringName] = [&"neutral", &"pleased", &"wary", &"angry"]

## An offer step's answers: accept, decline, think about it.
const OFFER_ANSWER_KEYS: Array[StringName] = [
	&"CONV_OFFER_ACCEPT", &"CONV_OFFER_DECLINE", &"CONV_OFFER_THINK"
]

## Id, unique within the conversation.
@export var id: StringName = &""
## What the node is.
@export var kind: Kind = Kind.LINE
## Line: id of the SpeakerDef who says it (&"" for narration with no speaker).
@export var speaker: StringName = &""
## Line: the speaker's mood, one of [constant MOODS]; &"" means neutral.
@export var mood: StringName = &""
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
## An offer step (M4.10-05): a Choice with this request id offers it on arrival and answers
## ACCEPT, DECLINE or "I will think about it" (all go to [member next]); its own choices
## are ignored.
@export var offer_request: StringName = &""


## The answer text key of choice [param index] ("" when out of range).
func answer_key(index: int) -> StringName:
	if is_offer():
		return OFFER_ANSWER_KEYS[index] if index >= 0 and index < OFFER_ANSWER_KEYS.size() else &""
	return choices[index].text_key if index >= 0 and index < choices.size() else &""


## How many answers a Choice has (three for an offer step).
func answer_count() -> int:
	return OFFER_ANSWER_KEYS.size() if is_offer() else choices.size()


## True for an offer step.
func is_offer() -> bool:
	return kind == Kind.CHOICE and not offer_request.is_empty()


## The ids this node can lead to: next for a Line, every choice's next for a Choice, none for
## an End.
func next_ids() -> Array[StringName]:
	var found: Array[StringName] = []
	match kind:
		Kind.LINE:
			found.append(next)
		Kind.CHOICE:
			if is_offer():
				found.append(next)
				return found
			for choice: ConversationChoiceDef in choices:
				if choice != null:
					found.append(choice.next)
	return found
