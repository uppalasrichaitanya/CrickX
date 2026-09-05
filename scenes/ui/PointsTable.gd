# PointsTable.gd — Sortable group standings table (pos, team, P, W, L, NRR, form).
extends PanelContainer

const COLS := ["#", "TEAM", "P", "W", "L", "NRR", "PTS"]
const WIDTHS := [28, 170, 30, 30, 30, 62, 40]

var _rows: VBoxContainer = null

func _ready() -> void:
	var vb := VBoxContainer.new()
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	vb.add_child(_build_header())
	vb.add_child(_rows)
	add_child(vb)

func _build_header() -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	for i in range(COLS.size()):
		var lbl := Label.new()
		lbl.text = COLS[i]
		lbl.custom_minimum_size.x = WIDTHS[i]
		lbl.add_theme_color_override("font_color", Constants.COLOR_ACCENT_GOLD)
		lbl.add_theme_font_size_override("font_size", 12)
		hb.add_child(lbl)
	return hb

# teams: Array[TeamData] already sorted by the caller.
func set_teams(teams: Array, highlight: String = "") -> void:
	for c in _rows.get_children():
		c.queue_free()
	for i in range(teams.size()):
		var t = teams[i]
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		var is_human = t.team_name == highlight
		var vals := [
			str(i + 1),
			("🏏 " if is_human else "") + t.team_name,
			str(t.matches_played),
			str(t.matches_won),
			str(t.matches_lost),
			"%.2f" % t.nrr,
			str(t.points),
		]
		for j in range(vals.size()):
			var lbl := Label.new()
			lbl.text = vals[j]
			lbl.custom_minimum_size.x = WIDTHS[j]
			lbl.add_theme_font_size_override("font_size", 12)
			if j == 6:
				lbl.add_theme_color_override("font_color", Constants.COLOR_ACCENT_GREEN)
			elif is_human:
				lbl.add_theme_color_override("font_color", Constants.COLOR_ACCENT_GOLD)
			else:
				lbl.add_theme_color_override("font_color", Constants.COLOR_TEXT_PRIMARY)
			hb.add_child(lbl)
		_rows.add_child(hb)
