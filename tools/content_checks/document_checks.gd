class_name ContentCheckDocuments
extends RefCounted
## Content checks for the documents and their puzzles: every answer is its world's real address
## from CAIRN, every authored world can be locked with the opening's capacitors, every text key
## is in documents.csv in both locales and states no lock energy, read-together documents point
## at each other, inscriptions read on another world give the same seven glyphs from that
## world's Ring, and the likely wrong readings (decoys) are no world's address. Pure functions
## that return one line per problem.
## Bible: gate-and-address-spec.md#puzzle-design-rules, technical-architecture.md#data-model,
## docs/content/m15-puzzles.md

## The table of document texts.
const TABLE: String = "documents.csv"
## The locales every document key needs, in the table's column order.
const LOCALES: Array[String] = ["en", "pt_BR"]
## A document must never state a lock energy; this unit gives one away.
const ENERGY_UNIT: String = "MWh"


## Documents whose puzzle is read from an inscription that stands on another world, by id, and
## that world's id: the address carved there must be the one CAIRN dials. (m15-puzzles.md:
## the stone on LINTEL gives MILESTONE's address.)
static func far_side_readings() -> Dictionary[StringName, StringName]:
	return {
		&"doc_milestone_letter": &"world_lintel",
		&"doc_milestone_frame_1": &"world_lintel",
		&"doc_milestone_frame_2": &"world_lintel",
		&"doc_milestone_record": &"world_lintel",
	}


## The wrong readings a player is most likely to dial (m15-puzzles.md, "Decoys for the
## validator"): seals 1 to 7 from CAIRN. None may ever be a real address.
static func decoys() -> Array[PackedInt32Array]:
	return [
		PackedInt32Array([35, 29, 19, 8, 24, 10, 22]),
		PackedInt32Array([35, 17, 29, 10, 19, 22, 8]),
		PackedInt32Array([35, 24, 18, 10, 19, 22, 8]),
		PackedInt32Array([35, 24, 29, 28, 19, 22, 8]),
		PackedInt32Array([35, 24, 29, 10, 23, 22, 8]),
		PackedInt32Array([35, 24, 29, 10, 19, 33, 8]),
		PackedInt32Array([35, 24, 29, 10, 19, 22, 26]),
		PackedInt32Array([35, 23, 10, 15, 5, 6, 4]),
		PackedInt32Array([35, 8, 10, 15, 5, 6, 4]),
		PackedInt32Array([35, 19, 10, 15, 27, 6, 4]),
		PackedInt32Array([35, 19, 10, 15, 26, 6, 4]),
		PackedInt32Array([35, 19, 10, 15, 5, 6, 22]),
		PackedInt32Array([35, 19, 10, 6, 5, 15, 4]),
		PackedInt32Array([35, 34, 29, 24, 3, 19, 22]),
		PackedInt32Array([35, 10, 24, 19, 8, 29, 15]),
		PackedInt32Array([35, 10, 34, 19, 29, 8, 15]),
		PackedInt32Array([35, 10, 24, 23, 29, 8, 15]),
		PackedInt32Array([35, 10, 24, 19, 22, 8, 15]),
		PackedInt32Array([35, 10, 24, 19, 29, 26, 15]),
		PackedInt32Array([35, 10, 24, 19, 29, 8, 13]),
	]


## Returns one line per document of [param documents] with answer glyphs whose world is not an
## authored world of [param worlds], or whose answer is not the world's first seven seals from
## the home world's origin over [param anchors_ly].
static func check_answers(
	documents: Array[DocumentDef], worlds: Array[WorldDef], anchors_ly: Array[Vector3i]
) -> Array[String]:
	var errors: Array[String] = []
	var home: WorldDef = _home(worlds)
	if home == null or anchors_ly.size() != GateAddress.GLYPH_COUNT:
		return errors
	var by_id: Dictionary[StringName, WorldDef] = _by_id(worlds)
	for document: DocumentDef in documents:
		if document.answer_glyphs.is_empty():
			continue
		if not by_id.has(document.world_id):
			errors.append(
				(
					"document %s: answer for %s, not an authored world"
					% [document.id, document.world_id]
				)
			)
			continue
		var real: Array[int] = _coordinates(by_id[document.world_id], anchors_ly, home.origin_glyph)
		if Array(document.answer_glyphs) != Array(real):
			errors.append(
				(
					"document %s: answer %s is not %s's address %s from CAIRN"
					% [document.id, Array(document.answer_glyphs), document.world_id, real]
				)
			)
	return errors


