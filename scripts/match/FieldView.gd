# FieldView.gd — Top-down TV-style visual representation of the match.
# Draws the oval, pitch and stumps; animates deliveries and outcomes from
# real engine data (zone, wicket_type, fielder, timing). Pure _draw() + tweens,
# no image assets. All animation respects MatchEngine.fast_forward.
extends Node2D
class_name FieldView

# ─── Geometry (canvas ~1000x300 centered in the HUD band) ───
const W := 1000.0
const H := 300.0
const CX := W * 0.5
const CY := H * 0.52
const OVAL_RX := 470.0     # boundary (rope) x radius
const OVAL_RY := 135.0     # boundary (rope) y radius
const CIRCLE_R := 265.0    # 30-yard circle radius (approx, drawn as ellipse)

# Pitch strip
const PITCH_W := 26.0
const PITCH_H := 150.0
const BOWLER_END := Vector2(CX, CY - PITCH_H * 0.5)   # top (bowler)
const BAT_END := Vector2(CX, CY + PITCH_H * 0.5)      # bottom (striker)

# ─── Colors ───
const GRASS := Color("#2E7D32")
const GRASS_DARK := Color("#1B5E20")
const ROPE := Color("#FAFAFA")
const CIRCLE_C := Color(1, 1, 1, 0.25)
const PITCH_C := Color("#C9A86A")
const CREASE_C := Color("#FFFFFF")
const STUMP_C := Color("#E0E0E0")
const BALL_C := Color("#D32F2F")
const BATSMAN_C := Color("#00C853")
const BATSMAN2_C := Color("#81C784")
const BOWLER_C := Color("#FFD600")
const FIELDER_C := Color(1, 1, 1, 0.85)
const KEEPER_C := Color("#4FC3F7")
const WAGON_RUN := Color(0.2, 0.9, 0.4, 0.8)
const WAGON_FOUR := Color(0.2, 0.85, 1.0, 0.8)
const WAGON_SIX := Color(1.0, 0.84, 0.0, 0.9)

# ─── Children (created in _ready) ───
var ball: Node2D = null
var ball_shadow: Node2D = null
var striker_m: Node2D = null
var nonstriker_m: Node2D = null
var bowler_m: Node2D = null
var keeper_m: Node2D = null
var fielders: Array[Node2D] = []
var burst: CPUParticles2D = null
var stumps_top: Node2D = null
var stumps_bot: Node2D = null
var flash: ColorRect = null

var wagon_lines: Array[Dictionary] = []   # {from: Vector2, to: Vector2, runs: int}
var show_wagon: bool = false

func _ready() -> void:
	_build_markers()
	_setup_flash()
	_reset_positions()

func _draw() -> void:
	# Grass base
	draw_rect(Rect2(0, 0, W, H), GRASS_DARK)
	# Mown stripes
	var stripe := 40.0
	for i in range(int(W / stripe)):
		if i % 2 == 0:
			draw_rect(Rect2(i * stripe, 0, stripe, H), GRASS)
	# Boundary rope (oval)
	_draw_oval(ROPE, 2.5)
	# 30-yard circle
	_draw_oval(CIRCLE_C, 1.5, CIRCLE_R, 118.0)
	# Pitch strip
	draw_rect(Rect2(CX - PITCH_W * 0.5, CY - PITCH_H * 0.5, PITCH_W, PITCH_H), PITCH_C)
	# Creases
	_draw_creases()
	# Wagon wheel (under markers, over grass)
	if show_wagon:
		_draw_wagon()

func _draw_oval(color: Color, width: float, rx := OVAL_RX, ry := OVAL_RY) -> void:
	var pts := PackedVector2Array()
	for i in range(65):
		var a := TAU * i / 64.0
		pts.append(Vector2(CX + rx * cos(a), CY + ry * sin(a)))
	draw_polyline(pts, color, width)

