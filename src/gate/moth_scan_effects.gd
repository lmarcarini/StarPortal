class_name MothScanEffects
extends RefCounted
## What a finished MOTH scan gives, applied by ProbeSystem: Look around raises Life, Structures
## and Targets and the threat to FAIR; a Close look takes a photo document of its target, marks
## an object recoverable and copies the target's marks into the Archive; Sky takes a sky photo;
## Ring reads 1 to 2 more addresses from the console's older log. Call only from
## SimSystem.tick().
## Bible: docs/content/m3-beyond-the-ring.md section 2 (MOTH scans)

## Source id of every MOTH report fact.
const SOURCE: StringName = &"moth"


## Gives the result of [param scan] (of [param target_id] for a Close look) on [param world_id].
static func apply(
	state: GameState, world_id: StringName, scan: MothRules.Scan, target_id: StringName
) -> void:
	match scan:
		MothRules.Scan.LOOK_AROUND:
			_look_around(state, world_id)
		MothRules.Scan.CLOSE_LOOK:
			_close_look(state, world_id, target_id)
		MothRules.Scan.SKY:
			state.probes.add_photo(world_id, "sky", &"", state.clock.tick)
		MothRules.Scan.RING:
			_ring(state, world_id)


static func _look_around(state: GameState, world_id: StringName) -> void:
	var facts: Array[WorldReport.Fact] = [
		WorldReport.Fact.LIFE,
		WorldReport.Fact.STRUCTURES,
		WorldReport.Fact.TARGETS,
		WorldReport.Fact.THREAT,
	]
	for fact: WorldReport.Fact in facts:
		WorldProgress.raise_fact(
			state,
			WorldProgress.FactChange.create(world_id, fact, WorldReport.Confidence.FAIR, SOURCE)
		)


static func _close_look(state: GameState, world_id: StringName, target_id: StringName) -> void:
	state.probes.add_photo(world_id, "close_look", target_id, state.clock.tick)
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, world_id)
	var target: WorldTarget = facts.find_target(target_id) if facts != null else null
	if target == null:
		return
	if target.is_object:
		WorldProgress.raise_target(state, world_id, target_id, TargetStates.State.RECOVERABLE)
	var marks: StringName = target.marks_document_id
	if not marks.is_empty() and not state.archive.has_document(marks):
		DeliverDocumentCommand.deliver(state, marks)


static func _ring(state: GameState, world_id: StringName) -> void:
	var galaxy: GalaxyCatalogue = state.galaxy
	var home_origin: int = galaxy.home().origin_glyph
	var keys: Array[String] = []
	for listed_id: StringName in MothRules.older_log_worlds(world_id, galaxy):
		keys.append(galaxy.address_of(listed_id, home_origin).key())
	keys.reverse()
	for key: String in keys:
		if state.address_book.find(key) == null:
			var entry := AddressEntry.create(key, AddressEntry.Source.CONSOLE, world_id)
			state.address_book.entries.push_front(entry)
	state.probes.ring_scanned[world_id] = true
	state.events.post(&"address_book_changed", [])
