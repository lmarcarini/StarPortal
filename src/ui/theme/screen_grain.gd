class_name ScreenGrain
extends CanvasLayer
## Grain and vignette over the whole screen. Never takes input. Shown while the
## display/screen_grain setting is on and follows changes to it.
## Bible: docs/content/interface-pass.md section 2 (Texture)

## Canvas layer the overlay draws on: above every screen and panel.
const LAYER: int = 90
const _SHADER: String = "res://src/ui/theme/screen_grain.gdshader"
const _SECTION: StringName = &"display"
const _KEY: StringName = &"screen_grain"

## The full-screen rectangle that carries the shader.
var overlay := ColorRect.new()


func _init() -> void:
	layer = LAYER
	overlay.name = &"Grain"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.focus_mode = Control.FOCUS_NONE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = load(_SHADER) as Shader
	overlay.material = material
	add_child(overlay)


func _enter_tree() -> void:
	Settings.setting_changed.connect(_on_setting_changed)
	visible = Settings.get_bool(_SECTION, _KEY)


func _exit_tree() -> void:
	Settings.setting_changed.disconnect(_on_setting_changed)


func _on_setting_changed(section: StringName, key: StringName, value: Variant) -> void:
	if section != _SECTION or key != _KEY:
		return
	visible = value == true
