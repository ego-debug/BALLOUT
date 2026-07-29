--!strict
-- Ballout | HazardService
-- Drives the moving map hazards. Until now these were only ever POSED in the
-- blockout (a ball hanging at one angle, containers frozen at their extremes)
-- — nothing animated them. This is that missing runtime.
--
-- WRECKING BALLS: true single-point pendulums. The chain hangs from the crane
-- arm's TIP and the whole chain+ball assembly rotates about that one pivot in
-- the arm's own vertical plane, so the ball is fastest and lowest at the
-- bottom of the arc and slowest at the ends — the shape the owner sketched.
--
-- PIT CONTAINERS: vertical ferries running anti-phase in pairs (one rising
-- while the other falls, crossing at mid-travel).
--
-- Ferries are REAL PHYSICS PLATFORMS (unanchored, held by a rigid
-- AlignPosition) rather than anchored parts shoved by CFrame. An anchored
-- part does not carry a rider, and teleporting the player's root each frame
-- to compensate fights the humanoid controller — that combination is what
-- made them unridable: jittery, no walking, no jumping.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BallConfig = require(ReplicatedStorage.BallConfig)
local SoundKit = require(ReplicatedStorage.SoundKit)
local BallService = require(script.Parent.BallService)

local HazardService = {}

type Pendulum = {
	ball: BasePart,
	chain: BasePart,
	pivot: Vector3,
	length: number,
	swing: Vector3, -- horizontal unit vector the ball swings along
	amp: number,    -- radians
	period: number,
	phase: number,
	lastPos: Vector3?, -- previous frame, for the ball's travel direction
}

type Ferry = {
	part: BasePart,
	align: AlignPosition,
	lowY: number,
	highY: number,
	period: number,
	phase: number,
}

local pendulums: { Pendulum } = {}
local ferries: { Ferry } = {}
local started = false

-- ── Wrecking-ball impacts ───────────────────────────────────────────────────
-- The ball threatens a corridor, not a pixel: hit radius is its own radius
-- plus WRECK_HIT_PAD. On contact you get launched along the ball's actual
-- direction of travel plus a big vertical kick.
--
-- The humanoid MUST be put into Physics state first — in any walking state
-- the controller brakes velocity writes and the launch just fizzles (the
-- same trap the dash/ballform code hits).
local hitAt: { [Player]: number } = {}

-- Players currently mid-flight. A ONE-SHOT velocity write is not enough: the
-- humanoid state machine drops back out of Physics into Freefall and its
-- controller damps horizontal motion, so the victim ends up going almost
-- straight up (measured 22 studs of travel where the launch called for ~93).
-- The horizontal component is therefore re-asserted every frame for the whole
-- flight, while gravity is left to shape Y. Same lesson as the dash code:
-- scripted movement has to be driven per-frame, not fired once.
type Flight = { root: BasePart, hum: Humanoid, hx: number, hz: number, until_: number, from: number, primed: boolean }
local flying: { [Player]: Flight } = {}

-- Don't keep pushing once they're back on the ground, or the victim skates
-- along the floor for the rest of the window. Small grace period first so the
-- frame right after launch (still touching ground) doesn't cancel it.
-- Long enough to cover the whole ASCENT (apex is ~0.6s at the current launch
-- speed) so a stray floor contact can never truncate the arc.
local LAND_GRACE = 0.7

local function stepFlights()
	local now = os.clock()
	for player, f in flying do
		local landed = now - f.from > LAND_GRACE
			and f.hum.FloorMaterial ~= Enum.Material.Air
		if now >= f.until_ or landed or not f.root.Parent or f.hum.Health <= 0 then
			flying[player] = nil
			if f.root.Parent and f.hum.Health > 0 then
				f.hum.PlatformStand = false
				f.hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		else
			-- PlatformStand (not just Physics state) is what actually frees the
			-- body: the humanoid's hip-height constraint otherwise pins it to
			-- the floor, so the victim SLID instead of launching (rises of 4,
			-- 21 and 4 studs from identical hits). Angular velocity is zeroed
			-- every frame — a limp body free to spin is what let the massless
			-- limbs catch the floor and catapult the character in the old bonk
			-- bug.
			f.hum.PlatformStand = true
			f.root.AssemblyAngularVelocity = Vector3.zero
			if not f.primed then
				-- ChangeState and the velocity write in launch() race each
				-- other: if the humanoid is still in a walking state when the
				-- write lands, the controller eats the vertical and the victim
				-- barely leaves the floor (measured rises of 33, 23 and 9 studs
				-- from identical hits). Re-assert the FULL launch on the first
				-- frame, by which point Physics state is guaranteed.
				f.primed = true
				f.root.AssemblyLinearVelocity = Vector3.new(f.hx, BallConfig.WRECK_LAUNCH_UP, f.hz)
			else
				local v = f.root.AssemblyLinearVelocity
				f.root.AssemblyLinearVelocity = Vector3.new(f.hx, v.Y, f.hz)
			end
		end
	end
