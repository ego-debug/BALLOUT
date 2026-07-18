# Ballout — Design Spec

A Roblox dodgeball game modeled on **Knockout City** (Velan Studios), rebranded and tweaked as **Ballout**.

This doc has two layers:
- **CANON** — mechanics verified from research on Knockout City (cited, fact-checked). These are the rules that *make the game the game*.
- **PROPOSED (Roblox)** — our starting numbers in Roblox units. KC never published engine values, so these are our translations of the *feel* descriptions, meant to be tuned live in-engine. Every number here is a starting point, not gospel.

Legend: 🟢 canon (verified) · 🔵 our proposed value to tune · ⚪ open question / undecided

---

## 1. The Core Throw / Catch Loop 🟢

The whole game orbits one loop: **throw → catch → throw back, faster.**

- **Throw** — tap to throw a light/slow ball; **hold to charge** a faster projectile, release to fire. 🟢
- **Auto-aim** — throws auto-target the nearest enemy in line of sight (all throws, not just charged). 🟢 *(For Ballout we'll do soft lock-on / aim assist, not hard lock.)*
- **Catch** — hold the catch input, timed so the ball lands in the character's arms. A **Perfect Catch** (press just before impact) triggers **Overcharge**. 🟢
- **Overcharge / charge tiers** — a perfect catch starts your next throw fully charged. Passing/perfect-catching between teammates stacks tiers **up to Tier 6**; 4+ tiers = "Supercharged," each tier increasing throw velocity. Charge **decays if you don't throw promptly.** 🟢
- **Fake throw** — keep hold of the ball to bait a catch; an enemy who bites is **vulnerable for a brief moment.** 🟢
- **Regaining a thrown ball** — only two ways: **catch it**, or **tackle the holder.** Dodging does NOT grab the ball — it bounces away. 🟢
- **Interception** — any player can catch a throw aimed at a teammate. 🟢
- **Throw shaping** — **curve** shots (thrown while spinning) and **lob/height** shots (thrown mid-flip). 🟢

### Proposed Roblox numbers 🔵
| Value | Proposed | Notes |
|---|---|---|
| Light throw speed | 90 studs/s | tap throw, catchable |
| Charged throw speed | 160 studs/s | full hold |
| Supercharged (Tier 4–6) | 200 → 240 studs/s | scales per tier |
| Full charge time | 1.2 s | hold-to-max |
| Catch active window | 0.40 s | from input press |
| **Perfect** catch sub-window | last 0.12 s before impact | triggers Overcharge |
| Overcharge decay | ~2.0 s to bleed one tier | forces "use it or lose it" |
| Fake-throw vulnerability | 0.5 s | attacker locked out of catch |
| Curve max lateral accel | ~40 studs/s² | tune for readable arc |

---

## 2. Ball Handling & Special Balls 🟢

One special ball spawns randomly on the map (standard dodgeballs are otherwise the norm). Roster is **5 balls** (research refuted a rumored 6th "Soda Ball" — 0-3):

| Ball | Behavior 🟢 | Proposed tuning 🔵 |
|---|---|---|
| **Standard Dodgeball** | Curve + lob + full Overcharge tiers. | Baseline (see §1). |
| **Bomb Ball** | Timer starts on pickup (beeps accelerate), auto-explodes on expiry regardless of holder. **Sticks to surfaces** (trap), AoE damage hits *everyone* incl. teammates & thrower. | ~15 s fuse; blast radius ~14 studs. |
| **Cage Ball** | No impact damage — forces the struck target into **Ballform** (~5.5 s), helpless (can't catch/dodge, can roll). Either team can scoop & throw them for instant KO or off-map. | Cage duration 5.5 s. |
| **Moon Ball** | Holder gets **~half gravity** (higher jumps, slow fall, long glide). Hit enemies are flung up with the same low-grav effect until they land. | Holder gravity ×0.5; knock-up ~40 studs/s. |
| **Sniper Ball** | **Straight throws only** (no lob/curve). Charged = red targeting line visible to all, locks at long range (needs line-of-sight to fire), **fastest ball in game**. Uncharged = slow fumble. | Charged 300 studs/s; uncharged 60. |
| **Multi Ball** | Carry **3 at once** (1 in hand, 2 orbiting); fire in rapid succession, capacity drops 3→2→1; can hand spares to ball-less teammates. | 3 charges, 0.25 s between shots. |

---

## 3. Ball-Up (the signature mechanic) 🟢

- Hold the ball-up input to roll into a **throwable ball**; a teammate picks you up and throws you. 🟢
- Hitting an enemy while in ball form is an **instant KO regardless of health.** 🟢
- A defender can **catch** the thrown ball-form player to negate it. 🟢
- **Special / Ultimate Throw** — a fully-charged teammate launches the balled player **high into the air → big AoE explosion**, KO'ing everyone in the blast zone; the flier gets a **bird's-eye view and controls the landing spot.** 🟢

### Proposed 🔵
| Value | Proposed |
|---|---|
| Ball-up roll speed | 45 studs/s |
| Thrown ball-form speed | 130 studs/s |
| Special Throw apex height | ~120 studs |
| Special Throw blast radius | ~22 studs |
| Landing-control steer radius | ~30 studs |

---

## 4. Movement & Feel 🔵 (mostly our invention — KC values not public)

KC feel: **fast, agile, snappy** — quicker than default Roblox, with a committing dodge and floaty air control.

| Value | Roblox default | Proposed Ballout | Rationale |
|---|---|---|---|
| Character height | ~5 studs | keep ~5 | R15 standard |
| Ball diameter | — | **2.0 studs** | chunky, readable, ~body-width |
| Walk/run speed | 16 | **22** | faster, KC-like snap |
| Jump (height) | ~7 studs | **~9 studs** | JumpHeight-based |
| Gravity | 196.2 | keep 196.2 | Moon Ball halves it locally |
| Dodge/roll distance | — | **20 studs** | quick burst |
| Dodge duration | — | **0.35 s** | commit window |
| Dodge i-frames | — | **first 0.20 s** | brief invuln vs balls |
| Dodge cooldown | — | **0.6 s** | anti-spam |
| Tackle lunge | — | **15 studs / 0.3 s** | steal ball from holder |
| Glide fall speed cap | — | **~40 studs/s** | air float after jump/Moon |

---

## 5. Health / KO System 🟢 (locked)

- **2 unblocked hits → KO.** First hit staggers, second KOs. ✅ confirmed by user.
- **Catch fully negates** an incoming hit (no damage) and hands you the ball.
- **Ball-form hit = instant KO.** Cage/off-map = instant KO.
- **Respawn delay:** 3 s. 🔵
- Health regenerates a few seconds after last hit (KC-style, keeps pace up). 🔵

---

## 6. Teams, Modes, Maps ⚪ (thin in research — to expand)

- Default **3v3**. 🟢
- Modes named in sources (rulesets not fully verified): **Team KO** (first to ~10 KOs), **Diamond Dash** (collect diamonds dropped by KO'd enemies), **Ball-Up Brawl** (only ball-ups score), **Face-Off** (1v1). ⚪
- Maps: launch had ~5, each with environmental hazards (traffic, rooftop ledges → off-map KOs). ⚪ We'll design original Ballout arenas.

---

## 7. Design Intent: 1:1 mechanics, original expression (IP strategy)

**Goal: the *feel and vibe* are a 1:1 clone of Knockout City's gameplay.** Mechanics, physics, and timing (§§1–6) are copied faithfully — these are not copyrightable, so cloning them is fine.

**What we change (to stay clear of DMCA / IP):** the copyrightable *expression* only —
- **Maps & environments** — all original Ballout arenas (do not reproduce KC's maps/layouts).
- **Some game modes** — reworked/renamed, our own twists.
- **Naming & branding** — game name "Ballout"; avoid KC's exact names/logos. Rename balls to our own flavor (the *behaviors* stay 1:1, only the names/skins change).
- **Art direction, characters, UI, music, VFX** — all original.

Rule of thumb: **copy the how, not the what-it-looks-like-and-is-called.**

### Ball naming (behavior 1:1, names ours) ⚪ to finalize
| KC (reference) | Ballout name (draft) |
|---|---|
| Standard Dodgeball | Standard Ball |
| Bomb Ball | _TBD_ |
| Cage Ball | _TBD_ |
| Moon Ball | _TBD_ |
| Sniper Ball | _TBD_ |
| Multi Ball | _TBD_ |

---

## 8. Controls 🟢 (KC scheme, adapted to Roblox)

Knockout City's mapping (verified) with our Roblox bindings. The **scheme is copied 1:1** — throw/catch on the two triggers, ball-up on the shoulder, etc. — only the exact keys are conventionalized for Roblox PC + gamepad.

Verified via Shacknews' full KC keybinding table (2026-07-14) — the key discovery:
**curve and lob come from dedicated TRICK JUMPS (Spin = E, Flip = Q), not from
strafing or plain jumping.** Throw during the spin = curveball (direction = held
movement); throw during the flip = lob.

| Action | KC (PC / Xbox·PS) 🟢 | Ballout PC ✅ | Ballout Gamepad ✅ |
|---|---|---|---|
| **Throw** (hold = charge) | Left Click / RT·R2 | Left Mouse | ButtonR2 |
| **Catch** | Right Click / LT·L2 | Right Mouse | ButtonL2 |
| **Spin (→ curve)** | E / B·Circle | **E** | **ButtonB** |
| **Flip (→ lob)** | Q / Y·Triangle | **Q** | **ButtonY** |
| **Fake throw** | F / R-stick click | F | ButtonR3 |
| **Dodge / bash** | Left Ctrl / X·Square | Left Ctrl | ButtonX |
| **Drop ball** | G / D-pad Left | G | D-pad Left |
| **Pass** | Middle Mouse / LB·L1 | ⚪ later (needs teammates) | ⚪ |
| **Ball-Up (Ballform)** | hold Left Alt / RB·R1 | ⚪ Left Alt (when built) | ⚪ ButtonR1 |
| **Sprint** | Left Shift / L-stick click | ⚪ later | ⚪ |
| **Jump** | Space / A·Cross | Space | ButtonA |
| **Taunt / Emote** | 1 · R / D-pad Up | ⚪ later | ⚪ |

Notes:
- **Tackle isn't its own input** in KC — you dodge into an enemy holding a ball.
- Plain jump does NOT lob — only the Q flip does. Charged spin-throw = fast curve, uncharged = slow curve (our charge system covers this naturally).
- Roblox mobile/touch layout is a later pass. ⚪

---

## Research provenance & gaps

- Sources: Push Square, TheGamer, Digital Trends, RealSport101, Gamepur, GameRant, and the Knockout City Fandom wiki. All **secondary** (no official Velan design docs exist; servers shut down June 2023).
- Confidently verified: throw/catch loop, Overcharge tiers, fake throw, ball-up + Special Throw, all 5 special balls.
- **Open (need our own tuning/decision):** exact KO hit count & respawn timing; precise catch/dodge/tackle frame windows; full mode rulesets; maps/hazards; progression/cosmetics/crews.
- Every 🔵 number is a **starting point for live tuning in Studio**, not a claim about KC's actual values.
