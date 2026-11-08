class_name WorldTargetDef
extends Resource
## One named thing on an authored world that the MOTH lists and a team can go to, such as the
## iron object at STILLWATER's causeway end. Embedded in its WorldDef, not a file of its own.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (MOTH scans) and section 3 (Worlds)

## Stable id, unique within its world, e.g. &"iron_object".
@export var id: StringName
## Translation key of the name the MOTH lists, e.g. &"TARGET_STILLWATER_IRON_OBJECT".
@export var name_key: StringName
## True for an object a Close look can mark recoverable; false for a feature of the land.
@export var is_object: bool = false
