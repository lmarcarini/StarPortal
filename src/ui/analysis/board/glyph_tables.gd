class_name GlyphTables
extends RefCounted
## The translated glyph names and picture descriptions, indexed by glyph index, for
## [method ClueText.format]. Built from the Registry in the current language.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math

## Translated name of each glyph; empty for a glyph without a definition.
var names: Array[String] = []
## Translated picture description of each glyph.
var pictures: Array[String] = []


## Returns the tables for all glyphs, read now so they follow the current language.
static func build() -> GlyphTables:
	var tables: GlyphTables = GlyphTables.new()
	for index: int in GateAddress.GLYPH_COUNT:
		var id: StringName = StringName(GlyphIcon.GLYPH_ID_FORMAT % index)
		var glyph: GlyphDef = Registry.get_def(id) as GlyphDef
		tables.names.append(TranslationServer.translate(glyph.name_key) if glyph != null else "")
		tables.pictures.append(
			TranslationServer.translate(glyph.picture_key) if glyph != null else ""
		)
	return tables