end

local function launch(player: Player, char: Model, dir: Vector3)
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and hum) then
		return
	end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero
	local hx = flat.X * BallConfig.WRECK_LAUNCH_OUT
	local hz = flat.Z * BallConfig.WRECK_LAUNCH_OUT
	-- take their actions away: no dodging or gliding out of the punt
	BallService.ApplyStun(char, BallConfig.WRECK_STUN)
	SoundKit.PlayAt(root, "clang") -- the wrecking ball RINGS on contact
	hum.PlatformStand = true
	-- lift clear of the floor so the ground contact that was pinning the
	-- launch is broken on the very first frame
	root.CFrame = root.CFrame + Vector3.new(0, 3, 0)
	root.AssemblyAngularVelocity = Vector3.zero
	root.AssemblyLinearVelocity = Vector3.new(hx, BallConfig.WRECK_LAUNCH_UP, hz)
	flying[player] = {
		root = root, hum = hum, hx = hx, hz = hz,
		from = os.clock(),
		until_ = os.clock() + BallConfig.WRECK_FLY_TIME,
		primed = false,
	}
end

local function checkImpacts(p: Pendulum, ballPos: Vector3, travel: Vector3)
	local reach = p.ball.Size.X / 2 + BallConfig.WRECK_HIT_PAD
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		-- Only GROUNDED players can be hit. The flight entry clears after
		-- WRECK_FLY_TIME but the arc itself lasts longer (~2.3s), so an
		-- airborne victim was falling back through the corridor and getting
		-- punted again — stacking to 100+ studs off a single swing. Requiring
		-- ground contact makes one swing mean exactly one launch.
		if root and root:IsA("BasePart") and hum and hum.FloorMaterial ~= Enum.Material.Air then
			if (root.Position - ballPos).Magnitude <= reach then
				-- Never re-hit someone already in flight. The corridor is wide
				-- and the victim rises through it, so without this they get
				-- JUGGLED: measured three stacked launches from one swing,
				-- turning a 34-stud pop into a 130-stud punt.
				if flying[player] == nil
					and now - (hitAt[player] or -math.huge) >= BallConfig.WRECK_HIT_COOLDOWN then
					hitAt[player] = now
					-- shove along travel; fall back to radial if the ball is
					-- momentarily stationary at the top of its arc
					local dir = travel
					if dir.Magnitude < 0.01 then
						dir = root.Position - ballPos
					end
					launch(player, char :: Model, dir)
				end
			end
		end
	end
end

local function step()
	local t = os.clock()
	stepFlights()
	for _, p in pendulums do
		local theta = p.amp * math.sin((t / p.period) * math.pi * 2 + p.phase)
		local dir = (Vector3.new(0, -1, 0) * math.cos(theta)) + (p.swing * math.sin(theta))
		local ballPos = p.pivot + dir * p.length
		p.ball.Position = ballPos
		-- chain spans pivot -> ball, oriented along that line
		local mid = p.pivot:Lerp(ballPos, 0.5)
		local span = (ballPos - p.pivot).Magnitude
		p.chain.Size = Vector3.new(p.chain.Size.X, span, p.chain.Size.Z)
		p.chain.CFrame = CFrame.lookAt(mid, ballPos) * CFrame.Angles(math.rad(90), 0, 0)
		local travel = if p.lastPos then ballPos - p.lastPos else Vector3.zero
		p.lastPos = ballPos
		checkImpacts(p, ballPos, travel)
	end
	for _, f in ferries do
		local mid = (f.lowY + f.highY) / 2
		local half = (f.highY - f.lowY) / 2
		local y = mid + half * math.sin((t / f.period) * math.pi * 2 + f.phase)
		-- move the TARGET, not the part: the physics solver carries the
		-- platform (and anyone standing on it) there itself
		f.align.Position = Vector3.new(f.align.Position.X, y, f.align.Position.Z)
	end
end

