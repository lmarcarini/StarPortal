class_name AmbientMove
extends RefCounted
## One ambient move: stay, go to spot [member index] in the room, or visit other room
## [member index].
## Bible: docs/content/interface-pass.md section 5 (Ambient life)

const STAY: StringName = &"stay"
const SPOT: StringName = &"spot"
const VISIT: StringName = &"visit"

## STAY, SPOT or VISIT.
var kind: StringName = STAY
## The spot or the other room, by index.
var index: int = 0
