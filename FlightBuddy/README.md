# Flight Buddy

A tavern full of minigames for World of Warcraft flight paths. It pops up when you take off and opens on the
**Tavern**: today's specials on the chalkboard, a card for every game on the notice board, your patron title, and
Tavern Talk with the latest scores from your friends and guild.

| Game | What it is |
|---|---|
| **Rune Breaker** | Pick a Warcraft hero (Thrall, Jaina, Rexxar, Magni, Sylvanas, Tyrande, Vol'jin, Bolvar, Cairne), shatter the fire crystals, set off Bloodlust. |
| **Gryphon Greens** | Top-down mini golf time trial across eight race courses (Elwynn to Mulgore) plus a daily course and the Grand Tour. |
| **Featherbeard** | Thread a Wildhammer gryphon between the pillars of Dun Morogh. Free flights and a daily run with a ghost of your best. |
| **High Tinker Pinball** | Gnome-engineered pinball in Tinker Town, with jobs from Mekkatorque, gizmos and a 3-ball Air Show. |
| **Jewelcrafter's Bench** | Match-3 gem cutting: Work Orders (a campaign with stars), a Daily Commission everyone plays, and 90-second Gem Rush. |
| **Orb Cannon** | Fire orbs into the ceiling, match three of a kind and bring whole clusters down. Endless waves and a Daily Salvo everyone plays. |
| **Tavern Pool** | Eight-ball against three tavern regulars, with real ball physics. A Solo table and a Daily Table everyone plays, fewest shots wins. |
| **Death Roll** | One-on-one death rolls with a wager, played out as a fight in the Brawler's Pit. |

Every game opens on its own menu: play or resume, pick your hero / gryphon / table crew / ball and putter / bench cloth,
leaderboards, how to play, and options.

## Orb Cannon
Aim with the pointer and click to fire; orbs bank off the side walls. Three or more of a kind that touch burst, and
anything left hanging from nothing falls. Falling orbs are worth far more, so cut big clusters off at the top.
- **Right-click** (or click the waiting orb) to swap it into the cannon.
- A shot that bursts nothing is a **miss**. Run out of misses and the ceiling comes down a row; it is over when the orbs
  reach the red line.
- Bursting shots in a row build a **streak** multiplier. Four in a row loads a **Prismatic Orb** (matches anything);
  dropping six at once loads a **Goblin Bomb**.
- **Daily Salvo:** one board for everyone. Clear it in as few shots as you can.
- The game is saved after every shot.

## Tavern Pool
The table stands the long way up and you shoot from the bottom.
- **Aim** by pointing where the cue ball should go. The line shows what it will strike and which way that ball sets off.
  The mouse wheel turns the aim a hair (hold Shift for a finer one).
- **Shoot:** press and hold, draw the pointer back for power (the further, the harder), and let go. Right-click lets the cue down without shooting.
- **Spin:** drag the red dot on the cue ball (bottom left) to where the tip should strike. High makes the cue ball run
  on after it hits (follow), low stops it or brings it back (draw), left and right change how it comes off the cushions.
  Right-click the cue ball to go back to the middle. The line past the ghost ball shows where the cue ball will go.
- **Eight-ball:** the first ball you pot after the break makes you solids or stripes. Pot all seven, then the eight.
  Pot one of yours and you shoot again. A foul (the cue ball down a pocket, nothing struck, the wrong ball struck first)
  gives the other player the cue ball in hand. The eight down too soon loses the frame.
- Three regulars: the Barkeep, the Brawler and the Hustler.
- **Solo table** and **Daily Table:** clear every ball in as few shots as you can; a foul costs a shot.

## Jewelcrafter's Bench
Swap two neighbouring gems (click one then the other, or drag) to line up three or more.
- **4 in a row** cuts a Faceted gem (clears its row or column)
- **An L or T** cuts a Brilliant gem (bursts the 3x3 around it)
- **5 in a row** cuts a Prismatic gem (swap it with any gem to clear that colour)
- Swap two specials together for a bigger blast.

Work Orders bring goals: cut certain gems, clear the gold ore veins under the gems, or crack geode crusts
(a crusted gem can't be moved; match it to crack it). Leftover moves become a polish bonus.

## Install
Unzip so you have `World of Warcraft\_forever_\Interface\AddOns\FlightBuddy\FlightBuddy.toc`, then restart the game.
(After that, `/reload` picks up changes to existing files. New files or TOC edits need a full restart.)

## Commands
| Command | What it does |
|---|---|
| `/fb` | Open or close Flight Buddy |
| `/fb options` | Flight behaviour (open / ask / off), close on landing, score sharing, realm boards, sound, reduced motion, window size |
| `/fb test` | Preview the take-off prompt |
| `/fb resetpos` | Move the window back to the centre |

## Gryphon Greens
Click and drag back from anywhere, like a slingshot, then let go to putt. The dotted line shows your aim, and over
its first stretch it bends the way the green will take the ball at the pace you are pulling.
Pull into the red for maximum power, but your aim gets a little shaky.

It's a **time trial**: the clock runs from your first putt to your last cup. Each stroke under par takes 5 seconds off,
each stroke over par adds 5 seconds, and a hole-in-one takes off an extra 5 seconds. Bonuses can take off at most
half your time. Water, lava and slime cost a stroke.

**The whole green rolls**, like a real putting green. Every hole has its own shape: a green that leans to one side,
a two-tier green with the cup on the top shelf, a hog's back to hold the crest of, a valley that feeds the cup, a ridge
right across the lane, a double-breaker that falls one way and then the other, a banked corner you can ride round at pace, a crowned cup, a
punchbowl. The break is the obstacle, and the skill shot: read it right and the green does the work for you.

**Reading it**: light and shadow show the shape of the green, thin contour lines crowd together where it is steep, and
high ground is paler than low. Pull back to putt (or watch for a moment as a hole opens) and small beads drift downhill
all over it: pale and slow on a gentle lean, amber and quick on a steep one, red where it is too steep for a ball to stop
(it will roll on down). A putt across a slope **breaks** downhill, and breaks more the slower it is rolling; uphill costs
pace and downhill gives it. A punchbowl carries anything that dies inside it to the cup.

A few holes also keep one wall or post standing where the easy putt would go. Openings are never less than half the
lane, and every hole can be aced with the right shot.

- **Daily course**: the same course for everyone that day. Replay as often as you like; your best time counts.
- **Quick round**: any course, any time. Your best time on each course goes on that course's leaderboard.
- **Ball & putter**: unlock balls and putters by playing.

Each course has its own signature hazard, and every one is telegraphed so you can read it and time your putt:

| Course | Hazard |
|---|---|
| Elwynn & Stormwind | **Mages** throw a fireball at a ball that rolls into their dashed circle. Roll past fast or give them room. |
| Tirisfal | **Ghouls** lob slime. The landing spot darkens first; the splat stops a ball dead for a few seconds. |
| Durotar | **War drums** send a shockwave across their dashed circle on every beat. Dust devils roam the ravine. |
| Teldrassil | **Wisps** circle a spot like moving bumpers. |
| Echo Isles | **Tide pools** flood and drain. The dashed edge flashes blue just before the water comes in. |
| Dun Morogh | **Portcullis gates** slide shut on a beat; the slot flashes red just before. |
| Gnomeregan | **Blowers** push a ball along (and keep a stopped ball moving). |
| Mulgore | **Dust devils** wander the fairway and spin a ball around. |

Every hole also has a **lucky coin** on a riskier line: roll over it and finish the hole to take 3 seconds off your time.
Sand traps guard the greedy lines, boost lanes hug the walls for anyone who wants the fast way round, and every
blower hangs on a wall with its airflow drawn on the grass.

Slopes and boost pads are marked with arrows. A hazard that hits a resting ball never costs you a stroke.

### Flight rounds (new in 1.6.0)

Every flight path has its own round of Gryphon Greens. Pick a destination at the flight master and the round is built for that route: the longer the flight, the more holes (1 to 9), starting with holes from the land you take off over and ending with holes from where you land. Everyone flying the same route gets the same holes, so each route has its own record and its own leaderboard. Sink the last putt before your gryphon touches down for a "Landed it" bonus of 5 seconds. Every route you fly is added to your Flight Log (in the Gryphon Greens menu), where you can play it any time, in a city or at the forge, and its record counts wherever you play it. Only the landing bonus needs you to be in the air.

## Leaderboards
Every game has leaderboards for your **Friends**, your **Guild** and your whole **Realm**, for today and all time.
Results are shared with your guild, party or raid, online friends, and (if you leave realm boards on) a hidden realm
channel that only Flight Buddy uses. Nothing is sent anywhere else, and nothing appears in your chat.
Turn sharing off with **Share my scores**, or just the realm part with **Realm leaderboards**, in Options.

## Versus (live mini golf against other players)

Open Gryphon Greens, choose **Versus** from the menu, and invite up to three players: your group, your target, or anyone by name (`/fb vs Name`). They need Flight Buddy too.

- Everyone plays the same course at the same time. You see the other balls roll on your green in each player's colour.
- Fastest time wins: the clock, plus 5 seconds per stroke over par, minus 5 per stroke under. The match clock keeps running if you close the window.
- Pick the course and 3 or 6 holes in the lobby. Matches stay off the leaderboards.
- Challenges only pop up from people in your group, on your friends list or in your guild.
- No server: each shot is one small hidden addon whisper, replayed on the other players' screens.


## Death Roll

One-on-one death rolls with a wager. Open the **Roll** tab (or type `/deathroll`), set a wager and a starting number, and challenge your target, a group member or anyone by name (`/deathroll Name 50`). They get an Accept/Decline pop-up.

- Rolls are the game's real `/roll`: first 1 to the starting number, then 1 to whatever was rolled last. Roll a 1 and you lose.
- Each roll plays out as a hit in the Brawler's Pit: your roll is the health you are left with.
- The loser can pay up (the addon opens the trade and fills in the amount) or ask for double or nothing.
- The ledger tracks who owes whom, plus your wins, losses and net gold.
- Guildmates and groupmates with Flight Buddy get a notice and can watch live. Challenges only pop up from friends, guildmates and group members.
