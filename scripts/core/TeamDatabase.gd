# TeamDatabase.gd — Hardcoded starter teams with fictional realistic players.
# Loaded by GameManager on startup to populate the team roster.
extends Node
class_name TeamDatabase

static func create_all_teams() -> Array[TeamData]:
	var teams: Array[TeamData] = []
	teams.append(_create_india())
	teams.append(_create_australia())
	teams.append(_create_england())
	teams.append(_create_south_africa())
	teams.append(_create_new_zealand())
	teams.append(_create_pakistan())
	teams.append(_create_west_indies())
	teams.append(_create_sri_lanka())
	return teams

static func _p(pname: String, bat: int, bowl: int, bat_style: String, bowl_type: String, field: int = 65) -> PlayerData:
	var p = PlayerData.new()
	p.player_name = pname
	p.batting_skill = bat
	p.bowling_skill = bowl
	p.batting_style = bat_style
	p.bowling_type = bowl_type
	p.fielding_skill = field
	return p

static func _team(tname: String, code: String, col: Color, players: Array[PlayerData]) -> TeamData:
	var t = TeamData.new()
	t.team_name = tname
	t.country_code = code
	t.team_color = col
	t.squad = players
	t.playing_xi = players.slice(0, 11)
	return t

# ═══════════════════════════════════════
# INDIA
# ═══════════════════════════════════════
static func _create_india() -> TeamData:
	var players: Array[PlayerData] = [
		_p("Vikram Sharma", 92, 15, "AGGRESSIVE", "NONE", 80),
		_p("Rohan Kapoor", 88, 10, "BALANCED", "NONE", 85),
		_p("Arjun Malhotra", 90, 25, "AGGRESSIVE", "NONE", 75),
		_p("Sanjay Iyer", 82, 30, "BALANCED", "NONE", 70),
		_p("Kiran Patel", 78, 20, "BALANCED", "NONE", 80),
		_p("Ravi Jadav", 72, 82, "BALANCED", "SPIN", 85),
		_p("Ankit Thakur", 55, 40, "DEFENSIVE", "NONE", 90),
		_p("Deepak Kulkarni", 35, 78, "DEFENSIVE", "SPIN", 65),
		_p("Praveen Kumar", 30, 85, "DEFENSIVE", "FAST", 55),
		_p("Suresh Yadav", 20, 88, "DEFENSIVE", "FAST", 60),
		_p("Manoj Mishra", 15, 82, "DEFENSIVE", "MEDIUM", 50),
		_p("Abhishek Rawat", 70, 15, "BALANCED", "NONE", 75),
		_p("Nikhil Verma", 62, 30, "BALANCED", "MEDIUM", 70),
		_p("Yash Chauhan", 40, 74, "DEFENSIVE", "SPIN", 60),
		_p("Gopal Nair", 25, 79, "DEFENSIVE", "MEDIUM", 55),
	]
	return _team("India", "IND", Color("#0033A0"), players)

# ═══════════════════════════════════════
# AUSTRALIA
# ═══════════════════════════════════════
static func _create_australia() -> TeamData:
	var players: Array[PlayerData] = [
		_p("David Warner-Smith", 90, 10, "AGGRESSIVE", "NONE", 70),
		_p("Marcus Thorn", 85, 15, "BALANCED", "NONE", 80),
		_p("Steven Marsh", 88, 20, "BALANCED", "NONE", 75),
		_p("Glenn Ashwood", 80, 75, "AGGRESSIVE", "SPIN", 85),
		_p("Mitchell Crane", 72, 25, "BALANCED", "NONE", 70),
		_p("Cameron Cooper", 65, 35, "DEFENSIVE", "NONE", 90),
		_p("Patrick Hughes", 50, 45, "DEFENSIVE", "NONE", 85),
		_p("James Croft", 30, 90, "DEFENSIVE", "FAST", 60),
		_p("Nathan Slade", 25, 86, "DEFENSIVE", "FAST", 55),
		_p("Josh Blackwell", 20, 84, "DEFENSIVE", "MEDIUM", 50),
		_p("Adam Warne", 35, 80, "DEFENSIVE", "SPIN", 65),
		_p("Liam Kowalski", 68, 12, "AGGRESSIVE", "NONE", 72),
		_p("Owen Bradman", 60, 35, "BALANCED", "MEDIUM", 68),
		_p("Finn Hollins", 38, 76, "DEFENSIVE", "SPIN", 58),
		_p("Riley Merrick", 22, 81, "DEFENSIVE", "FAST", 52),
	]
	return _team("Australia", "AUS", Color("#FFCD00"), players)