func _draw_creases() -> void:
	var lw := 6.0
	# Bowling crease (top, at stumps)
	draw_line(Vector2(CX - PITCH_W * 0.5 - 14, BOWLER_END.y), Vector2(CX + PITCH_W * 0.5 + 14, BOWLER_END.y), CREASE_C, 1.5)
	# Popping crease (top)
	draw_line(Vector2(CX - PITCH_W * 0.5 - 14, BOWLER_END.y + lw * 1.2), Vector2(CX + PITCH_W * 0.5 + 14, BOWLER_END.y + lw * 1.2), CREASE_C, 1.5)
	# Batting crease (bottom, at stumps)
	draw_line(Vector2(CX - PITCH_W * 0.5 - 14, BAT_END.y), Vector2(CX + PITCH_W * 0.5 + 14, BAT_END.y), CREASE_C, 1.5)
	# Popping crease (bottom)
	draw_line(Vector2(CX - PITCH_W * 0.5 - 14, BAT_END.y - lw * 1.2), Vector2(CX + PITCH_W * 0.5 + 14, BAT_END.y - lw * 1.2), CREASE_C, 1.5)

func _draw_wagon() -> void:
	for line in wagon_lines:
		var col := WAGON_RUN
		if line["runs"] == 4: col = WAGON_FOUR
		elif line["runs"] >= 5: col = WAGON_SIX
		draw_line(line["from"], line["to"], col, 1.5)

# ─── Zone → field position mapping ───
# Angles from the batting end (radians, 0 = straight down the ground toward the
# bowler; positive = on-side/left of screen, negative = off-side/right).
const ZONE_ANGLES: Dictionary = {
	Constants.FieldZone.MID_ON: 0.55,
	Constants.FieldZone.LONG_ON: 0.32,
	Constants.FieldZone.MID_WICKET: -0.55,
	Constants.FieldZone.SQUARE_LEG: -1.25,
	Constants.FieldZone.FINE_LEG: -2.05,
	Constants.FieldZone.MID_OFF: -0.55,
	Constants.FieldZone.COVER: -1.05,
	Constants.FieldZone.POINT: -1.70,
}

# A point in the field for the given zone (about 60-70% of the way to the rope).
func zone_point(zone: int) -> Vector2:
	var angle: float = ZONE_ANGLES.get(zone, 0.0)
	var dir := Vector2(sin(angle), -cos(angle))  # up = toward the bowler's end
	return BAT_END + dir * Vector2(330.0, 92.0)

func boundary_point(zone: int) -> Vector2:
	var p := zone_point(zone)
	# Extend the ray from the striker until it hits the rope (binary search on
	# the ellipse equation).
	var dir := (p - BAT_END).normalized()
	var lo := 0.0
	var hi := 1000.0
	for i in range(24):
		var mid := (lo + hi) * 0.5
		var pt := BAT_END + dir * mid
		var nx := (pt.x - CX) / OVAL_RX
		var ny := (pt.y - CY) / OVAL_RY
		if nx * nx + ny * ny < 1.0:
			lo = mid
		else:
			hi = mid
	return BAT_END + dir * lo * 0.97

# ─── Marker construction ───
func _build_markers() -> void:
	striker_m = _make_marker(BATSMAN_C, 7.0)
	nonstriker_m = _make_marker(BATSMAN2_C, 7.0)
	bowler_m = _make_marker(BOWLER_C, 6.0)
	keeper_m = _make_marker(KEEPER_C, 6.0)
	# 11 fielders
	for i in range(11):
		var f := _make_marker(FIELDER_C, 4.5)
		fielders.append(f)
	# Ball + shadow
	ball = Node2D.new()
	add_child(ball)
	var b := _draw_dot(BALL_C, 5.0)
	ball.add_child(b)
	ball_shadow = Node2D.new()
	add_child(ball_shadow)
	ball_shadow.add_child(_draw_dot(Color(0, 0, 0, 0.3), 4.0))
	# Stumps groups
	stumps_top = _make_stumps(BOWLER_END)
	stumps_bot = _make_stumps(BAT_END)
	# Burst particles
	burst = CPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 24
	burst.lifetime = 0.5
	burst.spread = 180.0
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 160.0
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.6
	burst.color = Color(1, 0.84, 0.0)
	add_child(burst)