## Returns one line per authored world other than home whose lock energy from home is more
## than the opening's capacity: the starting capacity plus every capacitor bank the base has
## room for ([param balance]).
static func check_reach(
	worlds: Array[WorldDef], anchors_ly: Array[Vector3i], balance: BalanceConfig
) -> Array[String]:
	var errors: Array[String] = []
	var home: WorldDef = _home(worlds)
	if home == null or balance == null or anchors_ly.size() != GateAddress.GLYPH_COUNT:
		return errors
	var capacity: float = (
		balance.starting_capacity_mwh
		+ balance.max_capacitor_banks * balance.capacitor_bank_capacity_mwh
	)
	for world: WorldDef in worlds:
		if world.is_home:
			continue
		var address: GateAddress = AddressRule.address_of(
			world.position_ly, anchors_ly, home.origin_glyph
		)
		var energy: float = EnergyMath.lock_energy_mwh(
			address, home.position_ly, anchors_ly, balance
		)
		if energy > capacity:
			errors.append(
				(
					"world %s needs %.1f MWh to lock, above the opening's %.1f MWh"
					% [world.id, energy, capacity]
				)
			)
	return errors


## Returns one line per document key (title, body, source) missing from [param table] (as
## read_table() returns it) or empty in a locale, and per text that states a lock energy.
static func check_keys(
	documents: Array[DocumentDef], table: Dictionary[String, PackedStringArray]
) -> Array[String]:
	var errors: Array[String] = []
	for document: DocumentDef in documents:
		for key: StringName in [document.title_key, document.body_key, document.source_key]:
			if key.is_empty():
				continue
			var texts: PackedStringArray = table.get(String(key), PackedStringArray())
			for column: int in LOCALES.size():
				var text: String = texts[column] if column < texts.size() else ""
				if text.strip_edges().is_empty():
					errors.append(
						(
							"document %s: key '%s' has no %s text in %s"
							% [document.id, key, LOCALES[column], TABLE]
						)
					)
				elif text.contains(ENERGY_UNIT):
					errors.append("document %s: key '%s' states a lock energy" % [document.id, key])
	return errors


## Returns one line per document whose pair_id names a document that does not name it back.
static func check_pairs(documents: Array[DocumentDef]) -> Array[String]:
	var errors: Array[String] = []
	var by_id: Dictionary[StringName, DocumentDef] = {}
	for document: DocumentDef in documents:
		by_id[document.id] = document
	for document: DocumentDef in documents:
		if document.pair_id.is_empty() or not by_id.has(document.pair_id):
			continue
		var pair: DocumentDef = by_id[document.pair_id]
		if pair.pair_id != document.id:
			errors.append(
				(
					"document %s is read with %s, which is read with '%s'"
					% [document.id, pair.id, pair.pair_id]
				)
			)
	return errors


