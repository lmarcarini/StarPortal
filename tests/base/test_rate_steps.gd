## Tests for RateSteps: whole-tick progress at a fractional speed, and the closed-form ticks
## to finish agreeing with stepping one tick at a time at every phase.
## Bible: docs/content/m26-staff-and-money.md section 3
extends GdUnitTestSuite


func test_ticks_to_matches_stepping() -> void:
	var rates: Array = [
		[3, 12], [4, 12], [12, 12], [16, 12], [24, 12], [44, 40], [49, 40], [54, 40]
	]
	for rate: Array in rates:
		var num: int = rate[0]
		var den: int = rate[1]
		for work: int in [1, 2, 3, 5, 9, 240, 481]:
			for start: int in 13:
				var left: int = work
				var ticks: int = 0
				while left > 0:
					left -= RateSteps.step(start + ticks, num, den)
					ticks += 1
				var message: String = "%d/%d work %d start %d" % [num, den, work, start]
				(
					assert_int(RateSteps.ticks_to(work, start, num, den))
					. override_failure_message(message)
					. is_equal(ticks)
				)


func test_edges() -> void:
	assert_int(RateSteps.ticks_to(0, 5, 3, 12)).is_equal(0)
	assert_int(RateSteps.ticks_to(10, 5, 0, 12)).is_equal(-1)
	assert_int(RateSteps.step(3, 50, 40)).is_equal(2)
	assert_int(RateSteps.step(2, 50, 40)).is_equal(1)
