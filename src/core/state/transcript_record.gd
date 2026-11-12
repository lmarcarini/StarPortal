class_name TranscriptRecord
extends RefCounted
## A saved conversation: its id, channel, world, the tick it started, the path through it
## (nodes reached and choices made) and whether it was cut off. The Archive renders the text
## from the path, so later content changes apply to old transcripts.
## Saved shape: {"uid", "conversation", "channel", "world", "tick", "path", "cut_off"};
## path is [[node id, choice index or −1], ...].
## Bible: docs/content/m4-core-systems.md sections 3 and 9

## Channels a conversation runs on.
const CHANNELS: Array[String] = ["wormhole", "incoming", "phone"]
## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["uid", "conversation", "channel", "world", "tick", "path", "cut_off"]

## Unique id among transcripts.
var uid: int = 0
## Conversation id.
var conversation: StringName = &""
## &"wormhole", &"incoming" or &"phone".
var channel: StringName = &"wormhole"
## World id it ran at, or &"" (phone).
var world: StringName = &""
## Tick it started.
var tick: int = 0
## Each step: [node id (StringName), choice index (int, −1 when no choice)].
var path: Array[Array] = []
## True when the signal was lost before the End node.
var cut_off: bool = false


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"conversation": String(conversation),
		"channel": String(channel),
		"world": String(world),
		"tick": tick,
		"path": write_path(path),
		"cut_off": cut_off,
	}


## Builds one from valid saved [param data].
static func from_dict(data: Dictionary) -> TranscriptRecord:
	var record := TranscriptRecord.new()
	record.uid = SaveFields.read_int(data.get("uid"))
	record.conversation = SaveFields.read_id(data.get("conversation"))
	record.channel = SaveFields.read_id(data.get("channel"))
	record.world = SaveFields.read_id(data.get("world"))
	record.tick = SaveFields.read_int(data.get("tick"))
	record.path = read_path(data.get("path"))
	record.cut_off = data.get("cut_off") == true
	return record


## Errors of saved [param data]: keys, uid, conversation id, channel, world string, tick,
## path and cut_off a bool.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	if not SaveFields.is_tick(data["uid"]):
		errors.append("'uid' is not a whole number of at least 0")
	errors.append_array(common_errors(data))
	if not SaveFields.is_tick(data["tick"]):
		errors.append("'tick' is not a tick")
	if not data["cut_off"] is bool:
		errors.append("'cut_off' is not a bool")
	return errors


## Errors of the fields shared with the active conversation: "conversation", "channel",
## "world" and "path".
static func common_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not SaveFields.is_id(data["conversation"]):
		errors.append("'conversation' is not a non-empty string")
	if not (data["channel"] is String and CHANNELS.has(str(data["channel"]))):
		errors.append("'channel' is not wormhole, incoming or phone")
	if not data["world"] is String:
		errors.append("'world' is not a string")
	errors.append_array(path_errors(data["path"]))
	return errors


## Errors of a saved path: an array of [non-empty string, whole number of at least −1].
static func path_errors(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not value is Array:
		errors.append("'path' is not an array")
		return errors
	var steps: Array = value
	for index: int in steps.size():
		var step: Variant = steps[index]
		var pair: Array = step if step is Array else []
		var ok: bool = pair.size() == 2
		if ok:
			ok = SaveFields.is_id(pair[0]) and SaveFields.is_int(pair[1])
			ok = ok and SaveFields.read_int(pair[1]) >= -1
		if not ok:
			errors.append("path %d is not [node, choice index]" % index)
	return errors


## Returns a path as JSON-safe data.
static func write_path(steps: Array[Array]) -> Array:
	var data: Array = []
	for step: Array in steps:
		var node: StringName = step[0]
		data.append([String(node), step[1]])
	return data


## Reads a valid saved path.
static func read_path(value: Variant) -> Array[Array]:
	var steps: Array[Array] = []
	if not value is Array:
		return steps
	var entries: Array = value
	for entry: Variant in entries:
		var pair: Array = entry if entry is Array else []
		if pair.size() == 2:
			steps.append([SaveFields.read_id(pair[0]), SaveFields.read_int(pair[1], -1)])
	return steps
