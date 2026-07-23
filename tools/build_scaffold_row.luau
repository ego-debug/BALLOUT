--!strict
-- Ballout | SCAFFOLD ROW — "FRACTURED CORE" arrangement (v26, 2026-07-23)
-- Run in EDIT mode: require(game:GetService("ServerStorage").MapTools.build_scaffold_row:Clone())
-- Rebuilds BuildZone.ScaffoldRowBlockout from scratch. SOURCE OF TRUTH.
--
-- ORIGINAL composition (owner-approved divergence pass): dense central core
-- with X-shaped circulation — corner spawns, hazards on opposing DIAGONALS.
--   CORE (center): tower frame, bay walls, floors 14/28, hugging scaffold
--   N+S:  TWIN mirrored VOID pits flanking the core, each with an
--         anti-phase container pair (scaffold floats over the north one)
--   NE+SE: TWIN cranes — mirrored wrecking balls arc diagonally toward the
--         core corners; both flanks are hazard lanes, the core is the only
--         clean channel
--   NE/SW: raised spawn yards (diagonal spawn axis)
--   Edge roads ring the map with cover rhythm + three blocker towers
-- Every route feeds the core. Nothing shares zone adjacency with any
-- existing game's map.

local Workspace = game:GetService("Workspace")

local zone = Workspace:FindFirstChild("BuildZone")
if not zone then
	error("BuildZone missing — build the yard first")
end
local old = zone:FindFirstChild("ScaffoldRowBlockout")
if old then
	old:Destroy()
end
local m = Instance.new("Model")
m.Name = "ScaffoldRowBlockout"

local GREY = Color3.fromRGB(163, 162, 165)
local GREY_DK = Color3.fromRGB(120, 120, 124)
local GREY_LT = Color3.fromRGB(200, 200, 203)
local DARK = Color3.fromRGB(52, 52, 56)
local SKIRT = Color3.fromRGB(110, 110, 116)
local RAMP_ORANGE = Color3.fromRGB(235, 150, 60)
local BROWN = Color3.fromRGB(150, 105, 65)
local CX, CZ = 0, -650

