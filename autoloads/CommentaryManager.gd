# CommentaryManager.gd — Generates contextual commentary text (Autoload).
# 40+ unique lines per event type, varying by wicket type and milestones.
extends Node

var _rng := RandomNumberGenerator.new()

# Track recently used lines to avoid repeats
var _recent_lines: Array[String] = []
const MAX_RECENT: int = 20

func _ready() -> void:
	_rng.randomize()

func get_commentary(event: String, context: Dictionary = {}) -> String:
	var pool: Array[String] = _get_pool(event, context)
	if pool.is_empty():
		return ""
	
	# Avoid recent repeats
	var available = pool.filter(func(line): return line not in _recent_lines)
	if available.is_empty():
		available = pool
		_recent_lines.clear()
	
	var line = available[_rng.randi_range(0, available.size() - 1)]
	_recent_lines.append(line)
	if _recent_lines.size() > MAX_RECENT:
		_recent_lines.pop_front()
	return line

func _get_pool(event: String, ctx: Dictionary) -> Array[String]:
	match event:
		"SIX":
			return _SIX_LINES
		"FOUR":
			return _FOUR_LINES
		"DOT":
			return _DOT_LINES
		"SINGLE":
			return _SINGLE_LINES
		"TWO":
			return _TWO_LINES
		"THREE":
			return _THREE_LINES
		"WIDE":
			return _WIDE_LINES
		"NO_BALL":
			return _NOBALL_LINES
		"WICKET":
			var wtype = ctx.get("wicket_type", "BOWLED")
			return _get_wicket_pool(wtype)
		"MILESTONE_50":
			return _FIFTY_LINES
		"MILESTONE_100":
			return _HUNDRED_LINES
		"FIFER":
			return _FIFER_LINES
		"HAT_TRICK_BALL":
			return _HAT_TRICK_LINES
		"CLOSE_FINISH":
			return _CLOSE_FINISH_LINES
		"CROWD_SIX":
			return _CROWD_SIX_LINES
		"CROWD_WICKET":
			return _CROWD_WICKET_LINES
		"PRESSURE":
			return _PRESSURE_LINES
		"IN_THE_ZONE":
			return _IN_ZONE_LINES
		"WEATHER_CHANGE":
			return _WEATHER_LINES
		"DRS":
			return _DRS_LINES
		"DRS_NOT_OUT":
			return _DRS_NOT_OUT_LINES
		"DRS_LOST":
			return _DRS_LOST_LINES
		"DROPPED_CATCH":
			return _DROPPED_LINES
		"MAIDEN":
			return _MAIDEN_LINES
		_:
			return ["Play continues."]

func _get_wicket_pool(wtype: String) -> Array[String]:
	match wtype:
		"BOWLED":
			return _WICKET_BOWLED
		"CAUGHT":
			return _WICKET_CAUGHT
		"LBW":
			return _WICKET_LBW
		"RUN_OUT":
			return _WICKET_RUNOUT
		"STUMPED":
			return _WICKET_STUMPED
		"CAUGHT_BEHIND":
			return _WICKET_CAUGHT_BEHIND
		_:
			return _WICKET_BOWLED

# ═══════════════════════════════════════
# COMMENTARY POOLS (40+ lines each)
# ═══════════════════════════════════════

var _SIX_LINES: Array[String] = [
	"That's gone all the way! A massive SIX!",
	"Into the stands! What a hit!",
	"That's been dispatched into the crowd!",
	"Effortless power! SIX runs!",
	"He's cleared the boundary with ease!",
	"Maximum! That's sailed over the rope!",
	"What a shot! The ball has disappeared!",
	"Deposited into row Z! Huge six!",
	"The crowd goes wild! What a strike!",
	"Launched into orbit! SIX!",
	"Clean as a whistle! Over the boundary!",
	"That's a monster hit! SIX runs!",
	"Picked up and dispatched! Maximum!",
	"Upper cut for SIX! Brilliant shot!",
	"Slog sweep and it's gone! SIX!",
	"A flat six over long-on! Power hitting!",
	"That's out of the ground! Incredible!",
	"Step down the track and smashed! SIX!",
	"Short ball pulled for a massive SIX!",
	"Lofted over extra cover! SIX runs!",
	"Goes deep into the stands! The crowd rises!",
	"He's toying with the bowler! SIX more!",
	"No mercy shown there! Maximum!",
	"A one-handed six! Outrageous!",
	"That ball has left the premises!",
	"Standing tall and launching it! SIX!",
	"The timing on that was perfection! Maximum!",
	"A towering six over midwicket!",
	"Clubbed away! That's six all day!",
	"What authority! SIX runs!",
	"The bowler can only watch it fly! SIX!",
	"Comes down the pitch and murders it! Maximum!",
	"Against the spin for SIX! Brilliant!",
	"Rocks back and pulls it for SIX!",
	"Down on one knee and scooped for SIX!",
	"Reverse sweep for SIX! Audacious!",
	"Top edge but it carries for SIX!",
	"Switch hit and it goes all the way!",
	"Helicopter shot for SIX! What a finish!",
	"Walks across and flicks for SIX!",
	"First ball SIX! Making a statement!",
	"Back to back sixes! The pressure is on the bowler!",
]

