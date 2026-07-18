--!strict
-- Ballout | BallService (server-authoritative)
-- One dodgeball. State machine: Free -> Held -> Flight -> (Caught | Hit) -> ...
--
-- Holding: the ball is UNANCHORED and WELDED to the holder's hand, so it moves
-- as part of the character assembly (no server-lag trailing while running).
-- Flight: kinematic quadratic bezier that tracks the target — supports
-- straight throws, curves (sideways bow) and overhead lobs (high arc).
-- Catching: timed window; perfect timing -> Overcharge tiers. 2 hits = KO.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BallConfig = require(ReplicatedStorage.BallConfig)
local Remotes = require(ReplicatedStorage.Remotes)
local AnimService = require(ServerScriptService.AnimService)
local BallformService = require(ServerScriptService.BallformService)
local GliderService = require(ServerScriptService.GliderService)

type Fighter = {
	character: Model,
	root: BasePart,
	isBot: boolean,
	player: Player?,
	team: string?,
}

local BallService = {}

-- ── State ────────────────────────────────────────────────────────────────
local ball: BasePart
local holdWeld: WeldConstraint? = nil
local state: string = "Free" -- "Free" | "Held" | "Flight"
local holder: Fighter? = nil

local flight = {
	target = nil :: Fighter?,
	origin = Vector3.zero,
	sideOffset = Vector3.zero, -- curve bow
	arcHeight = 0,             -- vertical bow
	controlT = 0.5,            -- where the bow's control point sits along the path
	duration = 1,
	s = 0,                     -- 0..1 progress
	locked = true,             -- aimed (homing) vs blind straight throw
	velocity = Vector3.zero,   -- used by blind throws & pop-ups
	thrower = nil :: Model?,
	isPass = false,            -- teammate pass: auto-caught, charges the ball
	spiralDir = 0,             -- curveballs corkscrew: -1/1 = spiral direction
	targetPoint = nil :: Vector3?, -- unlocked throws land AT this point
}

-- Fighters currently mid-dash (shoulder bash); bashing a loose ball pops it up.
local dashing: { [Model]: { expires: number, dir: Vector3 } } = {}

local fighters: { Fighter } = {}
local overcharge: { [Model]: number } = {}
local chargeRunSince: number? = nil -- how long the holder has been running charged
local chargeStart: number? = nil -- when the holder began winding up a throw
local chargeFull = false -- wound up to FULL: this throw counts as +1 Overcharge tier
local stunned: { [Model]: number } = {} -- hit stun: no actions until expiry
local hits: { [Model]: number } = {}
local catching: { [Model]: { pressedAt: number, expires: number } } = {}
local botHoldStart: number? = nil

local groundY = 0

-- Midfield ball spawn (also where the ball respawns after falling off the roofs).
local BALL_SPAWN = Vector3.new(0, 0, -20)

-- ── Helpers ────────────────────────────────────────────────────────────────
local function now(): number
	return os.clock()
end

-- The HQ has roofs at DIFFERENT heights (main deck, lower dummy roof,
-- garage roof) plus voids between buildings — so the floor under any point
-- is found by raycast, not a flat plane. Returns the surface Y, or nil
-- over the void.
local floorRayParams = RaycastParams.new()
floorRayParams.FilterType = Enum.RaycastFilterType.Exclude
local function floorYBelow(pos: Vector3): number?
	if ball then
		floorRayParams.FilterDescendantsInstances = { ball }
	end
	local hit = Workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -500, 0), floorRayParams)
	return if hit then hit.Position.Y else nil
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function fighterFor(character: Model): Fighter?
	for _, f in fighters do
		if f.character == character then
			return f
		end
	end
	return nil
end

local function enemyOf(f: Fighter): Fighter?
	for _, other in fighters do
		if other.character ~= f.character and other.character.Parent
			and (other.team == nil or f.team == nil or other.team ~= f.team) then
			return other
		end
	end
	return nil
end

local function teammateOf(f: Fighter): Fighter?
	for _, other in fighters do
		if other.character ~= f.character and other.character.Parent
			and other.team ~= nil and other.team == f.team then
			return other
		end
	end
	return nil
end

-- Sprint state per character (client-reported): picks which carry pose.
local sprintState: { [Model]: boolean } = {}

local function applyCarry(f: Fighter)
	if chargeStart and holder == f then
		-- Mid-windup: the throw arm stays cocked no matter what tries to
		-- restore a carry pose (sprint toggles, flips, glider, dash).
		AnimService.Windup(f.character)
	elseif sprintState[f.character] then
		AnimService.CarrySprint(f.character)
	else
		AnimService.Carry(f.character)
	end
end

local function feedback(f: Fighter?, kind: string, data: any?)
	if f and f.player then
		Remotes.Feedback:FireClient(f.player, kind, data)
	end
end

local function handOf(f: Fighter): BasePart?
	local hand = f.character:FindFirstChild("RightHand") or f.character:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		return hand
	end
	return nil