local function mk(name: string, size: Vector3, pos: Vector3, color: Color3?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos + Vector3.new(CX, 0, CZ)
	p.Color = color or GREY
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end
local function mkCF(name: string, size: Vector3, cf: CFrame, color: Color3?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color or GREY
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.Parent = m
	return p
end
local function wedge(name: string, size: Vector3, pos: Vector3, yaw: number, color: Color3?): WedgePart
	local r = Instance.new("WedgePart")
	r.Name = name
	r.Size = size
	r.Anchored = true
	r.Color = color or GREY
	r.Material = Enum.Material.SmoothPlastic
	r.CFrame = CFrame.new(pos + Vector3.new(CX, 0, CZ)) * CFrame.Angles(0, math.rad(yaw), 0)
	r.Parent = m
	return r
end
local function label(part: BasePart, text: string)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(26, 0, 4, 0)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.MaxDistance = 400
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 220, 90)
	t.TextStrokeTransparency = 0.3
	t.Text = text
	t.Parent = bb
	bb.Parent = part
end

-- ══ GROUND with TWIN VOID pits (x -24..24; z -82..-25 and z 25..82) ═════════
mk("Dirt", Vector3.new(400, 1, 58), Vector3.new(0, 0.5, -111), GREY_DK)
mk("Dirt", Vector3.new(400, 1, 50), Vector3.new(0, 0.5, 0), GREY_DK)
mk("Dirt", Vector3.new(400, 1, 58), Vector3.new(0, 0.5, 111), GREY_DK)
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		mk("Dirt", Vector3.new(176, 1, 57), Vector3.new(sx * 112, 0.5, sz * 53.5), GREY_DK)
	end
end
for _, sz in { -1, 1 } do
	mk("PitWall", Vector3.new(48, 30, 1), Vector3.new(0, -14, sz * 82.5), DARK)
	mk("PitWall", Vector3.new(48, 30, 1), Vector3.new(0, -14, sz * 25.5), DARK)
	mk("PitWall", Vector3.new(1, 30, 57), Vector3.new(-24.5, -14, sz * 53.5), DARK)
	mk("PitWall", Vector3.new(1, 30, 57), Vector3.new(24.5, -14, sz * 53.5), DARK)
end
do -- yard floor: repunch to the canyon (world x -160..-30, z -760..-690)
	for _, c in zone:GetChildren() do
		if c.Name == "BuildFloor" then
			c:Destroy()
		end
	end
	local function slab(size: Vector3, worldPos: Vector3)
		local p = Instance.new("Part")
		p.Name = "BuildFloor"
		p.Size = size
		p.Position = worldPos
		p.Color = GREY_DK
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.Parent = zone
	end
	slab(Vector3.new(520, 4, 108), Vector3.new(0, -2, -786))
	slab(Vector3.new(520, 4, 50), Vector3.new(0, -2, -650))
	slab(Vector3.new(520, 4, 108), Vector3.new(0, -2, -514))
	slab(Vector3.new(236, 4, 57), Vector3.new(-142, -2, -703.5))
	slab(Vector3.new(236, 4, 57), Vector3.new(142, -2, -703.5))
	slab(Vector3.new(236, 4, 57), Vector3.new(-142, -2, -596.5))
	slab(Vector3.new(236, 4, 57), Vector3.new(142, -2, -596.5))
end

-- ══ CORE: the tower exactly as evolved (center 0,0) ═════════════════════════
for ix = -1, 1 do
	for iz = -1, 1 do
		mk("TowerPillar", Vector3.new(3, 28, 3), Vector3.new(ix * 24, 14, iz * 24))
	end
end
mk("TowerFloor2", Vector3.new(51, 1, 29.5), Vector3.new(0, 14.5, -10.75))
mk("TowerFloor3", Vector3.new(51, 1, 21.5), Vector3.new(0, 28.5, -14.75))
mk("TowerFloor3", Vector3.new(27, 1, 29.5), Vector3.new(-12, 28.5, 10.75))
mk("TowerFloor3", Vector3.new(3, 1, 5.5), Vector3.new(24, 28.5, -1.25))
local wn = mk("TowerWallN", Vector3.new(21, 14, 2), Vector3.new(-12, 7, -24))
label(wn, "CORE TOWER — first-floor walls on the pillar lines")
mk("TowerWallN", Vector3.new(21, 14, 2), Vector3.new(12, 7, -24))
mk("TowerWallE", Vector3.new(2, 14, 21), Vector3.new(24, 7, -12))
mk("TowerWallW", Vector3.new(2, 14, 21), Vector3.new(-24, 7, 12))
mk("TowerWallS", Vector3.new(21, 14, 2), Vector3.new(-12, 7, 24))
mk("ScafN", Vector3.new(62, 0.6, 6), Vector3.new(-2, 14, -29.2))
-- east walkway STOPS at the roof-strip line (z ~1.5): the bare SE pillar
-- region and the ball's diagonal approach have NO scaffold
mk("ScafE", Vector3.new(6, 0.6, 30), Vector3.new(29.2, 14, -13))
do
	local ANG = math.rad(29)
	local function bracket(cf: CFrame)
		local b = Instance.new("Part")
		b.Name = "ScafBracket"
		b.Size = Vector3.new(0.8, 0.8, 8.5)
		b.Color = BROWN
		b.Material = Enum.Material.SmoothPlastic
		b.Anchored = true
		b.CFrame = cf
		b.Parent = m
	end
	for _, bx in { -26, -2, 22 } do
		bracket(CFrame.new(Vector3.new(bx, 11.4, -28.6) + Vector3.new(CX, 0, CZ)) * CFrame.Angles(ANG, 0, 0))
	end
	for _, bz in { -22, 0 } do
		bracket(CFrame.new(Vector3.new(28.6, 11.4, bz) + Vector3.new(CX, 0, CZ)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(-ANG, 0, 0))
	end
end
wedge("ScafRamp", Vector3.new(8, 14, 22), Vector3.new(-46, 7, -29.5), 90)
for _, cdef in { { 46, 10 }, { -6, 48 }, { 48, -34 }, { -44, 44 } } do
	mk("PlazaCrate", Vector3.new(6, 4.5, 5), Vector3.new(cdef[1], 3.25, cdef[2]))
end

-- ══ CONTAINERS over the pit (original spot; anti-phase cycle spec:
-- LOW top just under ground, HIGH top y 45, crossing mid-travel) ═════════════
local red = mk("ContainerRed", Vector3.new(10, 8, 26), Vector3.new(-9, -6, -56), Color3.fromRGB(140, 90, 90))
label(red, "CONTAINER A — shown LOW: sunk into the void, top just under ground")
local blue = mk("ContainerBlue", Vector3.new(10, 8, 26), Vector3.new(9, 41, -50), Color3.fromRGB(90, 110, 140))
label(blue, "CONTAINER B — shown HIGH: anti-phase, crossing mid-travel")
local redS = mk("ContainerRedS", Vector3.new(10, 8, 26), Vector3.new(-9, -6, 56), Color3.fromRGB(140, 90, 90))
label(redS, "CONTAINER C — south pit, shown LOW")
local blueS = mk("ContainerBlueS", Vector3.new(10, 8, 26), Vector3.new(9, 41, 50), Color3.fromRGB(90, 110, 140))
label(blueS, "CONTAINER D — south pit, shown HIGH (anti-phase)")

-- ══ SE: WRECKING BALL YARD (diagonal arc toward the core) ═══════════════════
mk("CraneMast", Vector3.new(6, 48, 6), Vector3.new(120, 24, 105))
mkCF("CraneArm", Vector3.new(4, 3, 130),
	CFrame.new(Vector3.new(74, 46, 66) + Vector3.new(CX, 0, CZ)) * CFrame.Angles(0, math.rad(45), 0))
mkCF("WreckChain", Vector3.new(1, 26, 1),
	CFrame.new(Vector3.new(60, 33, 52) + Vector3.new(CX, 0, CZ)))
local ball = mk("WreckBall", Vector3.new(20, 20, 20), Vector3.new(54, 16, 46), GREY_DK)
ball.Shape = Enum.PartType.Ball
label(ball, "WRECKING BALL — arcs along the diagonal toward the core corner")
local swing = mkCF("SwingZoneMark", Vector3.new(14, 0.25, 100),
	CFrame.new(Vector3.new(72, 1.2, 64) + Vector3.new(CX, 0, CZ)) * CFrame.Angles(0, math.rad(45), 0),
	Color3.fromRGB(190, 150, 150))
label(swing, "SWING PATH (diagonal, toward/away from the core)")
-- ══ NORTH LANE: SECOND CRANE (opposite lane from crane 1's southern arc) ════
-- WEST corridor of the north flank: arc LOW at z -100 (past the north pit),
-- endpoints at the pit flank (z ~-35) and the map edge (z ~-140). The MAST
-- stands OUTSIDE the playable bounds — only the arm reaches in.
mk("CraneMast2", Vector3.new(6, 48, 6), Vector3.new(-34, 24, -152))
mk("CraneArm2", Vector3.new(4, 3, 90), Vector3.new(-34, 46, -110))
mk("WreckChain2", Vector3.new(1, 26, 1), Vector3.new(-34, 33, -100))
local ball2 = mk("WreckBall2", Vector3.new(20, 20, 20), Vector3.new(-34, 16, -100), GREY_DK)
ball2.Shape = Enum.PartType.Ball
label(ball2, "WRECKING BALL 2 — shown at the arc's LOW point")
local swing2 = mk("SwingZoneMark2", Vector3.new(14, 0.25, 105), Vector3.new(-34, 1.2, -87.5), Color3.fromRGB(190, 150, 150))
label(swing2, "SWING PATH 2 — low at center, max height at both ends")

-- ══ E + W: SPAWN YARDS (edge centers) ═══════════════════════════════════════
for _, sp in { { x = 155, name = "TEAM A SPAWN (E)" }, { x = -155, name = "TEAM B SPAWN (W)" } } do
	local sgn = if sp.x > 0 then 1 else -1
	local deck = mk("SpawnDeck", Vector3.new(50, 2, 50), Vector3.new(sp.x, 2, 0), GREY_LT)
	label(deck, sp.name)
	mk("SpawnLip", Vector3.new(2, 5, 26), Vector3.new(sp.x - sgn * 26, 4.5, 0))
	wedge("SpawnRamp", Vector3.new(12, 2, 10), Vector3.new(sp.x, 2, -30), 0, GREY_LT)
	wedge("SpawnRamp", Vector3.new(12, 2, 10), Vector3.new(sp.x, 2, 30), 180, GREY_LT)
end

-- ══ EDGE ROADS: cover rhythm + three blocker towers ═════════════════════════
for i = -3, 3 do
	if i % 2 == 0 then
		mk("Pallets", Vector3.new(8, 4, 6), Vector3.new(i * 48, 3, if i % 3 == 0 then -122 else 122))
	else
		local pipe = mk("PipePile", Vector3.new(12, 3.4, 3.4), Vector3.new(i * 48, 2.7, if i % 3 == 0 then 122 else -122))
		pipe.Shape = Enum.PartType.Cylinder
	end
end
mk("Pallets", Vector3.new(8, 4, 6), Vector3.new(178, 3, 30))
mk("Pallets", Vector3.new(8, 4, 6), Vector3.new(-178, 3, -10))
local towers = { { 0, 115 }, { 178, 75 } }
for i, t in towers do
	local tower = mk("BlockerTower" .. (i + 1), Vector3.new(34, 46, 34), Vector3.new(t[1], 23.5, t[2]), Color3.fromRGB(145, 143, 148))
	if i == 1 then
		label(tower, "SOLID TOWERS — no entry, break the road sightlines")
	end
end

-- ══ NORTH STILT ROOM (was blocker 1): floor y16 on 4 pillars ════════════════
-- Too high for any jump/trick from ground; entry chain crate(4) ->
-- container(10) -> doorway floor(16): each hop <= jump 7, none skippable.
do
	local TX, TZ = 0, -115
	for _, sx in { -13, 13 } do
		for _, sz in { -13, 13 } do
			mk("RoomPillar", Vector3.new(4, 16, 4), Vector3.new(TX + sx, 8, TZ + sz))
		end
	end
	local floor2 = mk("RoomFloor", Vector3.new(34, 1, 34), Vector3.new(TX, 16.5, TZ))
	label(floor2, "STILT ROOM — crate -> container -> in. No direct jump")
	mk("RoomWall", Vector3.new(34, 10, 1.5), Vector3.new(TX, 22, TZ - 16.25))
	mk("RoomWall", Vector3.new(1.5, 10, 34), Vector3.new(TX - 16.25, 22, TZ))
	mk("RoomWall", Vector3.new(1.5, 10, 34), Vector3.new(TX + 16.25, 22, TZ))
	mk("RoomWall", Vector3.new(11, 10, 1.5), Vector3.new(TX - 11.5, 22, TZ + 16.25))
	mk("RoomWall", Vector3.new(11, 10, 1.5), Vector3.new(TX + 11.5, 22, TZ + 16.25))
	mk("RoomRoof", Vector3.new(36, 1, 36), Vector3.new(TX, 27.5, TZ))
	local crate = mk("EntryCrate", Vector3.new(4, 4, 4), Vector3.new(TX + 18, 2, TZ + 19))
	label(crate, "HOP 1 (top y4)")
	local cont = mk("EntryContainer", Vector3.new(10, 10, 8), Vector3.new(TX + 8, 5, TZ + 13), Color3.fromRGB(140, 90, 90))
	label(cont, "HOP 2 (top y10) -> doorway (floor y16)")
end

-- ══ COMPASS LETTERS (outside the bounds — for markup screenshots) ═══════════
-- 40-stud panels; PixelsPerStud 2.5 because TextScaled caps at 100px (a
-- bigger canvas renders a tiny glyph). Yaws make each glyph's top point
-- AWAY from the map center (glyph top at yaw 0 points -X on a Top face).
for _, d in { { "N", Vector3.new(0, 1, -168), -90 }, { "S", Vector3.new(0, 1, 168), 90 },
	{ "E", Vector3.new(208, 1, 0), 180 }, { "W", Vector3.new(-208, 1, 0), 0 } } do
	local p = mk("Compass" .. d[1], Vector3.new(40, 0.4, 40), d[2], Color3.fromRGB(60, 60, 66))
	p.CFrame = p.CFrame * CFrame.Angles(0, math.rad(d[3]), 0)
	p.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 2.5
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 220, 90)
	t.Text = d[1]
	t.Parent = gui
end

-- ══ BOUNDS GUIDE ════════════════════════════════════════════════════════════
for _, def in {
	{ Vector3.new(364, 0.3, 1), Vector3.new(0, 1.3, -126) },
	{ Vector3.new(364, 0.3, 1), Vector3.new(0, 1.3, 128) },
	{ Vector3.new(1, 0.3, 254), Vector3.new(-182, 1.3, 1) },
	{ Vector3.new(1, 0.3, 254), Vector3.new(182, 1.3, 1) },
} do
	local p = mk("PlayBoundsMark", def[1], def[2], Color3.fromRGB(40, 40, 44))
	p.CanCollide = false
end

m.Parent = zone
return "FRACTURED CORE built: " .. #m:GetChildren() .. " parts"