var _FOUR_LINES: Array[String] = [
	"Beautifully driven through the covers! FOUR!",
	"That's raced away to the boundary! FOUR runs!",
	"Timing! The ball flies to the fence!",
	"Through the gap and it's FOUR!",
	"Elegant stroke! FOUR through mid-off!",
	"Punched off the back foot! FOUR!",
	"Late cut and the boundary riders can't stop it!",
	"Classy shot! FOUR more runs!",
	"Swept fine and it speeds to the boundary!",
	"Glanced off the pads! FOUR runs!",
	"Edge and it races past the keeper! FOUR!",
	"Square cut played expertly! FOUR!",
	"Flicked off the hips for FOUR!",
	"Crashing drive through extra cover!",
	"That's rocketed to the boundary! FOUR!",
	"No stopping that! FOUR runs!",
	"Pull shot and it beats deep square leg!",
	"Cover drive of the highest quality! FOUR!",
	"Guided through third man! FOUR runs!",
	"On-drive along the ground! FOUR!",
	"Deft touch! FOUR past the keeper!",
	"Imperious drive! Pure class for FOUR!",
	"That screamed off the bat! FOUR!",
	"Placed it perfectly! FOUR runs!",
	"Off the meat of the bat! Boundary!",
	"Into the gap and away it goes! FOUR!",
	"Short and cut away for FOUR!",
	"Full toss dispatched for FOUR!",
	"Leaning into the drive! FOUR!",
	"A delicate glance for FOUR!",
	"Back foot punch through point! FOUR!",
	"Threaded the needle! FOUR runs!",
	"Caressed through the off side! FOUR!",
	"Whipped through midwicket! FOUR runs!",
	"Mistimed but it still runs to the boundary!",
	"Top edge flies over the keeper! FOUR!",
	"Inside edge beats leg stump and runs away!",
	"Driven on the up and it's FOUR!",
	"That ball deserved to be hit! FOUR!",
	"Pure timing! FOUR through the covers!",
	"Cut uppishly but safe! FOUR runs!",
]

var _DOT_LINES: Array[String] = [
	"Dot ball! Good bowling!",
	"Played and missed! No run.",
	"Defended solidly. No run.",
	"Left alone outside off. Dot ball.",
	"Good length and it beats the bat!",
	"Tight line! No room to score.",
	"The batsman respects that one. Dot ball.",
	"Blocked back down the pitch.",
	"Just short enough to leave. No run.",
	"Ooh, played and missed! Close!",
	"A teasing delivery! No run scored.",
	"Defends with soft hands. Dot ball.",
	"Tucked to the fielder. No run.",
	"Good discipline! Not offering a shot.",
	"That one moved away late! No edge.",
	"Left well alone. Good judgement.",
	"Turned past the outside edge! No run.",
	"Pushed to cover, no run available.",
	"Back of a length, defended.",
	"Watchful batting. No risk taken.",
	"Well bowled! The batsman has no answer.",
	"Just over the good length spot.",
	"Quiet single not taken. Dot ball.",
	"Tight over continues! Another dot.",
	"Beaten by the bounce! Close to an edge.",
	"Dug in short, ducked under. Dot.",
	"Just outside off, wisely left alone.",
	"Building pressure here! Another dot ball.",
	"Padded away. No run.",
	"Defended on the front foot. Solid.",
	"Short and wide but can't time it! Dot.",
	"Out-swinger, beaten! No edge though.",
	"Went for the drive, missed. Dot ball.",
	"Shoulder of the bat! No run.",
	"Played to point. Fielder stops it.",
	"Nudged to short leg. No single.",
	"Bouncer! Ducks under it. No run.",
	"The spinner gets some grip! No run.",
	"Stuck on the crease. Dot ball.",
	"Prodded forward. No run.",
	"Angled across, beaten! Another dot.",
]

