# WeatherPitchSystem.gd — Weather changes and pitch wear simulation (Module 2).
# Weather shifts every 10 overs. Pitch degrades per ball.
extends RefCounted
class_name WeatherPitchSystem

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func update(game_state: Dictionary) -> Dictionary:
	var mods: Dictionary = {
		"swing_bonus": 0.0,
		"seam_bonus": 0.0,
		"spin_bonus": 0.0,
		"boundary_mod": 0.0,
		"fatigue_mod": 1.0,
		"six_chance_mod": 0.0,
		"wide_chance_mod": 0.0,
	}
	
	# ─── Weather Effects ───
	var weather = game_state.get("weather", Constants.WeatherType.SUNNY)
	match weather:
		Constants.WeatherType.SUNNY:
			mods["fatigue_mod"] = 1.2
		Constants.WeatherType.OVERCAST:
			mods["swing_bonus"] = 0.15
			mods["seam_bonus"] = 0.10
			mods["spin_bonus"] = -0.10
		Constants.WeatherType.DRIZZLE:
			mods["boundary_mod"] = -0.20
			mods["wide_chance_mod"] = 0.05
		Constants.WeatherType.HUMID:
			mods["fatigue_mod"] = 1.3
			mods["spin_bonus"] = 0.10
			var over = game_state.get("current_over", 0)
			var format = game_state.get("format", Constants.MatchFormat.T20)
			var reverse_threshold = 12 if format == Constants.MatchFormat.T20 else 30
			if over >= reverse_threshold:
				mods["swing_bonus"] = 0.20
		Constants.WeatherType.WINDY:
			mods["swing_bonus"] = _rng.randf_range(-0.15, 0.15)
			mods["six_chance_mod"] = 0.10
	
	# ─── Pitch Effects ───
	var pitch = game_state.get("pitch_type", Constants.PitchType.FLAT)
	var over = game_state.get("current_over", 0)
	match pitch:
		Constants.PitchType.FLAT:
			mods["spin_bonus"] += -0.05
		Constants.PitchType.GREEN_SEAMER:
			if over < 10:
				mods["seam_bonus"] += 0.20
				mods["swing_bonus"] += 0.15
		Constants.PitchType.SPIN_TRACK:
			mods["spin_bonus"] += 0.25
		Constants.PitchType.BOUNCY:
			mods["seam_bonus"] += 0.10
		Constants.PitchType.DEAD_FLAT:
			mods["boundary_mod"] += 0.10
	
	# ─── Pitch Wear ───
	var wear = game_state.get("pitch_wear", 0.0)
	if wear > Constants.PITCH_ROUGH_THRESHOLD:
		mods["spin_bonus"] += wear * 0.3
	if wear > Constants.PITCH_DANGEROUS_THRESHOLD:
		mods["seam_bonus"] += 0.05
	
	return mods

func should_change_weather(current_over: int) -> bool:
	return current_over > 0 and current_over % 10 == 0

func get_random_weather() -> int:
	return _rng.randi_range(0, 4)

func get_weather_name(weather: int) -> String:
	match weather:
		Constants.WeatherType.SUNNY: return "Sunny"
		Constants.WeatherType.OVERCAST: return "Overcast"
		Constants.WeatherType.DRIZZLE: return "Drizzle"
		Constants.WeatherType.HUMID: return "Humid"
		Constants.WeatherType.WINDY: return "Windy"
		_: return "Clear"

func get_pitch_name(pitch: int) -> String:
	match pitch:
		Constants.PitchType.FLAT: return "Flat"
		Constants.PitchType.GREEN_SEAMER: return "Green Seamer"
		Constants.PitchType.SPIN_TRACK: return "Spin Track"
		Constants.PitchType.BOUNCY: return "Bouncy"
		Constants.PitchType.DEAD_FLAT: return "Dead Flat"
		_: return "Standard"
