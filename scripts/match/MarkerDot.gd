# MarkerDot.gd — Tiny self-drawing dot used for players, ball, and stumps.
extends Node2D
class_name MarkerDot

var dot_color: Color = Color.WHITE
var dot_radius: float = 4.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, dot_radius, dot_color)
	# Thin dark outline for contrast on any background
	draw_arc(Vector2.ZERO, dot_radius, 0, TAU, 16, Color(0, 0, 0, 0.5), 1.0)