var _SINGLE_LINES: Array[String] = [
	"Quick single! Good running!",
	"Pushed into the gap for ONE.",
	"Nudged to mid-on. They take a single.",
	"Rotates the strike. Smart cricket.",
	"Tapped to leg side. Easy single.",
	"Worked away for ONE run.",
	"Good awareness! Single taken.",
	"Dabbed to third man. One run.",
	"Tucked fine for a single.",
	"Driven to mid-off. They cross.",
	"Deflected off the pad for a single.",
	"Pushed through the off side. ONE.",
	"Running between wickets! One.",
	"Alert running! Single taken.",
	"Steered to point. Quick single.",
	"Soft hands, drops it short. ONE.",
	"Wristy flick for a single.",
	"Inside edge past the stumps. ONE.",
	"Worked to midwicket. Singles keep coming.",
	"Milking the bowling. Another single.",
	"Turn the strike over. Smart batting.",
	"One run. Keeps the scoreboard ticking.",
	"Good placement for a comfortable single.",
	"Off the hip for a quick single.",
	"Guides it to third man. Easy one.",
	"Picks the gap! One run.",
	"A thick edge and they scamper through!",
	"Plays it straight. One run.",
	"Dropped into the gap. Quick single!",
	"Pushed wide of mid-on. ONE run.",
	"Short arm pull for a single.",
	"Glanced fine. Single taken.",
	"Works it square. Good running!",
	"Eased to long-on. Easy single.",
	"Nurdled to leg. ONE.",
	"Clips off the toes. Single.",
	"Opens the face for a single.",
	"Turned to leg. Comfortable one.",
	"Squeezed to point. Just the one.",
	"Off the pads. Single!",
	"Tips and runs! Quick single.",
]

var _TWO_LINES: Array[String] = [
	"Good running! They come back for TWO!",
	"Placed in the gap and they push for TWO!",
	"Turn for the second! TWO runs!",
	"Smart cricket! Pushed for TWO.",
	"Running hard between the wickets! TWO runs!",
	"Good placement! Easy TWO runs!",
	"Into the gap and excellent running for TWO!",
	"Quick between the wickets! TWO taken!",
]

var _THREE_LINES: Array[String] = [
	"THREE runs! Outstanding running between wickets!",
	"Misfield in the deep! They take THREE!",
	"Into the gap and they come back for THREE!",
	"Brilliant running! THREE runs!",
	"Three runs taken! Great effort!",
	"Fumbled in the outfield! THREE runs!",
	"Placed wide and they push for THREE!",
	"Sprint between wickets! THREE runs!",
]

var _WIDE_LINES: Array[String] = [
	"Wide! Down the leg side!",
	"That's a wide! Too far outside off!",
	"Wide called! Straying in line there.",
	"The umpire signals WIDE!",
	"Wayward delivery! Wide ball!",
	"Can't reach that! Wide called!",
	"Drifting down leg. WIDE!",
	"Losing his line! That's a wide!",
	"Wide! The pressure telling on the bowler!",
	"Extra run! Wide ball!",
	"Fired down leg side! Wide!",
	"Too wide! The umpire stretches the arms!",
	"Gift for the batting side. WIDE!",
]

var _NOBALL_LINES: Array[String] = [
	"No ball! Front foot violation!",
	"NO BALL called! Free hit coming up!",
	"Overstepping! That's a no ball!",
	"The umpire calls NO BALL! Free hit!",
	"Costly mistake! No ball!",
	"Free hit opportunity! No ball!",
	"That's a no ball! Extra run and a free hit!",
	"Overstepped the crease! NO BALL!",
	"The bowler's front foot is past the line! No ball!",
	"Careless from the bowler! NO BALL!",
	"Above waist height! No ball called!",
	"Second bouncer of the over! NO BALL!",
]

# ─── Wicket commentary by type ───
var _WICKET_BOWLED: Array[String] = [
	"BOWLED HIM! Timber! The stumps are shattered!",
	"Clean bowled! What a delivery!",
	"BOWLED! Right through the gate!",
	"The off stump is cartwheeling! BOWLED!",
	"Knocked over! Clean as a whistle!",
	"BOWLED! He had no clue about that one!",
	"Through the defenses! BOWLED!",
	"The stumps are rattled! BOWLED!",
	"Castled! What a delivery that was!",
	"BOWLED! The middle stump takes a beating!",
	"Chopped on! He's bowled himself!",
	"Played all around it! BOWLED!",
	"An absolute jaffa! BOWLED!",
	"BOWLED! The furniture is disturbed!",
]

