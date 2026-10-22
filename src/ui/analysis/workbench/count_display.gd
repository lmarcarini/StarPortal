class_name CountDisplay
extends Label
## The Address Workbench counter: how many addresses still fit, with the locale's digit
## grouping ("33,891,580,800 possible"), or the contradiction message at zero.
## Bible: gate-and-address-spec.md#player-tools,
## gate-and-address-spec.md#clue-types-and-reliability (zero candidates means something is
## false)

var _count: int = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _count >= 0:
		show_count(_count)


## Shows [param count].
func show_count(count: int) -> void:
	_count = count
	if count == 0:
		text = tr("WORKBENCH_COUNT_NONE")
		return
	var key: String = "WORKBENCH_COUNT_ONE" if count == 1 else "WORKBENCH_COUNT_MANY"
	text = tr(key).format({"count": WorkbenchText.number(count, tr)})


## Returns the count shown, or -1 before the first.
func get_count() -> int:
	return _count
