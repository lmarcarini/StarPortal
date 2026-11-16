class_name OfferStep
extends RefCounted
## A conversation's offer step (M4.10-05): arriving offers the node's request (unless one is
## already open); its three answers are ACCEPT and DECLINE, which run the very commands the
## Command screen sends (AcceptRequestCommand, DeclineRequestCommand), and "I will think
## about it", which leaves the offer open for the wire and the Office. Called only by
## ConversationRules, from commands.
## Bible: docs/content/interface-rethink.md section 6; docs/content/m4-core-systems.md
## section 4

## Answer indices.
enum Answer { ACCEPT, DECLINE, THINK }

## Text keys of the answers, by index.
const TEXT_KEYS: Array[StringName] = ConversationNodeDef.OFFER_ANSWER_KEYS


## Offers [param node]'s request on arrival (nothing when one is already open).
static func arrive(state: GameState, node: ConversationNodeDef) -> void:
	if RequestRules.open_instance(state, node.offer_request) == null:
		StoryRulesItems.offer_request(state, node.offer_request)


## The open instance's uid of [param node]'s request, or -1.
static func uid_of(state: GameState, node: ConversationNodeDef) -> int:
	var record: RequestRecord = RequestRules.open_instance(state, node.offer_request)
	return record.uid if record != null else -1


## The three answers: {index, text_key, enabled, reason}. ACCEPT and DECLINE are disabled
## (with the command's refusal) when the request is no longer offered.
static func choices(state: GameState, node: ConversationNodeDef) -> Array[Dictionary]:
	var error: StringName = RequestRules.offer_error(state, uid_of(state, node))
	var found: Array[Dictionary] = []
	for index: int in TEXT_KEYS.size():
		var blocked: bool = index != Answer.THINK and not error.is_empty()
		(
			found
			. append(
				{
					"index": index,
					"text_key": TEXT_KEYS[index],
					"enabled": not blocked,
					"reason": error if blocked else null,
				}
			)
		)
	return found


## Why answer [param index] is refused, or &"".
static func choose_error(state: GameState, node: ConversationNodeDef, index: int) -> StringName:
	if index < 0 or index >= TEXT_KEYS.size():
		return &"no_such_choice"
	return _command(state, node, index).validate(state).error_code if index != Answer.THINK else &""


## Applies answer [param index] (checked first): the request command, or nothing to think.
static func choose(state: GameState, node: ConversationNodeDef, index: int) -> void:
	if index == Answer.THINK:
		return
	_command(state, node, index).apply(state)


static func _command(state: GameState, node: ConversationNodeDef, index: int) -> Command:
	var uid: int = uid_of(state, node)
	if index == Answer.ACCEPT:
		return AcceptRequestCommand.new(uid)
	return DeclineRequestCommand.new(uid)