func _make_marker(color: Color, radius: float) -> Node2D:
	var n := Node2D.new()
	n.add_child(_draw_dot(color, radius))
	add_child(n)
	return n

func _draw_dot(color: Color, radius: float) -> Node2D:
	var d := MarkerDot.new()
	d.dot_color = color
	d.dot_radius = radius
	return d

func _make_stumps(at: Vector2) -> Node2D:
	var g := Node2D.new()
	g.position = at
	for i in range(3):
		var s := MarkerDot.new()
		s.dot_color = STUMP_C
		s.dot_radius = 2.0
		s.position = Vector2((i - 1) * 4.0, 0)
		g.add_child(s)
	add_child(g)
	return g

func _setup_flash() -> void:
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.0)
	flash.size = Vector2(W, H)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

func _reset_positions() -> void:
	striker_m.position = BAT_END + Vector2(0, 6)
	nonstriker_m.position = BOWLER_END + Vector2(14, 6)
	bowler_m.position = BOWLER_END + Vector2(-20, -14)
	keeper_m.position = BAT_END + Vector2(0, 26)
	ball.position = bowler_m.position
	ball_shadow.position = ball.position
	_place_fielders()

# Standard-ish field for the 9 outfield fielders mapped onto zones
# (keeper and bowler are separate markers).
func _place_fielders() -> void:
	var zones := [Constants.FieldZone.MID_ON, Constants.FieldZone.LONG_ON, Constants.FieldZone.MID_WICKET,
		Constants.FieldZone.SQUARE_LEG, Constants.FieldZone.FINE_LEG, Constants.FieldZone.MID_OFF,
		Constants.FieldZone.COVER, Constants.FieldZone.POINT, Constants.FieldZone.LONG_ON]
	var t := 0.62
	for i in range(fielders.size()):
		if i < zones.size():
			var base := zone_point(zones[i])
			var depth := 0.55 if i < 6 else 0.9  # mix of ring and deep fielders
			fielders[i].position = BAT_END + (base - BAT_END) * depth
		else:
			fielders[i].position = zone_point(Constants.FieldZone.COVER) * 0.5

