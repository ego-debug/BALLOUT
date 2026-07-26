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
local CollectionService = game:GetService("CollectionService")
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
	catchChance: number?, -- bots only: 0..1 odds of catching an incoming ball
	                      -- (nil = BOT_ALWAYS_CATCH behavior; the training dummy)
}

local BallService = {}

-- Match hook (set by MatchService): called with the KO'd fighter.
BallService.OnKO = nil :: ((Fighter) -> ())?

-- ── State ────────────────────────────────────────────────────────────────
-- MULTI-BALL: every ball is a self-contained state machine. The primary
-- ball serves the lobby and matches; the drill ball belongs to the training
-- bot (it refills — see stepDrillRefill). Fighters hold at most ONE ball;
-- catching with full hands pops the held ball loose (catchBall).
type Flight = {
	target: Fighter?,
	origin: Vector3,
	sideOffset: Vector3,
	arcHeight: number,
	controlT: number,
	duration: number,
	s: number,
	locked: boolean,
	velocity: Vector3,
	thrower: Model?,
	isPass: boolean,
	spiralDir: number,
	targetPoint: Vector3?,
}
type Ball = {
	part: BasePart,
	holdWeld: WeldConstraint?,
	state: string, -- "Free" | "Held" | "Flight" | "Loose"
	holder: Fighter?,
	flight: Flight,
	botHoldStart: number?,
	chargeStart: number?,   -- windup began (drives pose + flame)
	chargeFull: boolean,
	chargeRunSince: number?,
	auraOn: boolean,
	auraShell: BasePart?,
	auraFlame: ParticleEmitter?,
	auraLight: PointLight?,
	stripe: BasePart?,
	decorWelds: { WeldConstraint },
	spawnPos: Vector3, -- fall-off-the-world respawn spot
	isDrill: boolean,
}

local balls: { Ball } = {}
local primaryBall: Ball
local drillBall: Ball

local function heldBy(f: Fighter): Ball?
	for _, b in balls do
		if b.holder == f then
			return b
		end
	end
	return nil
end

-- Fighters currently mid-dash (shoulder bash); bashing a loose ball pops it up.
-- `expires` is the bash window; `lockUntil` covers the WHOLE dive + landing
-- roll — no other action is allowed until it passes (dodge commitment: eating
-- the lockout is the punishment for bad timing).
local dashing: { [Model]: { expires: number, dir: Vector3, lockUntil: number } } = {}

local function dashLocked(character: Model): boolean
	local dash = dashing[character]
	return dash ~= nil and os.clock() < dash.lockUntil
end

local fighters: { Fighter } = {}
local overcharge: { [Model]: number } = {}
local stunned: { [Model]: number } = {} -- hit stun: no actions until expiry
local hits: { [Model]: number } = {}
local catching: { [Model]: { pressedAt: number, expires: number } } = {}

-- Catch commitment: arms-out is a bet, same as the dodge. While the catch
-- window is open NOTHING else works — you can't dash/flip/ball-up your way
-- out of a baited catch; the whiff stun is yours to eat. A SUCCESSFUL catch
-- clears `catching` (catchBall), so the lock releases instantly on a catch.
local function catchLocked(character: Model): boolean
	local c = catching[character]
	return c ~= nil and os.clock() <= c.expires
end

-- The one gate action handlers check: mid-dodge or mid-catch = committed.
local function actionLocked(character: Model): boolean
	return dashLocked(character) or catchLocked(character)
end

local groundY = 0

-- Where the ball spawns and respawns after falling off the world. HQ midfield
-- by default; Start() overrides it with the lobby's BallSpawn marker if the
-- lobby island is built.
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
	local exclude = {}
	for _, b in balls do
		table.insert(exclude, b.part)
	end
	floorRayParams.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -500, 0), floorRayParams)
	return if hit then hit.Position.Y else nil
end

-- Walls only exist to the kinematic ball via swept raycasts — it is
-- Anchored/CanCollide=false, so the physics engine never stops it. The sweep
-- runs against MAP GEOMETRY ONLY (Include filter), so characters, ball decor,
-- and the ball itself can never obstruct a throw. Map models are destroyed and
-- rebuilt by build scripts, so cached roots are re-collected when stale.
local wallRayParams = RaycastParams.new()
wallRayParams.FilterType = Enum.RaycastFilterType.Include
local wallRoots: { Instance } = {}
local WALL_ROOT_NAMES = { "BalloutMap", "BalloutLobby", "BalloutArena", "Baseplate" }
local function refreshWallRoots()
	local stale = #wallRoots == 0
	for _, root in wallRoots do
		if root.Parent == nil then
			stale = true
			break
		end
	end
	if stale then
		table.clear(wallRoots)
		for _, name in WALL_ROOT_NAMES do
			local inst = Workspace:FindFirstChild(name)
			if inst then
				table.insert(wallRoots, inst)
			end
		end
		wallRayParams.FilterDescendantsInstances = wallRoots
	end
end

local function sweepWall(from: Vector3, to: Vector3): RaycastResult?
	local delta = to - from
	if delta.Magnitude < 1e-4 then
		return nil
	end
	refreshWallRoots()
	-- Pad by the radius so surfaces stop the ball's skin, not its center.
	return Workspace:Raycast(from, delta.Unit * (delta.Magnitude + BallConfig.BALL_DIAMETER / 2), wallRayParams)
end

