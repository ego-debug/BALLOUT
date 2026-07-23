--!strict
-- Ballout | SCAFFOLD ROW blockout generator (grey skeleton, owner-directed)
-- Run in EDIT mode: require(game:GetService("ServerStorage").MapTools.build_scaffold_row:Clone())
-- Destroys and rebuilds BuildZone.ScaffoldRowBlockout from scratch — this file
-- is the SOURCE OF TRUTH for the skeleton (v9 state, 2026-07-23). Owner marks
-- up screenshots, we change THIS script, rerun. KC-scale: 400x280 inside the
-- yard; 1 story ≈ 14 studs.
--
-- Layout (all original):
--   MID: open tower frame (3x3 pillars), first-floor bay walls on the pillar
--        lines, scaffold ring at y14 (floats over the void on the north side),
--        half-floors at 14/28
--   NORTH: ground lane + middle-only two-story; Floor 2 reachable ONLY by
--        two vertically-cycling containers over a REAL void pit (no bottom)
--   SOUTH: middle-only elevated colonnade split by a ground breezeway where
--        the wrecking ball swings N<->S from a crane at the south edge;
--        facing divot ramps flank the 20-stud ball corridor
--   Three solid blocker towers pinch the lane ends; high beam WEST to the
--   exposed perch balances the east-side hazard.

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

-- ══ GROUND (void hole x -24..24, z -82..-25) + yard floor repunch ═══════════
mk("Dirt", Vector3.new(400, 1, 58), Vector3.new(0, 0.5, -111), GREY_DK)
mk("Dirt", Vector3.new(400, 1, 165), Vector3.new(0, 0.5, 57.5), GREY_DK)
mk("Dirt", Vector3.new(176, 1, 57), Vector3.new(-112, 0.5, -53.5), GREY_DK)
mk("Dirt", Vector3.new(176, 1, 57), Vector3.new(112, 0.5, -53.5), GREY_DK)
mk("PitWallN", Vector3.new(48, 30, 1), Vector3.new(0, -14, -82.5), DARK)
mk("PitWallS", Vector3.new(48, 30, 1), Vector3.new(0, -14, -25.5), DARK)
mk("PitWallW", Vector3.new(1, 30, 57), Vector3.new(-24.5, -14, -53.5), DARK)
mk("PitWallE", Vector3.new(1, 30, 57), Vector3.new(24.5, -14, -53.5), DARK)
do -- yard floor: 4 slabs leaving the same hole (world z -732..-675)
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

-- ══ SPAWN DECKS ═════════════════════════════════════════════════════════════
for _, side in { -1, 1 } do
	local deck = mk("SpawnDeck", Vector3.new(60, 2, 120), Vector3.new(side * 170, 2, 0), GREY_LT)
	label(deck, if side == -1 then "TEAM A SPAWN" else "TEAM B SPAWN")
	mk("SpawnLip", Vector3.new(2, 5, 40), Vector3.new(side * 138, 4.5, -40))
	mk("SpawnLip", Vector3.new(2, 5, 40), Vector3.new(side * 138, 4.5, 40))
	wedge("SpawnRamp", Vector3.new(12, 2, 10), Vector3.new(side * 132, 2, 0), if side == 1 then 90 else -90, GREY_LT)
end

-- ══ MID LANE + TOWER ════════════════════════════════════════════════════════
label(mk("MidLaneMark", Vector3.new(320, 0.2, 60), Vector3.new(0, 1.15, 0), Color3.fromRGB(140, 140, 145)), "MID LANE")
for ix = -1, 1 do
	for iz = -1, 1 do
		mk("TowerPillar", Vector3.new(3, 28, 3), Vector3.new(ix * 24, 14, iz * 24))
	end
end
mk("TowerFloor2", Vector3.new(56, 1, 32), Vector3.new(0, 14.5, -12))
mk("TowerFloor2b", Vector3.new(24, 1, 22), Vector3.new(16, 14.5, 14))
mk("TowerFloor3", Vector3.new(30, 1, 56), Vector3.new(-13, 28.5, 0))
label(mk("TowerTopBeam", Vector3.new(56, 1.5, 4), Vector3.new(0, 29, 24)), "TOWER")
-- first-floor walls ON the pillar lines (owner-drawn path)
local wn = mk("TowerWallN", Vector3.new(21, 14, 2), Vector3.new(-12, 7, -24))
label(wn, "FIRST-FLOOR WALLS — on the pillar lines")
mk("TowerWallN", Vector3.new(21, 14, 2), Vector3.new(12, 7, -24))
mk("TowerWallE", Vector3.new(2, 14, 21), Vector3.new(24, 7, -12))
mk("TowerWallW", Vector3.new(2, 14, 21), Vector3.new(-24, 7, 12))
mk("TowerWallS", Vector3.new(21, 14, 2), Vector3.new(-12, 7, 24))