-- Register one crane: ball + chain + the arm whose tip is the pivot.
local function addPendulum(model: Instance, ballName: string, chainName: string, armName: string, period: number)
	local ball = model:FindFirstChild(ballName)
	local chain = model:FindFirstChild(chainName)
	local arm = model:FindFirstChild(armName)
	if not (ball and chain and arm) then
		return
	end
	if not (ball:IsA("BasePart") and chain:IsA("BasePart") and arm:IsA("BasePart")) then
		return
	end
	-- The ball does NOT collide. An anchored part swept through a character
	-- imparts its own huge shove, which stacked on top of the scripted launch
	-- (measured ~64 studs of rise against a configured 34) and could just as
	-- easily crush someone into geometry. With collision off, the hit is
	-- entirely the scripted launch: predictable and tunable from BallConfig.
	ball.CanCollide = false
	chain.CanCollide = false

	-- pivot = top of the chain as authored; swing along the arm's long axis
	local pivot = Vector3.new(chain.Position.X, chain.Position.Y + chain.Size.Y / 2, chain.Position.Z)
	local look = arm.CFrame.LookVector
	local swing = Vector3.new(look.X, 0, look.Z)
	swing = if swing.Magnitude > 0.01 then swing.Unit else Vector3.new(0, 0, 1)
	table.insert(pendulums, {
		ball = ball,
		chain = chain,
		pivot = pivot,
		length = (pivot - ball.Position).Magnitude,
		swing = swing,
		amp = math.rad(38), -- narrower arc: slower sweep at the bottom
		period = period,
		phase = 0,
	})
end

-- Register an anti-phase ferry pair. The two parts are authored at opposite
-- extremes, so their poses define the travel range.
local function addFerryPair(model: Instance, lowName: string, highName: string, period: number)
	local low = model:FindFirstChild(lowName)
	local high = model:FindFirstChild(highName)
	if not (low and high and low:IsA("BasePart") and high:IsA("BasePart")) then
		return
	end
	local lowY, highY = low.Position.Y, high.Position.Y
	-- PHYSICS PLATFORMS. An ANCHORED part moved by CFrame does not carry a
	-- player — the character keeps its own velocity and the platform slides
	-- out from under it, and teleporting the root each frame to compensate
	-- fights the humanoid controller (that was the jitter: no walking, no
	-- jumping). Instead the container is unanchored and held by a rigid
	-- AlignPosition; the solver moves it, so riders are carried natively and
	-- can walk and jump normally.
	local function makePlatform(part: BasePart, phase: number)
		part.Anchored = false
		part.CanCollide = true
		part.Massless = false
		local att = Instance.new("Attachment")
		att.Name = "FerryAttach"
		att.Parent = part
		local ap = Instance.new("AlignPosition")
		ap.Mode = Enum.PositionAlignmentMode.OneAttachment
		ap.Attachment0 = att
		ap.RigidityEnabled = true
		ap.Position = part.Position
		ap.Parent = part
		local ao = Instance.new("AlignOrientation")
		ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
		ao.Attachment0 = att
		ao.RigidityEnabled = true
		ao.CFrame = part.CFrame.Rotation -- stays level, never tips or spins
		ao.Parent = part
		table.insert(ferries, {
			part = part, align = ap, lowY = lowY, highY = highY,
			period = period, phase = phase,
		})
	end
	makePlatform(low, -math.pi / 2)
	makePlatform(high, math.pi / 2)
end

function HazardService.Bind(model: Instance)
	addPendulum(model, "WreckBall", "WreckChain", "CraneArm", 12)
	addPendulum(model, "WreckBall2", "WreckChain2", "CraneArm2", 14)
	addFerryPair(model, "ContainerRed", "ContainerBlue", 20)
	addFerryPair(model, "ContainerRedS", "ContainerBlueS", 23)

	if not started and (#pendulums > 0 or #ferries > 0) then
		started = true
		RunService.Heartbeat:Connect(step)
	end
	return #pendulums, #ferries
end

function HazardService.Start()
	-- Scaffold Row is promoted to Workspace.BalloutArena at boot
	-- (Maps/ArenaScaffoldRow); fall back to the dev-yard blockout so the
	-- hazards still run for pure map-authoring sessions.
	local target: Instance? = Workspace:FindFirstChild("BalloutArena")
	if not target then
		local zone = Workspace:FindFirstChild("BuildZone")
		target = zone and zone:FindFirstChild("ScaffoldRowBlockout")
	end
	if target then
		local nb, nf = HazardService.Bind(target)
		print(("[Ballout] Hazards live: %d wrecking balls, %d ferries"):format(nb, nf))
	end
end

return HazardService
