class_name ContentCheckStory
extends RefCounted
## Content checks for story conditions and effects: every id they point at names a loaded
## definition, every ModifierEffect uses a known key, and ModifierEffect appears only on research
## and artefact definitions. Pure functions that return one line per problem. Definition cards
## call check_lists() for their own lists; check_registry() finds every list on every loaded
## definition by its exported properties.
## Bible: docs/content/m4-core-systems.md sections 1 and 6

const RegistryScript := preload("res://src/content/registry.gd")
## Definition classes whose effects may carry a ModifierEffect.
const MODIFIER_OWNERS: Array[StringName] = [&"ResearchDef", &"ArtefactDef"]


## Returns the problems of the [param conditions] and [param effects] of the definition
## [param owner_id]: a null entry, an empty or unknown reference (not a key of [param known]),
## an unknown modifier key, and a ModifierEffect when [param allow_modifiers] is false.
static func check_lists(
	owner_id: StringName,
	conditions: Array[ConditionDef],
	effects: Array[EffectDef],
	known: Dictionary[StringName, DefBase],
	allow_modifiers: bool
) -> Array[String]:
	var errors: Array[String] = []
	for condition: ConditionDef in conditions:
		errors.append_array(_check_entry(owner_id, condition, known))
	for effect: EffectDef in effects:
		errors.append_array(_check_entry(owner_id, effect, known))
		if effect is ModifierEffect:
			errors.append_array(
				_check_modifier(owner_id, effect as ModifierEffect, allow_modifiers)
			)
	return errors


## Returns the problems of every condition and effect list held in an exported Array property
## of a definition loaded in [param registry].
static func check_registry(registry: RegistryScript) -> Array[String]:
	var all: Array[DefBase] = registry.get_all_of(DefBase)
	var known: Dictionary[StringName, DefBase] = {}
	for def: DefBase in all:
		known[def.id] = def
	var errors: Array[String] = []
	for def: DefBase in all:
		var conditions: Array[ConditionDef] = []
		var effects: Array[EffectDef] = []
		_collect(def, conditions, effects)
		errors.append_array(check_lists(def.id, conditions, effects, known, _allows_modifiers(def)))
	return errors


## Returns true when [param def] is a definition class that may carry ModifierEffect.
static func _allows_modifiers(def: DefBase) -> bool:
	var script: Script = def.get_script()
	return script != null and MODIFIER_OWNERS.has(script.get_global_name())


## Appends to [param conditions] and [param effects] every entry of the exported Array
## properties of [param def] (nested lists inside other resources are their owner's job).
static func _collect(
	def: DefBase, conditions: Array[ConditionDef], effects: Array[EffectDef]
) -> void:
	for property: Dictionary in def.get_property_list():
		if property["type"] != TYPE_ARRAY or not (property["usage"] & PROPERTY_USAGE_STORAGE):
			continue
		var property_name: StringName = property["name"]
		var values: Array = def.get(property_name)
		for value: Variant in values:
			if not value is Resource:
				continue
			var entry: Resource = value
			if entry is ConditionDef:
				conditions.append(entry)
			elif entry is EffectDef:
				effects.append(entry)


static func _check_entry(
	owner_id: StringName, entry: Resource, known: Dictionary[StringName, DefBase]
) -> Array[String]:
	var errors: Array[String] = []
	if entry == null:
		errors.append("%s: empty condition or effect entry" % owner_id)
		return errors
	var script: Script = entry.get_script()
	var kind: String = script.get_global_name()
	var references: Array[StringName] = entry.call("get_references")
	for reference: StringName in references:
		if reference.is_empty():
			errors.append("%s: %s has an empty id" % [owner_id, kind])
		elif not known.has(reference):
			errors.append('%s: %s references unknown id "%s"' % [owner_id, kind, reference])
	return errors


static func _check_modifier(
	owner_id: StringName, modifier: ModifierEffect, allow_modifiers: bool
) -> Array[String]:
	var errors: Array[String] = []
	if not ModifierEffect.is_known_key(modifier.key):
		errors.append('%s: unknown modifier key "%s"' % [owner_id, modifier.key])
	if not allow_modifiers:
		errors.append("%s: ModifierEffect is only allowed on research and artefacts" % owner_id)
	return errors
