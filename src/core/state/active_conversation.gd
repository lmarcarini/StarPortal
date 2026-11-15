class_name ActiveConversation
extends RefCounted
## The conversation running now: its id, channel, world, phase, the node shown, the tick that
## node appeared, the tick it started, the path so far and whether it was cut off.
## Saved shape: {"conversation", "channel", "world", "phase", "node", "node_tick",
## "started_tick", "path", "cut_off"}.
## Bible: docs/content/m4-core-systems.md sections 3 and 9, docs/content/dialogue-screen.md
## section 7

## Where the conversation stands: OPENING before the first node, LINE on a line, CHOICE
## waiting for an answer, ENDED after its end (or a cut-off) until the player closes it.
enum Phase { OPENING, LINE, CHOICE, ENDED }

## Saved keys, in to_dict() order.
const KEYS: Array[String] = [
	"conversation",
	"channel",
	"world",
	"phase",
	"node",
	"node_tick",
	"started_tick",
	"path",
	"cut_off"
]
## Saved names of the phases, indexed by Phase value.
const PHASE_NAMES: Array[String] = ["opening", "line", "choice", "ended"]

## Conversation id.
var conversation: StringName = &""
## &"wormhole", &"incoming" or &"phone".
var channel: StringName = &"wormhole"
## World id, or &"" (phone).
var world: StringName = &""
## Where the conversation stands.
var phase: Phase = Phase.OPENING
## The node shown now; &"" while OPENING.
var node: StringName = &""
## Tick the node appeared.
var node_tick: int = 0
## Tick it started.
var started_tick: int = 0
## Steps so far, as in TranscriptRecord.path.
var path: Array[Array] = []
## ENDED: true when the link was cut (signal lost) rather than ended by the story.
var cut_off: bool = false


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"conversation": String(conversation),
		"channel": String(channel),
		"world": String(world),
		"phase": PHASE_NAMES[phase],
		"node": String(node),
		"node_tick": node_tick,
		"started_tick": started_tick,
		"path": TranscriptRecord.write_path(path),
		"cut_off": cut_off,
	}


## Builds one from valid saved [param data].
static func from_dict(data: Dictionary) -> ActiveConversation:
	var active := ActiveConversation.new()
	active.conversation = SaveFields.read_id(data.get("conversation"))
	active.channel = SaveFields.read_id(data.get("channel"))
	active.world = SaveFields.read_id(data.get("world"))
	active.phase = PHASE_NAMES.find(str(data.get("phase"))) as Phase
	active.node = StringName(str(data.get("node")))
	active.node_tick = SaveFields.read_int(data.get("node_tick"))
	active.started_tick = SaveFields.read_int(data.get("started_tick"))
	active.path = TranscriptRecord.read_path(data.get("path"))
	active.cut_off = data.get("cut_off") == true
	return active


## Errors of saved [param data]: keys, the shared fields, a phase, a node id (empty only
## while opening), two ticks and a cut_off flag.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	errors.append_array(TranscriptRecord.common_errors(data))
	var phase_name: Variant = data["phase"]
	if not phase_name is String or not PHASE_NAMES.has(phase_name):
		errors.append("'phase' is not one of %s" % [PHASE_NAMES])
	elif phase_name == "opening":
		if not data["node"] is String:
			errors.append("'node' is not a string")
	elif not SaveFields.is_id(data["node"]):
		errors.append("'node' is not a non-empty string")
	if not data["cut_off"] is bool:
		errors.append("'cut_off' is not a bool")
	for key: String in ["node_tick", "started_tick"]:
		if not SaveFields.is_tick(data[key]):
			errors.append("'%s' is not a tick" % key)
	return errors
