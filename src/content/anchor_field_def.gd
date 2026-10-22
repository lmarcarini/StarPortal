class_name AnchorFieldDef
extends DefBase
## The 36 anchor points of one domain: star clusters at fixed 3D positions, in integer light
## years. Glyph i stands for anchor i, so the array index is the glyph index.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## technical-architecture.md#data-model

## Id of the domain these anchors belong to; &"home" for now.
@export var domain_id: StringName
## Anchor positions in light years; exactly 36, index = glyph index.
@export var positions_ly: Array[Vector3i] = []
