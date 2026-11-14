class_name StateNames
extends RefCounted
## Saving enums as lowercase names, shared by the M4c state classes.
## Bible: technical-architecture.md#data-model


## The saved name of [param value] in [param names].
static func write(names: Array[String], value: int) -> String:
	return names[clampi(value, 0, names.size() - 1)]


## The enum value of saved [param value] in [param names], or 0 when unknown.
static func read(names: Array[String], value: Variant) -> int:
	return maxi(0, names.find(str(value))) if value is String else 0


## True when [param value] is one of [param names].
static func is_name(names: Array[String], value: Variant) -> bool:
	return value is String and names.has(str(value))
