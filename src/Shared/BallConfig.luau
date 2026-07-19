--!strict
-- Ballout | BallConfig
-- Every tunable "feel" number lives here so we can dial the game in live.
-- Values are starting points translated from the Knockout City feel research
-- (see DESIGN.md). Tune freely.

local BallConfig = {}

-- ── Ball ────────────────────────────────────────────────────────────────
BallConfig.BALL_DIAMETER = 1.8 -- KC ratio: ball is about a third of character
                               -- height; the ballform curl (2.8) stays bigger
BallConfig.BALL_COLOR = Color3.fromRGB(235, 90, 25) -- Ballout orange-red
BallConfig.BALL_GRAVITY = 45                         -- studs/s^2 (flatter than world 196 for punchy throws)

-- ── Throw speeds (studs/sec) ────────────────────────────────────────────
-- Ladder: regular full charge 140 -> Tier 1 purple 160 (the old regular)
-- -> Tier 2 purple 180 (the old purple) -> +20 per tier beyond.
BallConfig.LIGHT_SPEED = 60       -- tap throw
BallConfig.CHARGED_SPEED = 140    -- full hold (regular ball)
BallConfig.SUPER_STEP = 20        -- extra speed per Overcharge tier
BallConfig.MAX_TIER = 2           -- caps at Tier 2 (160 -> 180, no higher)
-- The purple does NOT decay on a timer: hold your ground and it stays.
-- RUN with it and it fades.
BallConfig.CHARGE_RUN_SPEED = 8   -- moving faster than this counts as running
BallConfig.CHARGE_RUN_GRACE = 0.5 -- seconds of running before the charge fades
BallConfig.FULL_CHARGE_TIME = 1.2 -- seconds hold to reach CHARGED_SPEED
BallConfig.CHARGE_WALK_MULT = 1 / 3 -- winding up slows you to a third of walk
                                    -- speed — no walking fast, no sprinting
BallConfig.MAX_FLIGHT_TIME = 5.0  -- safety: ball goes free after this long airborne

-- ── Throw shaping ───────────────────────────────────────────────────────
BallConfig.BASE_ARC = 2.5        -- gentle vertical bow on straight throws (studs)
BallConfig.CURVE_OFFSET = 55     -- max sideways bow at full strafe (studs)
BallConfig.CURVE_CONTROL_T = 0.22 -- bow sits close to the thrower: ball wraps out
                                  -- wide (almost behind you) then turns onto target
BallConfig.CURVE_SPIN_TIME = 0.2  -- character does a fast full 360 on the spin jump
BallConfig.CURVE_SPIRAL_RADIUS = 1.1 -- curveballs corkscrew around their path
BallConfig.CURVE_SPIRAL_TURNS = 3    -- full spirals over the flight
BallConfig.AIR_THROW_HANG = 0.35  -- aerial throw: vertical position freezes this long
                                  -- (horizontal air control stays free)
BallConfig.LOB_ARC = 40          -- lob arc height — STEEP, clears walls/obstacles
BallConfig.LOB_CONTROL_T = 0.25  -- lob apex sits near the thrower: straight up, then drops on target
BallConfig.LOB_SPEED_MULT = 0.75 -- lobs travel slower

-- ── Movement (applied to every character on spawn) ──────────────────────
BallConfig.WALK_SPEED = 22       -- Roblox default is 16; KC feel is faster
BallConfig.SPRINT_SPEED = 32     -- Shift + forward (or forward-diagonal) only
BallConfig.SPRINT_LEAN_DEG = 14  -- body tips into the run while sprinting
-- Height scale (KC chimney reference, character ~5 studs tall):
--   Q flip apex = feet just above standing HEAD height (~5.5 studs rise)
--   jump        = feet clearly above the Q apex     (~7 studs rise)
BallConfig.JUMP_HEIGHT = 7
BallConfig.DODGE_SPEED = 70      -- dash burst velocity (studs/s)
BallConfig.DODGE_TIME = 0.28     -- dash duration (~20 studs total)
BallConfig.DODGE_COOLDOWN = 0.6  -- measured AFTER the landing roll finishes
BallConfig.DASH_PITCH_DEG = 38   -- forward LEAN of the dash lunge (not flat prone)
BallConfig.DASH_ROLL_TIME = 0.35 -- fast parkour landing roll at the end of the dash
BallConfig.DASH_ROLL_SPEED = 16  -- roll starts near walk speed and decays to zero
BallConfig.DASH_BALL_RANGE = 5   -- bashing within this range of a loose ball pops it up
BallConfig.POP_UP_SPEED = 55     -- vertical launch speed of a bashed ball

-- ── Loose-ball physics (real dodgeball feel: bounce, roll, settle) ──────
BallConfig.BOUNCE_RESTITUTION = 0.55 -- energy kept per bounce
BallConfig.BOUNCE_FRICTION = 0.75    -- horizontal speed kept per bounce
BallConfig.ROLL_DRAG = 2.0           -- per-second horizontal decay while rolling
BallConfig.SETTLE_SPEED = 4          -- below this the ball comes to rest
BallConfig.WALL_RESTITUTION = 0.45   -- energy kept bouncing off a wall while Loose
BallConfig.FLIGHT_WALL_KEEP = 0.35   -- speed kept when a thrown flight smacks a wall

-- ── Trick jumps (KC-accurate: E = spin -> curve, Q = flip -> lob) ────────
BallConfig.TRICK_WINDOW = 0.5    -- release the throw within this after a spin/flip
BallConfig.FLIP_HOP_FRAC = 0.8   -- flip hop = ~5.5 studs (feet just above head height)
BallConfig.FLIP_ROTATIONS = 2    -- double front flip
BallConfig.FLIP_TIME = 0.35      -- both flips complete within this — fast

