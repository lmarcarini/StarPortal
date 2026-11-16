class_name ActorPose
extends RefCounted
## Where and how a floor figure or prop is drawn this frame.
## Bible: docs/content/interface-rethink.md section 2 (Show it happening)

## Feet (or base) on screen.
var at: Vector2 = Vector2.ZERO
## Depth scale.
var scale: float = 1.0
## Walk phase in seconds.
var phase: float = 0.0
## Opacity.
var alpha: float = 1.0
## Blue rim near the horizon, 0..1.
var rim: float = 0.0
