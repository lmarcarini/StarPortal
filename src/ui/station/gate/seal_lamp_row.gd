class_name SealLampRow
extends HBoxContainer
## The console's eight seal lamps, a row of [IndicatorLamp]s lit as the Ring's seals lock
## (the eighth is CAIRN's mark), blue while a wormhole is open.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Console)

const _LIT: Color = Color("#ffb347")

var _lamps: Array[IndicatorLamp] = []


func _ready() -> void:
	add_theme_constant_override(&"separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER
	for i: int in RingLook.SEALS:
		var lamp: IndicatorLamp = IndicatorLamp.new()
		lamp.custom_minimum_size = Vector2(22, 22) * HwMetrics.scale_of(self)
		_lamps.append(lamp)
		add_child(lamp)


## Lights the lamps for [param look].
func show_look(look: RingLook) -> void:
	for i: int in _lamps.size():
		var lit: bool = i < look.seals
		var colour: Color = UiPalette.RING if look.phase == RingLook.Phase.OPEN else _LIT
		_lamps[i].set_lit(lit, colour)


## Lamps lit now.
func lit_count() -> int:
	var count: int = 0
	for lamp: IndicatorLamp in _lamps:
		if lamp.is_lit():
			count += 1
	return count
