# TournamentHub.gd — Tournament landing screen: groups, stage, and actions.
extends Control

@onready var lbl_stage := $TopBar/StageLabel
@onready var lbl_subtitle := $TopBar/Subtitle
@onready var group_a := $Tables/GroupA
@onready var group_b := $Tables/GroupB
@onready var fixtures_list := $LeftPanel/FixturesList
@onready var btn_play := $Actions/BtnPlay
@onready var btn_sim := $Actions/BtnSim
@onready var btn_squad := $Actions/BtnSquad
@onready var btn_abandon := $Actions/BtnAbandon
@onready var btn_back := $Actions/BtnBack
@onready var lbl_next := $Actions/NextLabel
@onready var lbl_champion := $ChampionBanner
@onready var pick_panel := $PickPanel
@onready var pick_list := $PickPanel/PickVBox/PickList
@onready var btn_pick := $PickPanel/PickVBox/BtnPick
@onready var btn_resume := $PickPanel/PickVBox/BtnResume

func _ready() -> void:
	modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, Constants.SCENE_FADE_DURATION)

	btn_play.pressed.connect(_on_play)
	btn_sim.pressed.connect(_on_sim)
	btn_squad.pressed.connect(_on_squad)
	btn_abandon.pressed.connect(_on_abandon)
	btn_back.pressed.connect(_on_back)
	btn_pick.pressed.connect(_on_team_picked)
	btn_resume.pressed.connect(_on_resume_saved)
	TournamentManager.stage_changed.connect(_refresh)
	TournamentManager.champion_crowned.connect(func(_w: String) -> void: _refresh())

	# No active tournament (and no completed one to view) -> team picker,
	# with a Resume option if a save exists on disk.
	if not TournamentManager.is_active() and TournamentManager.champion == "":
		btn_resume.visible = TournamentManager.has_save()
		_show_team_picker()
	else:
		pick_panel.visible = false
		_record_pending_match_result()
		_refresh()

func _on_resume_saved() -> void:
	if not TournamentManager.load_saved():
		btn_resume.visible = false
		return
	AudioManager.play_click()
	pick_panel.visible = false
	_record_pending_match_result()
	_refresh()

# After a human-played match, the Scorecard routes back here — record its
# result into the standings using the meta the match flow left behind.
func _record_pending_match_result() -> void:
	if not GameManager.has_meta("pending_fixture_result"):
		return
	var pend: Dictionary = GameManager.get_meta("pending_fixture_result")
	GameManager.remove_meta("pending_fixture_result")
	if pend.is_empty():
		return
	var kind: String = pend.get("kind", "group")
	var home: String = pend.get("home", "")
	var away: String = pend.get("away", "")
	var winner: String = GameManager.get_meta("match_winner") if GameManager.has_meta("match_winner") else ""
	if winner == "" or home == "" or away == "":
		return
	var gm := GameManager
	if kind == "group":
		# NRR context comes from the finished-match scorecard (main-match
		# innings for super-over games — shootout runs never count).
		var sc: Dictionary = GameManager.get_meta("last_scorecard") if GameManager.has_meta("last_scorecard") else {}
		var innings: Array = TournamentManager.nrr_innings(sc, gm.first_innings_scorecard, winner) if not sc.is_empty() else []
		var payload := {"winner_runs": 0, "winner_overs": 20.0, "loser_runs": 0, "loser_overs": 20.0}
		if innings.size() == 2:
			payload = TournamentManager.nrr_payload(innings[0], innings[1])
		TournamentManager.record_result(home, away, winner, payload)
		# Group stage may now be complete — try advancing
		TournamentManager.advance_stage()
	elif kind.begins_with("semi"):
		var idx := int(kind.substr(4))
		TournamentManager.record_knockout(kind, home, away, winner)
		TournamentManager.advance_stage()
	elif kind == "final":
		TournamentManager.record_knockout("final", home, away, winner)
		TournamentManager.advance_stage()