-- Lobby = safe zone: hits inside still shove/sting/stun (the toy stays fun)
-- but never count toward a KO — infinite health while hanging out. The zone
-- is the invisible CanQuery=false "SafeZone" box under the lobby model.
local safeZonePart: BasePart? = nil
local function inSafeZone(pos: Vector3): boolean
	if safeZonePart == nil or safeZonePart.Parent == nil then
		local lobby = Workspace:FindFirstChild("BalloutLobby")
		local zone = if lobby then lobby:FindFirstChild("SafeZone") else nil
		safeZonePart = if zone and zone:IsA("BasePart") then zone else nil
	end
	local zone = safeZonePart
	if not zone then
		return false
	end
	local rel = zone.CFrame:PointToObjectSpace(pos)
	return math.abs(rel.X) <= zone.Size.X / 2
		and math.abs(rel.Y) <= zone.Size.Y / 2
		and math.abs(rel.Z) <= zone.Size.Z / 2
end

-- Training drill: the chalk circle on the training roof. The lobby bot only
-- throws while a player stands inside it (see the Held branch).
local drillPart: BasePart? = nil
local botDrillChargeAt: number? = nil
local function drillTarget(): Fighter?
	if drillPart == nil or drillPart.Parent == nil then
		local m = Workspace:FindFirstChild("BalloutMap")
		local d = if m then m:FindFirstChild("DrillCircle") else nil
		drillPart = if d and d:IsA("BasePart") then d else nil
	end
	local zone = drillPart
	if not zone then
		return nil
	end
	for _, f in fighters do
		if f.player and f.character.Parent and f.root.Parent then
			local rel = f.root.Position - zone.Position
			if Vector3.new(rel.X, 0, rel.Z).Magnitude <= BallConfig.DRILL_RADIUS then
				return f
			end
		end
	end
	return nil
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

-- NEAREST enemy/teammate, not first-registered: with lobby + match fighters
-- coexisting in one server, first-in-list could be someone across the map.
local function enemyOf(f: Fighter): Fighter?
	local best: Fighter? = nil
	local bestDist = math.huge
	for _, other in fighters do
		if other.character ~= f.character and other.character.Parent and other.root.Parent
			and (other.team == nil or f.team == nil or other.team ~= f.team) then
			local d = (other.root.Position - f.root.Position).Magnitude
			if d < bestDist then
				best, bestDist = other, d
			end
		end
	end
	return best
end

local function teammateOf(f: Fighter): Fighter?
	local best: Fighter? = nil
	local bestDist = math.huge
	for _, other in fighters do
		if other.character ~= f.character and other.character.Parent and other.root.Parent
			and other.team ~= nil and other.team == f.team then
			local d = (other.root.Position - f.root.Position).Magnitude
			if d < bestDist then
				best, bestDist = other, d
			end
		end
	end
	return best
end

-- Sprint state per character (client-reported): picks which carry pose.
local sprintState: { [Model]: boolean } = {}

local function applyCarry(f: Fighter)
	local held = heldBy(f)
	if held and held.chargeStart then
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

-- Stripe/aura must mirror the ball's anchored state. Writing a CFrame to an
-- UNANCHORED welded part makes the solver fight the weld and catapult the
-- whole assembly (the boot "runaway ball" bug). And WeldConstraints keep
-- STALE offsets across anchored teleports (the "black puck" bug). So: decor
-- is anchored + hard-snapped while the ball is server-driven, and gets a
-- FRESH weld (created at the correct pose) only while the ball is held.
local function syncBallDecor(b: Ball)
	for _, w in b.decorWelds do
		w:Destroy()
	end
	table.clear(b.decorWelds)
	local anchored = b.part.Anchored
	local function place(part: BasePart?, cf: CFrame)
		if not part then
			return
		end
		part.Anchored = true -- CFrame writes on anchored parts are inert
		part.CFrame = cf
		if not anchored then
			part.Anchored = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = b.part
			w.Part1 = part
			w.Parent = part
			table.insert(b.decorWelds, w)
		end
	end
	place(b.stripe, b.part.CFrame * CFrame.Angles(0, 0, math.rad(90)))
	place(b.auraShell, b.part.CFrame)
end

-- ── Hold / release (weld-based) ────────────────────────────────────────────
local function releaseHold(b: Ball)
	if b.holdWeld then
		b.holdWeld:Destroy()
		b.holdWeld = nil
	end
	b.chargeStart = nil -- ball left the hand: any windup ends with it
	b.part.Anchored = true
	syncBallDecor(b)
end

-- ── Charge aura ────────────────────────────────────────────────────────────
-- The ball STAYS orange; the charge shows as a pulsating purple flame aura:
-- particles + a neon shell + a point light (comic-book style).
local function setCharged(b: Ball, on: boolean)
	b.auraOn = on
	if b.auraFlame then
		b.auraFlame.Enabled = on
	end
	if b.auraLight then
		b.auraLight.Enabled = on
	end
	if b.auraShell then
		b.auraShell.Transparency = if on then 0.55 else 1
	end
end

-- Bounce/roll like a real dodgeball until it settles (state "Loose").
local function goLoose(b: Ball, vel: Vector3)
	releaseHold(b)
	b.state = "Loose"
	b.holder = nil
	b.flight.target = nil
	b.flight.velocity = vel
	setCharged(b, false)
end

