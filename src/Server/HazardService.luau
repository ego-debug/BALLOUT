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

local function launch(player: Player, char: Model, dir: Vector3)
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and hum) then
		return
	end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero
	hum:ChangeState(Enum.HumanoidStateType.Physics)
	root.AssemblyLinearVelocity =
		flat * BallConfig.WRECK_LAUNCH_OUT + Vector3.new(0, BallConfig.WRECK_LAUNCH_UP, 0)
	task.delay(BallConfig.WRECK_FLY_TIME, function()
		if char.Parent and hum.Health > 0 then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function checkImpacts(p: Pendulum, ballPos: Vector3, travel: Vector3)
	local reach = p.ball.Size.X / 2 + BallConfig.WRECK_HIT_PAD
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			if (root.Position - ballPos).Magnitude <= reach then
				if now - (hitAt[player] or -math.huge) >= BallConfig.WRECK_HIT_COOLDOWN then
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
	-- the dev blockout; the real arena can Bind() itself the same way
	local zone = Workspace:FindFirstChild("BuildZone")
	local blockout = zone and zone:FindFirstChild("ScaffoldRowBlockout")
	if blockout then
		local nb, nf = HazardService.Bind(blockout)
		print(("[Ballout] Hazards live: %d wrecking balls, %d ferries"):format(nb, nf))
	end
end

return HazardService