-- ── Ballform (KC ball-up: hold Alt/R1 — the CHARACTER curls into a ball
--    pose: knees to chest, arms wrapped around the legs; still human) ────
-- Rolling: momentum-based with a gyro tumble, capped under walk speed.
BallConfig.BALLFORM_MAX_SPEED = 20   -- max roll speed (~22 effective = walk speed)
BallConfig.BALLFORM_ENTRY_POP = 14   -- ball-up starts in the air, drops, bounces
BallConfig.BALLFORM_ACCEL = 45       -- how fast momentum builds toward input
BallConfig.BALLFORM_DRAG = 4         -- per-second decay when not steering
BallConfig.BALLFORM_ROLL_RADIUS = 1.4 -- visual tumble rate = speed / radius

-- ── Glider (Space while airborne: deploy; land/Space again: stow) ───────
BallConfig.GLIDE_FALL_SPEED = 5.5  -- tuned so max-jump + glider ≈ 1.5s total airtime
BallConfig.GLIDE_DRIFT_FRAC = 1.0  -- idle drift at full walk speed (dash-range
                                   -- coverage from a max-jump glide)
BallConfig.GLIDE_STEER_SPEED = 32  -- holding W glides at sprint speed
BallConfig.GLIDE_TURN_RATE = 140   -- A/D heading turn rate (deg/s) — forward only
BallConfig.GLIDE_MOUSE_FOLLOW = 1.6 -- how eagerly the heading chases the camera
                                    -- (per-second easing; LOOSE, not 1:1)
BallConfig.GLIDE_ACCEL = 30        -- how fast glide speed changes (studs/s^2)
BallConfig.GLIDE_BRAKE = 40        -- braking (S) deceleration — slows to a stop
BallConfig.GLIDE_TILT_CRUISE = -8  -- slight forward lean while cruising (deg)
BallConfig.GLIDE_TILT_FLARE = 20   -- tilt BACK while braking (legs swing forward)

-- ── Aiming / lock-on ─────────────────────────────────────────────────────
BallConfig.AIM_CONE_DEG = 25     -- look within this cone of a target to lock on
                                 -- (locked = red outline; throws home in.
                                 -- unlocked throws fly straight & blind)

-- ── Catch ───────────────────────────────────────────────────────────────
BallConfig.CATCH_RADIUS = 6.0     -- studs; ball counts as "arriving" at target
BallConfig.CATCH_WINDOW = 0.35    -- open-arms window (whole catch ≈ 0.6s:
                                  -- 0.35 open + 0.25 hug)
BallConfig.CATCH_SLIDE_TIME = 0.4 -- catch-step: slide ~1/3 dash in the held
                                  -- direction, decaying out with the animation
BallConfig.PERFECT_WINDOW = 0.18  -- press within this before arrival = Perfect Catch (Overcharge)

-- ── Pickup / hold ───────────────────────────────────────────────────────
BallConfig.PICKUP_RADIUS = 5.0
BallConfig.HOLD_OFFSET = Vector3.new(0, 0.5, -2.2)   -- relative to holder facing (right, up, forward)

-- ── Camera (locked third person, over-the-shoulder) ────────────────────
BallConfig.SHOULDER_OFFSET = Vector3.new(1.8, 0.6, 0) -- applied in CAMERA space
BallConfig.CAMERA_LIFT = 1.5     -- eye-height above the tracked root position
BallConfig.FACE_TURN_RATE = 12   -- body turn smoothing (higher = snappier)
BallConfig.CAMERA_MIN_ZOOM = 8
BallConfig.CAMERA_MAX_ZOOM = 18
BallConfig.CAMERA_DEFAULT_ZOOM = 13 -- KC framing: character smaller in frame
BallConfig.CROSSHAIR_Y = 0.38    -- crosshair rides ABOVE center (KC-style);
                                 -- marks where the ball actually goes

-- ── Hit feedback ─────────────────────────────────────────────────────────
BallConfig.STUN_TIME = 0.8       -- hit stun: no pickup/throw/catch/tricks until over
BallConfig.WHIFF_STUN = 0.3      -- whiffed catch: locked only until the hug finishes
BallConfig.HIT_KNOCKBACK = 60    -- body shoved back on hit (studs/s)
BallConfig.HIT_KNOCK_TIME = 0.4  -- shove duration — together ~12 studs of travel
BallConfig.HIT_SHAKE_TIME = 0.35 -- camera rumble duration
BallConfig.HIT_SHAKE_MAG = 0.7   -- camera rumble strength

-- ── Health / KO ─────────────────────────────────────────────────────────
BallConfig.HITS_TO_KO = 2
BallConfig.RESPAWN_DELAY = 3.0

-- ── Bot (training dummy) ────────────────────────────────────────────────
BallConfig.BOT_ALWAYS_CATCH = true  -- perfect-catches every incoming ball (feel test)
BallConfig.BOT_HOLD_DELAY = 0.6     -- seconds it holds before throwing back
BallConfig.BOT_NAME = "TrainingDummy"

-- ── Queue + match (Team KO) ─────────────────────────────────────────────
BallConfig.QUEUE_COUNTDOWN = 10   -- seconds from first player on the pad to start
BallConfig.MATCH_TEAM_SIZE = 3    -- 3v3; short human queues are filled with bots
BallConfig.MATCH_TARGET_KOS = 10  -- Team KO: first team to this many KOs wins
BallConfig.MATCH_END_LINGER = 5   -- winner splash before everyone returns to lobby
BallConfig.MATCH_BOT_CATCH_CHANCE = 0.35 -- match bots catch this fraction of throws

return BallConfig