## Returns one line per document of [param readings] (far_side_readings()) whose reading world
## is missing, whose answer holds that world's origin glyph, or whose answer is not its world's
## address dialed from that world's Ring.
static func check_far_side(
	documents: Array[DocumentDef],
	worlds: Array[WorldDef],
	anchors_ly: Array[Vector3i],
	readings: Dictionary[StringName, StringName]
) -> Array[String]:
	var errors: Array[String] = []
	var by_id: Dictionary[StringName, WorldDef] = _by_id(worlds)
	for document: DocumentDef in documents:
		if not readings.has(document.id):
			continue
		var where: StringName = readings[document.id]
		if not by_id.has(where) or not by_id.has(document.world_id):
			errors.append("document %s: read on %s, not an authored world" % [document.id, where])
			continue
		var origin: int = by_id[where].origin_glyph
		if document.answer_glyphs.has(origin):
			errors.append(
				(
					"document %s: read on %s, whose origin glyph %d is in the answer"
					% [document.id, where, origin]
				)
			)
		var from_there: Array[int] = _coordinates(by_id[document.world_id], anchors_ly, origin)
		if Array(document.answer_glyphs) != Array(from_there):
			errors.append(
				(
					"document %s: the inscription on %s reads %s, but %s dials %s from there"
					% [
						document.id,
						where,
						Array(document.answer_glyphs),
						document.world_id,
						from_there
					]
				)
			)
	for document_id: StringName in readings:
		if not documents.any(func(each: DocumentDef) -> bool: return each.id == document_id):
			errors.append("far-side reading %s names no document" % document_id)
	return errors


## Returns one line per decoy of [param decoy_list] that is an authored world's address from
## the home origin or equals a document's answer.
static func check_decoys(
	decoy_list: Array[PackedInt32Array],
	worlds: Array[WorldDef],
	anchors_ly: Array[Vector3i],
	documents: Array[DocumentDef]
) -> Array[String]:
	var errors: Array[String] = []
	var home: WorldDef = _home(worlds)
	if home == null or anchors_ly.size() != GateAddress.GLYPH_COUNT:
		return errors
	var real: Dictionary[String, String] = {}
	for world: WorldDef in worlds:
		real[str(_coordinates(world, anchors_ly, home.origin_glyph))] = "world %s" % world.id
	for document: DocumentDef in documents:
		if not document.answer_glyphs.is_empty():
			real[str(Array(document.answer_glyphs))] = "the answer of %s" % document.id
	for decoy: PackedInt32Array in decoy_list:
		var key: String = str(Array(decoy))
		if real.has(key):
			errors.append("decoy %s is %s" % [key, real[key]])
	return errors


## Returns one line per decoy of [param decoy_list] that is the address, from the home origin,
## of a world in [param galaxy] (a generated galaxy, procedural worlds included).
static func check_galaxy_decoys(
	decoy_list: Array[PackedInt32Array], galaxy: GalaxyCatalogue
) -> Array[String]:
	var errors: Array[String] = []
	var home: WorldRecord = galaxy.home()
	if home == null:
		return errors
	for decoy: PackedInt32Array in decoy_list:
		var coordinates: Array[int] = []
		coordinates.assign(Array(decoy))
		var found: WorldRecord = galaxy.find_by_coordinates(coordinates, home.origin_glyph)
		if found != null:
			errors.append("decoy %s is the address of %s" % [coordinates, found.id])
	return errors


## Returns the texts of the table [param file_name] in ContentSource.LOCALIZATION_DIR, by key,
## one entry per locale in LOCALES order. Empty when the file cannot be read.
static func read_table(file_name: String) -> Dictionary[String, PackedStringArray]:
	var table: Dictionary[String, PackedStringArray] = {}
	var file: FileAccess = FileAccess.open(
		ContentSource.LOCALIZATION_DIR + file_name, FileAccess.READ
	)
	if file == null:
		return table
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > 1 and not row[0].is_empty():
			table[row[0]] = row.slice(1)
	return table


static func _coordinates(world: WorldDef, anchors_ly: Array[Vector3i], origin: int) -> Array[int]:
	return AddressRule.address_of(world.position_ly, anchors_ly, origin).coordinates


static func _home(worlds: Array[WorldDef]) -> WorldDef:
	for world: WorldDef in worlds:
		if world.is_home:
			return world
	return null


static func _by_id(worlds: Array[WorldDef]) -> Dictionary[StringName, WorldDef]:
	var by_id: Dictionary[StringName, WorldDef] = {}
	for world: WorldDef in worlds:
		by_id[world.id] = world
	return by_id