func _nearest_fielder_to(p: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := 1e9
	for f in fielders:
		var d := f.position.distance_to(p)
		if d < best_d:
			best_d = d
			best = f
	return best

func _speed_scale() -> float:
	return 0.04 if MatchEngine.fast_forward else 1.0

# ─── Public API (called by MatchHUD) ───
func play_delivery(delivery_type: int) -> void:
	_reset_positions()
	# Ball leaves the bowler's hand toward the striker's end
	var target := BAT_END + Vector2(randf_range(-8, 8), randf_range(-6, 2))
	var dur := 0.45
	# Per-delivery flavor: bouncers kick up, yorkers stay full, spin drifts
	match delivery_type:
		Constants.DeliveryType.BOUNCER: dur = 0.38
		Constants.DeliveryType.YORKER: dur = 0.5
		Constants.DeliveryType.OFF_SPIN, Constants.DeliveryType.LEG_SPIN:
			dur = 0.62
			target = BAT_END + Vector2(randf_range(-14, 14), randf_range(-4, 2))
		Constants.DeliveryType.SLOWER: dur = 0.72
	var tw := create_tween()
	tw.tween_property(ball, "position", target, dur * _speed_scale())
	tw.parallel().tween_property(ball_shadow, "position", target, dur * _speed_scale())

func play_outcome(outcome: Dictionary) -> void:
	var runs: int = outcome.get("runs", 0)
	var zone: int = outcome.get("zone", Constants.FieldZone.MID_OFF)
	var wtype: String = outcome.get("wicket_type", "")
	var is_wide: bool = outcome.get("is_wide", false)
	var key: String = outcome.get("commentary_key", "")
	
	# Record for the wagon wheel
	if runs > 0 or outcome.get("is_wicket", false):
		var bp := boundary_point(zone)
		wagon_lines.append({"from": BAT_END, "to": bp, "runs": runs})
		if wagon_lines.size() > 160:
			wagon_lines.pop_front()
		queue_redraw()
	
	if is_wide:
		_animate_ball_to(keeper_m.position, 0.4)
		return
	
	if outcome.get("is_wicket", false):
		_animate_wicket(outcome, wtype, zone)
		return
	
	if key == "DROPPED_CATCH":
		_animate_drop(zone)
		return
	
	match runs:
		6: _animate_six(zone)
		4: _animate_four(zone)
		3, 2, 1: _animate_runs(zone, runs)
		0: _animate_dot()
		_: _animate_dot()

# ─── Outcome animations ───
func _animate_ball_to(target: Vector2, dur: float, arc: bool = false) -> void:
	var d := dur * _speed_scale()
	if arc:
		var tw := create_tween()
		var mid := (ball.position + target) * 0.5 + Vector2(0, -60)
		tw.tween_property(ball, "position", mid, d * 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_property(ball, "position", target, d * 0.5).set_ease(Tween.EASE_IN)
		var tws := create_tween()
		tws.tween_property(ball_shadow, "position", target, d)
	else:
		var tw := create_tween()
		tw.tween_property(ball, "position", target, d)
		var tws := create_tween()
		tws.tween_property(ball_shadow, "position", target, d)

func _animate_four(zone: int) -> void:
	var bp := boundary_point(zone)
	var chaser := _nearest_fielder_to(bp)
	var d := 0.55 * _speed_scale()
	# Chaser moves toward the ball
	if chaser:
		var twc := create_tween()
		twc.tween_property(chaser, "position", chaser.position + (bp - chaser.position) * 0.6, d)
	_animate_ball_to(bp, d)
	_fire_burst(bp, Color(0.2, 0.9, 0.4))
	_screen_flash(0.12)

func _animate_six(zone: int) -> void:
	var bp := boundary_point(zone)
	var d := 0.7 * _speed_scale()
	# Ball flies OVER — grow then shrink as it lands beyond the rope
	var tw := create_tween()
	var mid := (ball.position + bp) * 0.5 + Vector2(0, -70)
	tw.tween_property(ball, "position", mid, d * 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ball, "scale", Vector2(1.7, 1.7), d * 0.5)
	tw.tween_property(ball, "position", bp + Vector2(0, -12), d * 0.5).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ball, "scale", Vector2(1.0, 1.0), d * 0.5)
	var tws := create_tween()
	tws.tween_property(ball_shadow, "position", bp, d)
	_fire_burst(bp, Color(1, 0.84, 0.0), 36)
	_screen_flash(0.18)

func _animate_runs(zone: int, runs: int) -> void:
	var target := zone_point(zone)
	var fielder := _nearest_fielder_to(target)
	var d := 0.4 * _speed_scale()
	if fielder:
		_animate_ball_to(fielder.position, d)
		# Fielder holds briefly, then returns toward the bowler's end
		var twf := create_tween()
		twf.tween_interval(d)
		twf.tween_property(ball, "position", bowler_m.position, d * 0.6)
	else:
		_animate_ball_to(target, d)
	# Batsmen cross ends per run (visual shorthand: swap once per 2 runs)
	for i in range(runs):
		var cross := create_tween()
		cross.tween_interval(0.05 + 0.12 * i * _speed_scale())
		cross.tween_callback(func():
			var tmp := striker_m.position
			striker_m.position = nonstriker_m.position
			nonstriker_m.position = tmp)

func _animate_dot() -> void:
	# Soft push back toward the bowler / nearest fielder
	var f := _nearest_fielder_to(BAT_END + Vector2(0, -30))
	var d := 0.35 * _speed_scale()
	_animate_ball_to(f.position if f else BOWLER_END, d)

func _animate_drop(zone: int) -> void:
	var target := zone_point(zone)
	var fielder := _nearest_fielder_to(target)
	var d := 0.5 * _speed_scale()
	if fielder:
		_animate_ball_to(fielder.position, d, true)
		# Bounce off the fielder and dribble away
		var tw := create_tween()
		tw.tween_interval(d)
		tw.tween_property(ball, "position", fielder.position + Vector2(0, 14), 0.2 * _speed_scale())
	_fire_burst(fielder.position if fielder else target, Color(1, 0.3, 0.3))

func _animate_wicket(outcome: Dictionary, wtype: String, zone: int) -> void:
	match wtype:
		"BOWLED":
			_animate_ball_to(BAT_END, 0.3)
			_shatter_stumps(stumps_bot)
			_screen_flash(0.15, Color(1, 0.2, 0.2))
		"LBW":
			_animate_ball_to(BAT_END, 0.28)
			_fire_burst(BAT_END, Color(1, 0.25, 0.25), 14)
			_screen_flash(0.15, Color(1, 0.2, 0.2))
		"CAUGHT":
			var target := zone_point(zone)
			var fielder := _nearest_fielder_to(target)
			_animate_ball_to(fielder.position if fielder else target, 0.55, true)
			if fielder:
				_fire_burst(fielder.position, Color(0.3, 0.9, 1.0), 16)
		"CAUGHT_BEHIND":
			_animate_ball_to(keeper_m.position, 0.35, true)
			_fire_burst(keeper_m.position, Color(0.3, 0.9, 1.0), 16)
		"STUMPED":
			_animate_ball_to(keeper_m.position, 0.3)
			var tw := create_tween()
			tw.tween_interval(0.25 * _speed_scale())
			tw.tween_callback(func():
				ball.position = BAT_END
				_shatter_stumps(stumps_bot))
		"RUN_OUT":
			_animate_ball_to(zone_point(zone), 0.4)
			var tw := create_tween()
			tw.tween_interval(0.4 * _speed_scale())
			tw.tween_callback(func():
				ball.position = BAT_END
				_shatter_stumps(stumps_bot))
		_:
			_animate_ball_to(BAT_END, 0.3)
	# Dismissed batsman walks off
	var fade := create_tween()
	fade.tween_interval(0.6 * _speed_scale())
	fade.tween_property(striker_m, "modulate:a", 0.0, 0.4 * _speed_scale())
	fade.tween_callback(func(): striker_m.modulate.a = 1.0)

func _shatter_stumps(group: Node2D) -> void:
	# Scatter the three stump dots
	for child in group.get_children():
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(child, "position", Vector2(randf_range(-16, 16), randf_range(-12, 8)), 0.25 * _speed_scale())
		tw.tween_property(child, "modulate:a", 0.3, 0.25 * _speed_scale())
	_fire_burst(group.position, Color(1, 0.85, 0.3), 18)
	# Restore for next ball
	var restore := create_tween()
	restore.tween_interval(0.9 * _speed_scale())
	restore.tween_callback(func():
		for i in range(3):
			var child = group.get_child(i)
			child.position = Vector2((i - 1) * 4.0, 0)
			child.modulate.a = 1.0)

func _fire_burst(at: Vector2, color: Color, amount: int = 24) -> void:
	burst.color = color
	burst.amount = amount
	burst.position = at
	burst.restart()

func _screen_flash(strength: float, color: Color = Color(1, 1, 1, 1)) -> void:
	flash.color = Color(color.r, color.g, color.b, strength)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.35 * _speed_scale())

# Milestone fanfare — bigger, golden, centered on the striker
func play_fireworks() -> void:
	_fire_burst(striker_m.position, Color(1, 0.84, 0.0), 48)
	var second := CPUParticles2D.new()
	second.one_shot = true
	second.explosiveness = 1.0
	second.amount = 32
	second.lifetime = 0.8
	second.spread = 180.0
	second.initial_velocity_min = 40.0
	second.initial_velocity_max = 220.0
	second.color = Color(1, 0.5, 0.1)
	second.position = striker_m.position
	add_child(second)
	second.restart()
	var tw := create_tween()
	tw.tween_interval(1.2 * _speed_scale())
	tw.tween_callback(second.queue_free)
	_screen_flash(0.22, Color(1, 0.84, 0.0))

func toggle_wagon(enabled: bool) -> void:
	show_wagon = enabled
	queue_redraw()

func clear_wagon() -> void:
	wagon_lines.clear()
	queue_redraw()
