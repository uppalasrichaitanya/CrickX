# Constants.gd — Global constants and enumerations for Cricket Master.
# Autoloaded as "Constants". Single source of truth for all magic numbers.
extends Node

# ─── Match Format ───
const MAX_OVERS_T20: int = 20
const MAX_OVERS_ODI: int = 50
const MAX_WICKETS: int = 10
const BALLS_PER_OVER: int = 6
const MAX_BOWLER_OVERS_T20: int = 4
const MAX_BOWLER_OVERS_ODI: int = 10
const SQUAD_SIZE: int = 15
const PLAYING_XI_SIZE: int = 11

# ─── Networking ───
const DEFAULT_PORT: int = 54000
const RECONNECT_TIMEOUT: float = 60.0
const INPUT_TIMEOUT: float = 5.0

# ─── UI Timing ───
const SHOT_SELECTION_TIMEOUT: float = 4.0
# Human reaction window by difficulty (Settings slider). The old flat 4s silent
# fallback is what made the game look autoplayed — humans get room to breathe.
const HUMAN_INPUT_TIMEOUT: float = 6.0

static func human_input_timeout(diff: int) -> float:
	match diff:
		Difficulty.EASY:
			return 8.0
		Difficulty.HARD:
			return 4.0
		_:
			return 6.0

static func human_timeout_label(diff: int) -> String:
	return "%.0fs" % human_input_timeout(diff)
const SCENE_FADE_DURATION: float = 0.3
const TYPEWRITER_SPEED: float = 0.03  # seconds per character
const TURN_TRANSITION_DURATION: float = 3.0
const MILESTONE_FREEZE_DURATION: float = 1.0

# ─── Simulation Thresholds ───
const HIGH_FATIGUE_THRESHOLD: float = 0.7
const CRITICAL_FATIGUE_THRESHOLD: float = 0.85
const HOT_FORM_THRESHOLD: float = 0.75
const COLD_FORM_THRESHOLD: float = 0.4
const HIGH_PRESSURE_THRESHOLD: float = 0.8
const MEDIUM_PRESSURE_THRESHOLD: float = 0.6
const IN_THE_ZONE_CONFIDENCE: int = 85
const HIGH_RHYTHM_THRESHOLD: float = 0.8
const LOW_RHYTHM_THRESHOLD: float = 0.3
const HIGH_MORALE_THRESHOLD: float = 0.75
const LOW_MORALE_THRESHOLD: float = 0.4

# ─── Pitch Wear ───
const PITCH_WEAR_PER_BALL: float = 0.005
const PITCH_ROUGH_THRESHOLD: float = 0.4
const PITCH_DANGEROUS_THRESHOLD: float = 0.7

# ─── DRS ───
const DRS_REVIEWS_T20: int = 1
const DRS_REVIEWS_ODI: int = 2

# ─── Fielding & Dismissal ───
const CATCH_BASE_CHANCE: float = 0.78      # skilled fielder holds on
const CATCH_SKILL_WEIGHT: float = 0.004    # +/- per fielding skill point from 60
const CARRY_BASE_CHANCE: float = 0.85      # chance a take is clean, not a bump ball
const DROPPED_CATCH_SAVE: float = 0.25    # dropped chance on a misfield still costs runs
const NO_BALL_BASE: float = 0.015         # base no-ball chance (skill 80, rhythm 0.5)
const NO_BALL_MAX: float = 0.10            # cap for a wild bowler

# ─── Over Events ───
const BIG_OVER_RUNS: int = 12              # over qualifies as a "big over"
const DRINKS_BREAK_OVER_ODI: int = 20      # drinks break cadence (ODI)
const DRINKS_BREAK_OVER_T20: int = 10      # drinks break cadence (T20)
const SPELL_REST_RECOVERY: float = 0.05    # fatigue recovered per over rested

# ─── Theme Colors ───
const COLOR_BG_DARK := Color("#0D1117")
const COLOR_BG_PANEL := Color("#161B22")
const COLOR_ACCENT_GREEN := Color("#00C853")
const COLOR_ACCENT_GOLD := Color("#FFD600")
const COLOR_TEXT_PRIMARY := Color("#FFFFFF")
const COLOR_TEXT_SECONDARY := Color("#8B949E")
const COLOR_BORDER := Color("#30363D")
const COLOR_WICKET_RED := Color("#FF1744")

# ─── Enums ───
enum MatchFormat { T20, ODI }
enum MatchPhase { POWERPLAY, MIDDLE, DEATH }
enum PitchType { FLAT, GREEN_SEAMER, SPIN_TRACK, BOUNCY, DEAD_FLAT }
enum WeatherType { SUNNY, OVERCAST, DRIZZLE, HUMID, WINDY }
enum BattingStyle { AGGRESSIVE, BALANCED, DEFENSIVE }
enum BowlingType { FAST, MEDIUM, SPIN, NONE }
enum Difficulty { EASY, MEDIUM, HARD }

