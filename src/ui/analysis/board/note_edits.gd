class_name NoteEdits
extends RefCounted
## Builds the notes the Analysis Board submits: a copy of a clue's current note with one thing
## changed. Pure and static; the board submits the result as an [AnnotateClueCommand].
## Bible: gate-and-address-spec.md#player-tools


## Returns a copy of the note on [param clue_id] placed at [param position].
static func moved(intel: IntelState, clue_id: StringName, position: Vector2i) -> ClueNote:
	var note: ClueNote = _copy(intel, clue_id)
	note.board_position = position
	return note


## Returns a copy of the note on [param clue_id] with a link to [param other_id] added
## ([param linked] true) or removed, or null when the note already says so.
static func relinked(
	intel: IntelState, clue_id: StringName, other_id: StringName, linked: bool
) -> ClueNote:
	var note: ClueNote = _copy(intel, clue_id)
	if note.links.has(other_id) == linked:
		return null
	if linked:
		note.links.append(other_id)
	else:
		note.links.erase(other_id)
	return note


## Returns every tag on any clue's note, once each and sorted.
static func all_tags(intel: IntelState) -> Array[String]:
	var tags: Array[String] = []
	for clue: ClueRecord in intel.clues:
		for tag: String in intel.note_for(clue.id).tags:
			if not tags.has(tag):
				tags.append(tag)
	tags.sort()
	return tags


## Returns the clues linked to [param clue_id], whichever note holds the link: its own links
## first, then the clues that link to it in arrival order.
static func linked_ids(intel: IntelState, clue_id: StringName) -> Array[StringName]:
	var linked: Array[StringName] = intel.note_for(clue_id).links.duplicate()
	for other: ClueRecord in intel.clues:
		if intel.note_for(other.id).links.has(clue_id) and not linked.has(other.id):
			linked.append(other.id)
	return linked


static func _copy(intel: IntelState, clue_id: StringName) -> ClueNote:
	return ClueNote.from_dict(intel.note_for(clue_id).to_dict())
