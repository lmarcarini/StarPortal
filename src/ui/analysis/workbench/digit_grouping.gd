class_name DigitGrouping
extends RefCounted
## Writes whole numbers with the locale's digit-group separator, such as "33,891,580,800" in
## English and "33.891.580.800" in Brazilian Portuguese. The caller passes the separator, read
## from the translation table, so this stays a pure function.
## Bible: gate-and-address-spec.md#player-tools, overview.md#locked-decisions (Languages)

## Digits per group.
const GROUP_SIZE: int = 3


## Returns [param value] in base ten with [param separator] between each group of three
## digits, counted from the right; a negative number keeps its minus sign in front.
static func group(value: int, separator: String) -> String:
	var digits: String = str(value).trim_prefix("-")
	var grouped: String = ""
	var count: int = 0
	for index: int in range(digits.length() - 1, -1, -1):
		if count > 0 and count % GROUP_SIZE == 0:
			grouped = separator + grouped
		grouped = digits[index] + grouped
		count += 1
	return ("-" + grouped) if value < 0 else grouped
