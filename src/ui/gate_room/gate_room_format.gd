class_name GateRoomFormat
extends RefCounted
## Pure text helpers of the Gate Room: dates, durations, energies, outcome texts and glyph
## names. Every user-visible string comes from a translation key; the helpers translate with
## the TranslationServer so they can stay static.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## game-design.md#difficulty-and-accessibility

## Keys of the outcome names, indexed by DialOutcome.Kind.
const _NAME_KEYS: Array[StringName] = [
	&"GATE_OUTCOME_NO_GATE",
	&"GATE_OUTCOME_BLOCKED",
	&"GATE_OUTCOME_ORIGIN_REJECTED",
	&"GATE_OUTCOME_LOCK",
	&"GATE_OUTCOME_HOSTILE_LOCK",
]
## Keys of what each outcome tells the player (bible table "What the player learns").
const _MEANING_KEYS: Array[StringName] = [
	&"GATE_MEANING_NO_GATE",
	&"GATE_MEANING_BLOCKED",
	&"GATE_MEANING_ORIGIN_REJECTED",
	&"GATE_MEANING_LOCK",
	&"GATE_MEANING_HOSTILE_LOCK",
]
## Keys of the short caption line of each outcome.
const _CAPTION_KEYS: Array[StringName] = [
	&"GATE_CAPTION_NO_GATE",
	&"GATE_CAPTION_BLOCKED",
	&"GATE_CAPTION_ORIGIN_REJECTED",
	&"GATE_CAPTION_LOCK",
	&"GATE_CAPTION_HOSTILE_LOCK",
]
const _MINUTES_PER_HOUR: int = 60
const _GLYPH_ID_FORMAT: String = "glyph_%02d"


## Returns [param tick] as "YYYY-MM-DD hh:mm", the format of the time bar.
static func date_time(tick: int) -> String:
	var date: Dictionary = TimeMath.date_of(tick)
	return (
		"%04d-%02d-%02d %02d:%02d"
		% [date["year"], date["month"], date["day"], date["hour"], date["minute"]]
	)


## Returns [param ticks] (in-game minutes) as hours and minutes, e.g. "2 h 15 min".
static func duration(ticks: int) -> String:
	var total: int = maxi(ticks, 0)
	var hours: int = total / _MINUTES_PER_HOUR
	var minutes: int = total % _MINUTES_PER_HOUR
	var key: StringName = &"GATE_DURATION_MINUTES"
	if hours > 0:
		key = &"GATE_DURATION_HOURS"
	return translate(key).format({"hours": hours, "minutes": minutes})


## Returns [param mwh] as text with its unit, e.g. "318.5 MWh".
static func energy(mwh: float) -> String:
	return translate(&"GATE_ENERGY").format({"value": String.num(mwh, 1)})


## Returns the "ready in" text for [param ticks] as GateQueries.ticks_until_ready() reports
## it: 0 is "ready now", -1 is "never at the current output".
static func ready_in(ticks: int) -> String:
	if ticks < 0:
		return translate(&"GATE_READY_NEVER")
	if ticks == 0:
		return translate(&"GATE_READY_NOW")
	return translate(&"GATE_READY_IN").format({"time": duration(ticks)})


## Returns the translated name of outcome [param kind]; empty for a value outside the enum.
static func outcome_name(kind: int) -> String:
	return _translate_at(_NAME_KEYS, kind)


## Returns what outcome [param kind] means for the player.
static func outcome_meaning(kind: int) -> String:
	return _translate_at(_MEANING_KEYS, kind)


## Returns the short caption line of outcome [param kind], for screen readers and captions.
static func outcome_caption(kind: int) -> String:
	return _translate_at(_CAPTION_KEYS, kind)


## True for the outcomes that fail: No gate, Blocked and Origin rejected.
static func is_failure(kind: int) -> bool:
	return kind >= 0 and kind < _NAME_KEYS.size() and not DialOutcome.is_lock(kind)


## Returns the translated name of glyph [param index]; empty when there is no such glyph.
static func glyph_name(index: int) -> String:
	var glyph: GlyphDef = Registry.get_def(StringName(_GLYPH_ID_FORMAT % index)) as GlyphDef
	if glyph == null:
		return ""
	return translate(glyph.name_key)


## Returns the glyph names of [param address] in seal order, joined by commas.
static func address_text(address: GateAddress) -> String:
	var names: PackedStringArray = []
	for glyph: int in address.seals():
		names.append(glyph_name(glyph))
	return ", ".join(names)


## Returns the translation of [param key] in the current locale.
static func translate(key: StringName) -> String:
	return String(TranslationServer.translate(key))


static func _translate_at(keys: Array[StringName], index: int) -> String:
	if index < 0 or index >= keys.size():
		return ""
	return translate(keys[index])
