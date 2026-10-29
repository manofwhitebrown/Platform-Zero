class_name DrawProxy
extends Node2D
## A Node2D that draws via a callable taking (ci: CanvasItem). Lets a parent own the drawing code
## while the child keeps its own transform (e.g. swinging lamp, clock).
var fn: Callable

func _draw() -> void:
	if fn.is_valid():
		fn.call(self)