# ═══════════════════════════════════════
# ENGLAND
# ═══════════════════════════════════════
static func _create_england() -> TeamData:
	var players: Array[PlayerData] = [
		_p("James Baxter", 88, 12, "AGGRESSIVE", "NONE", 75),
		_p("Joe Hartley", 86, 18, "BALANCED", "NONE", 80),
		_p("Ben Archer", 84, 70, "AGGRESSIVE", "FAST", 80),
		_p("Harry Brook-Lane", 82, 15, "AGGRESSIVE", "NONE", 70),
		_p("Jonny Whitmore", 78, 10, "BALANCED", "NONE", 75),
		_p("Moeen Rashid", 68, 78, "BALANCED", "SPIN", 70),
		_p("Sam Livingstone", 75, 20, "AGGRESSIVE", "NONE", 65),
		_p("Chris Stanley", 45, 42, "DEFENSIVE", "NONE", 90),
		_p("Mark Wood-Hall", 20, 88, "DEFENSIVE", "FAST", 50),
		_p("Jofra Wellington", 15, 90, "DEFENSIVE", "FAST", 55),
		_p("Adil Sheikh", 30, 82, "DEFENSIVE", "SPIN", 60),
		_p("Tom Prescott", 66, 10, "AGGRESSIVE", "NONE", 70),
		_p("Will Kimpton", 58, 32, "BALANCED", "MEDIUM", 75),
		_p("Ethan Marlow", 36, 77, "DEFENSIVE", "SPIN", 62),
		_p("Josh Trenton", 24, 80, "DEFENSIVE", "FAST", 55),
	]
	return _team("England", "ENG", Color("#CF081F"), players)

# ═══════════════════════════════════════
# SOUTH AFRICA
# ═══════════════════════════════════════
static func _create_south_africa() -> TeamData:
	var players: Array[PlayerData] = [
		_p("Quinton Van Berg", 86, 10, "AGGRESSIVE", "NONE", 80),
		_p("Aiden Botha", 84, 15, "BALANCED", "NONE", 75),
		_p("Rassie Joubert", 82, 20, "BALANCED", "NONE", 85),
		_p("David Mulder", 80, 25, "BALANCED", "NONE", 70),
		_p("Heinrich Klaas", 75, 75, "AGGRESSIVE", "FAST", 70),
		_p("Andile Ntini", 55, 40, "DEFENSIVE", "NONE", 90),
		_p("Marco Steyn", 50, 45, "DEFENSIVE", "NONE", 85),
		_p("Kagiso Pretorius", 25, 88, "DEFENSIVE", "FAST", 55),
		_p("Anrich Viljoen", 20, 86, "DEFENSIVE", "FAST", 50),
		_p("Lungi De Bruyn", 15, 84, "DEFENSIVE", "FAST", 60),
		_p("Keshav Pillay", 30, 82, "DEFENSIVE", "SPIN", 65),
		_p("Dewald Bekker", 64, 14, "AGGRESSIVE", "NONE", 72),
		_p("Pieter Kruger", 56, 34, "BALANCED", "MEDIUM", 70),
		_p("Sizwe Dlamini", 34, 75, "DEFENSIVE", "SPIN", 66),
		_p("Ruan Fourie", 23, 82, "DEFENSIVE", "FAST", 50),
	]
	return _team("South Africa", "RSA", Color("#007A4D"), players)

# ═══════════════════════════════════════
# NEW ZEALAND
# ═══════════════════════════════════════
static func _create_new_zealand() -> TeamData:
	var players: Array[PlayerData] = [
		_p("Kane Whitfield", 90, 30, "BALANCED", "MEDIUM", 80),
		_p("Devon Conway-Park", 85, 10, "BALANCED", "NONE", 75),
		_p("Martin Phillips", 82, 15, "BALANCED", "NONE", 70),
		_p("Glenn Mitchell", 78, 72, "BALANCED", "SPIN", 85),
		_p("Daryl Henderson", 75, 40, "AGGRESSIVE", "MEDIUM", 70),
		_p("James Nichols", 65, 35, "DEFENSIVE", "NONE", 90),
		_p("Tom Fletcher", 50, 45, "DEFENSIVE", "NONE", 85),
		_p("Tim Southgate", 25, 88, "DEFENSIVE", "FAST", 55),
		_p("Trent Milne", 20, 90, "DEFENSIVE", "FAST", 60),
		_p("Kyle Ferguson", 15, 85, "DEFENSIVE", "FAST", 50),
		_p("Ish Patel", 30, 80, "DEFENSIVE", "SPIN", 65),
		_p("Reece Tolbert", 66, 12, "BALANCED", "NONE", 74),
		_p("Hemi Watene", 57, 33, "BALANCED", "MEDIUM", 71),
		_p("Callum Donnelly", 35, 76, "DEFENSIVE", "SPIN", 63),
		_p("Tane Robinson", 22, 81, "DEFENSIVE", "FAST", 54),
	]
	return _team("New Zealand", "NZL", Color("#000000"), players)

