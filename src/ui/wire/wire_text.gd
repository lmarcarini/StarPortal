class_name WireText
extends RefCounted
## Words for the wire: a refused key's hover reason. Pure.
## Bible: docs/content/interface-rethink.md section 6


## The hover reason for refusal [param code]: its WIRE_REFUSED_<CODE> text when there is
## one, else the generic one with the code.
static func refusal(code: StringName) -> String:
	var key: String = "WIRE_REFUSED_" + String(code).to_upper()
	var text: String = TranslationServer.translate(key)
	if text != key:
		return text
	return TranslationServer.translate(&"WIRE_REFUSED").format({"code": String(code)})