end

-- Ball decor (declared early: hold/release must keep them in sync).
local auraOn = false
local auraShell: BasePart? = nil
local auraFlame: ParticleEmitter? = nil
local auraLight: PointLight? = nil
local ballStripe: BasePart? = nil

-- Stripe/aura must mirror the ball's anchored state. Writing a CFrame to an
-- UNANCHORED welded part makes the solver fight the weld and catapult the
-- whole assembly (the boot "runaway ball" bug). And WeldConstraints keep
-- STALE offsets across anchored teleports (the "black puck" bug). So: decor
-- is anchored + hard-snapped while the ball is server-driven, and gets a
-- FRESH weld (created at the correct pose) only while the ball is held.
local decorWelds: { WeldConstraint } = {}

local function syncBallDecor()
	for _, w in decorWelds do
		w:Destroy()
	end
	table.clear(decorWelds)
	local anchored = ball.Anchored
	local function place(part: BasePart?, cf: CFrame)
		if not part then
			return
		end
		part.Anchored = true -- CFrame writes on anchored parts are inert
		part.CFrame = cf
		if not anchored then
			part.Anchored = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = ball
			w.Part1 = part
			w.Parent = part
			table.insert(decorWelds, w)
		end
	end
	place(ballStripe, ball.CFrame * CFrame.Angles(0, 0, math.rad(90)))
	place(auraShell, ball.CFrame)
end

-- ── Hold / release (weld-based) ────────────────────────────────────────────
local function releaseHold()
	if holdWeld then
		holdWeld:Destroy()
		holdWeld = nil
	end
	chargeStart = nil -- ball left the hand: any windup ends with it
	ball.Anchored = true
	syncBallDecor()
end

local function holdBall(f: Fighter)
	releaseHold()
	state = "Held"
	holder = f
	flight.target = nil
	chargeRunSince = nil -- fresh hold, fresh run-fade clock
	chargeStart = nil
	chargeFull = false

	local hand = handOf(f)
	local anchorPart: BasePart = hand or f.root
	if hand then
		-- Ball sits just past the PALM (hand-space -Y = out past the
		-- fingers). With the raised football-L carry the fingers point up,
		-- so the ball rests on top of the open hand — never on the forearm.
		ball.CFrame = hand.CFrame * CFrame.new(0, -(hand.Size.Y / 2 + BallConfig.BALL_DIAMETER / 2 - 0.15), 0)
	else
		ball.CFrame = CFrame.new(f.root.CFrame:PointToWorldSpace(BallConfig.HOLD_OFFSET))
	end

	ball.Anchored = false
	syncBallDecor() -- unanchor stripe/aura WITH the ball so the welds carry them
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchorPart
	weld.Part1 = ball
	weld.Parent = ball
	holdWeld = weld

	if f.isBot then
		botHoldStart = now()
	end
	applyCarry(f)
end

-- ── Charge aura ────────────────────────────────────────────────────────────
-- The ball STAYS orange; the charge shows as a pulsating purple flame aura:
-- particles + a neon shell + a point light (comic-book style).
local function setCharged(on: boolean)
	auraOn = on
	if auraFlame then
		auraFlame.Enabled = on
	end
	if auraLight then
		auraLight.Enabled = on
	end
	if auraShell then
		auraShell.Transparency = if on then 0.55 else 1
	end
end

-- ── Ball lifecycle ─────────────────────────────────────────────────────────
function BallService.MakeFree(position: Vector3)
	-- Free balls settle on the ground (kinematic, no physics drop).
	releaseHold()
	state = "Free"
	holder = nil
	botHoldStart = nil
	flight.target = nil
	-- Rest on whatever roof is under this point (roofs vary in height).
	local fy = floorYBelow(Vector3.new(position.X, math.max(position.Y, groundY) + 4, position.Z)) or groundY
	ball.Position = Vector3.new(position.X, fy + BallConfig.BALL_DIAMETER / 2, position.Z)
	setCharged(false)
end

local function computeThrowSpeed(tier: number, chargeFrac: number): number
	if tier > 0 then
		return BallConfig.CHARGED_SPEED + tier * BallConfig.SUPER_STEP
	end
	return lerp(BallConfig.LIGHT_SPEED, BallConfig.CHARGED_SPEED, math.clamp(chargeFrac, 0, 1))
end

-- Bounce/roll like a real dodgeball until it settles (state "Loose").
local function goLoose(vel: Vector3)
	releaseHold()
	state = "Loose"
	holder = nil
	flight.target = nil
	flight.velocity = vel
	setCharged(false)
end