local function holdBall(b: Ball, f: Fighter)
	-- ONE ball per pair of hands: catching (or scooping) with a ball already
	-- held pops the old one out of the hand and into the air.
	local already = heldBy(f)
	if already and already ~= b then
		local look = f.root.CFrame.LookVector
		goLoose(already, Vector3.new(look.X * 4, 22, look.Z * 4))
	end

	releaseHold(b)
	b.state = "Held"
	b.holder = f
	b.flight.target = nil
	b.chargeRunSince = nil -- fresh hold, fresh run-fade clock
	b.chargeStart = nil
	b.chargeFull = false

	local hand = handOf(f)
	local anchorPart: BasePart = hand or f.root
	if hand then
		-- Ball sits just past the PALM (hand-space -Y = out past the
		-- fingers). With the raised football-L carry the fingers point up,
		-- so the ball rests on top of the open hand — never on the forearm.
		b.part.CFrame = hand.CFrame * CFrame.new(0, -(hand.Size.Y / 2 + BallConfig.BALL_DIAMETER / 2 - 0.15), 0)
	else
		b.part.CFrame = CFrame.new(f.root.CFrame:PointToWorldSpace(BallConfig.HOLD_OFFSET))
	end

	b.part.Anchored = false
	syncBallDecor(b) -- unanchor stripe/aura WITH the ball so the welds carry them
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchorPart
	weld.Part1 = b.part
	weld.Parent = b.part
	b.holdWeld = weld

	if f.isBot then
		b.botHoldStart = now()
	end
	applyCarry(f)
end

-- ── Ball lifecycle ─────────────────────────────────────────────────────────
local function makeFreeBall(b: Ball, position: Vector3)
	-- Free balls settle on the ground (kinematic, no physics drop).
	releaseHold(b)
	b.state = "Free"
	b.holder = nil
	b.botHoldStart = nil
	b.flight.target = nil
	-- Rest on whatever roof is under this point (roofs vary in height).
	local fy = floorYBelow(Vector3.new(position.X, math.max(position.Y, groundY) + 4, position.Z)) or groundY
	b.part.Position = Vector3.new(position.X, fy + BallConfig.BALL_DIAMETER / 2, position.Z)
	setCharged(b, false)
end

-- Public API: the primary (lobby/match) ball — existing callers keep working.
function BallService.MakeFree(position: Vector3)
	makeFreeBall(primaryBall, position)
end

local function computeThrowSpeed(tier: number, chargeFrac: number): number
	if tier > 0 then
		return BallConfig.CHARGED_SPEED + tier * BallConfig.SUPER_STEP
	end
	return lerp(BallConfig.LIGHT_SPEED, BallConfig.CHARGED_SPEED, math.clamp(chargeFrac, 0, 1))
end

