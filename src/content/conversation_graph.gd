class_name ConversationGraph
extends RefCounted
## Pure checks of a conversation's node graph: channels, unique node ids, start and every next
## exist, every node reachable, no cycle (so every path reaches an End), Line minutes at least
## 1, and every Choice offering at least one answer without conditions.
## Bible: docs/content/m4-core-systems.md section 3


## The problems of [param conversation], one line each.
static func errors(conversation: ConversationDef) -> Array[String]:
	var found: Array[String] = []
	if conversation.channels.is_empty():
		found.append("needs at least one channel")
	for channel: StringName in conversation.channels:
		if not ConversationDef.CHANNELS.has(channel):
			found.append("unknown channel '%s'" % channel)
	var by_id: Dictionary[StringName, ConversationNodeDef] = {}
	for node: ConversationNodeDef in conversation.nodes:
		if node == null or node.id.is_empty():
			found.append("a node has no id")
		elif by_id.has(node.id):
			found.append("node '%s' is repeated" % node.id)
		else:
			by_id[node.id] = node
			found.append_array(_node_errors(node))
	if not by_id.has(conversation.start):
		found.append("start '%s' is not a node" % conversation.start)
		return found
	for node: ConversationNodeDef in by_id.values():
		for next_id: StringName in node.next_ids():
			if not by_id.has(next_id):
				found.append("node '%s' leads to unknown '%s'" % [node.id, next_id])
	if not found.is_empty():
		return found
	var state: Dictionary[StringName, int] = {}
	if _has_cycle(conversation.start, by_id, state):
		found.append("the nodes form a loop, so a path never ends")
	for node_id: StringName in by_id:
		if not state.has(node_id):
			found.append("node '%s' cannot be reached from start" % node_id)
	return found


static func _node_errors(node: ConversationNodeDef) -> Array[String]:
	var found: Array[String] = []
	match node.kind:
		ConversationNodeDef.Kind.LINE:
			if node.text_key.is_empty():
				found.append("line '%s' needs a text key" % node.id)
		ConversationNodeDef.Kind.CHOICE:
			var free: bool = false
			for choice: ConversationChoiceDef in node.choices:
				if choice != null and choice.conditions.is_empty():
					free = true
			if not free:
				found.append("choice '%s' needs an answer without conditions" % node.id)
	return found


## Depth-first walk: 1 while on the path, 2 when done. True when a node is met again on the path.
static func _has_cycle(
	node_id: StringName,
	by_id: Dictionary[StringName, ConversationNodeDef],
	state: Dictionary[StringName, int]
) -> bool:
	if state.get(node_id, 0) == 1:
		return true
	if state.get(node_id, 0) == 2:
		return false
	state[node_id] = 1
	for next_id: StringName in by_id[node_id].next_ids():
		if _has_cycle(next_id, by_id, state):
			return true
	state[node_id] = 2
	return false
