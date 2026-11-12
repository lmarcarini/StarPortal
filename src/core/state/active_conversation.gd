class_name ActiveConversation
extends RefCounted
## The conversation running now: its id, channel, world, the node shown, the tick that node
## appeared and the path so far.
## Saved shape: {"conversation", "channel", "world", "node", "node_tick", "path"}.
## Bible: docs/content/m4-core-systems.md sections 3 and 9

## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["conversation", "channel", "world", "node", "node_tick", "path"]

## Conversation id.
var conversation: StringName = &""
## &"wormhole", &"incoming" or &"phone".
var channel: StringName = &"wormhole"
## World id, or &"" (phone).
var world: StringName = &""
## The node shown now.
var node: StringName = &""
## Tick the node appeared.
var node_tick: int = 0
## Steps so far, as in TranscriptRecord.path.
var path: Array[Array] = []


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"conversation": String(conversation),
		"channel": String(channel),
		"world": String(world),
		"node": String(node),
		"node_tick": node_tick,
		"path": TranscriptRecord.write_path(path),
	}


## Builds one from valid saved [param data].
static func from_dict(data: Dictionary) -> ActiveConversation:
	var active := ActiveConversation.new()
	active.conversation = SaveFields.read_id(data.get("conversation"))
	active.channel = SaveFields.read_id(data.get("channel"))
	active.world = SaveFields.read_id(data.get("world"))
	active.node = SaveFields.read_id(data.get("node"))
	active.node_tick = SaveFields.read_int(data.get("node_tick"))
	active.path = TranscriptRecord.read_path(data.get("path"))
	return active


## Errors of saved [param data]: keys, the shared fields, a node id and a tick.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	errors.append_array(TranscriptRecord.common_errors(data))
	if not SaveFields.is_id(data["node"]):
		errors.append("'node' is not a non-empty string")
	if not SaveFields.is_tick(data["node_tick"]):
		errors.append("'node_tick' is not a tick")
	return errors