-- curveDir: -1..1 (spin direction), isLob: flip lob, aimDir: the thrower's
-- CAMERA look direction — used for the lock check and blind throws, because
-- the character model itself may be mid-spin when the throw releases.
function BallService.Throw(f: Fighter, chargeFrac: number, curveDir: number, isLob: boolean, aimDir: Vector3?, aimPoint: Vector3?)
	if state ~= "Held" or holder ~= f then
		return
	end
	if BallformService.IsBalled(f.character) then
		return
	end
	if now() < (stunned[f.character] or 0) then
		return
	end
	local enemy = enemyOf(f)
	if not enemy then
		return
	end

	local origin = ball.Position
	local targetPos = enemy.root.Position
	local delta = targetPos - origin
	local dist = delta.Magnitude
	if dist < 1 then
		return
	end

	-- A FULL windup counts as one Overcharge tier ("charge = one purple
	-- catch"): stacks on caught overcharge, capped at MAX_TIER.
	local tier = overcharge[f.character] or 0
	if chargeFull and not f.isBot then
		tier = math.min(tier + 1, BallConfig.MAX_TIER)
	end
	chargeFull = false
	local speed = computeThrowSpeed(tier, chargeFrac)
	if isLob then
		speed *= BallConfig.LOB_SPEED_MULT
	end

	-- Lock-on check: the thrower's AIM (camera) must be within the cone of
	-- the target for the throw to home in. Otherwise it flies straight and
	-- blind — along the aim, never along the mid-spin character model.
	local rawLook = aimDir or f.root.CFrame.LookVector
	local lookFlat = Vector3.new(rawLook.X, 0, rawLook.Z)
	lookFlat = if lookFlat.Magnitude > 0.01 then lookFlat.Unit else Vector3.zAxis
	local toEnemyFlat = Vector3.new(delta.X, 0, delta.Z)
	local locked = f.isBot -- the dummy always locks
	if not f.isBot and toEnemyFlat.Magnitude > 0.01 then
		locked = lookFlat:Dot(toEnemyFlat.Unit) >= math.cos(math.rad(BallConfig.AIM_CONE_DEG))
	end

	-- Unlocked throws fly TO the crosshair's world point (client raycast),
	-- with the same curve/lob shaping. Locked throws home on the enemy.
	local pointTarget: Vector3? = nil
	if not locked then
		if typeof(aimPoint) == "Vector3" and (aimPoint - origin).Magnitude <= 200 then
			pointTarget = aimPoint
		else
			pointTarget = origin + lookFlat * 60
		end
		dist = math.max((pointTarget - origin).Magnitude, 1)
	end

	releaseHold()
	state = "Flight"
	holder = nil
	botHoldStart = nil
	overcharge[f.character] = 0 -- consumed
	flight.locked = locked
	flight.thrower = f.character
	flight.isPass = false

	local curve = math.clamp(curveDir, -1, 1)
	local aimVec = if locked then (targetPos - origin) else ((pointTarget :: Vector3) - origin)
	local aimFlat = Vector3.new(aimVec.X, 0, aimVec.Z)
	local flatDir = if aimFlat.Magnitude > 0.01 then aimFlat.Unit else lookFlat
	local rightVec = flatDir:Cross(Vector3.yAxis)
	flight.target = if locked then enemy else nil
	flight.targetPoint = pointTarget
	flight.origin = origin
	flight.s = 0
	flight.duration = dist / speed
	flight.sideOffset = rightVec * (curve * BallConfig.CURVE_OFFSET)
	flight.arcHeight = if isLob then BallConfig.LOB_ARC else BallConfig.BASE_ARC
	-- Lobs rocket up steeply right next to the thrower then drop on target;
	-- curves wrap out wide early then hook in; straight throws stay symmetric.
	flight.controlT = if isLob
		then BallConfig.LOB_CONTROL_T
		elseif curve ~= 0 then BallConfig.CURVE_CONTROL_T
		else 0.5
	-- Curveballs corkscrew around their path (same speed, spiral motion).
	flight.spiralDir = if not isLob and curve ~= 0 then curve else 0

	AnimService.Swing(f.character)
	feedback(f, "Throw", {
		charged = chargeFrac >= 0.95 or tier > 0,
		tier = tier,
		speed = speed,
		curve = curveDir,
		lob = isLob,
		locked = locked,
	})
end

-- Pass: a soft homing throw to a TEAMMATE; arrives as a charged catch.
function BallService.Pass(f: Fighter)
	if state ~= "Held" or holder ~= f then
		return
	end
	if now() < (stunned[f.character] or 0) then
		return
	end
	local mate = teammateOf(f)
	if not mate then
		feedback(f, "NoPass", nil)
		return
	end
	local origin = ball.Position
	local dist = (mate.root.Position - origin).Magnitude
	if dist < 2 then
		return
	end
	releaseHold()
	state = "Flight"
	holder = nil
	botHoldStart = nil
	flight.locked = true
	flight.isPass = true
	flight.thrower = f.character
	flight.target = mate
	flight.origin = origin
	flight.s = 0
	flight.duration = dist / BallConfig.CHARGED_SPEED
	flight.sideOffset = Vector3.zero
	flight.arcHeight = BallConfig.BASE_ARC
	flight.controlT = 0.5
	flight.spiralDir = 0
	AnimService.Swing(f.character)
	feedback(f, "Pass", nil)
end

local function catchBall(catcher: Fighter, perfect: boolean)
	catching[catcher.character] = nil
	holdBall(catcher)
	-- Arms snap closed on contact, then ease back into the carry.
	AnimService.CatchClose(catcher.character)
	task.delay(0.25, function()
		if holder == catcher then
			applyCarry(catcher)
		end
	end)

	if perfect then
		local tier = math.min((overcharge[catcher.character] or 0) + 1, BallConfig.MAX_TIER)
		overcharge[catcher.character] = tier
		setCharged(true) -- purple flame aura, ball stays orange
		feedback(catcher, "PerfectCatch", { tier = tier })
	else
		overcharge[catcher.character] = 0
		setCharged(false)
		feedback(catcher, "Catch", nil)
	end
end

local function koFighter(f: Fighter)
	hits[f.character] = 0
	overcharge[f.character] = 0
	feedback(f, "KO", nil)
	AnimService.Reset(f.character)
	if f.player then
		local hum = f.character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = 0
		end
	end
end

local function hitFighter(f: Fighter)
	hits[f.character] = (hits[f.character] or 0) + 1
	local count = hits[f.character]
	-- Push direction = the ball's actual travel direction, so the shove is
	-- exactly opposite the incoming throw from EVERY angle.
	local travel
	if flight.locked then
		travel = f.root.Position - flight.origin
	else
		travel = flight.velocity
	end
	travel = Vector3.new(travel.X, 0, travel.Z)
	local pushDir = if travel.Magnitude > 0.1 then travel.Unit else -f.root.CFrame.LookVector
	feedback(f, "Hit", { count = count, ko = count >= BallConfig.HITS_TO_KO, knock = pushDir })
	-- Struck on the back if the ball was moving the way the victim faces.
	local look = f.root.CFrame.LookVector
	local fromBehind = Vector3.new(look.X, 0, look.Z):Dot(pushDir) > 0
	AnimService.HitReact(f.character, fromBehind)
	-- Stunned: no pickup, throws, catches or tricks until this expires.
	stunned[f.character] = now() + BallConfig.STUN_TIME
	if count >= BallConfig.HITS_TO_KO then
		koFighter(f)
	end
	-- Ball ricochets back the way it came — up and away, never caught.
	goLoose(-pushDir * 11 + Vector3.new(0, 14, 0))
end

local function resolveArrival(target: Fighter)
	if flight.isPass then
		-- Passes are auto-caught and arrive CHARGED (instant purple).
		flight.isPass = false
		catchBall(target, true)
		return
	end
	if target.isBot and BallConfig.BOT_ALWAYS_CATCH then
		catchBall(target, true)
		return
	end
	local c = catching[target.character]
	if c and now() <= c.expires then
		-- Must be FACING the incoming ball — no blind back-catches.
		local travel = target.root.Position - flight.origin
		local travelFlat = Vector3.new(travel.X, 0, travel.Z)
		local facingBall = true
		if travelFlat.Magnitude > 0.1 then
			local look = target.root.CFrame.LookVector
			facingBall = Vector3.new(look.X, 0, look.Z).Unit:Dot(-travelFlat.Unit) > 0.1
		end
		if facingBall then
			local perfect = (now() - c.pressedAt) <= BallConfig.PERFECT_WINDOW
			catchBall(target, perfect)
		else
			hitFighter(target)
		end
	else
		hitFighter(target)
	end
end

-- ── Catch input ────────────────────────────────────────────────────────────
function BallService.RegisterCatch(character: Model)
	if BallformService.IsBalled(character) then
		return -- balled players can't catch
	end
	if now() < (stunned[character] or 0) then
		return -- stunned: hands don't work
	end
	catching[character] = { pressedAt = now(), expires = now() + BallConfig.CATCH_WINDOW }
	-- Arms fly WIDE OPEN — the visible catch attempt. They only snap closed
	-- if a ball actually arrives (catchBall); otherwise they drop: whiffed.
	AnimService.CatchOpen(character, BallConfig.CATCH_WINDOW)
	-- WHIFFED catch (baited by a fake, or just empty air) = same stun as a
	-- hit. This is the fake-out's whole payoff: bait the catch, then throw.
	local entry = catching[character]
	task.delay(BallConfig.CATCH_WINDOW, function()
		if catching[character] == entry then
			catching[character] = nil
			stunned[character] = now() + BallConfig.WHIFF_STUN
			-- The bear hug plays even on empty air — hugging nothing IS the
			-- whiff tell — then the arms drop.
			AnimService.CatchClose(character)
			task.delay(0.25, function()
				if not (holder and holder.character == character) then
					AnimService.Reset(character)
				end
			end)
			local f = fighterFor(character)
			if f then
				feedback(f, "Whiffed", nil)
			end
		end
	end)
end

-- Dev hook: lets test scripts drive throws for a character directly.
function BallService.DebugFighter(character: Model): Fighter?
	return fighterFor(character)
end

-- Dev hook: dump the ball state machine for diagnosis.
function BallService.DebugState()
	return {
		state = state,
		holderName = holder and holder.character.Name or "nil",
		target = flight.target and flight.target.character.Name or "nil",
		targetPoint = flight.targetPoint and tostring(flight.targetPoint) or "nil",
		origin = tostring(flight.origin),
		duration = flight.duration,
		s = flight.s,
		velocity = tostring(flight.velocity),
		locked = flight.locked,
		isPass = flight.isPass,
		charging = chargeStart ~= nil,
		chargeFull = chargeFull,
	}
end

-- ── Registration ───────────────────────────────────────────────────────────
function BallService.RegisterFighter(f: Fighter)
	table.insert(fighters, f)
	hits[f.character] = 0
	overcharge[f.character] = 0
end

function BallService.UnregisterFighter(character: Model)
	for i = #fighters, 1, -1 do
		if fighters[i].character == character then
			table.remove(fighters, i)
		end
	end
	hits[character] = nil
	overcharge[character] = nil
	stunned[character] = nil
	catching[character] = nil
	dashing[character] = nil
	sprintState[character] = nil
	if holder and holder.character == character then
		BallService.MakeFree(ball.Position)
	end
	if flight.target and flight.target.character == character then
		BallService.MakeFree(ball.Position)
	end
end

-- Shared by Free and Loose states: grab the ball, or bash it skyward mid-dash.
local function checkPickupAndBash()
	local t = now()
	for _, f in fighters do
		if f.character.Parent and f.root.Parent and not BallformService.IsBalled(f.character) then
			if now() < (stunned[f.character] or 0) then
				continue
			end
			-- The dead don't play dodgeball.
			local hum = f.character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health <= 0 then
				continue
			end
			local d = (ball.Position - f.root.Position).Magnitude
			local dash = dashing[f.character]
			if dash and t < dash.expires then
				-- Shoulder bash: pop the ball straight up.
				if d <= BallConfig.DASH_BALL_RANGE then
					state = "Loose"
					flight.velocity = Vector3.new(dash.dir.X * 10, BallConfig.POP_UP_SPEED, dash.dir.Z * 10)
					feedback(f, "PopUp", nil)
					break
				end
				-- Mid-dash fighters bash; they don't scoop.
			elseif d <= BallConfig.PICKUP_RADIUS then
				holdBall(f)
				setCharged(false)
				break
			end
		end
	end
end

-- ── Per-frame update ───────────────────────────────────────────────────────
local function onHeartbeat(dt: number)
	-- Comic-book pulse: the aura breathes while charged.
	if auraOn then
		local pulse = 0.5 + 0.5 * math.sin(now() * 8)
		if auraShell then
			auraShell.Transparency = 0.4 + pulse * 0.35
		end
		if auraLight then
			auraLight.Brightness = 0.8 + pulse * 1.4
		end
	end

	if state == "Held" and holder then
		-- Weld keeps the ball glued to the hand; only the bot timer runs here.
		if holder.isBot and botHoldStart and (now() - botHoldStart) >= BallConfig.BOT_HOLD_DELAY then
			botHoldStart = nil
			BallService.Throw(holder, 1.0, 0, false)
		end
		-- Full windup reached: purple flame ignites — this throw will fly
		-- like an Overcharge tier ("charge = one purple catch").
		if chargeStart and not chargeFull and (now() - chargeStart) >= BallConfig.FULL_CHARGE_TIME then
			chargeFull = true
			setCharged(true)
		end
		-- Purple fades only if you RUN with it — hold your ground, keep it.
		if holder and not holder.isBot and (overcharge[holder.character] or 0) > 0 then
			local v = holder.root.AssemblyLinearVelocity
			local moving = Vector3.new(v.X, 0, v.Z).Magnitude > BallConfig.CHARGE_RUN_SPEED
			if moving then
				if not chargeRunSince then
					chargeRunSince = now()
				elseif now() - chargeRunSince > BallConfig.CHARGE_RUN_GRACE then
					overcharge[holder.character] = 0
					chargeRunSince = nil
					setCharged(false)
					feedback(holder, "ChargeFaded", nil)
				end
			else
				chargeRunSince = nil
			end
		end

	elseif state == "Flight" then
		local target = flight.target
		local targetPos
		if target then
			if not (target.character.Parent and target.root.Parent) then
				BallService.MakeFree(ball.Position)
				return
			end
			targetPos = target.root.Position
		else
			targetPos = flight.targetPoint or ball.Position
		end

		flight.s = math.min(flight.s + dt / flight.duration, 1)
		local s = flight.s

		-- Quadratic bezier from origin to the target's live position, bowed
		-- sideways for curves and upward for arcs/lobs. controlT < 0.5 pushes
		-- the bow toward the thrower: out wide early, hook in late.
		local mid = flight.origin:Lerp(targetPos, flight.controlT) + flight.sideOffset + Vector3.new(0, flight.arcHeight, 0)
		local a = flight.origin:Lerp(mid, s)
		local b = mid:Lerp(targetPos, s)
		local pos = a:Lerp(b, s)

		-- Curveball corkscrew: a helical offset around the flight path that
		-- peaks mid-flight and tapers to ZERO at the target (clean arrival).
		if flight.spiralDir ~= 0 then
			local path = Vector3.new(targetPos.X - flight.origin.X, 0, targetPos.Z - flight.origin.Z)
			if path.Magnitude > 0.1 then
				local rightV = path.Unit:Cross(Vector3.yAxis)
				local theta = s * BallConfig.CURVE_SPIRAL_TURNS * math.pi * 2 * flight.spiralDir
				local radius = BallConfig.CURVE_SPIRAL_RADIUS * math.sin(math.pi * s)
				pos += (rightV * math.cos(theta) + Vector3.yAxis * math.sin(theta)) * radius
			end
		end
		ball.Position = pos

		if target then
			if s >= 1 or (ball.Position - targetPos).Magnitude <= BallConfig.CATCH_RADIUS * 0.5 then
				resolveArrival(target)
			end
		else
			-- Point throw: anyone in the path can still catch/eat it.
			for _, f in fighters do
				if f.character ~= flight.thrower and f.character.Parent and f.root.Parent then
					if (ball.Position - f.root.Position).Magnitude <= BallConfig.CATCH_RADIUS * 0.6 then
						resolveArrival(f)
						return
					end
				end
			end
			if s >= 1 then
				-- Arrives at the marker CARRYING its momentum: a buoyant
				-- skip-bounce onward, not a dead stop (Loose physics then
				-- bounces and rolls it out).
				local dir = Vector3.new(targetPos.X - flight.origin.X, 0, targetPos.Z - flight.origin.Z)
				dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.zero
				local arriveSpeed = (targetPos - flight.origin).Magnitude / math.max(flight.duration, 0.05)
				goLoose(dir * math.max(arriveSpeed * 0.35, 12) + Vector3.new(0, 10, 0))
			end
		end

	elseif state == "Loose" then
		-- Real-dodgeball feel: bounce with energy loss, roll with drag, settle.
		flight.velocity += Vector3.new(0, -BallConfig.BALL_GRAVITY, 0) * dt
		local newPos = ball.Position + flight.velocity * dt
		-- The floor is whatever roof is under the ball (raycast — roofs sit
		-- at different heights). Off the edge there is no floor: the ball
		-- falls into the clouds and respawns at midfield.
		local floorFound = floorYBelow(newPos)
		local overFloor = floorFound ~= nil
		local floorY = (floorFound or -1e9) + BallConfig.BALL_DIAMETER / 2
		if newPos.Y < groundY - 80 then
			BallService.MakeFree(BALL_SPAWN)
			return
		end
		if newPos.Y <= floorY and overFloor then
			newPos = Vector3.new(newPos.X, floorY, newPos.Z)
			local vy = -flight.velocity.Y * BallConfig.BOUNCE_RESTITUTION
			if vy < 6 then
				vy = 0 -- too weak to bounce again: start rolling
			end
			flight.velocity = Vector3.new(
				flight.velocity.X * BallConfig.BOUNCE_FRICTION,
				vy,
				flight.velocity.Z * BallConfig.BOUNCE_FRICTION
			)
		end
		-- Rolling drag once it's staying on the ground.
		if newPos.Y <= floorY + 0.05 and flight.velocity.Y == 0 and overFloor then
			local decay = math.max(0, 1 - BallConfig.ROLL_DRAG * dt)
			flight.velocity = Vector3.new(flight.velocity.X * decay, 0, flight.velocity.Z * decay)
			if flight.velocity.Magnitude <= BallConfig.SETTLE_SPEED then
				BallService.MakeFree(newPos)
				return
			end
		end
		ball.Position = newPos
		checkPickupAndBash()

	elseif state == "Free" then
		checkPickupAndBash()
	end
end

-- ── Setup ──────────────────────────────────────────────────────────────────
function BallService.Start()
	local baseplate = Workspace:FindFirstChild("Baseplate") :: BasePart?
	if baseplate then
		groundY = baseplate.Position.Y + baseplate.Size.Y / 2
	end

	ball = Instance.new("Part")
	ball.Name = "Dodgeball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * BallConfig.BALL_DIAMETER
	ball.Color = BallConfig.BALL_COLOR
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanTouch = false
	ball.CanQuery = false
	ball.Massless = true
	ball.TopSurface = Enum.SurfaceType.Smooth
	ball.BottomSurface = Enum.SurfaceType.Smooth
	ball.Parent = Workspace

	-- Single black stripe around the equator.
	local stripe = Instance.new("Part")
	stripe.Name = "Stripe"
	stripe.Shape = Enum.PartType.Cylinder
	stripe.Size = Vector3.new(0.3, BallConfig.BALL_DIAMETER * 1.02, BallConfig.BALL_DIAMETER * 1.02)
	stripe.Color = Color3.fromRGB(25, 25, 28)
	stripe.Material = Enum.Material.SmoothPlastic
	stripe.Anchored = true -- born anchored like the ball; syncBallDecor keeps them matched
	stripe.Massless = true
	stripe.CanCollide = false
	stripe.CanQuery = false
	stripe.CanTouch = false
	stripe.CFrame = ball.CFrame * CFrame.Angles(0, 0, math.rad(90))
	stripe.Parent = ball
	-- No weld here: syncBallDecor creates a fresh weld only while held.
	ballStripe = stripe

	-- Charge aura: purple flame particles + pulsing neon shell + glow.
	local shell = Instance.new("Part")
	shell.Name = "ChargeAura"
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.one * (BallConfig.BALL_DIAMETER + 0.5)
	shell.Color = Color3.fromRGB(170, 80, 255)
	shell.Material = Enum.Material.Neon
	shell.Transparency = 1
	shell.Anchored = true -- born anchored like the ball; syncBallDecor keeps them matched
	shell.Massless = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CFrame = ball.CFrame
	shell.Parent = ball
	auraShell = shell

	local auraAtt = Instance.new("Attachment")
	auraAtt.Parent = ball
	local flame = Instance.new("ParticleEmitter")
	flame.Color = ColorSequence.new(Color3.fromRGB(210, 120, 255), Color3.fromRGB(120, 40, 220))
	flame.LightEmission = 1
	flame.Lifetime = NumberRange.new(0.25, 0.45)
	flame.Rate = 45
	flame.Speed = NumberRange.new(2, 5)
	flame.SpreadAngle = Vector2.new(180, 180)
	flame.Acceleration = Vector3.new(0, 7, 0)
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	flame.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	flame.Enabled = false
	flame.Parent = auraAtt
	auraFlame = flame

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(180, 90, 255)
	glow.Range = 9
	glow.Brightness = 1.2
	glow.Enabled = false
	glow.Parent = ball
	auraLight = glow

	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0.4, 0); a0.Parent = ball
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -0.4, 0); a1.Parent = ball
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.25
	trail.Parent = ball

	-- Spawn midfield, clear of the player spawn.
	BallService.MakeFree(Vector3.new(0, 0, -20))

	RunService.Heartbeat:Connect(onHeartbeat)
	-- No per-frame decor snap here: while the ball is server-driven the
	-- CLIENT snaps the stripe/shell in RenderStepped (separate anchored
	-- parts interpolate out of sync on clients — server-side snapping
	-- can't fix that and its replication would fight the client's writes).
	-- syncBallDecor still runs at every hold/release transition.

	-- Client protocol: ThrowRequest(phase, chargeFrac, curveDir, isLob)
	--   phase "start"   -> windup pose while charging
	--   phase "release" -> actual throw
	Remotes.ThrowRequest.OnServerEvent:Connect(function(player, phase, chargeFrac, curveDir, isLob, aimDir, aimPoint)
		local char = player.Character
		if not char then return end
		local f = fighterFor(char)
		if not f then return end

		if phase == "start" then
			if state == "Held" and holder == f then
				AnimService.Windup(char)
				chargeStart = now()
				chargeFull = false
			end
		elseif phase == "release" then
			local aim = if typeof(aimDir) == "Vector3" then aimDir else nil
			local point = if typeof(aimPoint) == "Vector3" then aimPoint else nil
			BallService.Throw(f, tonumber(chargeFrac) or 0, tonumber(curveDir) or 0, isLob == true, aim, point)
		end
	end)

	Remotes.CatchRequest.OnServerEvent:Connect(function(player)
		local char = player.Character
		if char then
			BallService.RegisterCatch(char)
		end
	end)

	-- Q flip: brief curled tuck pose (knees to chest). Pose only — it does
	-- NOT count as ballform, so you can still throw/lob mid-flip.
	Remotes.FlipRequest.OnServerEvent:Connect(function(player)
		local char = player.Character
		local f = char and fighterFor(char)
		if f then
			if now() < (stunned[char] or 0) then
				return
			end
			AnimService.TuckPulse(char, BallConfig.FLIP_TIME)
			-- Holding the ball? The carry pose comes right back after.
			task.delay(BallConfig.FLIP_TIME + 0.05, function()
				if holder == f then
					applyCarry(f)
				end
			end)
		end
	end)

	-- Ballform hold (KC ball-up: hold Alt / R1): curled ball pose, rolls
	-- around, can't throw/catch. Not while holding the dodgeball.
	Remotes.BallformRequest.OnServerEvent:Connect(function(player, on)
		local char = player.Character
		local f = char and fighterFor(char)
		if not f then
			return
		end
		if on == true then
			GliderService.Disable(char) -- can't glide as a ball
			-- You can't be a ball AND hold a ball: drop it first.
			if state == "Held" and holder == f then
				AnimService.Reset(char)
				local look = f.root.CFrame.LookVector
				BallService.MakeFree(f.root.Position + Vector3.new(look.X, 0, look.Z) * 4)
			end
			if BallformService.Enable(char) then
				feedback(f, "Ballform", { on = true })
			end
		else
			if BallformService.Disable(char) then
				feedback(f, "Ballform", { on = false })
			end
		end
	end)

	-- Drop ball (KC: G / D-pad Left) — set it down in front of you.
	Remotes.DropRequest.OnServerEvent:Connect(function(player)
		local char = player.Character
		local f = char and fighterFor(char)
		if f and state == "Held" and holder == f then
			AnimService.Reset(f.character)
			local look = f.root.CFrame.LookVector
			BallService.MakeFree(f.root.Position + Vector3.new(look.X, 0, look.Z) * 5)
		end
	end)

	-- Glider: deploy/stow. Holding the ball? Left hand grips the bar, right
	-- arm keeps the ball raised.
	Remotes.GlideRequest.OnServerEvent:Connect(function(player, on, extra)
		local char = player.Character
		local f = char and fighterFor(char)
		if not f then
			return
		end
		if on == "flare" then
			AnimService.GlideFlare(char, extra == true)
		elseif on == true then
			GliderService.Enable(char)
			if holder == f then
				applyCarry(f) -- right arm: ball
				AnimService.GlidePose(char, false) -- left hand: bar
			else
				AnimService.GlidePose(char, true)
			end
		else
			GliderService.Disable(char)
			AnimService.Reset(char)
			if holder == f then
				applyCarry(f)
			end
		end
	end)

	-- Pass (R): holding = pass to a teammate; empty-handed = ask for one.
	Remotes.PassRequest.OnServerEvent:Connect(function(player)
		local char = player.Character
		local f = char and fighterFor(char)
		if not f then
			return
		end
		if state == "Held" and holder == f then
			BallService.Pass(f)
		else
			local mate = teammateOf(f)
			if mate and holder == mate then
				feedback(mate, "PassPing", nil)
				feedback(f, "PassAsked", nil)
			else
				feedback(f, "NoPass", nil)
			end
		end
	end)

	-- Sprint state: switches the carry pose (raised-L walk vs two-hand run).
	Remotes.SprintRequest.OnServerEvent:Connect(function(player, on)
		local char = player.Character
		local f = char and fighterFor(char)
		if not f then
			return
		end
		sprintState[char] = on == true
		if holder == f then
			applyCarry(f)
		end
	end)

	-- Shoulder bash: track the dash window so a loose ball can be popped up,
	-- and play the elbow-lead dash pose.
	Remotes.DashRequest.OnServerEvent:Connect(function(player, dir)
		local char = player.Character
		local f = char and fighterFor(char)
		if not f then
			return
		end
		if now() < (stunned[char] or 0) then
			return
		end
		local d = if typeof(dir) == "Vector3" then Vector3.new(dir.X, 0, dir.Z) else Vector3.zero
		d = if d.Magnitude > 0.01 then d.Unit else Vector3.zero
		dashing[char] = { expires = now() + BallConfig.DODGE_TIME + 0.1, dir = d }
		if d.Magnitude > 0.01 then
			AnimService.DashPose(char)
			-- Sphere shell for the whole dive+roll: the tumbling body slides
			-- smoothly instead of catching the floor (camera stays glassy).
			BallformService.PhysicsShell(char, BallConfig.DODGE_TIME + BallConfig.DASH_ROLL_TIME + 0.05)
			-- The dive lands in a tucked parkour roll.
			task.delay(BallConfig.DODGE_TIME, function()
				if char.Parent then
					AnimService.TuckPulse(char, BallConfig.DASH_ROLL_TIME)
				end
			end)
			-- Holding the ball through the dash? Carry pose returns after.
			task.delay(BallConfig.DODGE_TIME + BallConfig.DASH_ROLL_TIME + 0.1, function()
				if holder == f then
					applyCarry(f)
				end
			end)
		end
	end)

	-- Fake throw: IDENTICAL motion to a real throw (windup came from the
	-- shared "start" phase; this is the release swing) — ball never leaves.
	-- curve/lob are echoed back so the client plays the same spin/hang.
	Remotes.FakeRequest.OnServerEvent:Connect(function(player, curveDir, isLob)
		local char = player.Character
		local f = char and fighterFor(char)
		if f and state == "Held" and holder == f then
			-- The fake cancels the windup: the aura falls back to whatever
			-- the ACTUAL caught-overcharge state is.
			chargeStart = nil
			chargeFull = false
			setCharged((overcharge[f.character] or 0) > 0)
			AnimService.Swing(f.character)
			task.delay(0.35, function()
				if holder == f then
					applyCarry(f)
				end
			end)
			feedback(f, "Fake", { curve = tonumber(curveDir) or 0, lob = isLob == true })
		end
	end)
end

return BallService
