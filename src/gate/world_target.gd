class_name WorldTarget
extends RefCounted
## One named thing on a world that the MOTH lists and a team can go to: copied from an authored
## WorldTargetDef or derived for a procedural world. Derived data, never saved.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (MOTH scans) and section 3 (Worlds)

## Stable id, unique within its world.
var id: StringName
## Translation key of the name the MOTH lists.
var name_key: StringName
## True for an object a Close look can mark recoverable.
var is_object: bool = false
## Document of the target's marks or inscription a Close look copies into the Archive; &""
## when it has none. Procedural targets have none.
var marks_document_id: StringName = &""
## Id of the ArtefactDef recovering this target also gives; &"" when none (M4).
var artefact_id: StringName = &""


## Returns a target with [param target_id], [param key] and [param object].
static func create(target_id: StringName, key: StringName, object: bool) -> WorldTarget:
	var target := WorldTarget.new()
	target.id = target_id
	target.name_key = key
	target.is_object = object
	return target