func _show_team_picker() -> void:
	pick_panel.visible = true
	pick_list.clear()
	for t in GameManager.all_teams:
		pick_list.add_item(t.team_name)
	pick_list.select(0)
	lbl_stage.text = "NEW TOURNAMENT"
	lbl_subtitle.text = "Pick your team — 2 groups of 4, semis, final"

func _on_team_picked() -> void:
	var items: Array = pick_list.get_selected_items()
	if items.is_empty():
		return
	AudioManager.play_click()
	var team = GameManager.all_teams[items[0]]
	TournamentManager.start_new_tournament(team)
	pick_panel.visible = false
	_refresh()

func _refresh() -> void:
	lbl_stage.text = TournamentManager.stage_label()
	var human = TournamentManager.human_team_name
	lbl_subtitle.text = ("Your team: " + human) if human != "" else ""
	group_a.set_teams(TournamentManager.sorted_group(0), human)
	group_b.set_teams(TournamentManager.sorted_group(1), human)
	_populate_fixtures()
	
	# Champion banner
	if TournamentManager.stage == TournamentManager.Stage.DONE and TournamentManager.champion != "":
		lbl_champion.visible = true
		lbl_champion.text = "🏆 " + TournamentManager.champion + " WIN THE CUP! 🏆"
		btn_play.visible = false
		btn_sim.visible = false
		lbl_next.text = ""
	else:
		lbl_champion.visible = false
	
	# Next-fixture banner + button states
	var nxt: Dictionary = TournamentManager.next_human_fixture()
	if nxt.is_empty():
		btn_play.visible = false
		lbl_next.text = "No more fixtures for your team" if TournamentManager.stage != TournamentManager.Stage.DONE else ""
		btn_sim.visible = not TournamentManager.pending_ai_fixtures().is_empty() \
			or TournamentManager.stage in [TournamentManager.Stage.SEMIS, TournamentManager.Stage.FINAL]
		btn_sim.text = "▶ Sim to Next Stage" if not TournamentManager.stage == TournamentManager.Stage.GROUPS else "▶ Sim Other Matches"
	else:
		btn_play.visible = true
		var kind := "GROUP" if nxt.get("kind", "group") == "group" else str(nxt.get("kind", "GROUP")).to_upper()
		btn_play.text = "🏏 Play: %s vs %s" % [nxt["home"], nxt["away"]]
		lbl_next.text = "Stage: %s" % TournamentManager.stage_label()
		btn_sim.visible = not TournamentManager.pending_ai_fixtures().is_empty()
		btn_sim.text = "▶ Sim Other Matches"

func _populate_fixtures() -> void:
	fixtures_list.clear()
	if TournamentManager.stage == TournamentManager.Stage.GROUPS:
		for f in TournamentManager.fixtures:
			var line := "%s vs %s" % [f["home"], f["away"]]
			if f["done"]:
				line += "  →  %s ✔" % f["winner"]
			fixtures_list.add_item(line)
	elif TournamentManager.stage == TournamentManager.Stage.SEMIS:
		for s in TournamentManager.semis:
			var line := "SEMI: %s vs %s" % [s["home"], s["away"]]
			if s["done"]:
				line += "  →  %s ✔" % s["winner"]
			fixtures_list.add_item(line)
	elif TournamentManager.stage == TournamentManager.Stage.FINAL:
		var fm = TournamentManager.final_match
		var line := "FINAL: %s vs %s" % [fm.get("home", ""), fm.get("away", "")]
		if fm.get("done", false):
			line += "  →  %s ✔" % fm.get("winner", "")
		fixtures_list.add_item(line)
	if TournamentManager.champion != "":
		fixtures_list.add_item("🏆 CHAMPION: %s" % TournamentManager.champion)

func _on_play() -> void:
	var nxt: Dictionary = TournamentManager.next_human_fixture()
	if nxt.is_empty():
		return
	AudioManager.play_click()
	var home = TournamentManager.team_by_name(nxt["home"])
	var away = TournamentManager.team_by_name(nxt["away"])
	var human = TournamentManager.team_by_name(TournamentManager.human_team_name)
	# Route through the toss screen
	GameManager.set_meta("toss_home", home)
	GameManager.set_meta("toss_away", away)
	GameManager.set_meta("toss_human", human)
	GameManager.set_meta("toss_fixture", nxt.get("kind", "group"))
	_fade_to("res://scenes/ui/TossScreen.tscn")

