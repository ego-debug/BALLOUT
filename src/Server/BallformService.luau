--!strict
-- Ballout | BallformService
-- KC's ball-up: the CHARACTER curls into a ball pose — knees to chest, arms
-- wrapped around the legs. Still a human body, not a sphere. Held while the
-- player keeps the ballform key down.
--
-- Also owns the "physics shell": body parts go non-collidable + frictionless
-- and an invisible sphere becomes the only collider. Used by the held
-- ballform AND briefly by the dash dive/landing roll, so a tumbling body can
-- never catch the floor (that corner-catching was the camera jitter).

local ServerScriptService = game:GetService("ServerScriptService")
local AnimService = require(ServerScriptService.AnimService)

local BallformService = {}

local held: { [Model]: boolean } = {}
local savedHip: { [Model]: number } = {}
local savedWalk: { [Model]: number } = {}

local BALLED_HIP_HEIGHT = 0.6 -- body sinks low so the curl reads compact
local SLIPPERY = PhysicalProperties.new(0.7, 0, 0, 100, 1)

type ShellData = {
	entries: { { part: BasePart, props: PhysicalProperties?, canCollide: boolean } },
	collider: BasePart,
}
local shells: { [Model]: ShellData } = {}

local function applyShell(character: Model)
	if shells[character] then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end

	local entries = {}
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(entries, {
				part = part,
				props = part.CustomPhysicalProperties,
				canCollide = part.CanCollide,
			})
			part.CustomPhysicalProperties = SLIPPERY
			part.CanCollide = false
		end
	end

	local sphere = Instance.new("Part")
	sphere.Name = "BallformCollider"
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.one * 2.8
	sphere.Transparency = 1
	sphere.CanCollide = true
	sphere.CanQuery = false
	sphere.CanTouch = false
	sphere.Massless = true
	-- Frictionless, moderately elastic: drops land with ONE subtle bounce
	-- (the client's micro-bounce filter kills anything smaller).
	sphere.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0.25, 100, 1)
	sphere.CFrame = CFrame.new(root.Position)
	sphere.Parent = character
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = sphere
	weld.Parent = sphere

	shells[character] = { entries = entries, collider = sphere }
end

local function removeShell(character: Model)
	local shell = shells[character]
	if not shell then
		return
	end
	shells[character] = nil
	for _, e in shell.entries do
		if e.part.Parent then
			e.part.CustomPhysicalProperties = e.props
			e.part.CanCollide = e.canCollide
		end
	end
	shell.collider:Destroy()
end

function BallformService.IsBalled(character: Model): boolean
	return held[character] == true
end

-- Returns true if the state actually changed (so the caller can notify).
function BallformService.Enable(character: Model): boolean
	if held[character] then
		return false
	end
	held[character] = true
	applyShell(character)
	AnimService.Tuck(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		savedHip[character] = humanoid.HipHeight
		humanoid.HipHeight = BALLED_HIP_HEIGHT
		-- Normal walking off; the client drives roll momentum instead.
		savedWalk[character] = humanoid.WalkSpeed
		humanoid.WalkSpeed = 0
	end
	return true
end

function BallformService.Disable(character: Model): boolean
	if not held[character] then
		return false
	end
	held[character] = nil
	AnimService.Untuck(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if savedHip[character] then
			humanoid.HipHeight = savedHip[character]
		end
		if savedWalk[character] then
			humanoid.WalkSpeed = savedWalk[character]
		end
	end
	savedHip[character] = nil
	savedWalk[character] = nil
	removeShell(character)
	return true
end

-- Temporary shell (dash dive + landing roll). Auto-removes unless the
-- player balled up in the meantime — then the held ballform owns it.
function BallformService.PhysicsShell(character: Model, duration: number)
	applyShell(character)
	task.delay(duration, function()
		if not held[character] then
			removeShell(character)
		end
	end)
end

return BallformService
