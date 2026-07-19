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

	-- Whole-city safe zone: generously past the HQ playable bounds
	-- (x -107..160, y -9..76, z -120..75, measured in Studio).
	marker("SafeZone", Vector3.new(300, 110, 220), Vector3.new(26, 30, -22))

	model.Parent = Workspace
	return model
end

return Lobby
