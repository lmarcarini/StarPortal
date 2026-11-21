class_name GlyphFrequency
extends RefCounted
## Glyph frequency (S04, docs/content/research-and-progression.md section 10): once
## researched, the alien panel marks the glyphs seen in the clipped document, as a set (their
## order is still the player's to work out). Pure.
## Bible: docs/content/research-and-progression.md section 10


## The glyphs to mark for the clipped document [param def] in [param state], sorted; empty
## before the research or for no document.
static func marked(state: GameState, def: DocumentDef) -> PackedInt32Array:
	var found := PackedInt32Array()
	if def == null or not ResearchPerks.has(state, ResearchPerks.GLYPH_FREQUENCY):
		return found
	found = def.answer_glyphs.duplicate()
	found.sort()
	return found
