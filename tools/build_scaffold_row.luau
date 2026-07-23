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
-- slabs run flush with the PILLAR OUTER FACES (±25.5): full pillar width,
-- never past it — the scaffold gap (planks at 26.2+) stays visible
mk("TowerFloor2", Vector3.new(51, 1, 29.5), Vector3.new(0, 14.5, -10.75))
-- y28 roof is an L (north band + west band): the wrecking ball's swing
-- plane (x 2..22, z 0..98) stays COMPLETELY clear of geometry
mk("TowerFloor3", Vector3.new(51, 1, 21.5), Vector3.new(0, 28.5, -14.75))
-- west band reaches x 1.5 (caps the center + S-mid pillars); a thin east
-- strip continues the north band to cap E-mid. ONLY the SE corner pillar
-- stays bare — unfinished right where the ball swings past.
mk("TowerFloor3", Vector3.new(27, 1, 29.5), Vector3.new(-12, 28.5, 10.75))
mk("TowerFloor3", Vector3.new(3, 1, 5.5), Vector3.new(24, 28.5, -1.25))
-- first-floor walls ON the pillar lines (owner-drawn path)
local wn = mk("TowerWallN", Vector3.new(21, 14, 2), Vector3.new(-12, 7, -24))
label(wn, "FIRST-FLOOR WALLS — on the pillar lines")
mk("TowerWallN", Vector3.new(21, 14, 2), Vector3.new(12, 7, -24))
mk("TowerWallE", Vector3.new(2, 14, 21), Vector3.new(24, 7, -12))
mk("TowerWallW", Vector3.new(2, 14, 21), Vector3.new(-24, 7, 12))
mk("TowerWallS", Vector3.new(21, 14, 2), Vector3.new(-12, 7, 24))

