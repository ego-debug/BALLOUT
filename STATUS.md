# Ballout — Project Debrief

_Snapshot for planning / cross-topic discussion (marketing, YouTube, monetisation)._

---

## 1. What the game is

**Ballout** is a Roblox dodgeball game — a deliberate spiritual successor to
**Knockout City** (Velan Studios, servers shut down June 2023). The pitch in one
line: *"Knockout City died. So I rebuilt it in Roblox."*

Fast 3v3 team dodgeball. Throw, catch, dodge, get knocked out. Two hits = KO.

---

## 2. Relationship to Knockout City (the legal line)

This distinction drives a lot of decisions, so it's worth stating plainly:

| Copied 1:1 — deliberately | Original — must stay ours |
|---|---|
| Mechanics, physics, timings | Maps and layouts |
| Throw/catch/dodge loop | Art, characters, UI |
| Control scheme | Names and branding |
| Special-ball *behaviours* | Special-ball *names* |

**Game mechanics are not copyrightable — map layouts and art are.**
So the feel is cloned faithfully; everything visual/nameable is built from
scratch. One map was scrapped and rebuilt mid-development after it was
confirmed to match a real KC layout too closely (same lane structure, same
hazard placement). That was the right call — a DMCA doesn't need to win in
court to get the game delisted, and the risk scales exactly with success.

**Marketing implication:** the recognisable thing in a short-form clip is the
*gameplay* — the charge-up, the perfect catch, the curve shot, the 2-hit KO.
That's all legally ours to show. Maps were never carrying the recognition, so
originality there costs nothing.

---

## 3. What's built and working

### Core combat (the KC loop — complete)
- **Throw** — tap for a light throw, hold to charge; soft lock-on aim assist
- **Catch** — timed window; perfect timing → **Overcharge** (2 tiers, faster throws)
- **Fake throw** — bait a catch, punish the whiff
- **Curve** (E spin) and **Lob** (Q flip) — trick-jump shots, KC-accurate
- **Pass** to teammates
- **Dodge/dash** with landing roll, doubles as a **shoulder bash** to steal
- **Ball-up (ballform)** — roll around as a ball
- **Glider**
- **2 hits = KO**, 2s respawn

### Commitment rules (the skill ceiling)
Stun, dodge and catch each **lock you out of everything else** until they
resolve — no animation-cancelling out of a bad read. Bad timing gets punished.
This is the discipline that made KC feel deep.

### Extra mechanics beyond KC
- **Dash bonk** — face-plant a wall or clash mid-dash → floored, birds circling
- **Multi-ball** — catching with full hands pops your held ball loose

### Lobby + match flow (end-to-end working)
- **HQ rooftop city** as a social lobby — infinite health, free ball to mess with
- **Queue rooms** — 6 walk-in rooms (2 per mode); stand in one to queue
- **Matchmaking** — waits 3 min for real players, then fills with bots
- **Team KO 3v3** — teams assigned, first to 10 KOs, winner splash, back to lobby
- **Bots** fill empty slots (beatable — 35% catch rate)
- **Training bot** — chalk drill circle; stand in it and it winds up and throws at
  you, refills its own ball. Genuinely useful for practising catch timing.

### Fairness / monetisation groundwork
- **All players locked to one body build** (same height, blocky proportions).
  Equal jump height isn't equal reach — a taller avatar clears higher ledges and
  is a bigger target. Locking it keeps map traversal fair **and** makes any
  future cosmetics purely cosmetic (no pay-to-win).

---

## 4. Maps

**One map exists.**

### "Scaffold Row" — construction site (blockout ~complete, not yet playable in matches)
Original layout. Rooftop construction site above a cloud void.
- Excavated central basin with smooth hillsides (real elevation change)
- **Two swinging wrecking balls** — live, physics pendulums, knock players flying
- **Two void pits** with **vertical shipping-container ferries** — ridable moving
  platforms; miss the timing and you fall
- North boarding hall + south sniper perch (two distinct buildings)
- Central tower with timber scaffolding, reached by a real parkour climb
- Sealed perimeter with **4 deliberate drop gaps** — you can be knocked off the map
- Custom-generated meshes throughout (buildings, containers, cranes, skyline)

**A second arena ("Block Party") exists as the current match arena** but is
placeholder-grade — Scaffold Row is meant to replace it.

---

## 5. What's still missing

### Blocking a real launch
1. **Match HUD** — score/timer are on arena walls only, nothing on screen. Biggest single gap.
2. **Scaffold Row not wired into matches** — still sits in a dev yard; needs hooking up + dev-marker cleanup
3. **Sound** — the game is essentially silent. No SFX, no music.
4. **Mobile controls** — Roblox is mobile-majority; currently PC/gamepad only
5. **More maps** — one arena isn't enough for retention

### Signature features not built yet
6. **Ball-up teammate throws** — KC's most iconic mechanic (get thrown by a teammate as a ball). Big TikTok moment; currently missing.
7. **Special balls** — Bomb / Cage / Moon / Sniper / Multi (behaviours designed, names need to be original, none implemented)
8. **Party system** — can't queue with friends yet
9. **Roaming bots** — they stand still and throw; don't chase or dodge

### Polish / longer term
10. **Custom animations** — currently IK stand-ins, not authored animation
11. **Cosmetics shop** — outfits, intros, poses, ball trails (groundwork laid, nothing built)
12. **Progression** — no XP, levels, or unlocks

---

## 6. Honest state assessment

**The hard part is done.** The combat loop is complete and feels right, and the
full lobby → queue → match → back to lobby cycle works end to end. That's
usually where these projects die.

**What's left is mostly breadth, not depth** — HUD, sound, mobile, more maps,
more mechanics. Individually straightforward; collectively a lot of work.

**Nearest playable milestone:** HUD + wire up Scaffold Row + basic sound would
make it demo-able to real players.

**Strongest content hooks for short-form video:**
- The revival story ("KC died, I rebuilt it") — strongest single hook
- Wrecking ball punting someone off a skyscraper
- Perfect catch → Overcharge → counter-KO
- Ball-up teammate throws *(once built — worth prioritising for this reason alone)*
- Dev-progress content: the map went through ~85 documented revisions