-- ══ SCAFFOLD RING (mid-only; north side floats over the void) ═══════════════
mk("ScafN", Vector3.new(100, 1, 8), Vector3.new(0, 14, -40))
mk("ScafS", Vector3.new(100, 1, 8), Vector3.new(0, 14, 40))
mk("ScafE", Vector3.new(8, 1, 88), Vector3.new(46, 14, 0))
mk("ScafW", Vector3.new(8, 1, 88), Vector3.new(-46, 14, 0))
for _, px in { -46, 46 } do
	for _, pz in { -40, 0, 40 } do
		mk("ScafPole", Vector3.new(1.5, 14, 1.5), Vector3.new(px, 7, pz))
	end
end
for _, d in { { x = -80, z = -40, yaw = 90 }, { x = 80, z = 40, yaw = -90 },
	{ x = 46, z = -70, yaw = 180 }, { x = -46, z = 70, yaw = 0 } } do
	wedge("ScafRamp", Vector3.new(8, 14, 26), Vector3.new(d.x, 7, d.z), d.yaw)
end

-- ══ SOUTH: colonnade halves + breezeway + facing divot ramps ════════════════
label(mk("SouthColonnadeFloor", Vector3.new(58, 1, 44), Vector3.new(-41, 8, 100)), "COLONNADE WEST (elevated)")
label(mk("SouthColonnadeFloor", Vector3.new(40, 1, 44), Vector3.new(50, 8, 100)), "COLONNADE EAST (elevated)")
mk("SouthRail", Vector3.new(58, 2.5, 1), Vector3.new(-41, 9.75, 79.5))
mk("SouthRail", Vector3.new(40, 2.5, 1), Vector3.new(50, 9.75, 79.5))
local breeze = mk("BreezewayMark", Vector3.new(42, 0.2, 44), Vector3.new(9, 1.15, 100), Color3.fromRGB(190, 150, 150))
label(breeze, "GROUND BREEZEWAY — ball swings through here")
-- 8 pillars ON the platform corners
for _, c in { { -68, 80 }, { -68, 120 }, { -14, 80 }, { -14, 120 },
	{ 32, 80 }, { 32, 120 }, { 68, 80 }, { 68, 120 } } do
	-- crane-height pillars (tops at y 52) carrying the tall twin roofs
	mk("ColPillar", Vector3.new(3, 43.5, 3), Vector3.new(c[1], 30.25, c[2]))
end
mk("ColRoof", Vector3.new(58, 1, 44), Vector3.new(-41, 52.5, 100))
mk("ColRoof", Vector3.new(40, 1, 44), Vector3.new(50, 52.5, 100))
-- skirts: nobody gets under the platforms
mk("PlatformSkirt", Vector3.new(58, 8, 1.5), Vector3.new(-41, 4, 78.75), SKIRT)
mk("PlatformSkirt", Vector3.new(58, 8, 1.5), Vector3.new(-41, 4, 121.25), SKIRT)
mk("PlatformSkirt", Vector3.new(1.5, 8, 44), Vector3.new(-69.25, 4, 100), SKIRT)
mk("PlatformSkirt", Vector3.new(1.5, 8, 44), Vector3.new(-12.75, 4, 100), SKIRT)
mk("PlatformSkirt", Vector3.new(40, 8, 1.5), Vector3.new(50, 4, 78.75), SKIRT)
mk("PlatformSkirt", Vector3.new(40, 8, 1.5), Vector3.new(50, 4, 121.25), SKIRT)
mk("PlatformSkirt", Vector3.new(1.5, 8, 44), Vector3.new(30.75, 4, 100), SKIRT)
mk("PlatformSkirt", Vector3.new(1.5, 8, 44), Vector3.new(69.25, 4, 100), SKIRT)
-- facing divot ramps: feet at x 2 and x 22 — the 20-stud ball corridor
-- runs exactly between them
wedge("DivotRamp", Vector3.new(44, 8.5, 14), Vector3.new(-5, 4.25, 100), -90, RAMP_ORANGE)
wedge("DivotRamp", Vector3.new(44, 8.5, 14), Vector3.new(23, 4.25, 100), 90, RAMP_ORANGE)
-- colonnade end ramps + open-end ground cover
wedge("ColEndRamp", Vector3.new(44, 8.5, 22), Vector3.new(81, 4.25, 100), -90, GREY_LT)
wedge("ColEndRamp", Vector3.new(44, 8.5, 22), Vector3.new(-81, 4.25, 100), 90, GREY_LT)
for _, sx in { -1, 1 } do
	mk("SouthEndPallets", Vector3.new(8, 4, 6), Vector3.new(sx * 100, 3, 92))
	local pipe = mk("SouthEndPipes", Vector3.new(12, 3.4, 3.4), Vector3.new(sx * 128, 2.7, 108))
	pipe.Shape = Enum.PartType.Cylinder
