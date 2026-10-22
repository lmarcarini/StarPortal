class_name WorkbenchText
extends RefCounted
## Builds the Address Workbench's sentences from translation templates in
## localization/workbench.csv and glyph names (GlyphDef.name_key). The caller passes its own
## tr as [param translate], so the text follows the locale the view uses.
## Bible: gate-and-address-spec.md#player-tools,
## technical-architecture.md#input-accessibility-and-localisation

## Template key per AddressConstraint.Kind, in enum order.
const RULE_KEYS: Array[StringName] = [
	&"WORKBENCH_RULE_GLYPH_AT",
	&"WORKBENCH_RULE_GLYPH_NOT_AT",
	&"WORKBENCH_RULE_EXCLUDED",
	&"WORKBENCH_RULE_INCLUDED",
	&"WORKBENCH_RULE_EXACT_SET",
	&"WORKBENCH_RULE_NEARER_THAN",
]
## Key of the digit-group separator ("," in English, "." in Brazilian Portuguese).
const SEPARATOR_KEY: StringName = &"WORKBENCH_DIGIT_SEPARATOR"
## Key of the separator between names in a list.
const LIST_SEPARATOR_KEY: StringName = &"WORKBENCH_LIST_SEPARATOR"


## Returns glyph [param glyph]'s translation key for its name, or &"" for no glyph.
static func glyph_name_key(glyph: int) -> StringName:
	if glyph < 0 or glyph >= GateAddress.GLYPH_COUNT:
		return &""
	var def: GlyphDef = Registry.get_def(StringName(GlyphIcon.GLYPH_ID_FORMAT % glyph)) as GlyphDef
	return def.name_key if def != null else &""


## Returns glyph [param glyph]'s translated name.
static func glyph_name(glyph: int, translate: Callable) -> String:
	return str(translate.call(glyph_name_key(glyph)))


## Returns [param glyphs]' names joined by the translated list separator.
static func glyph_names(glyphs: Array[int], translate: Callable) -> String:
	var names: PackedStringArray = PackedStringArray()
	for glyph: int in glyphs:
		names.append(glyph_name(glyph, translate))
	return str(translate.call(LIST_SEPARATOR_KEY)).join(names)


## Returns [param constraint] in plain words, e.g. "Heron is at seal 2".
static func describe(constraint: AddressConstraint, translate: Callable) -> String:
	var template: String = str(translate.call(RULE_KEYS[constraint.kind]))
	var first: String = glyph_name(constraint.glyphs[0], translate)
	match constraint.kind:
		AddressConstraint.Kind.EXACT_SET:
			return template.format({"glyphs": glyph_names(constraint.glyphs, translate)})
		AddressConstraint.Kind.NEARER_THAN:
			var second: String = glyph_name(constraint.glyphs[1], translate)
			return template.format({"nearer": first, "farther": second})
	return template.format({"glyph": first, "seal": constraint.seal})


## Returns [param value] grouped with the translated digit-group separator.
static func number(value: int, translate: Callable) -> String:
	return DigitGrouping.group(value, str(translate.call(SEPARATOR_KEY)))