-- curveDir: -1..1 (spin direction), isLob: flip lob, aimDir: the thrower's
-- CAMERA look direction — used for the lock check and blind throws, because
-- the character model itself may be mid-spin when the throw releases.
local function throwBall(b: Ball, f: Fighter, chargeFrac: number, curveDir: number, isLob: boolean, aimDir: Vector3?, aimPoint: Vector3?)
	if BallformService.IsBalled(f.character) then
		return
	end
	if now() < (stunned[f.character] or 0) then
		return
	end
	if actionLocked(f.character) then
		return -- committed (dodge or catch): no throwing out of it
	end
	local enemy = enemyOf(f)
	if not enemy then
		return
	end

	local origin = b.part.Position
	local targetPos = enemy.root.Position
	local delta = targetPos - origin
	local dist = delta.Magnitude
	if dist < 1 then
		return
	end

	-- A FULL windup counts as one Overcharge tier ("charge = one purple
	-- catch"): stacks on caught overcharge, capped at MAX_TIER.
	local tier = overcharge[f.character] or 0
	if b.chargeFull and not f.isBot then
		tier = math.min(tier + 1, BallConfig.MAX_TIER)
	end
	b.chargeFull = false
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

	releaseHold(b)
	b.state = "Flight"
	b.holder = nil
	b.botHoldStart = nil
	overcharge[f.character] = 0 -- consumed
	local flight = b.flight
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

-- Public: throw whichever ball the fighter is holding.
function BallService.Throw(f: Fighter, chargeFrac: number, curveDir: number, isLob: boolean, aimDir: Vector3?, aimPoint: Vector3?)
	local b = heldBy(f)
	if b then
		throwBall(b, f, chargeFrac, curveDir, isLob, aimDir, aimPoint)
	end
end

-- Pass: a soft homing throw to a TEAMMATE; arrives as a charged catch.
function BallService.Pass(f: Fighter)
	local b = heldBy(f)
	if not b then
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
	local origin = b.part.Position
	local dist = (mate.root.Position - origin).Magnitude
	if dist < 2 then
		return
	end
	releaseHold(b)
	b.state = "Flight"
	b.holder = nil
	b.botHoldStart = nil
	local flight = b.flight
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

local function catchBall(b: Ball, catcher: Fighter, perfect: boolean)
	catching[catcher.character] = nil
	holdBall(b, catcher) -- pops any already-held ball loose (full hands rule)
	-- Arms snap closed on contact, then ease back into the carry.
	AnimService.CatchClose(catcher.character)
	task.delay(0.25, function()
		if b.holder == catcher then
			applyCarry(catcher)
		end
	end)

	if perfect then
		local tier = math.min((overcharge[catcher.character] or 0) + 1, BallConfig.MAX_TIER)
		overcharge[catcher.character] = tier
		setCharged(b, true) -- purple flame aura, ball stays orange
		feedback(catcher, "PerfectCatch", { tier = tier })
	else
		overcharge[catcher.character] = 0
		setCharged(b, false)
		feedback(catcher, "Catch", nil)
	end
end

-- ── Dash bonk ──────────────────────────────────────────────────────────────
-- Reckless dodging has consequences: face-plant a wall mid-dash (or clonk
-- heads with another dasher) and you're on the floor for BONK_STUN with
-- birds circling. Dashing into a STANDING player stays a tackle — only solid
-- map geometry and mutual dashers bonk.
local bonkEffects: { { character: Model, parts: { BasePart }, expires: number } } = {}

local function spawnBirds(character: Model)
	local head = character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local parts = {}
	for i = 1, 3 do
		local b = Instance.new("Part")
		b.Name = "BonkBird"
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.new(0.55, 0.55, 0.55)
		b.Color = Color3.fromRGB(255, 220, 90)
		b.Material = Enum.Material.Neon
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Parent = Workspace
		table.insert(parts, b)
	end
	table.insert(bonkEffects, { character = character, parts = parts, expires = now() + BallConfig.BONK_STUN })
end

local function stepBonkEffects()
	for i = #bonkEffects, 1, -1 do
		local fx = bonkEffects[i]
		local head = if fx.character.Parent then fx.character:FindFirstChild("Head") else nil
		if now() > fx.expires or not (head and head:IsA("BasePart")) then
			for _, p in fx.parts do
				p:Destroy()
			end
			table.remove(bonkEffects, i)
		else
			-- classic cartoon orbit around the (possibly floored) head
			local t = now() * 4
			for k, p in fx.parts do
				local a = t + (k - 1) * (math.pi * 2 / 3)
				p.Position = head.Position + Vector3.new(math.cos(a) * 1.7, 0.9, math.sin(a) * 1.7)
			end
		end
	end
end

local function bonkFighter(f: Fighter)
	if now() < (stunned[f.character] or 0) then
		return -- already down (predicted report + server fallback can race)
	end
	dashing[f.character] = nil
	stunned[f.character] = now() + BallConfig.BONK_STUN
	-- curl up holding the head; the client tips the body onto the floor
	AnimService.TuckPulse(f.character, BallConfig.BONK_STUN * 0.9)
	BallformService.PhysicsShell(f.character, BallConfig.BONK_STUN)
	spawnBirds(f.character)
	feedback(f, "Bonk", { duration = BallConfig.BONK_STUN })
end

local function stepDashBonks()
	refreshWallRoots()
	local active: { Fighter } = {}
	for _, f in fighters do
		local dash = dashing[f.character]
		if dash and now() < dash.expires and dash.dir.Magnitude > 0.01
			and f.character.Parent and f.root.Parent then
			-- face-plant: a proper WALL dead ahead (steep normal only, so
			-- dashing up ramps never counts)
			local hit = Workspace:Raycast(f.root.Position, dash.dir * BallConfig.BONK_WALL_RANGE, wallRayParams)
			if hit and math.abs(hit.Normal.Y) < 0.5 then
				bonkFighter(f)
			else
				table.insert(active, f)
			end
		end
	end
	for i = 1, #active do
		for j = i + 1, #active do
			if (active[i].root.Position - active[j].root.Position).Magnitude <= BallConfig.BONK_DASHER_RANGE then
				bonkFighter(active[i])
				bonkFighter(active[j])
			end
		end
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
	-- Match hook: MatchService keeps score off this.
	if BallService.OnKO then
		task.spawn(BallService.OnKO :: (Fighter) -> (), f)
	end
end

local function hitFighter(b: Ball, f: Fighter)
	-- In the lobby safe zone nothing counts toward a KO; everywhere else
	-- hits accumulate as normal.
	local safe = inSafeZone(f.root.Position)
	if not safe then
		hits[f.character] = (hits[f.character] or 0) + 1
	end
	local count = hits[f.character] or 0
	local flight = b.flight
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
	feedback(f, "Hit", { count = count, ko = not safe and count >= BallConfig.HITS_TO_KO, knock = pushDir })
	-- Struck on the back if the ball was moving the way the victim faces.
	local look = f.root.CFrame.LookVector
	local fromBehind = Vector3.new(look.X, 0, look.Z):Dot(pushDir) > 0
	AnimService.HitReact(f.character, fromBehind)
	-- Stunned: no pickup, throws, catches or tricks until this expires.
	stunned[f.character] = now() + BallConfig.STUN_TIME
	if not safe and count >= BallConfig.HITS_TO_KO then
		koFighter(f)
	end
	-- Ball ricochets back the way it came — up and away, never caught.
	goLoose(b, -pushDir * 11 + Vector3.new(0, 14, 0))
end

local function resolveArrival(b: Ball, target: Fighter)
	local flight = b.flight
	if flight.isPass then
		-- Passes are auto-caught and arrive CHARGED (instant purple).
		flight.isPass = false
		catchBall(b, target, true)
		return
	end
	if target.isBot then
		-- Per-bot catch odds: the training dummy always catches (feel test);
		-- match bots roll catchChance so they're actually beatable.
		local chance = target.catchChance
		if chance == nil then
			chance = if BallConfig.BOT_ALWAYS_CATCH then 1 else 0
		end
		if math.random() < chance then
			catchBall(b, target, true)
			return
		end
		-- no catch: falls through to the normal arrival path (a hit)
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
			catchBall(b, target, perfect)
		else
			hitFighter(b, target)
		end
	else
		hitFighter(b, target)
	end
end

-- ── Catch input ────────────────────────────────────────────────────────────
-- Public stun, for map hazards (wrecking balls) that need to take a player's
-- actions away without going through the ball. Gates the SERVER handlers via
-- the same `stunned` table everything else uses, and tells the client so its
-- own dash / glider / throw gates close too.
function BallService.ApplyStun(character: Model, duration: number)
	stunned[character] = math.max(stunned[character] or 0, now() + duration)
	local f = fighterFor(character)
	if f then
		feedback(f, "Launched", { duration = duration })
	end
end

function BallService.RegisterCatch(character: Model)
	if BallformService.IsBalled(character) then
		return -- balled players can't catch
	end
	if now() < (stunned[character] or 0) then
		return -- stunned: hands don't work
	end
	if dashLocked(character) then
		return -- dodge commitment: no catching out of the dive/roll
	end
	if catchLocked(character) then
		return -- one bet at a time: no re-pressing to roll the window forward
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
				local f2 = fighterFor(character)
				if not (f2 and heldBy(f2)) then
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

-- Dev hook: report the commitment locks for a character.
function BallService.DebugLocks(character: Model)
	return { dash = dashLocked(character), catch = catchLocked(character), stunned = now() < (stunned[character] or 0) }
end

-- Dev hook: dump the ball state machines. Top-level fields mirror the
-- PRIMARY ball (existing test scripts keep working); `balls` has them all.
function BallService.DebugState()
	local hitCounts = {}
	for m, c in hits do
		hitCounts[m.Name] = c
	end
	local ballDump = {}
	for _, b in balls do
		table.insert(ballDump, {
			name = b.part.Name,
			state = b.state,
			holderName = b.holder and b.holder.character.Name or "nil",
			charging = b.chargeStart ~= nil,
			pos = tostring(b.part.Position),
		})
	end
	return {
		hits = hitCounts,
		state = primaryBall.state,
		holderName = primaryBall.holder and primaryBall.holder.character.Name or "nil",
		target = primaryBall.flight.target and primaryBall.flight.target.character.Name or "nil",
		targetPoint = primaryBall.flight.targetPoint and tostring(primaryBall.flight.targetPoint) or "nil",
		origin = tostring(primaryBall.flight.origin),
		duration = primaryBall.flight.duration,
		s = primaryBall.flight.s,
		velocity = tostring(primaryBall.flight.velocity),
		locked = primaryBall.flight.locked,
		isPass = primaryBall.flight.isPass,
		charging = primaryBall.chargeStart ~= nil,
		chargeFull = primaryBall.chargeFull,
		balls = ballDump,
	}
end

-- ── Registration ───────────────────────────────────────────────────────────
function BallService.RegisterFighter(f: Fighter)
	table.insert(fighters, f)
	hits[f.character] = 0
	overcharge[f.character] = 0
end

function BallService.SetTeam(character: Model, team: string?)
	local f = fighterFor(character)
	if f then
		f.team = team
	end
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
	for _, b in balls do
		if b.holder and b.holder.character == character then
			makeFreeBall(b, b.part.Position)
		end
		if b.flight.target and b.flight.target.character == character then
			makeFreeBall(b, b.part.Position)
		end
	end
end

-- Shared by Free and Loose states: grab the ball, or bash it skyward mid-dash.
local function checkPickupAndBash(b: Ball)
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
			local d = (b.part.Position - f.root.Position).Magnitude
			local dash = dashing[f.character]
			if dash and t < dash.expires then
				-- Shoulder bash: pop the ball straight up.
				if d <= BallConfig.DASH_BALL_RANGE then
					b.state = "Loose"
					b.flight.velocity = Vector3.new(dash.dir.X * 10, BallConfig.POP_UP_SPEED, dash.dir.Z * 10)
					feedback(f, "PopUp", nil)
					break
				end
				-- Mid-dash fighters bash; they don't scoop.
			elseif d <= BallConfig.PICKUP_RADIUS and heldBy(f) == nil then
				-- full hands don't scoop a second ball off the floor
				holdBall(b, f)
				setCharged(b, false)
				break
			end
		end
	end
end

-- ── Drill refill ───────────────────────────────────────────────────────────
-- The training bot never runs dry: when he's empty-handed and his ball is
-- unheld, it snaps back into his hand once the circle has been empty for
-- DRILL_REFILL_WAIT — or immediately if the ball got lost (fell off / far).
local drillLastOccupiedAt = 0

local function trainingBot(): Fighter?
	for _, f in fighters do
		if f.isBot and f.character.Name == BallConfig.BOT_NAME and f.character.Parent and f.root.Parent then
			return f
		end
	end
	return nil
end

local function stepDrillRefill()
	if drillTarget() then
		drillLastOccupiedAt = now()
	end
	local bot = trainingBot()
	if not bot or heldBy(bot) then
		return
	end
	local b = drillBall
	if b.holder ~= nil or b.state == "Flight" then
		return -- someone's playing with it / it's mid-air: leave it alone
	end
	local lost = (b.part.Position - bot.root.Position).Magnitude > BallConfig.DRILL_LOST_RANGE
	local circleQuiet = (now() - drillLastOccupiedAt) >= BallConfig.DRILL_REFILL_WAIT
	if lost or circleQuiet then
		holdBall(b, bot)
		setCharged(b, false)
	end
end

-- Move the kinematic ball AND roll it like a real one: rotation accumulates
-- from travel (axis = up x motion, angle = distance / radius, capped so
-- throw-speed flights don't strobe). Pure vertical motion doesn't spin.
local function moveBallRolling(b: Ball, to: Vector3, dt: number)
	local delta = to - b.part.Position
	local axis = Vector3.yAxis:Cross(delta)
	if axis.Magnitude > 1e-4 then
		local angle = math.min(delta.Magnitude / (BallConfig.BALL_DIAMETER / 2), BallConfig.BALL_SPIN_MAX * dt)
		b.part.CFrame = CFrame.fromAxisAngle(axis.Unit, angle) * b.part.CFrame.Rotation + to
	else
		b.part.Position = to
	end
end

-- ── Per-frame update ───────────────────────────────────────────────────
local function stepBall(b: Ball, dt: number)
	-- Comic-book pulse: the aura breathes while charged.
	if b.auraOn then
		local pulse = 0.5 + 0.5 * math.sin(now() * 8)
		if b.auraShell then
			b.auraShell.Transparency = 0.4 + pulse * 0.35
		end
		if b.auraLight then
			b.auraLight.Brightness = 0.8 + pulse * 1.4
		end
	end

	local state = b.state
	local holder = b.holder
	local flight = b.flight
	local ball = b.part

	if state == "Held" and holder then
		-- Weld keeps the ball glued to the hand; only bot logic runs here.
		if holder.isBot then
			if holder.character.Name == BallConfig.BOT_NAME then
				-- TRAINING DRILL: the lobby bot holds the ball indefinitely.
				-- A player standing in the chalk circle starts a visible
				-- windup (chargeStart ignites the flame at full charge);
				-- leaving the circle mid-windup cancels it.
				if drillTarget() then
					if botDrillChargeAt == nil then
						botDrillChargeAt = now()
						b.chargeStart = now()
						b.chargeFull = false
						AnimService.Windup(holder.character)
					elseif now() - botDrillChargeAt >= BallConfig.BOT_DRILL_CHARGE then
						botDrillChargeAt = nil
						b.chargeStart = nil
						throwBall(b, holder, 1.0, 0, false)
						return
					end
				elseif botDrillChargeAt then
					botDrillChargeAt = nil
					b.chargeStart = nil
					setCharged(b, false)
					applyCarry(holder) -- wind-down: the circle emptied
				end
			elseif b.botHoldStart and (now() - b.botHoldStart) >= BallConfig.BOT_HOLD_DELAY then
				-- match bots: quick catch-and-return, as before
				b.botHoldStart = nil
				throwBall(b, holder, 1.0, 0, false)
				return
			end
		end
		-- Full windup reached: purple flame ignites — this throw will fly
		-- like an Overcharge tier ("charge = one purple catch").
		if b.chargeStart and not b.chargeFull and (now() - b.chargeStart) >= BallConfig.FULL_CHARGE_TIME then
			b.chargeFull = true
			setCharged(b, true)
		end
		-- Purple fades only if you RUN with it — hold your ground, keep it.
		if not holder.isBot and (overcharge[holder.character] or 0) > 0 then
			local v = holder.root.AssemblyLinearVelocity
			local moving = Vector3.new(v.X, 0, v.Z).Magnitude > BallConfig.CHARGE_RUN_SPEED
			if moving then
				if not b.chargeRunSince then
					b.chargeRunSince = now()
				elseif now() - b.chargeRunSince > BallConfig.CHARGE_RUN_GRACE then
					overcharge[holder.character] = 0
					b.chargeRunSince = nil
					setCharged(b, false)
					feedback(holder, "ChargeFaded", nil)
				end
			else
				b.chargeRunSince = nil
			end
		end

	elseif state == "Flight" then
		local target = flight.target
		local targetPos
		if target then
			if not (target.character.Parent and target.root.Parent) then
				makeFreeBall(b, ball.Position)
				return
			end
			targetPos = target.root.Position
		else
			targetPos = flight.targetPoint or ball.Position
		end

		flight.s = math.min(flight.s + dt / flight.duration, 1)
		local sProg = flight.s

		-- Quadratic bezier from origin to the target's live position, bowed
		-- sideways for curves and upward for arcs/lobs. controlT < 0.5 pushes
		-- the bow toward the thrower: out wide early, hook in late.
		local mid = flight.origin:Lerp(targetPos, flight.controlT) + flight.sideOffset + Vector3.new(0, flight.arcHeight, 0)
		local pa = flight.origin:Lerp(mid, sProg)
		local pb = mid:Lerp(targetPos, sProg)
		local pos = pa:Lerp(pb, sProg)

		-- Curveball corkscrew: a helical offset around the flight path that
		-- peaks mid-flight and tapers to ZERO at the target (clean arrival).
		if flight.spiralDir ~= 0 then
			local path = Vector3.new(targetPos.X - flight.origin.X, 0, targetPos.Z - flight.origin.Z)
			if path.Magnitude > 0.1 then
				local rightV = path.Unit:Cross(Vector3.yAxis)
				local theta = sProg * BallConfig.CURVE_SPIRAL_TURNS * math.pi * 2 * flight.spiralDir
				local radius = BallConfig.CURVE_SPIRAL_RADIUS * math.sin(math.pi * sProg)
				pos += (rightV * math.cos(theta) + Vector3.yAxis * math.sin(theta)) * radius
			end
		end
		-- Walls end a flight: the ball smacks and drops. Kinematic flights
		-- would otherwise sail straight through map geometry.
		local wallHit = sweepWall(ball.Position, pos)
		if wallHit then
			local travelV = (pos - ball.Position) / math.max(dt, 1 / 240)
			local n = wallHit.Normal
			local reflected = travelV - 2 * travelV:Dot(n) * n
			ball.Position = wallHit.Position + n * (BallConfig.BALL_DIAMETER / 2)
			goLoose(b, reflected * BallConfig.FLIGHT_WALL_KEEP)
			return
		end
		moveBallRolling(b, pos, dt)

		if target then
			if sProg >= 1 or (ball.Position - targetPos).Magnitude <= BallConfig.CATCH_RADIUS * 0.5 then
				resolveArrival(b, target)
			end
		else
			-- Point throw: anyone in the path can still catch/eat it.
			for _, f in fighters do
				if f.character ~= flight.thrower and f.character.Parent and f.root.Parent then
					if (ball.Position - f.root.Position).Magnitude <= BallConfig.CATCH_RADIUS * 0.6 then
						resolveArrival(b, f)
						return
					end
				end
			end
			if sProg >= 1 then
				-- Arrives at the marker CARRYING its momentum: a buoyant
				-- skip-bounce onward, not a dead stop (Loose physics then
				-- bounces and rolls it out).
				local dir = Vector3.new(targetPos.X - flight.origin.X, 0, targetPos.Z - flight.origin.Z)
				dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.zero
				local arriveSpeed = (targetPos - flight.origin).Magnitude / math.max(flight.duration, 0.05)
				goLoose(b, dir * math.max(arriveSpeed * 0.35, 12) + Vector3.new(0, 10, 0))
			end
		end

	elseif state == "Loose" then
		-- Real-dodgeball feel: bounce with energy loss, roll with drag, settle.
		flight.velocity += Vector3.new(0, -BallConfig.BALL_GRAVITY, 0) * dt
		local newPos = ball.Position + flight.velocity * dt
		-- Walls: swept raycast (see sweepWall). Steep surfaces reflect like a
		-- real bounce; near-flat hits (roofs/floors) are left to the floor
		-- logic below, which owns vertical bounce, roll, and settle.
		local wallHit = sweepWall(ball.Position, newPos)
		if wallHit and wallHit.Normal.Y < 0.7 then
			local n = wallHit.Normal
			newPos = wallHit.Position + n * (BallConfig.BALL_DIAMETER / 2)
			local vn = flight.velocity:Dot(n)
			if vn < 0 then
				flight.velocity = (flight.velocity - 2 * vn * n) * BallConfig.WALL_RESTITUTION
			end
		end
		-- The floor is whatever roof is under the ball (raycast — roofs sit
		-- at different heights). Off the edge there is no floor: the ball
		-- falls into the clouds and respawns at its home spot.
		local floorFound = floorYBelow(newPos)
		local overFloor = floorFound ~= nil
		local floorY = (floorFound or -1e9) + BallConfig.BALL_DIAMETER / 2
		if newPos.Y < groundY - 80 then
			makeFreeBall(b, b.spawnPos)
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
				makeFreeBall(b, newPos)
				return
			end
		end
		moveBallRolling(b, newPos, dt)
		checkPickupAndBash(b)

	elseif state == "Free" then
		checkPickupAndBash(b)
	end
end

local function onHeartbeat(dt: number)
	stepDashBonks()
	stepBonkEffects()
	stepDrillRefill()
	for _, b in balls do
		stepBall(b, dt)
	end
end

-- ── Setup ──────────────────────────────────────────────────────────────────
function BallService.Start()
	local baseplate = Workspace:FindFirstChild("Baseplate") :: BasePart?
	if baseplate then
		groundY = baseplate.Position.Y + baseplate.Size.Y / 2
	end

	local function newBall(name: string, spawnPos: Vector3, isDrill: boolean): Ball
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * BallConfig.BALL_DIAMETER
		part.Color = BallConfig.BALL_COLOR
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		CollectionService:AddTag(part, "BalloutBall") -- client decor snap key
		part.Parent = Workspace

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
		stripe.CFrame = part.CFrame * CFrame.Angles(0, 0, math.rad(90))
		stripe.Parent = part
		-- No weld here: syncBallDecor creates a fresh weld only while held.

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
		shell.CFrame = part.CFrame
		shell.Parent = part

		local auraAtt = Instance.new("Attachment")
		auraAtt.Parent = part
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

		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(180, 90, 255)
		glow.Range = 9
		glow.Brightness = 1.2
		glow.Enabled = false
		glow.Parent = part

		local trail = Instance.new("Trail")
		local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0.4, 0); a0.Parent = part
		local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -0.4, 0); a1.Parent = part
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.25
		trail.Parent = part

		local b: Ball = {
			part = part,
			holdWeld = nil,
			state = "Free",
			holder = nil,
			flight = {
				target = nil,
				origin = Vector3.zero,
				sideOffset = Vector3.zero,
				arcHeight = 0,
				controlT = 0.5,
				duration = 1,
				s = 0,
				locked = true,
				velocity = Vector3.zero,
				thrower = nil,
				isPass = false,
				spiralDir = 0,
				targetPoint = nil,
			},
			botHoldStart = nil,
			chargeStart = nil,
			chargeFull = false,
			chargeRunSince = nil,
			auraOn = false,
			auraShell = shell,
			auraFlame = flame,
			auraLight = glow,
			stripe = stripe,
			decorWelds = {},
			spawnPos = spawnPos,
			isDrill = isDrill,
		}
		table.insert(balls, b)
		return b
	end

	-- The lobby (if built) owns the hangout ball; fall back to HQ midfield.
	local lobby = Workspace:FindFirstChild("BalloutLobby")
	local marker = if lobby then lobby:FindFirstChild("BallSpawn") else nil
	if marker and marker:IsA("BasePart") then
		BALL_SPAWN = marker.Position
	end

	-- ARENA TEST MODE: while the dev blockout is the active spawn, put the
	-- ball in the blockout too — otherwise it sits back in the lobby and the
	-- map can't be playtested at all. This also makes it a real SPAWNER
	-- rather than a one-off drop: spawnPos is the same marker, and the
	-- fall-off-the-world check re-frees the ball there, so the voids and the
	-- wrecking balls can eat it as often as they like and it always comes back.
	do
		local zone = Workspace:FindFirstChild("BuildZone")
		local blockout = zone and zone:FindFirstChild("ScaffoldRowBlockout")
		local testSpawn = blockout and blockout:FindFirstChild("TestSpawn")
		local arenaMarker = blockout and blockout:FindFirstChild("BallSpawn")
		if testSpawn and testSpawn:IsA("SpawnLocation") and testSpawn.Enabled
			and arenaMarker and arenaMarker:IsA("BasePart") then
			BALL_SPAWN = arenaMarker.Position
		end
	end
	primaryBall = newBall("Dodgeball", BALL_SPAWN, false)
	makeFreeBall(primaryBall, BALL_SPAWN)

	-- The training bot's practice ball spawns at his pad; stepDrillRefill
	-- hands it to him as soon as he registers.
	local hqMap = Workspace:FindFirstChild("BalloutMap")
	local pad = if hqMap then hqMap:FindFirstChild("DummyPad") else nil
	local drillSpawn = if pad and pad:IsA("BasePart") then pad.Position + Vector3.new(4, 2, 0) else BALL_SPAWN
	drillBall = newBall("DrillBall", drillSpawn, true)
	makeFreeBall(drillBall, drillSpawn)

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
			local b = heldBy(f)
			if b and not actionLocked(char) then
				AnimService.Windup(char)
				b.chargeStart = now()
				b.chargeFull = false
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
			if now() < (stunned[char] or 0) or actionLocked(char) then
				return
			end
			AnimService.TuckPulse(char, BallConfig.FLIP_TIME)
			-- Holding the ball? The carry pose comes right back after.
			task.delay(BallConfig.FLIP_TIME + 0.05, function()
				if heldBy(f) then
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
			if actionLocked(char) then
				return -- committed (dodge or catch): no balling up
			end
			GliderService.Disable(char) -- can't glide as a ball
			-- You can't be a ball AND hold a ball: drop it first.
			local held = heldBy(f)
			if held then
				AnimService.Reset(char)
				local look = f.root.CFrame.LookVector
				makeFreeBall(held, f.root.Position + Vector3.new(look.X, 0, look.Z) * 4)
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
		local held = if f then heldBy(f) else nil
		if f and held and not actionLocked(char) then
			AnimService.Reset(f.character)
			local look = f.root.CFrame.LookVector
			makeFreeBall(held, f.root.Position + Vector3.new(look.X, 0, look.Z) * 5)
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
		if actionLocked(char) and on ~= false then
			return -- committed (dodge or catch): no glider escape
		end
		if on == "flare" then
			AnimService.GlideFlare(char, extra == true)
		elseif on == true then
			GliderService.Enable(char)
			if heldBy(f) then
				applyCarry(f) -- right arm: ball
				AnimService.GlidePose(char, false) -- left hand: bar
			else
				AnimService.GlidePose(char, true)
			end
		else
			GliderService.Disable(char)
			AnimService.Reset(char)
			if heldBy(f) then
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
		if actionLocked(char) then
			return -- committed (dodge or catch): no passing out of it
		end
		if heldBy(f) then
			BallService.Pass(f)
		else
			local mate = teammateOf(f)
			if mate and heldBy(mate) then
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
		if heldBy(f) and not actionLocked(char) then
			applyCarry(f) -- mid-commitment the committed pose owns the body
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
		if actionLocked(char) then
			return -- no dash-chaining, and no dashing out of a catch bet
		end
		local d = if typeof(dir) == "Vector3" then Vector3.new(dir.X, 0, dir.Z) else Vector3.zero
		d = if d.Magnitude > 0.01 then d.Unit else Vector3.zero
		dashing[char] = {
			expires = now() + BallConfig.DODGE_TIME + 0.1,
			dir = d,
			lockUntil = now() + BallConfig.DODGE_TIME + BallConfig.DASH_ROLL_TIME,
		}
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

	-- Client-predicted wall bonk: the dash moves on the client, so the wall
	-- is felt there first (zero-delay tip-over). We validate — actually mid-
	-- dash, wall plausibly ahead of the (replication-lagged) root — then make
	-- it official: authoritative stun, birds, and the Bonk echo for status.
	Remotes.BonkReport.OnServerEvent:Connect(function(player)
		local char = player.Character
		local f = char and fighterFor(char)
		if not f then
			return
		end
		if now() < (stunned[char] or 0) then
			return
		end
		local dash = dashing[char]
		if not dash or now() > dash.lockUntil + 0.35 then
			return -- not dashing (or long past it): ignore the report
		end
		refreshWallRoots()
		local hit = Workspace:Raycast(f.root.Position, dash.dir * (BallConfig.BONK_WALL_RANGE + 6), wallRayParams)
		if hit and math.abs(hit.Normal.Y) < 0.5 then
			bonkFighter(f)
		end
	end)

	-- Fake throw: IDENTICAL motion to a real throw (windup came from the
	-- shared "start" phase; this is the release swing) — ball never leaves.
	-- curve/lob are echoed back so the client plays the same spin/hang.
	Remotes.FakeRequest.OnServerEvent:Connect(function(player, curveDir, isLob)
		local char = player.Character
		local f = char and fighterFor(char)
		local held = if f then heldBy(f) else nil
		if f and held and not actionLocked(char) then
			-- The fake cancels the windup: the aura falls back to whatever
			-- the ACTUAL caught-overcharge state is.
			held.chargeStart = nil
			held.chargeFull = false
			setCharged(held, (overcharge[f.character] or 0) > 0)
			AnimService.Swing(f.character)
			task.delay(0.35, function()
				if heldBy(f) then
					applyCarry(f)
				end
			end)
			feedback(f, "Fake", { curve = tonumber(curveDir) or 0, lob = isLob == true })
		end
	end)
end

return BallService
