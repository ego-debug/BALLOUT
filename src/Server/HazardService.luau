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
-- Anchored parts moved by CFrame do NOT carry players in Roblox, so riders are
-- detected and translated by the same delta each frame — otherwise you'd stand
-- still while the container slid out from under you.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

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
}

type Ferry = {
	part: BasePart,
	lowY: number,
	highY: number,
	period: number,
	phase: number,
}

local pendulums: { Pendulum } = {}
local ferries: { Ferry } = {}
local started = false

-- Ride support: anything standing on top of a ferry moves with it.
local function carryRiders(part: BasePart, delta: number)
	if math.abs(delta) < 1e-4 then
		return
	end
	local top = part.Position.Y + part.Size.Y / 2
	local halfX, halfZ = part.Size.X / 2 + 1.5, part.Size.Z / 2 + 1.5
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local rel = part.CFrame:PointToObjectSpace(root.Position)
			-- feet sit ~3 studs under the root; allow a small band above the deck
			local feetY = root.Position.Y - 3
			if math.abs(rel.X) <= halfX and math.abs(rel.Z) <= halfZ
				and feetY >= top - 1.5 and feetY <= top + 4 then
				root.CFrame = root.CFrame + Vector3.new(0, delta, 0)
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
	end
	for _, f in ferries do
		local mid = (f.lowY + f.highY) / 2
		local half = (f.highY - f.lowY) / 2
		local y = mid + half * math.sin((t / f.period) * math.pi * 2 + f.phase)
		local delta = y - f.part.Position.Y
		f.part.Position = Vector3.new(f.part.Position.X, y, f.part.Position.Z)
		carryRiders(f.part, delta)
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
		amp = math.rad(55),
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
	table.insert(ferries, { part = low, lowY = lowY, highY = highY, period = period, phase = -math.pi / 2 })
	table.insert(ferries, { part = high, lowY = lowY, highY = highY, period = period, phase = math.pi / 2 })
end

function HazardService.Bind(model: Instance)
	addPendulum(model, "WreckBall", "WreckChain", "CraneArm", 5.5)
	addPendulum(model, "WreckBall2", "WreckChain2", "CraneArm2", 6.5)
	addFerryPair(model, "ContainerRed", "ContainerBlue", 9)
	addFerryPair(model, "ContainerRedS", "ContainerBlueS", 10)

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
