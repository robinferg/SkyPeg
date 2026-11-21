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

Every game opens on its own menu: play or resume, pick your hero / gryphon / table crew / ball and putter / bench cloth,
leaderboards, how to play, and options.

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

Every hole is built round one idea standing where the easy putt would go: a wall across half the lane to bank round,
a gate to thread, a post to pick a side of, a rise to go over or round, a pass between two rises that gathers a
well-aimed putt, a broad swell that bends the line. Openings are never less than half the lane, and every hole can be
aced with the right shot.

The greens have **contours**, like a real putting green. A shaded dome is a rise and a dish is a hollow; chevrons drift
downhill to show which way a ball will roll. A putt across a slope **breaks** downhill, and breaks more the slower it is
rolling. Putt up a steep rise too softly and the ball runs out of pace and rolls back; hit it firmly and it goes over
the top. Some cups sit on a **crown** (a level top with a slope all round: too soft comes back to you, too hard runs off
the far side), some at the bottom of a **punchbowl** that gathers anything that reaches it, and some have a
**backstop**: a rise behind the cup that brings a bold putt back. The chevrons are pale and slow on a gentle slope,
amber and quick on a steep one.

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
