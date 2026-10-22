class_name ClueSetParams
extends RefCounted
## Tuning of one generated dossier: how many candidate addresses it may leave, how many clues
## it may hold, how many kinds it must mix, and how often the generator retries.
## Bible: gate-and-address-spec.md#puzzle-tuning-rules

## Fewest candidate addresses the dossier may leave (a true dossier never leaves 0).
var min_candidates: int = 1
## Most candidate addresses the dossier may leave.
var max_candidates: int = 20
## Most clues in the dossier.
var max_clues: int = 7
## Fewest different clue kinds in the dossier.
var min_kinds: int = 3
## Attempts before the best set found so far is returned.
var max_attempts: int = 50
