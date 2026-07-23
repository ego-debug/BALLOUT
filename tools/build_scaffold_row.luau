--!strict
-- Ballout | SCAFFOLD ROW — "FRACTURED CORE" arrangement (v26, 2026-07-23)
-- Run in EDIT mode: require(game:GetService("ServerStorage").MapTools.build_scaffold_row:Clone())
-- Rebuilds BuildZone.ScaffoldRowBlockout from scratch. SOURCE OF TRUTH.
--
-- ORIGINAL composition (owner-approved divergence pass): dense central core
-- with X-shaped circulation — corner spawns, hazards on opposing DIAGONALS.
--   CORE (center): tower frame, bay walls, floors 14/28, hugging scaffold
--   N:    the original VOID pit north of the core (scaffold floats over
--         its south end); two anti-phase container rides cross it
--   NW:   pavilion building on the north rim road
--   SE:   WRECKING BALL YARD — crane in the corner, ball arcs diagonally
--         toward the core between two gallery stubs (timed cover)
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

-- ══ GROUND with the original VOID pit (x -24..24, z -82..-25) ═══════════════
mk("Dirt", Vector3.new(400, 1, 58), Vector3.new(0, 0.5, -111), GREY_DK)
mk("Dirt", Vector3.new(400, 1, 165), Vector3.new(0, 0.5, 57.5), GREY_DK)
mk("Dirt", Vector3.new(176, 1, 57), Vector3.new(-112, 0.5, -53.5), GREY_DK)
mk("Dirt", Vector3.new(176, 1, 57), Vector3.new(112, 0.5, -53.5), GREY_DK)
mk("PitWallN", Vector3.new(48, 30, 1), Vector3.new(0, -14, -82.5), DARK)
mk("PitWallS", Vector3.new(48, 30, 1), Vector3.new(0, -14, -25.5), DARK)
mk("PitWallW", Vector3.new(1, 30, 57), Vector3.new(-24.5, -14, -53.5), DARK)
mk("PitWallE", Vector3.new(1, 30, 57), Vector3.new(24.5, -14, -53.5), DARK)
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
	slab(Vector3.new(520, 4, 215), Vector3.new(0, -2, -567.5))
	slab(Vector3.new(236, 4, 57), Vector3.new(-142, -2, -703.5))
	slab(Vector3.new(236, 4, 57), Vector3.new(142, -2, -703.5))
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
mk("ScafW", Vector3.new(6, 0.6, 40), Vector3.new(-29.2, 14, -12))
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
	for _, bz in { -26, -12, 2 } do
		bracket(CFrame.new(Vector3.new(-28.6, 11.4, bz) + Vector3.new(CX, 0, CZ)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(ANG, 0, 0))
	end
	for _, bz in { -22, 0 } do
		bracket(CFrame.new(Vector3.new(28.6, 11.4, bz) + Vector3.new(CX, 0, CZ)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(-ANG, 0, 0))
	end
end
wedge("ScafRamp", Vector3.new(8, 14, 22), Vector3.new(-46, 7, -29.5), 90)
for _, cdef in { { 46, 10 }, { -6, 48 }, { 48, -34 }, { -44, 44 } } do
	mk("PlazaCrate", Vector3.new(6, 4.5, 5), Vector3.new(cdef[1], 3.25, cdef[2]))
end

-- ══ NW: PAVILION overlook on the canyon's north rim ═════════════════════════
do
	local PX, PZ = -95, -125
	local f2 = mk("NorthFloor2", Vector3.new(70, 1, 26), Vector3.new(PX, 14, PZ))
	label(f2, "PAVILION — ramps both ends")
	mk("NorthStoryWall", Vector3.new(70, 14, 1.5), Vector3.new(PX, 7, PZ + 12.5))
	mk("NorthStoryWall", Vector3.new(70, 14, 1.5), Vector3.new(PX, 7, PZ - 12.5))
	mk("NorthStoryWall", Vector3.new(1.5, 14, 24), Vector3.new(PX - 34.25, 7, PZ))
	mk("NorthStoryWall", Vector3.new(1.5, 14, 24), Vector3.new(PX + 34.25, 7, PZ))
	mk("NorthRoof", Vector3.new(80, 1, 30), Vector3.new(PX, 44, PZ))
	for _, px in { -35, 0, 35 } do
		mk("NorthPost", Vector3.new(4, 30, 4), Vector3.new(PX + px, 29, PZ + 11))
		mk("NorthPostBack", Vector3.new(4, 30, 4), Vector3.new(PX + px, 29, PZ - 11))
	end
	mk("NorthFloor2Rail", Vector3.new(70, 2.5, 1), Vector3.new(PX, 15.75, PZ + 12))
	wedge("NorthRamp", Vector3.new(12, 14, 28), Vector3.new(PX - 49, 7, PZ), 90)
	wedge("NorthRamp", Vector3.new(12, 14, 28), Vector3.new(PX + 49, 7, PZ), -90)
end

-- ══ CONTAINERS over the pit (original spot; anti-phase cycle spec:
-- LOW top just under ground, HIGH top y 45, crossing mid-travel) ═════════════
local red = mk("ContainerRed", Vector3.new(10, 8, 26), Vector3.new(-9, -6, -56), Color3.fromRGB(140, 90, 90))
label(red, "CONTAINER A — shown LOW: sunk into the void, top just under ground")
local blue = mk("ContainerBlue", Vector3.new(10, 8, 26), Vector3.new(9, 41, -50), Color3.fromRGB(90, 110, 140))
label(blue, "CONTAINER B — shown HIGH: anti-phase, crossing mid-travel")

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
for _, g in { { x = 30, z = 92 }, { x = 96, z = 26 } } do
	mk("GalleryFloor", Vector3.new(36, 1, 18), Vector3.new(g.x, 8, g.z))
	for _, sx in { -16, 16 } do
		for _, sz in { -7.5, 7.5 } do
			mk("GalleryPillar", Vector3.new(3, 13.5, 3), Vector3.new(g.x + sx, 15.25, g.z + sz))
		end
	end
	mk("GallerySkirt", Vector3.new(36, 8, 1.5), Vector3.new(g.x, 4, g.z - 9.75), SKIRT)
	mk("GallerySkirt", Vector3.new(36, 8, 1.5), Vector3.new(g.x, 4, g.z + 9.75), SKIRT)
	mk("GallerySkirt", Vector3.new(1.5, 8, 18), Vector3.new(g.x - 18.75, 4, g.z), SKIRT)
	mk("GallerySkirt", Vector3.new(1.5, 8, 18), Vector3.new(g.x + 18.75, 4, g.z), SKIRT)
	wedge("GalleryRamp", Vector3.new(18, 8.5, 14), Vector3.new(g.x - 25, 4.25, g.z), 90, RAMP_ORANGE)
	mk("GalleryRoofPost", Vector3.new(3, 30, 3), Vector3.new(g.x - 16, 28.75, g.z - 7.5))
	mk("GalleryRoofPost", Vector3.new(3, 30, 3), Vector3.new(g.x + 16, 28.75, g.z + 7.5))
	mk("GalleryRoof", Vector3.new(40, 1, 22), Vector3.new(g.x, 44, g.z))
end

-- ══ NE + SW: SPAWN YARDS (diagonal axis) ════════════════════════════════════
for _, sp in { { x = 155, z = -95, name = "TEAM A SPAWN (NE)" }, { x = -155, z = 95, name = "TEAM B SPAWN (SW)" } } do
	local sgn = if sp.x > 0 then 1 else -1
	local deck = mk("SpawnDeck", Vector3.new(50, 2, 50), Vector3.new(sp.x, 2, sp.z), GREY_LT)
	label(deck, sp.name)
	mk("SpawnLip", Vector3.new(2, 5, 30), Vector3.new(sp.x - sgn * 26, 4.5, sp.z - sgn * 8))
	wedge("SpawnRamp", Vector3.new(12, 2, 10), Vector3.new(sp.x - sgn * 22, 2, sp.z + sgn * 16), sgn * 90, GREY_LT)
	wedge("SpawnRamp", Vector3.new(12, 2, 10), Vector3.new(sp.x + sgn * 8, 2, sp.z - sgn * 28), if sgn > 0 then 180 else 0, GREY_LT)
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
local towers = { { 0, -115 }, { 0, 115 }, { 178, 75 } }
for i, t in towers do
	local tower = mk("BlockerTower" .. i, Vector3.new(34, 46, 34), Vector3.new(t[1], 23.5, t[2]), Color3.fromRGB(145, 143, 148))
	if i == 1 then
		label(tower, "SOLID TOWERS — no entry, break the road sightlines")
	end
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