end

-- ══ NORTH: ground lane + middle-only two-story (container access only) ══════
label(mk("NorthLaneMark", Vector3.new(320, 0.2, 44), Vector3.new(0, 1.15, -100), Color3.fromRGB(150, 150, 154)), "NORTH LANE (ground)")
for i = -3, 3 do
	if i ~= 0 then
		if i % 2 == 0 then
			mk("Pallets", Vector3.new(8, 4, 6), Vector3.new(i * 44, 3, -100 + (if i % 3 == 0 then 8 else -8)))
		else
			local pipe = mk("PipePile", Vector3.new(12, 3.4, 3.4), Vector3.new(i * 44, 2.7, -100 + (if i % 3 == 0 then -8 else 8)))
			pipe.Shape = Enum.PartType.Cylinder
		end
	end
end
local nFloor2 = mk("NorthFloor2", Vector3.new(140, 1, 44), Vector3.new(0, 14, -100))
label(nFloor2, "NORTH FLOOR 2 — container-jump access ONLY")
mk("NorthRoof", Vector3.new(150, 1, 48), Vector3.new(0, 26, -100))
for _, px in { -70, -35, 0, 35, 70 } do
	mk("NorthPost", Vector3.new(2, 12, 2), Vector3.new(px, 20, -79))
	mk("NorthPostBack", Vector3.new(2, 26, 2), Vector3.new(px, 13, -121))
end
mk("NorthFloor2Rail", Vector3.new(140, 2.5, 1), Vector3.new(0, 15.75, -78.5))
for _, cx2 in { -45, 5, 50 } do
	mk("Floor2Crates", Vector3.new(6, 4, 5), Vector3.new(cx2, 16.5, -104))
end

-- ══ CONTAINERS over the void (vertical cycle scripted at dress time) ════════
local red = mk("ContainerRed", Vector3.new(10, 8, 26), Vector3.new(-9, 5, -56), Color3.fromRGB(140, 90, 90))
label(red, "CONTAINER A (low) — first hop, rides over the void")
local blue = mk("ContainerBlue", Vector3.new(10, 8, 26), Vector3.new(9, 9.5, -50), Color3.fromRGB(90, 110, 140))
label(blue, "CONTAINER B — rises to just under the scaffold lip")

-- ══ WRECKING BALL (crane south, swings N<->S through the breezeway) ═════════
mk("CraneMast", Vector3.new(6, 48, 6), Vector3.new(12, 24, 122))
mk("CraneArm", Vector3.new(4, 3, 120), Vector3.new(12, 46, 60))
mk("WreckChain", Vector3.new(1, 26, 1), Vector3.new(12, 33, 50))
local ball = mk("WreckBall", Vector3.new(20, 20, 20), Vector3.new(12, 16, 44), GREY_DK)
ball.Shape = Enum.PartType.Ball
label(ball, "WRECKING BALL 20st — swings tower bay <-> colonnade")
local swing = mk("SwingZoneMark", Vector3.new(14, 0.25, 92), Vector3.new(12, 1.2, 52), Color3.fromRGB(190, 150, 150))
label(swing, "SWING PATH (N <-> S)")

-- ══ HIGH ROUTE (west) + blockers + cross-cuts + bounds ══════════════════════
mk("HighBeam", Vector3.new(120, 1.5, 5), Vector3.new(-90, 28, 24))
label(mk("WestPerch", Vector3.new(20, 1, 20), Vector3.new(-150, 28, 24)), "HIGH PERCH (exposed)")
mk("PerchLadderMark", Vector3.new(3, 28, 3), Vector3.new(-158, 14, 30), GREY_LT)
local towers = { { 115, -100 }, { -115, -100 }, { 115, 105 } }
for i, t in towers do
	local tower = mk("BlockerTower" .. i, Vector3.new(34, 46, 34), Vector3.new(t[1], 23.5, t[2]), Color3.fromRGB(145, 143, 148))
	if i == 1 then
		label(tower, "SOLID TOWERS — no entry, block sightlines")
	end
end
for _, x in { -110, 110 } do
	mk("CrossCutMark", Vector3.new(10, 0.2, 240), Vector3.new(x, 1.16, 0), Color3.fromRGB(130, 130, 136))
end
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
return "Scaffold Row blockout built: " .. #m:GetChildren() .. " parts"