# ═══════════════════════════════════════
# PAKISTAN
# ═══════════════════════════════════════
static func _create_pakistan() -> TeamData:
	var players: Array[PlayerData] = [
		_p("Babar Khan", 92, 10, "BALANCED", "NONE", 80),
		_p("Rizwan Ahmed", 84, 12, "BALANCED", "NONE", 85),
		_p("Fakhar Hussain", 80, 8, "AGGRESSIVE", "NONE", 65),
		_p("Iftikhar Malik", 75, 65, "AGGRESSIVE", "SPIN", 60),
		_p("Shadab Qureshi", 68, 78, "BALANCED", "SPIN", 80),
		_p("Imad Ali", 60, 76, "DEFENSIVE", "SPIN", 70),
		_p("Mohammad Nawaz", 55, 40, "DEFENSIVE", "NONE", 90),
		_p("Shaheen Afridi-Khan", 20, 92, "DEFENSIVE", "FAST", 50),
		_p("Haris Rauf-Ali", 15, 88, "DEFENSIVE", "FAST", 55),
		_p("Naseem Waqar", 10, 86, "DEFENSIVE", "FAST", 45),
		_p("Abrar Bashir", 25, 80, "DEFENSIVE", "SPIN", 60),
		_p("Saim Farooq", 67, 12, "AGGRESSIVE", "NONE", 70),
		_p("Usman Ghani", 59, 30, "BALANCED", "MEDIUM", 68),
		_p("Zafar Iqbal", 37, 77, "DEFENSIVE", "SPIN", 60),
		_p("Wahab Tariq", 21, 83, "DEFENSIVE", "FAST", 48),
	]
	return _team("Pakistan", "PAK", Color("#006600"), players)

# ═══════════════════════════════════════
# WEST INDIES
# ═══════════════════════════════════════
static func _create_west_indies() -> TeamData:
	var players: Array[PlayerData] = [
		_p("Brandon King-Charles", 82, 10, "AGGRESSIVE", "NONE", 75),
		_p("Nicholas Richards", 80, 15, "AGGRESSIVE", "NONE", 70),
		_p("Shai Brathwaite", 78, 20, "BALANCED", "NONE", 80),
		_p("Shimron Lewis", 85, 8, "AGGRESSIVE", "NONE", 65),
		_p("Kyle Thomas", 70, 65, "BALANCED", "SPIN", 75),
		_p("Jason McCoy", 65, 72, "AGGRESSIVE", "FAST", 80),
		_p("Rovman Joseph", 72, 45, "AGGRESSIVE", "MEDIUM", 85),
		_p("Alzarri Williams", 20, 88, "DEFENSIVE", "FAST", 55),
		_p("Akeal Grant", 30, 80, "DEFENSIVE", "SPIN", 60),
		_p("Obed Pierre", 15, 85, "DEFENSIVE", "FAST", 50),
		_p("Gudakesh Persaud", 25, 78, "DEFENSIVE", "SPIN", 65),
		_p("Javel Josephs", 65, 12, "AGGRESSIVE", "NONE", 70),
		_p("Daron Blackwood", 58, 32, "BALANCED", "MEDIUM", 68),
		_p("Kirk Alphonso", 36, 74, "DEFENSIVE", "SPIN", 62),
		_p("Shamar Benn", 22, 80, "DEFENSIVE", "FAST", 52),
	]
	return _team("West Indies", "WI", Color("#7B0041"), players)

# ═══════════════════════════════════════
# SRI LANKA
# ═══════════════════════════════════════
static func _create_sri_lanka() -> TeamData:
	var players: Array[PlayerData] = [
		_p("Pathum de Silva", 84, 15, "BALANCED", "NONE", 75),
		_p("Kusal Jayasuriya", 82, 10, "AGGRESSIVE", "NONE", 80),
		_p("Charith Mendis", 80, 20, "BALANCED", "NONE", 70),
		_p("Dhananjaya Perera", 75, 78, "BALANCED", "SPIN", 75),
		_p("Bhanuka Fernando", 72, 25, "AGGRESSIVE", "NONE", 65),
		_p("Dasun Karunaratne", 68, 70, "BALANCED", "MEDIUM", 80),
		_p("Wanindu Lakmal", 65, 82, "BALANCED", "SPIN", 85),
		_p("Lahiru Theekshana", 30, 85, "DEFENSIVE", "SPIN", 60),
		_p("Dushmantha Bandara", 20, 86, "DEFENSIVE", "FAST", 55),
		_p("Kasun Kumara", 15, 84, "DEFENSIVE", "FAST", 50),
		_p("Maheesh de Zoysa", 25, 80, "DEFENSIVE", "MEDIUM", 60),
		_p("Avishka Mendons", 66, 12, "BALANCED", "NONE", 72),
		_p("Ravindu Silva", 58, 30, "BALANCED", "MEDIUM", 70),
		_p("Sahan Wickrama", 36, 76, "DEFENSIVE", "SPIN", 63),
		_p("Dilshan Perera", 22, 81, "DEFENSIVE", "FAST", 53),
	]
	return _team("Sri Lanka", "SL", Color("#0000FF"), players)
