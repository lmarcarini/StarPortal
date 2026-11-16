class_name HardwareIconsExtra
extends RefCounted
## More code-drawn icons for the hardware kit (M4.10: the frame and the wire), drawn with
## HardwareIcons' pen; HardwareIcons.draw() calls them.
## Bible: docs/content/interface-rethink.md sections 3, 6 and 7

## Icon ids drawn here.
const IDS: Array[StringName] = [
	&"pause",
	&"play",
	&"fast",
	&"funds",
	&"power",
	&"confidence",
	&"log",
	&"hire",
	&"pass",
	&"accept",
	&"decline",
	&"study",
	&"switch_on",
	&"assign",
	&"rescue",
	&"answer",
	&"ignore",
	&"go_to",
	&"report",
	&"tree",
	&"dismiss",
]


## True when icon [param id] is drawn here.
static func has(id: StringName) -> bool:
	return IDS.has(id)


static func _icon_pause(p: HardwareIcons._Pen) -> void:
	p.box(0.25, 0.2, 0.42, 0.8)
	p.box(0.58, 0.2, 0.75, 0.8)


static func _icon_play(p: HardwareIcons._Pen) -> void:
	p.poly([0.3, 0.2, 0.78, 0.5, 0.3, 0.8, 0.3, 0.2])


static func _icon_fast(p: HardwareIcons._Pen) -> void:
	p.poly([0.15, 0.25, 0.5, 0.5, 0.15, 0.75, 0.15, 0.25])
	p.poly([0.5, 0.25, 0.85, 0.5, 0.5, 0.75, 0.5, 0.25])


static func _icon_funds(p: HardwareIcons._Pen) -> void:
	p.ring(0.5, 0.5, 0.38)
	p.line(0.5, 0.18, 0.5, 0.82)
	p.poly([0.62, 0.35, 0.4, 0.35, 0.4, 0.5, 0.6, 0.5, 0.6, 0.65, 0.38, 0.65])


static func _icon_power(p: HardwareIcons._Pen) -> void:
	p.ring(0.5, 0.55, 0.32)
	p.line(0.5, 0.12, 0.5, 0.5)


static func _icon_confidence(p: HardwareIcons._Pen) -> void:
	p.line(0.15, 0.8, 0.85, 0.8)
	p.box(0.2, 0.55, 0.32, 0.8)
	p.box(0.44, 0.4, 0.56, 0.8)
	p.box(0.68, 0.2, 0.8, 0.8)


static func _icon_log(p: HardwareIcons._Pen) -> void:
	p.box(0.2, 0.15, 0.8, 0.85)
	p.line(0.3, 0.32, 0.7, 0.32)
	p.line(0.3, 0.48, 0.7, 0.48)
	p.line(0.3, 0.64, 0.7, 0.64)


static func _icon_hire(p: HardwareIcons._Pen) -> void:
	_person(p)
	p.line(0.78, 0.4, 0.78, 0.64)
	p.line(0.66, 0.52, 0.9, 0.52)


static func _icon_pass(p: HardwareIcons._Pen) -> void:
	_person(p)
	p.line(0.66, 0.52, 0.9, 0.52)


static func _icon_accept(p: HardwareIcons._Pen) -> void:
	p.poly([0.18, 0.52, 0.42, 0.76, 0.84, 0.26])


static func _icon_decline(p: HardwareIcons._Pen) -> void:
	p.line(0.22, 0.22, 0.78, 0.78)
	p.line(0.78, 0.22, 0.22, 0.78)


static func _icon_study(p: HardwareIcons._Pen) -> void:
	p.ring(0.42, 0.42, 0.22)
	p.line(0.58, 0.58, 0.85, 0.85)


static func _icon_switch_on(p: HardwareIcons._Pen) -> void:
	p.box(0.3, 0.15, 0.7, 0.85)
	p.box(0.38, 0.22, 0.62, 0.5)


static func _icon_assign(p: HardwareIcons._Pen) -> void:
	p.ring(0.32, 0.3, 0.12)
	p.poly([0.12, 0.75, 0.16, 0.52, 0.48, 0.52, 0.52, 0.75])
	p.line(0.58, 0.5, 0.88, 0.5)
	p.poly([0.76, 0.38, 0.88, 0.5, 0.76, 0.62])


static func _icon_rescue(p: HardwareIcons._Pen) -> void:
	p.ring(0.5, 0.5, 0.36)
	p.ring(0.5, 0.5, 0.18)
	p.line(0.5, 0.14, 0.5, 0.32)
	p.line(0.5, 0.68, 0.5, 0.86)
	p.line(0.14, 0.5, 0.32, 0.5)
	p.line(0.68, 0.5, 0.86, 0.5)


static func _icon_answer(p: HardwareIcons._Pen) -> void:
	_handset(p)


static func _icon_ignore(p: HardwareIcons._Pen) -> void:
	_handset(p)
	p.line(0.15, 0.85, 0.85, 0.15)


static func _icon_go_to(p: HardwareIcons._Pen) -> void:
	p.line(0.15, 0.5, 0.8, 0.5)
	p.poly([0.6, 0.3, 0.85, 0.5, 0.6, 0.7])


static func _icon_report(p: HardwareIcons._Pen) -> void:
	p.box(0.22, 0.12, 0.78, 0.88)
	p.line(0.32, 0.3, 0.68, 0.3)
	p.line(0.32, 0.45, 0.68, 0.45)
	p.line(0.32, 0.6, 0.55, 0.6)


static func _icon_tree(p: HardwareIcons._Pen) -> void:
	p.box(0.4, 0.12, 0.6, 0.3)
	p.box(0.12, 0.7, 0.32, 0.88)
	p.box(0.68, 0.7, 0.88, 0.88)
	p.line(0.5, 0.3, 0.5, 0.5)
	p.poly([0.22, 0.7, 0.22, 0.5, 0.78, 0.5, 0.78, 0.7])


static func _icon_dismiss(p: HardwareIcons._Pen) -> void:
	p.line(0.3, 0.3, 0.7, 0.7)
	p.line(0.7, 0.3, 0.3, 0.7)


static func _person(p: HardwareIcons._Pen) -> void:
	p.ring(0.4, 0.32, 0.14)
	p.poly([0.15, 0.82, 0.2, 0.58, 0.6, 0.58, 0.65, 0.82])


static func _handset(p: HardwareIcons._Pen) -> void:
	p.poly([0.2, 0.3, 0.35, 0.2, 0.45, 0.38, 0.38, 0.46, 0.54, 0.62, 0.62, 0.55, 0.8, 0.65])
	p.poly([0.8, 0.65, 0.7, 0.8, 0.2, 0.3])
