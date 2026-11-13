class_name StoryRules
extends RefCounted
## The one simulation-layer entry point for story conditions and effects: check() evaluates a
## condition against GameState (read only), apply() makes an effect happen and posts its event.
## apply() is called only from Command.apply() or SimSystem.tick(). ModifierEffect is never
## applied: modifiers are summed while their source holds (M4-21). No Node, autoload or global
## random.
## Bible: docs/content/m4-core-systems.md section 1

## Reason key of a standing change made by a story effect.
const CAUSE_KEY: StringName = &"STORY_CAUSE"


## True when [param condition] holds in [param state]; an unknown condition is false.
static func check(state: GameState, condition: ConditionDef) -> bool:
	if condition is FlagIsCondition:
		var flag_is: FlagIsCondition = condition
		return _flag_equals(state.flags.get(flag_is.flag, false), flag_is.value)
	if condition is StandingAtLeastCondition:
		var at_least: StandingAtLeastCondition = condition
		return FactionRules.standing(state, at_least.faction) >= at_least.amount
	if condition is StandingBelowCondition:
		var below: StandingBelowCondition = condition
		return FactionRules.standing(state, below.faction) < below.amount
	if condition is FactionMetCondition:
		return state.factions.met.has((condition as FactionMetCondition).faction)
	if condition is ResearchDoneCondition:
		return state.research.is_done((condition as ResearchDoneCondition).project)
	if condition is HasArtefactCondition:
		return count_held(state, (condition as HasArtefactCondition).artefact) > 0
	if condition is WorldStatusAtLeastCondition:
		var world: WorldStatusAtLeastCondition = condition
		return int(state.worlds.status_of(world.world)) >= int(world.status)
	if condition is RequestIsCondition:
		var request_is: RequestIsCondition = condition
		var newest: RequestRecord = newest_request(state, request_is.request)
		return newest != null and int(newest.state) == int(request_is.state)
	if condition is NoDialSinceCondition:
		return _no_dial_since(state, (condition as NoDialSinceCondition).flag)
	return false


## True when every one of [param conditions] holds (true for none).
static func check_all(state: GameState, conditions: Array[ConditionDef]) -> bool:
	return failing(state, conditions).is_empty()


## The conditions of [param conditions] that do not hold, in order.
static func failing(state: GameState, conditions: Array[ConditionDef]) -> Array[ConditionDef]:
	var found: Array[ConditionDef] = []
	for condition: ConditionDef in conditions:
		if not check(state, condition):
			found.append(condition)
	return found


## Applies [param effect] for [param _source] (the definition that holds it) and posts
## its event. Returns false when it could not apply (nothing held to take or study, unknown
## request or project, a ModifierEffect) and then changes nothing.
static func apply(state: GameState, effect: EffectDef, _source: StringName) -> bool:
	if effect == null or effect is ModifierEffect:
		return false
	if effect is SetFlagEffect:
		var set_flag: SetFlagEffect = effect
		return _set_flag(state, set_flag.flag, set_flag.value)
	if effect is StampFlagEffect:
		return _set_flag(state, (effect as StampFlagEffect).flag, state.clock.tick)
	if effect is ChangeStandingEffect:
		var standing: ChangeStandingEffect = effect
		FactionRules.change(state, standing.faction, standing.delta, CAUSE_KEY)
		return FactionRules.is_known(state, standing.faction)
	if effect is ChangeMoneyEffect:
		state.budget.funds_k += (effect as ChangeMoneyEffect).amount_k
		state.events.post(&"budget_changed", [state.budget.funds_k])
		return true
	if effect is AddDocumentEffect:
		return _add_document(state, (effect as AddDocumentEffect).document)
	if effect is AddAddressEffect:
		return _add_address(state, (effect as AddAddressEffect).world)
	var unlock: Array = UnlockRules.unlock_pair(effect)
	if not unlock.is_empty():
		var unlock_id: StringName = unlock[0]
		return UnlockRules.apply_to_game(state, unlock_id, unlock[1])
	return StoryRulesItems.apply(state, effect)


## Applies each of [param effects] in order; returns how many applied.
static func apply_all(state: GameState, effects: Array[EffectDef], source: StringName) -> int:
	var applied: int = 0
	for effect: EffectDef in effects:
		if apply(state, effect, source):
			applied += 1
	return applied


## How many artefacts of [param artefact] the player holds, in any place.
static func count_held(state: GameState, artefact: StringName) -> int:
	var count: int = 0
	for record: ArtefactRecord in state.artefacts.items:
		if record.artefact == artefact:
			count += 1
	return count


## The newest instance of [param request], or null.
static func newest_request(state: GameState, request: StringName) -> RequestRecord:
	for index: int in range(state.requests.items.size() - 1, -1, -1):
		var record: RequestRecord = state.requests.items[index]
		if record.request == request:
			return record
	return null


## A saved flag equals [param expected]; JSON turns ints into floats, so numbers compare by
## value and bools only with bools.
static func _flag_equals(actual: Variant, expected: Variant) -> bool:
	if expected is bool or actual is bool:
		return actual is bool and expected is bool and actual == expected
	if (expected is int or expected is float) and (actual is int or actual is float):
		var a: float = actual
		var b: float = expected
		return is_equal_approx(a, b)
	return str(actual) == str(expected) and actual is String == expected is String


static func _no_dial_since(state: GameState, flag: StringName) -> bool:
	var stamp: Variant = state.flags.get(flag)
	if not SaveFields.is_int(stamp):
		return true
	var since: int = SaveFields.read_int(stamp)
	if state.gate.dial_started_tick >= since:
		return false
	for entry: DialLogEntry in state.gate.dial_log:
		if entry.tick >= since:
			return false
	return true


static func _set_flag(state: GameState, flag: StringName, value: Variant) -> bool:
	if flag.is_empty():
		return false
	state.flags[flag] = value
	state.events.post(&"flag_changed", [flag])
	return true


static func _add_document(state: GameState, document: StringName) -> bool:
	if document.is_empty() or state.archive.has_document(document):
		return false
	DeliverDocumentCommand.deliver(state, document)
	return true


static func _add_address(state: GameState, world: StringName) -> bool:
	var galaxy: GalaxyCatalogue = state.galaxy
	if galaxy == null or galaxy.get_world(world) == null:
		return false
	var key: String = galaxy.address_of(world, galaxy.home().origin_glyph).key()
	if state.address_book.find(key) != null:
		return false
	var entry := AddressEntry.create(key, AddressEntry.Source.DOCUMENT, world)
	entry.world_id = world
	state.address_book.entries.push_front(entry)
	state.events.post(&"address_book_changed", [])
	return true
