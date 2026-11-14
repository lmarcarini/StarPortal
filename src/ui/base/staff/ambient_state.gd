class_name AmbientState
extends RefCounted
## What AmbientRules.next_move needs to know about one person: their room's spots, which
## spots are taken, and how many other rooms they could visit.
## Bible: docs/content/interface-pass.md section 5 (Ambient life)

## Spots in the person's room.
var spot_count: int = 0
## Spot indices already taken (including the person's own).
var taken: Array[int] = []
## Number of other rooms that are on, on any level.
var other_rooms: int = 0
