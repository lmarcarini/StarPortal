class_name RequestText
extends RefCounted
## Words of the Requests sub-tab in the current locale: a request's title, its status line
## (offer days left, deadline countdown or "No deadline", result), its objective lines with a
## mark for each condition, and its reward, penalty and decline previews.
## Bible: docs/content/m4-core-systems.md section 4

## Mark of a met and an unmet objective condition.
const MET: String = "[x]"
const UNMET: String = "[ ]"
## Text key of each closed result (RequestRecord.RequestState as int).
const RESULT_KEYS: Dictionary[int, StringName] = {
	2: &"REQUEST_RESULT_FULFILLED",
	3: &"REQUEST_RESULT_FAILED",
	4: &"REQUEST_RESULT_DECLINED",
	5: &"REQUEST_RESULT_LAPSED",
}


## The request's translated title, or its id.
static func title(def: RequestDef, record: RequestRecord) -> String:
	if def == null or def.title_key.is_empty():
		return String(record.request)
	return _tr(def.title_key)


## The status line of [param record] at [param state]'s tick.
static func status(state: GameState, def: RequestDef, record: RequestRecord) -> String:
	match record.state:
		RequestRecord.RequestState.OFFERED:
			var lapse: int = record.offered_tick
			if def != null:
				lapse += def.offer_days * TimeMath.TICKS_PER_DAY
			return _tr(&"REQUEST_OFFER_LEFT").format({"days": _days_left(state, lapse)})
		RequestRecord.RequestState.ACTIVE:
			if record.deadline_tick < 0:
				return _tr(&"REQUEST_NO_DEADLINE")
			var left: int = _days_left(state, record.deadline_tick)
			return _tr(&"REQUEST_DEADLINE_LEFT").format({"days": left})
	var key: StringName = RESULT_KEYS.get(record.state as int, &"REQUEST_RESULT_FULFILLED")
	return _tr(key)


## One line per objective condition: "[x] Requires ..." when it holds, "[ ] ..." when not.
static func objective_lines(state: GameState, def: RequestDef) -> Array[String]:
	var found: Array[String] = []
	if def == null:
		return found
	for condition: ConditionDef in def.objective:
		var mark: String = MET if StoryRules.check(state, condition) else UNMET
		found.append("%s %s" % [mark, StoryText.reason(condition)])
	return found


## "Reward: a, b" style lines for the reward, penalty and on-decline effects that have any
## preview ("?" for hidden ones).
static func preview_lines(def: RequestDef) -> Array[String]:
	var found: Array[String] = []
	if def == null:
		return found
	var groups: Array = [
		[&"REQUEST_REWARD", def.reward],
		[&"REQUEST_PENALTY", def.penalty],
		[&"REQUEST_ON_DECLINE", def.on_decline],
	]
	for group: Array in groups:
		var parts: PackedStringArray = []
		var effects: Array[EffectDef] = group[1]
		for effect: EffectDef in effects:
			var text: String = StoryText.preview(effect)
			if not text.is_empty():
				parts.append(text)
		if not parts.is_empty():
			var key: StringName = group[0]
			found.append(_tr(key).format({"effects": ", ".join(parts)}))
	return found


static func _days_left(state: GameState, until_tick: int) -> int:
	var left: int = maxi(until_tick - state.clock.tick, 0)
	return ceili(float(left) / float(TimeMath.TICKS_PER_DAY))


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