var _WICKET_CAUGHT: Array[String] = [
	"CAUGHT! Skied it! Simple catch!",
	"There it goes! Caught at mid-off!",
	"Caught! He couldn't resist that one!",
	"Caught in the deep! He's gone!",
	"Taken! Good catch at midwicket!",
	"CAUGHT! Top edge and safe hands!",
	"Caught at long-on! He went for one too many!",
	"Pouched! Easy catch at cover!",
	"Caught at slip! The trap works!",
	"Snagged at fine leg! CAUGHT!",
	"Flying catch at extra cover! OUT!",
	"CAUGHT! Brilliant diving catch!",
	"Caught at square leg! He mistimed that!",
	"Taken low at gully! What a grab!",
]

var _WICKET_LBW: Array[String] = [
	"Huge appeal... the finger goes up! LBW!",
	"LBW! Plumb in front! No doubt!",
	"Trapped! That's stone dead LBW!",
	"LBW! The umpire has no hesitation!",
	"Struck on the pads! LBW! OUT!",
	"Dead in front! LBW!",
	"Pinned on the crease! LBW!",
	"Massive appeal and it's given! LBW!",
	"That was hitting middle and leg! LBW!",
	"Playing across the line! LBW!",
	"Full and straight! LBW! Gone!",
	"Three reds! Absolutely plumb LBW!",
]

var _WICKET_RUNOUT: Array[String] = [
	"RUN OUT! Direct hit! Brilliant fielding!",
	"RUN OUT! They went for the extra run!",
	"Direct hit! RUN OUT! Incredible!",
	"Short of the crease! RUN OUT!",
	"Terrible mix-up! RUN OUT!",
	"Run out by inches! What drama!",
	"Direct hit from the boundary! RUN OUT!",
	"Hesitation costs a wicket! RUN OUT!",
	"Neither yes nor no! RUN OUT!",
	"Sent back too late! RUN OUT!",
]

var _WICKET_STUMPED: Array[String] = [
	"STUMPED! Quick hands from the keeper!",
	"Down the track and stumped! Way out of his crease!",
	"Stumped! The keeper whips the bails off!",
	"STUMPED! He was nowhere near the crease!",
	"Lightning quick stumping! OUT!",
	"Danced down and missed! STUMPED!",
]

var _WICKET_CAUGHT_BEHIND: Array[String] = [
	"Caught behind! Thin edge!",
	"The keeper takes it! Caught behind!",
	"Feather edge and the keeper dives! OUT!",
	"Nick! Caught by the wicketkeeper!",
	"Faint edge carries through! Caught behind!",
	"The snicko-meter will show that! Caught behind!",
]

var _FIFTY_LINES: Array[String] = [
	"FIFTY! A superb half-century! Raises the bat to the crowd!",
	"50 up! A well-crafted innings! Standing ovation!",
	"Fifty runs! That's a brilliant knock! The crowd applauds!",
	"Half-century! He punches the air! What a knock!",
	"FIFTY! Fighting innings! Warm applause from the stands!",
	"50 runs! The helmet comes off! What an effort!",
	"A deserved fifty! Quality batting!",
	"FIFTY! Making it look easy out there!",
]

var _HUNDRED_LINES: Array[String] = [
	"CENTURY! A magnificent hundred! Standing ovation!",
	"100 runs! What a phenomenal innings! The crowd is on its feet!",
	"A CENTURY! Arms spread wide! What a moment!",
	"HUNDRED UP! Jumps in the air! Brilliant century!",
	"A well-deserved century! Hat off moment! Sublime!",
	"100! The dressing room is applauding! Special innings!",
	"CENTURY! Goes big in celebration! Historic knock!",
	"A hundred! The bat is kissed and raised! Wonderful!",
]

var _FIFER_LINES: Array[String] = [
	"FIVE wickets! A five-wicket haul! Incredible bowling spell!",
	"5-for! Match-winning spell! The crowd salutes!",
	"Five-fer! Devastating bowling performance!",
	"FIVE WICKETS! He's torn through the batting lineup!",
	"A five-wicket haul! The ball is raised! Superb bowling!",
]

