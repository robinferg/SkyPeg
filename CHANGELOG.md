# Flight Buddy changelog

## 2.4.0

**Two new games: Orb Cannon and Tavern Pool.**

**Orb Cannon.** Aim with the pointer and fire orbs up into the ceiling; they bank off the side walls. Three or more of a kind that touch burst, and anything left hanging from nothing falls, which is where the big points are.

- A shot that bursts nothing is a miss; run out of misses and the ceiling comes down a row. It is over when the orbs reach the line
- Right-click (or click the waiting orb) to swap it into the cannon
- Bursting shots in a row build a streak multiplier. Four in a row loads a Prismatic Orb that matches anything; dropping six at once loads a Goblin Bomb
- Endless waves that get harder, and a Daily Salvo: one board for everyone, cleared in as few shots as you can
- Leaderboards for both, and the game is saved after every shot. `/fb orbs` jumps straight in

**Tavern Pool.** Eight-ball on a proper table: sixteen balls, six pockets, cushions with jaws, and the rules of the game.

- Press on the table to aim: the cue points at the pointer and stays where you leave it. The line shows what the cue ball will strike and which way that ball sets off. The mouse wheel turns the aim a hair
- Draw the power bar down and let go to shoot. The cue on the table comes back as far as you pull, and a long pull is a hard shot
- **Alliance and Horde balls:** seven blue with the Alliance crest, seven red with the Horde's, and a skull on the eight. A switch in the menu brings back classic solids and stripes
- **Spin.** Drag the dot on the cue ball to where the tip should strike: high and the cue ball runs on after it hits, low and it stops dead or comes back, left or right and it comes off the cushions that way. Balls skid before they settle into a roll, as real ones do
- Balls turn as they roll (the cue ball's two red dots give its spin away) and drop into the pockets
- When the eight loses you the frame, the card says exactly why (the cue ball went down too, another ball was struck first, it went down with your last ball, or before your seven), and you are told the moment you get onto the eight
- Three regulars to play, from the Barkeep to the Hustler. Pot the first ball after the break to take your seven, clear them, then the eight
- Fouls give the other player the cue ball in hand
- A Solo table and a Daily Table (the same balls for everyone): clear them in the fewest shots, with leaderboards for both
- Saved after every shot, even with the balls still rolling. `/fb pool` jumps straight in

**Gryphon Greens: a ball no longer sits on a steep slope.** Grass now holds a slow ball less than a fast one. A putt that runs out of pace on steep ground rolls back down and keeps rolling until the ground eases off. The red beads mark exactly the ground a ball cannot stop on. Putts also die a little more softly on the flat, and three greens that lean all one way (Iceflow Lake, Ban'ethil Barrow, the Gates of Orgrimmar) lean a little less, so a ball can still be stopped on them. Because balls roll differently, golf best times and golf score boards start fresh.

**Nothing you have earned gets lost.**

- **Gryphon Greens** writes your round down at every hole and every stroke, not only when the window closes, so a crash or a dropped connection costs one shot at most
- **Featherbeard:** a flight cut short because the window closed (you landed, or combat started) now counts as a finished flight, record and all
- **High Tinker Pinball:** logging out or reloading with a game on the table banks the score so far
- **Jewelcrafter's Bench:** a Work Order you left half done to play the daily is offered again on the menu
- Every game is asked to save on its own at logout, so one that trips can no longer stop the others

**Also in this version** (2.3.1 was never released on its own):

- **Gryphon Greens: the slopes mean it now.** Leaning greens are much steeper, close to the steepest a ball can still stop on, so a soft putt breaks about twice as far as a firm one: hit hard through the break, or play it soft and let the green carry it. Climbs are far taller and longer: a normal putt dies on the way up and rolls back, so a big hill has to be hit like one. Every hole re-tested and given a new par
- **Rune Breaker no longer loses your run.** Closing the window while the first ball of a session was still in flight (a flight landing mid-shot did it) saved nothing, and the next login started you again at level 1. A run now survives closing or logging out at any moment
- **Death Roll: an accepted challenge now starts on both screens.** The challenger could be left on "Waiting for ... to accept" while the other player was already in the game, because the two games spelled the realm differently and so did not recognise each other. Flight Buddy now learns how the server writes your realm a few seconds after login. Inside a game the two players are told apart by name and by the game's own number, never by realm, so the answer to your challenge is recognised however the server signs it. An accept is whispered to every spelling of the challenger at once, said on the guild and group channels as well, and repeated until the other game confirms it; rolls heard on those channels count if the whisper was lost. **Both players need this version**: an older Flight Buddy can still fail to answer. If a challenge sits unanswered you are told so after twenty seconds, and `/deathroll debug` prints what was sent and received. Golf Versus invites got the realm fix too
- **Death Roll shows your opponent's character.** When they are standing with you the pit shows them exactly as they are. When they are somewhere else it now shows their race and what they are wearing, sent with the challenge and remembered for next time, instead of a class crest. `/deathroll look` shows what your opponents will see of you
- Because the greens changed, golf best times and golf score boards start fresh once more. Nothing else is reset, and from now on golf only resets when the courses themselves change

## 2.3.0

**Gryphon Greens: the whole green rolls.** The small round rises and hollows are gone. Every green is now one surface with its own shape, like a real putting green, and the break itself is the obstacle and the skill shot.

- **Eleven kinds of green.** Greens that lean to one side, two-tier greens with the cup on the top shelf, hog's backs to hold the crest of, valleys that feed the cup, double-breakers and rolling greens that fall one way and then the other, banked corners you can ride round at pace, ridges right across the lane to carry, crowned cups, punchbowls, and downhill greens with a backstop behind the hole
- **Reading the green.** Light and shadow show the shape of the green, and thin contour lines crowd together where it is steep. Pull back to putt and small beads drift downhill all over it: pale and slow on a gentle lean, amber on a steep one, red where a ball cannot stop. Let go and they fade away
- **Punchbowls gather properly.** The slope now holds all the way down to the cup, so a ball that dies inside the bowl rolls in instead of stopping on its side
- **Thoradin's Wall has three ways through.** The ramp launches from a normal firm putt (and tells you when you were too slow), and the door in the wall is a tunnel that lets the ball out on the far side
- **Lifts carry the ball in plain sight.** In Thunder Bluff the platform rises with the ball on it; in the Undercity it sinks away on its own iron-and-stone elevator. No more rolling underground
- **Circle of Binding:** the crack in the rock is half again as wide, so a ball that reaches it goes in
- Every hole re-tested with a strong player and a casual one, and given a new par
- Best times set on the old greens are retired again: course, route and today's daily bests start fresh, and times are only ranked against others set on this version. Stats, unlocks and the flight log are untouched
- Versus needs both players on this version (the game tells you if they are not)

## 2.2.0

**Gryphon Greens rebuilt.** The holes had become so easy that a strong player could bank a whole round down to 0 seconds. Every hole has been redesigned on its existing layout, following what the best mini golf games do: one idea per hole, a wide safe way round, a skilful line to the cup, and slopes that help a good putt as often as they punish a poor one.

- **Greens with contours, like real putting.** Rises and hollows are shaded into the felt, with chevrons drifting downhill: pale and slow on a gentle slope, amber and quick on a steep one. A putt across a slope breaks downhill, and breaks more the slower it rolls. Putt up a steep rise too softly and the ball runs out of pace and rolls back down; hit it firmly and it goes over the top
- **The aim line reads the break.** Over its first stretch the dotted line bends the way the green will take the ball at the pace you are pulling. Rails, bounces and anything that moves are still yours to judge
- **One idea per hole.** A wall across half the lane to bank round, a blocker to go either side of, a post, a rise to go over or round, a pass between two rises that gathers a well-aimed putt, a broad swell that bends the line. No opening is ever less than half the lane
- **Crowned cups, punchbowls and backstops.** Some cups sit on a level crown with a slope all round; some lie in a punchbowl that gathers anything over its lip; some have a rise behind them that brings a bold putt back
- **A real cup lip.** A putt catching the edge of the cup has to arrive slower than one dead centre
- **Painted props** for each land (stumps in Elwynn, kegs in Dun Morogh, moonstones in Teldrassil and so on) replace the plain round posts
- **More creatures on the course.** Holes that had nothing moving now have one of the locals walking the lane: kobolds at Northshire, a harvest golem at Westfall, rams, yetis, kodos, harpies, ghouls, wisps and more
- **Honest pars**, set by play-testing every rebuilt hole with a strong player and a casual one
- **Bonuses can take off at most half your time**, so no round can be banked down to nothing
- Circle of Binding's crack no longer fires the ball straight into the cup
- Best times set on the old holes are retired: course, route and today's daily bests start fresh, and new times are never ranked against times from older versions. Your stats, unlocks and flight log are kept
- Versus needs both players on this version (the game tells you if they are not)

Also in this version:

- **Tavern: the games are much easier to see.** Three large cabinets to a row with each game's name on a big brass plate and your progress written beneath; the shelf is gone and the wall behind is darker so the games stand out
- Larger writing on the marquee, the chalkboard, the notice board and the keeper's scroll
- Pointing at a cabinet shows it on the marquee; games still being built wait on a second floor under their dust sheets
- **Fixed:** "No player named ... is currently playing" appearing in chat after loading screens. Flight Buddy was answering its own score request with a whisper the server could not deliver
- **Fixed:** Versus and Death Roll invites, accepts and score replies between players now reach each other on realms where the server writes the realm name differently from the game; players are whispered by name, and each player appears once on the boards and in the Death Roll ledger

## 2.1.0
- **Death Roll:** a new game. Challenge anyone to a one-on-one death roll for gold, like a duel request, from the Roll tab or `/deathroll Name 50`. Rolls use the real `/roll`, every roll plays out as a blow in the Brawler's Pit, the loser can go double or nothing, and guildmates and groupmates with Flight Buddy can watch the play-by-play
- **Versus:** live mini golf against up to three other players. Everyone plays the same course at once and you watch the other balls roll. Open Gryphon Greens, choose Versus, and invite your group, your target or anyone by name (`/fb vs Name`)
- **Tornadoes** now grab the ball, spin it up the funnel and throw it, and they take a ball that is sitting still too
- Hazards no longer wait for you to putt: a drum beat, a rising tide or a mage will move a ball left sitting in range (no stroke counted)
- New tornado art
- **The Tavern is now an arcade hall:** every game is a cabinet on the floor (eight to a page, with dust sheets over the ones still being built), a marquee with one PLAY button always has something worth playing, and Pim Tokenspring, keeper of the games, tells you about whatever you point at. Round game tokens replace the text tabs, today's specials are ticked off on a chalkboard, and friend and guild scores are pinned to the notice board
- Fans now blow a ball that is left sitting in their stream
- Tornadoes always throw the ball onto open ground on the course
- Fixed: the tunnel through Ban'ethil Barrow could not be entered
- Fixed: Burning Blade Coven's picture did not line up with the hole; its lava spill, coin and fel sparks are back where they belong
- Fixed: a few coins sat on the rail, and a narrow speed strip had no arrows

## 2.0.1
- Restored each course's signature hazards that went missing in 2.0.0: Stormwind mages, slime-lobbing ghouls, the Scarlet sorcerer, orc war drums, dust devils, wisps, tide pools, the witch doctor and the Tinker Town blower

## 2.0.0
- Gryphon Greens: all nine courses rebuilt with new hand-painted mini golf art (54 holes)
- New obstacles: aimable launch cannons, ramps, the Deeprun Tram, moonwells, hexes, kodo and murloc carriers, tides
- Flight rounds: every flight path is its own course, with a Flight Log to replay them on the ground
- New Arathi & Hillsbrad course in Quick Round
- Rune Breaker: 10 ball skins to win by feats, new rune cannon and gryphon nest, hero splash art when a Hero Rune fires
