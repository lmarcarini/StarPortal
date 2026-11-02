class_name ResearchCategoryDef
extends DefBase
## A sub-tab of the Research tab (docs/content/m25-lean-start.md section 3, "Where it lives"):
## its place among the sub-tabs and its name. Every ResearchDef names one category. Gate,
## Defence and Life branches from the bible map onto new categories here, in data only.
## Read only at runtime.
## Bible: docs/content/m25-lean-start.md section 3, game-design.md (tech tree branches)

## Position among the sub-tabs, lowest first; unique among categories.
@export var order: int = 0
## Translation key of the sub-tab's name ("Construction").
@export var name_key: StringName = &""
