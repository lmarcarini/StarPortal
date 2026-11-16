class_name GateDestination
extends RefCounted
## One place the Gate can dial, as the station shows it: the address, the world it reaches
## when known, the name to stencil and status icons (the picture is drawn from the world
## id). Built by the destination rack (or a test); a value, never saved.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Destinations)

## The address to dial.
var address: GateAddress = null
## The world it reaches; &"" when never reached.
var world_id: StringName = &""
## Name to show (a designation, or the address's glyph names when unknown).
var title: String = ""
## Status icons (HardwareIcons ids), at most four shown.
var icons: Array[StringName] = []


## A destination for [param target] called [param name_text].
static func of(target: GateAddress, name_text: String, world: StringName = &"") -> GateDestination:
	var d: GateDestination = GateDestination.new()
	d.address = target
	d.title = name_text
	d.world_id = world
	return d
