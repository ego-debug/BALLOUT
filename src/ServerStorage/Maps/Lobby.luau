--!strict
-- Ballout | Lobby island builder
--
-- The main social hub: a big sky island where everyone spawns, hangs out,
-- parties up, and walks into queue portals. Built from scratch at every
-- server boot (destroy-and-rebuild, same pattern as tools/build_map.luau),
-- so the layout lives in git as code — never inside the .rbxl.
--
-- Markers other systems read:
--   BalloutLobby.BallSpawn  — where the hangout ball spawns/respawns
--   BalloutLobby.SafeZone   — invisible volume; hits inside never KO
--   BalloutLobby.QueuePads.* — placeholder portal pads (Phase 3 wires them)
--
-- v1 is deliberately basic — functional layout first, art pass later.

local Workspace = game:GetService("Workspace")

local Lobby = {}

-- Island sits high in the sky, well away from the HQ map near the origin.
local CENTER = Vector3.new(0, 320, 600)
local DECK_W = 280 -- x
local DECK_D = 220 -- z
local DECK_T = 6
local DECK_TOP = CENTER.Y + DECK_T / 2 -- y of the walkable surface

local COL_DECK = Color3.fromRGB(99, 95, 98)
local COL_RIM = Color3.fromRGB(58, 56, 60)
local COL_PARTY = Color3.fromRGB(58, 125, 21)
local COL_QUEUE_LIVE = Color3.fromRGB(196, 40, 28)
local COL_QUEUE_SOON = Color3.fromRGB(80, 80, 84)
local COL_SPAWN = Color3.fromRGB(39, 70, 45)
local COL_COVER = Color3.fromRGB(160, 95, 53)

