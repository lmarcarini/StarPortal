class_name RequestLog
extends RefCounted
## Log lines of requests: one when a request is accepted, fulfilled, failed, declined or
## lapses ("Request fulfilled: Survey the ruins."). Offers are not logged (the conversation is).
## Bible: docs/content/m4-core-systems.md section 4

## Text key of each logged state (RequestRecord.RequestState as int).
const LINE_KEYS: Dictionary[int, StringName] = {
	1: &"LOG_LINE_REQUEST_ACTIVE",
	2: &"LOG_LINE_REQUEST_FULFILLED",
	3: &"LOG_LINE_REQUEST_FAILED",
	4: &"LOG_LINE_REQUEST_DECLINED",
	5: &"LOG_LINE_REQUEST_LAPSED",
}


## The entries request_changed [param args] ([uid, state]) writes at [param tick].
static func entries(args: Array, state: GameState, tick: int) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	if args.size() < 2:
		return found
	var uid: int = args[0]
	var to: int = args[1]
	var record: RequestRecord = RequestRules.find(state, uid)
	if record == null or not LINE_KEYS.has(to):
		return found
	found.append(
		LogEntry.create(tick, &"faction", &"", {"request_id": String(record.request), "state": to})
	)
	return found


## The line of a request entry's [param args].
static func line(args: Dictionary) -> String:
	var to: int = SaveFields.read_int(args.get("state"), 2)
	var key: StringName = LINE_KEYS.get(to, &"LOG_LINE_REQUEST_FULFILLED")
	var id: StringName = StringName(str(args.get("request_id", "")))
	return String(TranslationServer.translate(key)).format({"name": StoryText.name_of(id)})
