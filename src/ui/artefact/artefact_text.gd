class_name ArtefactText
extends RefCounted
## Words about artefacts in the current locale: names and the hazard line.
## Bible: docs/content/m4-core-systems.md section 5


## "The Kindred Loom's hazard struck." for [param artefact_id].
static func hazard_line(artefact_id: StringName) -> String:
	return String(TranslationServer.translate(&"LOG_LINE_ARTEFACT_HAZARD")).format(
		{"name": StoryText.name_of(artefact_id)}
	)
