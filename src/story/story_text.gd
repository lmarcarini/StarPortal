class_name StoryText
extends RefCounted
## Plain-language lines for story effects and conditions in the current locale: an effect's
## preview ("Kindred standing +10", "$500k", "An artefact: Kindred Loom"; a hidden effect is
## "?") and a condition's reason ("Requires Kindred standing 25"). Names come from the loaded
## definitions; an unknown id shows as itself. Flag effects have no preview line ("").
## Bible: docs/content/m4-core-systems.md section 1

## Text key of each world status, in WorldStatusAtLeastCondition.WorldStatus order.
const STATUS_KEYS: Array[StringName] = [
	&"WORLD_STATUS_UNKNOWN",
	&"WORLD_STATUS_LOCKED",
	&"WORLD_STATUS_PROBED",
	&"WORLD_STATUS_SURVEYED",
	&"WORLD_STATUS_CONTACTED",
]


## The preview line of [param effect]; "" for flags and unknown effects.
static func preview(effect: EffectDef) -> String:
	if effect == null:
		return ""
	if effect.hidden:
		return _tr(&"STORY_HIDDEN")
	if effect is ChangeStandingEffect:
		var standing: ChangeStandingEffect = effect
		if standing.faction == FactionRules.COMMITTEE:
			return _tr(&"STORY_FX_CONFIDENCE").format({"amount": signed(standing.delta)})
		return _line(&"STORY_FX_STANDING", standing.faction, signed(standing.delta))
	if effect is ChangeMoneyEffect:
		var money: int = (effect as ChangeMoneyEffect).amount_k
		var shown: String = ("+" if money > 0 else "") + MoneyLabel.format_k(money)
		return _tr(&"STORY_FX_MONEY").format({"amount": shown})
	if effect is ModifierEffect:
		var modifier: ModifierEffect = effect
		return _tr(&"STORY_FX_MODIFIER").format(
			{"key": String(modifier.key), "amount": signed(modifier.amount)}
		)
	return _item_preview(effect)


## The reason line of [param condition] (what the player must reach).
static func reason(condition: ConditionDef) -> String:
	if condition == null:
		return ""
	var key: StringName = condition.reason_key()
	var refs: Array[StringName] = condition.get_references()
	var id: StringName = refs[0] if not refs.is_empty() else &""
	var amount: String = ""
	if condition is StandingAtLeastCondition:
		amount = str((condition as StandingAtLeastCondition).amount)
	elif condition is StandingBelowCondition:
		amount = str((condition as StandingBelowCondition).amount)
	var status: String = ""
	if condition is WorldStatusAtLeastCondition:
		var status_index: int = (condition as WorldStatusAtLeastCondition).status
		status = _tr(STATUS_KEYS[clampi(status_index, 0, STATUS_KEYS.size() - 1)])
	return _tr(key).format({"name": name_of(id), "amount": amount, "status": status})


## The translated name of the definition [param id], or the id itself when unknown.
static func name_of(id: StringName) -> String:
	if id.is_empty():
		return ""
	var def: DefBase = Registry.get_def(id)
	for property: String in ["name_key", "title_key"]:
		if def != null and property in def:
			var key: StringName = def.get(property)
			if not key.is_empty():
				return _tr(key)
	return String(id)


## [param amount] with its sign: "+10", "-2", "0".
static func signed(amount: int) -> String:
	return ("+" if amount > 0 else "") + str(amount)


static func _item_preview(effect: EffectDef) -> String:
	var keys: Dictionary[String, StringName] = {
		"AddDocumentEffect": &"STORY_FX_DOCUMENT",
		"DrainPowerEffect": &"STORY_FX_DRAIN",
		"AddAddressEffect": &"STORY_FX_ADDRESS",
		"OfferRequestEffect": &"STORY_FX_REQUEST",
		"GiveArtefactEffect": &"STORY_FX_GIVE_ARTEFACT",
		"TakeArtefactEffect": &"STORY_FX_TAKE_ARTEFACT",
		"StudyArtefactEffect": &"STORY_FX_STUDY_ARTEFACT",
		"UnlockResearchEffect": &"STORY_FX_UNLOCK_RESEARCH",
		"CompleteResearchEffect": &"STORY_FX_COMPLETE_RESEARCH",
	}
	var script: Script = effect.get_script()
	var key: StringName = keys.get(String(script.get_global_name()), &"")
	if key.is_empty():
		return ""
	var refs: Array[StringName] = effect.get_references()
	var amount: String = str((effect as DrainPowerEffect).mwh) if effect is DrainPowerEffect else ""
	return _line(key, refs[0] if not refs.is_empty() else &"", amount)


static func _line(key: StringName, id: StringName, amount: String) -> String:
	return _tr(key).format({"name": name_of(id), "amount": amount})


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