enum ShotType {
	AGGRESSIVE_DRIVE,
	PULL_SHOT,
	SWEEP_SHOT,
	LOFT_SLOG,
	DEFENSIVE_BLOCK,
	LEAVE_BALL
}

enum DeliveryType {
	YORKER,
	BOUNCER,
	FULL_TOSS,
	OFF_SPIN,
	LEG_SPIN,
	SLOWER
}

enum WicketType {
	BOWLED,
	CAUGHT,
	LBW,
	RUN_OUT,
	STUMPED,
	HIT_WICKET,
	CAUGHT_BEHIND,
	RETIRED_HURT
}

enum Timing { EARLY, PERFECT, LATE, MISTIMED }
enum Footwork { FRONT_FOOT, BACK_FOOT }
enum BowlLength { YORKER, FULL, GOOD_LENGTH, SHORT }
enum BowlLine { OUTSIDE_OFF, STUMPS, OUTSIDE_LEG, BODY }

# ─── Shot/Bowl Matchup Matrix Keys ───
# Maps a (DeliveryType, ShotType) pair to risk/reward modifiers.
# Format: { "wicket_mod", "runs_mod", "dot_mod", "boundary_mod" }
var MATCHUP_MATRIX: Dictionary = {
	_key(DeliveryType.YORKER, ShotType.LOFT_SLOG): { "wicket_mod": 0.25, "runs_mod": 0.15, "dot_mod": 0.30, "boundary_mod": 0.10 },
	_key(DeliveryType.BOUNCER, ShotType.PULL_SHOT): { "wicket_mod": 0.30, "runs_mod": 0.10, "dot_mod": 0.20, "boundary_mod": 0.40 },
	_key(DeliveryType.OFF_SPIN, ShotType.SWEEP_SHOT): { "wicket_mod": 0.25, "runs_mod": 0.10, "dot_mod": 0.30, "boundary_mod": 0.35 },
	_key(DeliveryType.SLOWER, ShotType.AGGRESSIVE_DRIVE): { "wicket_mod": 0.45, "runs_mod": 0.10, "dot_mod": 0.35, "boundary_mod": 0.10 },
	_key(DeliveryType.FULL_TOSS, ShotType.AGGRESSIVE_DRIVE): { "wicket_mod": 0.05, "runs_mod": 0.25, "dot_mod": 0.10, "boundary_mod": 0.50 },
	_key(DeliveryType.FULL_TOSS, ShotType.LOFT_SLOG): { "wicket_mod": 0.08, "runs_mod": 0.20, "dot_mod": 0.10, "boundary_mod": 0.55 },
	_key(DeliveryType.FULL_TOSS, ShotType.PULL_SHOT): { "wicket_mod": 0.05, "runs_mod": 0.30, "dot_mod": 0.10, "boundary_mod": 0.45 },
	_key(DeliveryType.YORKER, ShotType.DEFENSIVE_BLOCK): { "wicket_mod": 0.10, "runs_mod": 0.05, "dot_mod": 0.70, "boundary_mod": 0.02 },
	_key(DeliveryType.BOUNCER, ShotType.DEFENSIVE_BLOCK): { "wicket_mod": 0.08, "runs_mod": 0.05, "dot_mod": 0.75, "boundary_mod": 0.02 },
	_key(DeliveryType.LEG_SPIN, ShotType.SWEEP_SHOT): { "wicket_mod": 0.20, "runs_mod": 0.15, "dot_mod": 0.25, "boundary_mod": 0.30 },
	_key(DeliveryType.LEG_SPIN, ShotType.LOFT_SLOG): { "wicket_mod": 0.35, "runs_mod": 0.10, "dot_mod": 0.15, "boundary_mod": 0.30 },
	_key(DeliveryType.OFF_SPIN, ShotType.DEFENSIVE_BLOCK): { "wicket_mod": 0.05, "runs_mod": 0.05, "dot_mod": 0.80, "boundary_mod": 0.01 },
}

func _key(delivery: int, shot: int) -> String:
	return str(delivery) + "_" + str(shot)

func get_matchup(delivery: int, shot: int) -> Dictionary:
	var k = _key(delivery, shot)
	if MATCHUP_MATRIX.has(k):
		return MATCHUP_MATRIX[k]
	# Default balanced outcome
	return { "wicket_mod": 0.12, "runs_mod": 0.20, "dot_mod": 0.40, "boundary_mod": 0.15 }