-- ══ SCAFFOLDING (cantilevered, owner's sketch): west-north-east wrap with a
-- GAP on the south/SW; no ground poles — diagonal brackets tie each walkway
-- back to the tower walls. North run floats over the void.
-- thin planks floated 1.2 studs off the wall faces (slight gap, real-
-- scaffold look; too thin to fall through)
mk("ScafW", Vector3.new(6, 0.6, 40), Vector3.new(-29.2, 14, -12))
mk("ScafN", Vector3.new(62, 0.6, 6), Vector3.new(-2, 14, -29.2))
mk("ScafE", Vector3.new(6, 0.6, 56), Vector3.new(29.2, 14, 0))
do
	local BROWN = Color3.fromRGB(150, 105, 65)
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
	-- base at the WALL (low end), tip under the walkway's OUTER lip.
	-- Sign convention verified numerically (v14): for a Z-length part,
	-- +pitch sends local +Z DOWN-toward-the-wall on the north face.
	for _, bx in { -26, -2, 22 } do -- north: wall is the +Z side
		bracket(CFrame.new(Vector3.new(bx, 11.4, -28.6) + Vector3.new(CX, 0, CZ)) * CFrame.Angles(ANG, 0, 0))
	end
	for _, bz in { -26, -12, 2 } do -- west: wall is the +X side
		bracket(CFrame.new(Vector3.new(-28.6, 11.4, bz) + Vector3.new(CX, 0, CZ)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(ANG, 0, 0))
	end
	for _, bz in { -22, 0, 22 } do -- east: wall is the -X side
		bracket(CFrame.new(Vector3.new(28.6, 11.4, bz) + Vector3.new(CX, 0, CZ)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(-ANG, 0, 0))
	end
end
wedge("ScafRamp", Vector3.new(8, 14, 22), Vector3.new(-46, 7, -29.5), 90)
wedge("ScafRamp", Vector3.new(8, 14, 22), Vector3.new(29.5, 7, 41), 180)

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

-- ══ NORTH: sealed ground story + tall second story (ramps both ends) ═══════
-- Ground cover lives in the lane strips around the building (the two piles
-- that sat inside the old open colonnade moved to the north strip).
for i = -3, 3 do
	if i ~= 0 then
		local zPos = if math.abs(i * 44) < 70 then -130 else -100 + (if i % 3 == 0 then 8 else -8)
		if i % 2 == 0 then
			mk("Pallets", Vector3.new(8, 4, 6), Vector3.new(i * 44, 3, zPos))
		else
			local pipe = mk("PipePile", Vector3.new(12, 3.4, 3.4), Vector3.new(i * 44, 2.7, zPos))
			pipe.Shape = Enum.PartType.Cylinder
		end
	end
end
local nFloor2 = mk("NorthFloor2", Vector3.new(140, 1, 44), Vector3.new(0, 14, -100))
label(nFloor2, "NORTH FLOOR 2 — ramps both ends; containers cross high above")
-- sealed ground story: walls on all four sides, nobody walks under
mk("NorthStoryWall", Vector3.new(140, 14, 1.5), Vector3.new(0, 7, -79.25))
mk("NorthStoryWall", Vector3.new(140, 14, 1.5), Vector3.new(0, 7, -120.75))
mk("NorthStoryWall", Vector3.new(1.5, 14, 43), Vector3.new(-69.25, 7, -100))
mk("NorthStoryWall", Vector3.new(1.5, 14, 43), Vector3.new(69.25, 7, -100))
-- WAY taller second story: posts 14->44, roof at 44 (container crest 45
-- just clears the roof line)
mk("NorthRoof", Vector3.new(150, 1, 48), Vector3.new(0, 44, -100))
-- second story enclosed: solid back, front walls EITHER SIDE of the central
-- container jump-in opening (x -24..24); ramp ends stay fully open. No
-- middle front pillar - it would stand in the jump-in.
mk("NorthUpperWall", Vector3.new(140, 30, 1.5), Vector3.new(0, 29, -120.75))
mk("NorthUpperWall", Vector3.new(46, 30, 1.5), Vector3.new(-47, 29, -79.25))
mk("NorthUpperWall", Vector3.new(46, 30, 1.5), Vector3.new(47, 29, -79.25))
for _, px in { -70, -35, 35, 70 } do
	mk("NorthPost", Vector3.new(2, 30, 2), Vector3.new(px, 29, -79))
end
for _, px in { -70, -35, 0, 35, 70 } do
	mk("NorthPostBack", Vector3.new(2, 30, 2), Vector3.new(px, 29, -121))
end
-- jump-in lip spans the opening only
mk("NorthFloor2Rail", Vector3.new(48, 2.5, 1), Vector3.new(0, 15.75, -78.5))
for _, cx2 in { -45, 5, 50 } do
	mk("Floor2Crates", Vector3.new(6, 4, 5), Vector3.new(cx2, 16.5, -104))
end
-- Floor 2 access ramps at both ends
wedge("NorthRamp", Vector3.new(12, 14, 28), Vector3.new(-84, 7, -100), 90)
wedge("NorthRamp", Vector3.new(12, 14, 28), Vector3.new(84, 7, -100), -90)

-- ══ CONTAINERS over the void (vertical cycle scripted at dress time) ════════
-- CYCLE SPEC (for dress-time scripting): anti-phase vertical travel —
-- one rises while the other falls, crossing at mid-travel (~y 17.5).
--   LOW extreme:  container top a touch UNDER ground level (top y -2,
--                 sunk into the void — you drop on or wait)
--   HIGH extreme: top slightly under the crane top (top y 45 vs crane 48)
-- Placeholders posed at the two extremes:
local red = mk("ContainerRed", Vector3.new(10, 8, 26), Vector3.new(-9, -6, -56), Color3.fromRGB(140, 90, 90))
label(red, "CONTAINER A — shown at LOW: sunk into the void, top just under ground")
local blue = mk("ContainerBlue", Vector3.new(10, 8, 26), Vector3.new(9, 41, -50), Color3.fromRGB(90, 110, 140))
label(blue, "CONTAINER B — shown at HIGH: top slightly under the crane top. They cycle in OPPOSITE directions, crossing mid-travel")

-- ══ WRECKING BALL (crane south, swings N<->S through the breezeway) ═════════
mk("CraneMast", Vector3.new(6, 48, 6), Vector3.new(12, 24, 122))
mk("CraneArm", Vector3.new(4, 3, 120), Vector3.new(12, 46, 60))
mk("WreckChain", Vector3.new(1, 26, 1), Vector3.new(12, 33, 50))
local ball = mk("WreckBall", Vector3.new(20, 20, 20), Vector3.new(12, 16, 44), GREY_DK)
ball.Shape = Enum.PartType.Ball
label(ball, "WRECKING BALL 20st — swings tower bay <-> colonnade")
local swing = mk("SwingZoneMark", Vector3.new(14, 0.25, 92), Vector3.new(12, 1.2, 52), Color3.fromRGB(190, 150, 150))
label(swing, "SWING PATH (N <-> S)")

-- ══ BLOCKERS + cross-cuts + bounds ══════════════════════════════════════════
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
