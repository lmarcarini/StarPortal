class_name SetFlagEffect
extends EffectDef
## Sets a flag (bool, int or String).
## Bible: docs/content/m4-core-systems.md section 1

## Flag name.
@export var flag: StringName = &""
## New value: bool, int or String.
@export var value: Variant = true