# ─── Wagon Wheel Zones ───
enum FieldZone {
	FINE_LEG,       # 1
	SQUARE_LEG,     # 2
	MID_WICKET,     # 3
	LONG_ON,        # 4
	MID_ON,         # 5
	MID_OFF,        # 6
	COVER,          # 7
	POINT           # 8
}

# Shot → preferred zones mapping
var SHOT_ZONES: Dictionary = {
	ShotType.AGGRESSIVE_DRIVE: [FieldZone.COVER, FieldZone.MID_OFF],
	ShotType.PULL_SHOT: [FieldZone.SQUARE_LEG, FieldZone.FINE_LEG],
	ShotType.SWEEP_SHOT: [FieldZone.FINE_LEG, FieldZone.MID_WICKET],
	ShotType.LOFT_SLOG: [FieldZone.MID_ON, FieldZone.MID_OFF, FieldZone.LONG_ON],
	ShotType.DEFENSIVE_BLOCK: [FieldZone.MID_OFF, FieldZone.MID_ON],
	ShotType.LEAVE_BALL: [],
}

# Zone display names (for commentary flavor)
var ZONE_NAMES: Dictionary = {
	FieldZone.FINE_LEG: "fine leg",
	FieldZone.SQUARE_LEG: "square leg",
	FieldZone.MID_WICKET: "mid-wicket",
	FieldZone.LONG_ON: "long-on",
	FieldZone.MID_ON: "mid-on",
	FieldZone.MID_OFF: "mid-off",
	FieldZone.COVER: "the covers",
	FieldZone.POINT: "point",
}

# Fielding layouts per match phase: 11 entries of {zone, depth} where depth is
# the fraction of the way from the striker's end toward the zone's rope point.
# POWERPLAY: aggressive ring of catchers + 2 deep. MIDDLE: balanced.
# DEATH: five boundary riders, five in the ring.
var PHASE_FIELD_LAYOUTS: Dictionary = {
	MatchPhase.POWERPLAY: [
		{"zone": FieldZone.SQUARE_LEG, "depth": 0.28},
		{"zone": FieldZone.MID_WICKET, "depth": 0.32},
		{"zone": FieldZone.POINT, "depth": 0.30},
		{"zone": FieldZone.COVER, "depth": 0.34},
		{"zone": FieldZone.MID_OFF, "depth": 0.30},
		{"zone": FieldZone.MID_ON, "depth": 0.32},
		{"zone": FieldZone.FINE_LEG, "depth": 0.45},
		{"zone": FieldZone.SQUARE_LEG, "depth": 0.72},
		{"zone": FieldZone.LONG_ON, "depth": 0.90},
		{"zone": FieldZone.COVER, "depth": 0.88},
		{"zone": FieldZone.MID_WICKET, "depth": 0.70},
	],
	MatchPhase.MIDDLE: [
		{"zone": FieldZone.MID_ON, "depth": 0.45},
		{"zone": FieldZone.LONG_ON, "depth": 0.88},
		{"zone": FieldZone.MID_WICKET, "depth": 0.55},
		{"zone": FieldZone.SQUARE_LEG, "depth": 0.50},
		{"zone": FieldZone.FINE_LEG, "depth": 0.60},
		{"zone": FieldZone.MID_OFF, "depth": 0.48},
		{"zone": FieldZone.COVER, "depth": 0.52},
		{"zone": FieldZone.POINT, "depth": 0.50},
		{"zone": FieldZone.LONG_ON, "depth": 0.90},
		{"zone": FieldZone.COVER, "depth": 0.85},
		{"zone": FieldZone.MID_WICKET, "depth": 0.82},
	],
	MatchPhase.DEATH: [
		{"zone": FieldZone.FINE_LEG, "depth": 0.92},
		{"zone": FieldZone.SQUARE_LEG, "depth": 0.88},
		{"zone": FieldZone.MID_WICKET, "depth": 0.90},
		{"zone": FieldZone.LONG_ON, "depth": 0.95},
		{"zone": FieldZone.COVER, "depth": 0.92},
		{"zone": FieldZone.MID_OFF, "depth": 0.45},
		{"zone": FieldZone.COVER, "depth": 0.40},
		{"zone": FieldZone.POINT, "depth": 0.42},
		{"zone": FieldZone.MID_ON, "depth": 0.44},
		{"zone": FieldZone.MID_WICKET, "depth": 0.40},
		{"zone": FieldZone.SQUARE_LEG, "depth": 0.40},
	],
}

# Catch-hold modifier for contested catches by fielding phase
# (field up in the powerplay helps; spread at the death hurts).
const CATCH_PHASE_MOD: Dictionary = {
	MatchPhase.POWERPLAY: 0.04,
	MatchPhase.MIDDLE: 0.0,
	MatchPhase.DEATH: -0.05,
}