func _on_sim() -> void:
	# Simulate all AI fixtures of the current group stage, then advance stages
	# if possible. Runs visibly fast via fast_forward.
	AudioManager.play_click()
	_sim_pending()
	# After simming, stages may advance (e.g., group stage completed)
	TournamentManager.advance_stage()
	_refresh()

func _sim_pending() -> void:
	# Synchronous auto-sim using the ball simulator directly (no engine UI flow):
	# a lightweight result generator for AI-vs-AI fixtures.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for f in TournamentManager.fixtures:
		if not f["done"] and f["home"] != TournamentManager.human_team_name \
				and f["away"] != TournamentManager.human_team_name:
			var home = TournamentManager.team_by_name(f["home"])
			var away = TournamentManager.team_by_name(f["away"])
			var res := _quick_sim(home, away, rng)
			TournamentManager.record_result(f["home"], f["away"], res["winner"], res)
	# Semis/final auto-sim if the human isn't involved
	if TournamentManager.stage == TournamentManager.Stage.SEMIS:
		for i in range(TournamentManager.semis.size()):
			var s = TournamentManager.semis[i]
			if not s["done"] and s["home"] != TournamentManager.human_team_name \
					and s["away"] != TournamentManager.human_team_name:
				var res := _quick_sim(TournamentManager.team_by_name(s["home"]),
					TournamentManager.team_by_name(s["away"]), rng)
				TournamentManager.record_knockout("semi%d" % i, s["home"], s["away"], res["winner"])
		TournamentManager.advance_stage()
	if TournamentManager.stage == TournamentManager.Stage.FINAL and not TournamentManager.final_match.get("done", false):
		var fm = TournamentManager.final_match
		if fm["home"] != TournamentManager.human_team_name and fm["away"] != TournamentManager.human_team_name:
			var res := _quick_sim(TournamentManager.team_by_name(fm["home"]),
				TournamentManager.team_by_name(fm["away"]), rng)
			TournamentManager.record_knockout("final", fm["home"], fm["away"], res["winner"])
			TournamentManager.advance_stage()

# Quick statistical sim for AI-vs-AI fixtures: uses team batting/bowling strength
# averages to produce a plausible score and winner (no per-ball simulation).
func _quick_sim(home: TeamData, away: TeamData, rng: RandomNumberGenerator) -> Dictionary:
	var score_a := _team_t20_score(home, away, rng)
	var score_b := _team_t20_score(away, home, rng)
	var winner := home.team_name if score_a["runs"] > score_b["runs"] else away.team_name
	if score_a["runs"] == score_b["runs"]:
		# Level scores — play a real super-over shootout through BallSimulator.
		winner = _sim_super_over(home, away)
	return {
		"winner": winner,
		"winner_runs": score_a["runs"] if winner == home.team_name else score_b["runs"],
		"winner_overs": 20.0,
		"loser_runs": score_b["runs"] if winner == home.team_name else score_a["runs"],
		"loser_overs": 20.0,
	}

# Real sudden-death shootout for simmed ties: 6 legal balls per side with a
# 2-wicket cap, resolved through BallSimulator with the actual XIs.
# Player sim-state is snapshotted and restored so the shootout has no side
# effects on the tournament. Repeats on further ties (max 5 rounds, then seed).
func _sim_super_over(home: TeamData, away: TeamData) -> String:
	var sim := BallSimulator.new()
	add_child(sim)  # runs _ready (RNG + difficulty)
	var ai := AIController.new()
	var snapshot := _snapshot_xi(home)
	snapshot.append_array(_snapshot_xi(away))
	var gm_pressure: float = GameManager.batting_pressure
	var gm_momentum: float = GameManager.momentum
	var gm_wear: float = GameManager.pitch_wear
	var winner := ""
	var rounds := 0
	while winner == "" and rounds < 5:
		rounds += 1
		var a := _sim_mini_innings(home, away, sim, ai)
		var b := _sim_mini_innings(away, home, sim, ai)
		if a > b:
			winner = home.team_name
		elif b > a:
			winner = away.team_name
	if winner == "":
		winner = home.team_name if randf() < 0.5 else away.team_name
	_restore_xi(snapshot)
	GameManager.batting_pressure = gm_pressure
	GameManager.momentum = gm_momentum
	GameManager.pitch_wear = gm_wear
	sim.queue_free()
	return winner

