## Every en and pt_BR value in localization/*.csv can be drawn by the default theme font:
## no character the font lacks (such as "→" or "▲"), until a project font comes with the art
## pass.
## Bible: technical-architecture.md#input-accessibility-and-localisation
extends GdUnitTestSuite

const LOCALIZATION_DIR: String = "res://localization"
## Columns checked, by header name.
const LOCALES: Array[String] = ["en", "pt_BR"]


func test_every_string_uses_only_characters_the_default_font_draws() -> void:
	var font: Font = ThemeDB.fallback_font
	var missing: Array[String] = []
	var files: PackedStringArray = DirAccess.get_files_at(LOCALIZATION_DIR)
	var checked: int = 0
	for file_name: String in files:
		if file_name.get_extension() != "csv":
			continue
		checked += 1
		missing.append_array(_missing_in(LOCALIZATION_DIR.path_join(file_name), font))
	assert_int(checked).is_greater(0)
	assert_array(missing).is_empty()


## "file key locale: 'c' (U+XXXX)" for each character of [param path] the font lacks.
func _missing_in(path: String, font: Font) -> Array[String]:
	var found: Array[String] = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < header.size() or row[0].is_empty():
			continue
		for locale: String in LOCALES:
			var column: int = header.find(locale)
			if column < 0:
				continue
			for index: int in row[column].length():
				var code: int = row[column].unicode_at(index)
				if code < 0x20 or font.has_char(code):
					continue
				found.append(
					"%s %s %s: '%s' (U+%04X)" % [path.get_file(), row[0], locale, char(code), code]
				)
	return found