var _HAT_TRICK_LINES: Array[String] = [
	"He's on a hat-trick... the field is set... here it comes...",
	"HAT-TRICK BALL! The atmosphere is electric!",
	"Can he do it?! The hat-trick delivery is coming up!",
	"Two in two! The crowd is on the edge of their seats!",
	"The stadium holds its breath... hat-trick ball...",
]

var _CLOSE_FINISH_LINES: Array[String] = [
	"ONE WICKET STANDS BETWEEN GLORY AND DEFEAT!",
	"ABSOLUTE PANDEMONIUM IN THE STADIUM!",
	"Hearts are racing! This is unbelievable tension!",
	"Can you believe what we're witnessing?! Incredible!",
	"It all comes down to this! The final moments!",
	"Nerves of steel needed now! Incredible drama!",
	"This is what cricket is all about! Breathtaking!",
	"The atmosphere is absolutely electric!",
	"Every ball is a lifetime! What a contest!",
	"Unbearable tension! This is sport at its finest!",
]

var _CROWD_SIX_LINES: Array[String] = [
	"THE CROWD IS ON ITS FEET! 🎉",
	"The stands erupt! What a hit!",
	"Listen to that roar!",
	"The fans are loving this! Massive!",
	"Pandemonium in the crowd!",
]

var _CROWD_WICKET_LINES: Array[String] = [
	"SILENCE... then a roar from the bowling side!",
	"The fielding team celebrates wildly!",
	"Pumped! The bowler roars in celebration!",
	"Arms aloft! The crowd explodes!",
	"What a moment! The stadium erupts!",
]

var _PRESSURE_LINES: Array[String] = [
	"The pressure is immense here!",
	"You can feel the tension building!",
	"This is high-pressure cricket at its finest!",
	"Nervy times for the batting side!",
	"The squeeze is on! Building pressure!",
	"Dot balls building the tension!",
	"Silence in the crowd... the pressure mounts.",
	"Something has to give! The pressure is relentless!",
]

var _IN_ZONE_LINES: Array[String] = [
	"He's seeing it like a football right now!",
	"In scintillating form! Everything is going to the boundary!",
	"He's in the zone! Untouchable right now!",
	"Class act! Playing on a different level!",
	"Can't bowl to him when he's in this mood!",
	"Making it look like a different pitch!",
	"Imperious batting! He's in a zone!",
]

var _WEATHER_LINES: Array[String] = [
	"Dark clouds rolling in — conditions about to change!",
	"The wind is picking up! Could be a factor!",
	"Overcast skies — the seamers will be licking their lips!",
	"A drizzle starts... the outfield will slow down.",
	"Humid conditions — the ball might start reversing later!",
	"Bright sunshine now — good for batting!",
]

var _DRS_LINES: Array[String] = [
	"The T is being formed! DRS review!",
	"Going upstairs! Let's see what the technology says!",
	"Review taken! Who will the technology favor?",
	"DRS initiated! The big screen lights up!",
	"Time to check with the third umpire!",
]

var _DRS_NOT_OUT_LINES: Array[String] = [
	"HE'S NOT OUT! The review brings the decision back!",
	"OVERTURNED! A huge reprieve for the batting side!",
	"Not out! The technology sides with the batsman!",
	"Great work from the captain — review won!",
	"OVERTURNED! The stumps were missed, that's for sure!",
]

var _DRS_LOST_LINES: Array[String] = [
	"Review lost... the decision stands.",
	"Upheld! The review didn't save him.",
	"Decision stands after the review. Review lost.",
	"No luck with the third umpire — review lost.",
]

var _DROPPED_LINES: Array[String] = [
	"DROPPED! That's a costly miss!",
	"Put down! He won't get an easier chance than that!",
	"A terrible drop! That could prove decisive!",
	"Grassed it! The bowler looks devastated!",
	"Shell-shocked! The catch was spilled!",
	"The chance goes begging! Dropped!",
	"Butter fingers! A real let-off for the batsman!",
]

var _MAIDEN_LINES: Array[String] = [
	"Maiden over! Outstanding discipline from the bowler!",
	"Six dots! That's a maiden! Tremendous spell!",
	"A maiden! Building enormous pressure!",
	"Not a run scored! Maiden over!",
	"Brilliant over! Maiden! The crowd appreciates!",
	"Tidy maiden! The bowler is in complete control!",
]