local function mk(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(part: BasePart, text: string, studsUp: number)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(24, 0, 5, 0) -- studs
	bb.StudsOffset = Vector3.new(0, studsUp, 0)
	bb.MaxDistance = 220
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.4
	t.Text = text
	t.Parent = bb
	bb.Parent = part
end

function Lobby.Build(): Model
	local old = Workspace:FindFirstChild("BalloutLobby")
	if old then
		old:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "BalloutLobby"

	-- ── Deck + rim rail (ball bounces off the rail; players can hop it) ──
	mk(model, "Deck", Vector3.new(DECK_W, DECK_T, DECK_D), CENTER, COL_DECK)
	local railH = 3
	local railY = DECK_TOP + railH / 2
	mk(model, "RailN", Vector3.new(DECK_W + 3, railH, 1.5), Vector3.new(CENTER.X, railY, CENTER.Z - DECK_D / 2), COL_RIM)
	mk(model, "RailS", Vector3.new(DECK_W + 3, railH, 1.5), Vector3.new(CENTER.X, railY, CENTER.Z + DECK_D / 2), COL_RIM)
	mk(model, "RailW", Vector3.new(1.5, railH, DECK_D + 3), Vector3.new(CENTER.X - DECK_W / 2, railY, CENTER.Z), COL_RIM)
	mk(model, "RailE", Vector3.new(1.5, railH, DECK_D + 3), Vector3.new(CENTER.X + DECK_W / 2, railY, CENTER.Z), COL_RIM)

	-- ── Spawn plaza (south side): everyone appears here ──────────────────
	local spawnZ = CENTER.Z + 62
	for i, x in { -30, -10, 10, 30 } do
		for j, z in { spawnZ, spawnZ + 16 } do
			local s = Instance.new("SpawnLocation")
			s.Name = ("SpawnPad%d_%d"):format(i, j)
			s.Size = Vector3.new(6, 0.5, 6)
			s.Position = Vector3.new(CENTER.X + x, DECK_TOP + 0.25, z)
			s.Color = COL_SPAWN
			s.Material = Enum.Material.SmoothPlastic
			s.Anchored = true
			s.Neutral = true
			s.Duration = 0 -- no forcefield flash
			s.TopSurface = Enum.SurfaceType.Smooth
			s.Parent = model
		end
	end

	-- ── Queue portals (north edge): placeholder pads, Phase 3 wires them ─
	local pads = Instance.new("Folder")
	pads.Name = "QueuePads"
	local portalZ = CENTER.Z - DECK_D / 2 + 18
	local portals = {
		{ x = -60, name = "TeamKO", text = "TEAM KO  3v3", live = true },
		{ x = 0, name = "Soon1", text = "COMING SOON", live = false },
		{ x = 60, name = "Soon2", text = "COMING SOON", live = false },
	}
	for _, def in portals do
		local cx = CENTER.X + def.x
		local color = if def.live then COL_QUEUE_LIVE else COL_QUEUE_SOON
		local pad = mk(pads, def.name, Vector3.new(14, 0.3, 14), Vector3.new(cx, DECK_TOP + 0.15, portalZ), color, Enum.Material.Neon)
		mk(pads, def.name .. "PillarL", Vector3.new(2, 14, 2), Vector3.new(cx - 8, DECK_TOP + 7, portalZ), COL_RIM)
		mk(pads, def.name .. "PillarR", Vector3.new(2, 14, 2), Vector3.new(cx + 8, DECK_TOP + 7, portalZ), COL_RIM)
		local bar = mk(pads, def.name .. "Bar", Vector3.new(18, 2, 2), Vector3.new(cx, DECK_TOP + 15, portalZ), color, Enum.Material.Neon)
		label(bar, def.text, 3)
	end
	pads.Parent = model

	-- ── Party-up area (west side): marked ground + tables to gather at ───
	mk(model, "PartyFloor", Vector3.new(60, 0.2, 100), Vector3.new(CENTER.X - 95, DECK_TOP + 0.1, CENTER.Z), COL_PARTY, Enum.Material.Grass)
	for i, off in { Vector3.new(-105, 0, -30), Vector3.new(-85, 0, -10), Vector3.new(-105, 0, 15), Vector3.new(-85, 0, 35) } do
		local t = mk(model, "PartyTable" .. i, Vector3.new(6, 3, 6), CENTER + off + Vector3.new(0, DECK_T / 2 + 1.5, 0), COL_RIM, Enum.Material.WoodPlanks)
		t.Shape = Enum.PartType.Cylinder
		t.Orientation = Vector3.new(0, 0, 90)
	end

	-- ── Center court: a few cover blocks so ball toss has hide-and-peek ──
	for i, off in { Vector3.new(-25, 0, -20), Vector3.new(25, 0, -20), Vector3.new(-25, 0, 25), Vector3.new(25, 0, 25) } do
		mk(model, "Cover" .. i, Vector3.new(10, 4, 3), CENTER + off + Vector3.new(0, DECK_T / 2 + 2, 0), COL_COVER, Enum.Material.Brick)
	end

	-- ── Markers ──────────────────────────────────────────────────────────
	local ballSpawn = mk(model, "BallSpawn", Vector3.new(2, 2, 2), Vector3.new(CENTER.X, DECK_TOP + 3, CENTER.Z), Color3.new(1, 1, 1))
	ballSpawn.Transparency = 1
	ballSpawn.CanCollide = false
	ballSpawn.CanQuery = false -- invisible to the ball's wall/floor raycasts
	ballSpawn.CanTouch = false

	local zone = mk(model, "SafeZone", Vector3.new(DECK_W + 20, 80, DECK_D + 20), CENTER + Vector3.new(0, 40, 0), Color3.new(1, 1, 1))
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanQuery = false -- ditto: never blocks throws
	zone.CanTouch = false

	model.Parent = Workspace

	-- The lobby owns spawning now: any older spawn (the HQ dev spawn) is
	-- disabled at runtime — the place file itself is left untouched.
	for _, d in Workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and not d:IsDescendantOf(model) then
			d.Enabled = false
		end
	end

	return model
end

return Lobby
