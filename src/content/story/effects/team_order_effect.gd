class_name TeamOrderEffect
extends EffectDef
## Gives the team in the field an order (a TeamContactRules.Order: carry on, come home, stay
## one more day, come through, hold on), as an answer in a team conversation.
## Bible: docs/content/interface-rethink.md section 4 (A team can only talk through an open gate)

## The order (TeamContactRules.Order index).
@export var order: int = 0
