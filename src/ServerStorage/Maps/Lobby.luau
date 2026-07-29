--!strict
-- Ballout | Lobby overlay (the HQ city IS the lobby)
--
-- The visible lobby is the HQ map itself — hangout city, queue rooms on the
-- old soccer-court footprint (see tools/build_map.luau). This overlay only
-- contributes the invisible FUNCTIONAL markers, rebuilt every boot so they
-- live in git, never inside the .rbxl:
--
--   BalloutLobby.BallSpawn — where the hangout ball spawns/respawns
--   BalloutLobby.SafeZone  — covers the whole HQ; hits inside never KO
--
-- Match arenas (Phase 4+) are built OUTSIDE the SafeZone, so damage simply
-- turns back on there. Queue pads are map-side named parts (QueuePad*) that
-- the queue system reads directly.

local Workspace = game:GetService("Workspace")

local Lobby = {}

function Lobby.Build(): Model
	local old = Workspace:FindFirstChild("BalloutLobby")
	if old then
		old:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "BalloutLobby"

	local function marker(name: string, size: Vector3, pos: Vector3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = pos
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false -- invisible to the ball's wall/floor raycasts
		p.CanTouch = false
		p.Parent = model
		return p
	end

	-- The hangout ball lives at HQ midfield, same spot as always.
	marker("BallSpawn", Vector3.new(2, 2, 2), Vector3.new(0, 4, -20))

	-- Spawner pad DEVICE: circle on the deck, the ball levitates over it
	-- (same furniture as the arena pads — players learn it in the lobby).
	local base = Instance.new("Part")
	base.Name = "BallPad"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(0.5, 7, 7)
	base.CFrame = CFrame.new(0, 0.25, -20) * CFrame.Angles(0, 0, math.rad(90))
	base.Color = Color3.fromRGB(38, 36, 44)
	base.Material = Enum.Material.Metal
	base.Anchored = true
	base.Parent = model
	local ring = Instance.new("Part")
	ring.Name = "BallPadRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, 5.6, 5.6)
	ring.CFrame = CFrame.new(0, 0.55, -20) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 170, 60)
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Parent = model
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 170, 60)
	glow.Range = 12
	glow.Brightness = 0.9
	glow.Parent = ring

	-- THE spawn: everyone spawns in the garage. This used to ride on the dev
	-- blockout's TestSpawn — which is stripped now that Scaffold Row is a real
	-- arena — so the lobby owns a proper (invisible) SpawnLocation over the
	-- map's GarageSpawn pad.
	local hq = Workspace:FindFirstChild("BalloutMap")
	local pad = if hq then hq:FindFirstChild("GarageSpawn") else nil
	local spawnPos = if pad and pad:IsA("BasePart")
		then pad.Position + Vector3.new(0, 0.6, 0)
		else Vector3.new(-5, 0.8, -43)
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "GarageSpawnLocation"
	spawnLoc.Size = Vector3.new(9, 0.4, 9)
	spawnLoc.CFrame = CFrame.lookAt(spawnPos, Vector3.new(spawnPos.X, spawnPos.Y, spawnPos.Z + 30)) -- face out the garage door
	spawnLoc.Transparency = 1
	spawnLoc.CanCollide = false
	spawnLoc.CanQuery = false
	spawnLoc.Anchored = true
	spawnLoc.Duration = 0
	spawnLoc.Neutral = true
	spawnLoc.Parent = model

	-- Whole-city safe zone: generously past the HQ playable bounds
	-- (x -107..160, y -9..76, z -120..75, measured in Studio).
	marker("SafeZone", Vector3.new(300, 110, 220), Vector3.new(26, 30, -22))

	model.Parent = Workspace
	return model
end

return Lobby
