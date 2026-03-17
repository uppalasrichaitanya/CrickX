# PlayerData.gd — Resource representing a single cricket player.
# Holds static attributes and dynamic in-match statistics.
extends Resource
class_name PlayerData

# ─── Static Attributes ───
@export var player_name: String = ""
@export_range(1, 100) var batting_skill: int = 50
@export_range(1, 100) var bowling_skill: int = 20
@export var batting_style: String = "BALANCED"  # AGGRESSIVE / BALANCED / DEFENSIVE
@export var bowling_type: String = "NONE"        # FAST / MEDIUM / SPIN / NONE
@export_range(1, 100) var fielding_skill: int = 60

# ─── Dynamic In-Match Stats (reset per match) ───
@export var stamina: float = 100.0
@export var match_runs: int = 0
@export var match_balls: int = 0
@export var match_fours: int = 0
@export var match_sixes: int = 0
@export var match_wickets: int = 0
@export var match_overs_bowled: float = 0.0
@export var match_runs_conceded: int = 0
@export var match_maidens: int = 0
@export var match_catches: int = 0
@export var dismissal_text: String = ""  # e.g., "c Maxwell b Cummins"
@export var is_out: bool = false
@export var is_on_strike: bool = false

# ─── Deep Logic Dynamic Stats ───
var form: float = 0.65           # 0.0 – 1.0 (randomized per match start)
var fatigue: float = 0.0         # 0.0 – 1.0 (increases during match)
var morale: float = 0.5          # 0.0 – 1.0
var confidence: int = 50         # 0 – 100
var rhythm: float = 0.5          # 0.0 – 1.0 (bowler)
var current_spell_overs: float = 0.0  # tracks consecutive bowling

# ─── AI Memory (per innings) ───
var shot_history: Dictionary = {}     # { ShotType: count }
var weakness_map: Dictionary = {}     # { DeliveryType: success_rate }

func reset_match_stats() -> void:
	match_runs = 0
	match_balls = 0
	match_fours = 0
	match_sixes = 0
	match_wickets = 0
	match_overs_bowled = 0.0
	match_runs_conceded = 0
	match_maidens = 0
	match_catches = 0
	dismissal_text = ""
	is_out = false
	is_on_strike = false
	fatigue = 0.0
	confidence = 50
	morale = 0.5
	rhythm = 0.5
	current_spell_overs = 0.0
	shot_history = {}
	weakness_map = {}
	# Randomize form per match
	form = clampf(randf_range(0.4, 0.9), 0.0, 1.0)

func get_strike_rate() -> float:
	if match_balls == 0:
		return 0.0
	return (float(match_runs) / float(match_balls)) * 100.0

func get_economy() -> float:
	if match_overs_bowled <= 0.0:
		return 0.0
	return float(match_runs_conceded) / match_overs_bowled

func get_effective_batting_skill() -> float:
	var form_mod = 0.6 + form * 0.8
	var morale_mod = 0.7 + morale * 0.6
	var confidence_mod = (float(confidence) - 50.0) / 200.0
	return float(batting_skill) * form_mod * morale_mod + confidence_mod * 10.0

func get_effective_bowling_skill() -> float:
	var form_mod = 0.6 + form * 0.8
	var morale_mod = 0.7 + morale * 0.6
	var rhythm_mod = 0.7 + rhythm * 0.6
	return float(bowling_skill) * form_mod * morale_mod * rhythm_mod
