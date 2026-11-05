class_name RateSteps
extends RefCounted
## Whole-tick progress at a fractional rate, with nothing fractional stored (docs/content/
## m26-staff-and-money.md section 3). A job running at [code]num / den[/code] of normal speed
## makes [code]floor((t + 1) × num / den) − floor(t × num / den)[/code] ticks of progress on clock
## tick t, so the progress over any run of ticks depends only on the clock ticks it covers. It is
## exact and deterministic across saves, since only the clock tick is saved. At 5 / 4 it is the
## M2.5 Workshop scheme (two ticks of progress on ticks 3, 7, 11 ...).
## Bible: docs/content/m26-staff-and-money.md section 3, docs/content/m25-lean-start.md section 4


## Ticks of progress made on clock tick [param tick] at [param num] / [param den] speed
## ([param tick] and [param num] ≥ 0, [param den] ≥ 1).
static func step(tick: int, num: int, den: int) -> int:
	return (tick + 1) * num / den - tick * num / den


## Clock ticks needed for [param work] ticks of progress, the first on clock tick
## [param first_tick], at [param num] / [param den] speed. 0 when no work is left; -1 when the
## speed is 0 (it never finishes).
static func ticks_to(work: int, first_tick: int, num: int, den: int) -> int:
	if work <= 0:
		return 0
	if num <= 0:
		return -1
	var target: int = work + first_tick * num / den
	return (target * den + num - 1) / num - first_tick
