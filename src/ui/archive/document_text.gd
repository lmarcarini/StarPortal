class_name DocumentText
extends RefCounted
## Pure text helpers of the Archive: a document's translated title, source and kind, the line
## saying when it arrived, its body as plain paragraphs with simple emphasis (BBCode for a
## RichTextLabel), and the order documents are listed and offered to read together. Nothing
## here reads [member DocumentDef.answer_glyphs] or [member DocumentDef.world_id]: the Archive
## shows only what the document's own text says.
## Bible: game-design.md#core-loop, gate-and-address-spec.md#the-opening-puzzle

## Translation key of each DocumentDef.Kind, indexed by kind, then the transcript kind.
const KIND_KEYS: Array[StringName] = [
	&"ARCHIVE_KIND_NOTE",
	&"ARCHIVE_KIND_IMAGE",
	&"ARCHIVE_KIND_DOSSIER",
	&"ARCHIVE_KIND_LOG",
	&"ARCHIVE_KIND_GIFT",
	&"ARCHIVE_KIND_ARTEFACT",
	&"ARCHIVE_KIND_TRANSCRIPT",
]
## Kind index of a conversation transcript (after the DocumentDef kinds).
const TRANSCRIPT_KIND: int = 6

static var _bold: RegEx = RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
static var _italic: RegEx = RegEx.create_from_string("\\*(.+?)\\*")


## Returns the translation key of [param kind] (a DocumentDef.Kind), or the note's for an
## unknown kind.
static func kind_key(kind: int) -> StringName:
	if kind < 0 or kind >= KIND_KEYS.size():
		return KIND_KEYS[0]
	return KIND_KEYS[kind]


## Returns the translated title of [param def], or "Untitled document" when it has none.
static func title(def: DocumentDef) -> String:
	if def == null or def.title_key.is_empty():
		return _translate(&"ARCHIVE_UNTITLED")
	return _translate(def.title_key)


## Returns "Source: <who>" for [param def], or "" when it names no source.
static func source_line(def: DocumentDef) -> String:
	if def == null or def.source_key.is_empty():
		return ""
	return _translate(&"ARCHIVE_SOURCE").format({"source": _translate(def.source_key)})


## Returns "Received YYYY-MM-DD HH:MM" for a document that arrived at [param tick].
static func received_line(tick: int) -> String:
	var date: Dictionary = TimeMath.date_of(maxi(tick, 0))
	var text: String = (
		"%04d-%02d-%02d %02d:%02d"
		% [date["year"], date["month"], date["day"], date["hour"], date["minute"]]
	)
	return _translate(&"ARCHIVE_RECEIVED").format({"date": text})


## Returns [param text] as BBCode: paragraphs split on blank lines, trimmed and separated by
## one blank line; single line breaks kept; any "[" shown literally; [code]**bold**[/code]
## and [code]*italic*[/code] as emphasis.
static func body_bbcode(text: String) -> String:
	var paragraphs: PackedStringArray = []
	var lines: PackedStringArray = []
	for line: String in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
		if not line.strip_edges().is_empty():
			lines.append(line.strip_edges())
			continue
		if not lines.is_empty():
			paragraphs.append(_emphasis("\n".join(lines).replace("[", "[lb]")))
			lines.clear()
	if not lines.is_empty():
		paragraphs.append(_emphasis("\n".join(lines).replace("[", "[lb]")))
	return "\n\n".join(paragraphs)


## Returns [param received] (arrival order) newest first.
static func newest_first(received: Array[StringName]) -> Array[StringName]:
	var ids: Array[StringName] = received.duplicate()
	ids.reverse()
	return ids


## Returns the documents to offer beside [param document_id], newest first from
## [param received], without the document itself; its [param pair_id] comes first when held.
static func read_with_order(
	document_id: StringName, pair_id: StringName, received: Array[StringName]
) -> Array[StringName]:
	var ids: Array[StringName] = newest_first(received)
	ids.erase(document_id)
	if not pair_id.is_empty() and ids.has(pair_id):
		ids.erase(pair_id)
		ids.push_front(pair_id)
	return ids


static func _emphasis(text: String) -> String:
	var bold: String = _bold.sub(text, "[b]$1[/b]", true)
	return _italic.sub(bold, "[i]$1[/i]", true)


static func _translate(key: StringName) -> String:
	return String(TranslationServer.translate(key))


## The partial translation of [param def]'s alien text once Xenolinguistics (S09) is done in
## [param state]: its DOC_*_GLOSS text in italics, or "" (before the research, or when the
## document has no alien text).
static func gloss(def: DocumentDef, state: GameState) -> String:
	if def == null:
		return ""
	var stem: String = String(def.id).trim_prefix("doc_").to_upper()
	if ResearchPerks.has(state, XenoPerks.LOOM_TRANSLATOR):
		var full: String = TranslationServer.translate(StringName("DOC_%s_TRANSLATION" % stem))
		if full != "DOC_%s_TRANSLATION" % stem:
			return (
				"[i]%s[/i]" % TranslationServer.translate(&"DOC_TRANSLATION").format({"text": full})
			)
	if not ResearchPerks.has(state, ResearchPerks.XENOLINGUISTICS):
		return ""
	var key: StringName = StringName("DOC_%s_GLOSS" % String(def.id).trim_prefix("doc_").to_upper())
	var text: String = TranslationServer.translate(key)
	if text == String(key):
		return ""
	return "[i]%s[/i]" % TranslationServer.translate(&"DOC_GLOSS").format({"text": text})
