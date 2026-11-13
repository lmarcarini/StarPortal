class_name ConversationChoiceDef
extends Resource
## One answer at a Choice node: its text, the conditions to offer it, the effects it applies
## and the node it leads to. A choice whose conditions fail is hidden, or greyed with its
## reason when show_locked. Read only at runtime.
## Bible: docs/content/m4-core-systems.md section 3

## Translation key of the answer.
@export var text_key: StringName = &""
## Conditions that must all hold to pick it.
@export var conditions: Array[ConditionDef] = []
## Effects applied when picked.
@export var effects: Array[EffectDef] = []
## True: greyed with its reason when locked; false: hidden.
@export var show_locked: bool = false
## Id of the next node.
@export var next: StringName = &""