func _snapshot_xi(team: TeamData) -> Array:
	var snap := []
	for p in team.playing_xi:
		snap.append([p, p.form, p.fatigue, p.morale, p.confidence, p.rhythm])
	return snap

func _restore_xi(snapshot: Array) -> void:
	for entry in snapshot:
		var p: PlayerData = entry[0]
		p.form = entry[1]
		p.fatigue = entry[2]
		p.morale = entry[3]
		p.confidence = entry[4]
		p.rhythm = entry[5]

func _sim_mini_innings(bat: TeamData, bowl: TeamData, sim: BallSimulator, ai: AIController) -> int:
	var state := {
		"format": Constants.MatchFormat.T20,
		"phase": Constants.MatchPhase.DEATH,
		"current_over": 19,
		"current_ball": 0,
		"total_runs": 0,
		"total_wickets": 0,
		"target": 0,
		"max_overs": 20,
		"is_first_innings": true,
	}
	var striker: PlayerData = bat.playing_xi[0]
	var bowler: PlayerData = _best_bowler(bowl)
	var runs := 0
	var wkts := 0
	var balls := 0
	while balls < 6 and wkts < 2:
		var shot: int = ai.choose_batting_shot(striker, state)
		var del: int = ai.choose_bowling_delivery(bowler, striker, state)
		var o: Dictionary = sim.simulate_ball(striker, bowler, shot, del, state, bowl)
		if o.get("is_wide", false) or o.get("is_no_ball", false):
			runs += 1
			continue
		balls += 1
		if o.get("is_wicket", false):
			wkts += 1
		else:
			runs += int(o.get("runs", 0))
	return runs

func _best_bowler(team: TeamData) -> PlayerData:
	var best: PlayerData = team.playing_xi[0]
	for p in team.get_bowlers():
		if p.bowling_skill > best.bowling_skill:
			best = p
	return best

func _team_t20_score(bat: TeamData, bowl: TeamData, rng: RandomNumberGenerator) -> Dictionary:
	var bat_avg := 0.0
	for p in bat.playing_xi:
		bat_avg += p.batting_skill
	bat_avg /= 11.0
	var bowl_avg := 0.0
	for p in bowl.playing_xi:
		bowl_avg += p.bowling_skill
	bowl_avg /= 11.0
	var base := 150.0 + (bat_avg - bowl_avg) * 0.9
	var score := int(clampf(rng.randfn(base, 22.0), 60.0, 240.0))
	return {"runs": score}

func _on_squad() -> void:
	# Open the XI picker for the human's team; changes persist into the save.
	var human = TournamentManager.team_by_name(TournamentManager.human_team_name)
	if human == null:
		return
	AudioManager.play_click()
	GameManager.set_meta("xi_team", human)
	GameManager.set_meta("xi_return", "res://scenes/ui/TournamentHub.tscn")
	GameManager.set_meta("xi_start_match", false)
	_fade_to("res://scenes/ui/XIPicker.tscn")

func _on_abandon() -> void:
	AudioManager.play_click()
	TournamentManager.abandon()
	_fade_to("res://scenes/ui/MainMenu.tscn")

func _on_back() -> void:
	AudioManager.play_click()
	_fade_to("res://scenes/ui/MainMenu.tscn")

func _fade_to(scene_path: String) -> void:
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	get_tree().change_scene_to_file(scene_path)
