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

-- ══ GLOBAL MAP SCALE (v83) ══════════════════════════════════════════════════
-- Playtest: the player could jump straight onto containers, second floors and
-- the scaffolding, defeating every climb gate in the map. The blockout was
-- authored to a DERIVED "KC scale" that turned out too small against a 5-stud
-- character with a 7-stud jump. Everything below stays authored at scale 1 and
-- the finished model is scaled about map centre at the very end, so all the
-- geometry keeps its proportions to itself.
local MAP_SCALE = 1.45

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

-- ══ ELEVATION: lowered CENTRE BASIN + smooth hillsides (v68) ════════════════
-- The whole central N-S band is EXCAVATED to BASIN_Y; the spawn flanks stay
-- up on plateaus, and broad walkable HILLSIDES (full map depth, ~22 deg)
-- roll down between them — a hillside, not a ramp you have to find. The
-- structure shift pass at the bottom of this script drops everything that
-- stands inside the band by the same amount.
--   |x| <= 85          basin      (top y = -13)
--   85 < |x| < 119     hillside   (smooth 1 -> -13)
--   |x| >= 119         plateau    (top y = 1)
local BAND = 85       -- basin half-width
local SLOPE_RUN = 34  -- hillside run on each side
local DROP = 14       -- basin is this far below the plateaus
local PLATEAU_TOP = 1
local BASIN_TOP = PLATEAU_TOP - DROP

-- how far DOWN a thing at this x/z sits relative to the old flat ground
local function bandDelta(x: number, z: number): number
	if math.abs(z) > 140 then
		return 0 -- outworld apron keeps plateau level
	end
	local ax = math.abs(x)
	if ax <= BAND then
		return -DROP
	elseif ax >= BAND + SLOPE_RUN then
		return 0
	end
	return -DROP * (1 - (ax - BAND) / SLOPE_RUN)
end

-- PLATEAUS (top y=1). West is split around the SW finger void.
mk("Dirt", Vector3.new(81, 1, 202), Vector3.new(-159.5, 0.5, -39), GREY_DK)
mk("Dirt", Vector3.new(81, 1, 58), Vector3.new(-159.5, 0.5, 111), GREY_DK)
mk("Dirt", Vector3.new(48, 1, 20), Vector3.new(-176, 0.5, 72), GREY_DK)
mk("Dirt", Vector3.new(9, 1, 20), Vector3.new(-123.5, 0.5, 72), GREY_DK)
mk("Dirt", Vector3.new(81, 1, 280), Vector3.new(159.5, 0.5, 0), GREY_DK)

-- HILLSIDES: wedges spanning the full map depth. A wedge is tall at its
-- local +Z end, so yaw -90 puts the high side at -X (west) and yaw 90 at +X.
wedge("Hillside", Vector3.new(280, DROP, SLOPE_RUN), Vector3.new(-102, BASIN_TOP + DROP / 2, 0), -90, GREY_DK)
wedge("Hillside", Vector3.new(280, DROP, SLOPE_RUN), Vector3.new(102, BASIN_TOP + DROP / 2, 0), 90, GREY_DK)

-- BASIN floor (top y=-13) with the twin void pits cut out
mk("Dirt", Vector3.new(61, 1, 280), Vector3.new(-54.5, BASIN_TOP - 0.5, 0), GREY_DK)
mk("Dirt", Vector3.new(61, 1, 280), Vector3.new(54.5, BASIN_TOP - 0.5, 0), GREY_DK)
mk("Dirt", Vector3.new(48, 1, 58), Vector3.new(0, BASIN_TOP - 0.5, -111), GREY_DK)
mk("Dirt", Vector3.new(48, 1, 50), Vector3.new(0, BASIN_TOP - 0.5, 0), GREY_DK)
mk("Dirt", Vector3.new(48, 1, 58), Vector3.new(0, BASIN_TOP - 0.5, 111), GREY_DK)

-- RETAINING WALLS shoring the basin's N/S ends against the outworld apron
-- (out of bounds behind the fences — reads as site shoring, no cliff seam)
for _, sz in { -1, 1 } do
	mk("RetainWall", Vector3.new(2 * BAND, DROP + 1, 2), Vector3.new(0, BASIN_TOP + (DROP + 1) / 2 - 0.5, sz * 141), DARK)
end

-- CENTRE PIT walls: from the basin floor straight down (void, no bottom)
for _, sz in { -1, 1 } do
	mk("PitWall", Vector3.new(48, 30, 1), Vector3.new(0, BASIN_TOP - 15, sz * 82.5), DARK)
	mk("PitWall", Vector3.new(48, 30, 1), Vector3.new(0, BASIN_TOP - 15, sz * 25.5), DARK)
	mk("PitWall", Vector3.new(1, 30, 57), Vector3.new(-24.5, BASIN_TOP - 15, sz * 53.5), DARK)
	mk("PitWall", Vector3.new(1, 30, 57), Vector3.new(24.5, BASIN_TOP - 15, sz * 53.5), DARK)
end

-- SW FINGER VOID stays out on the west plateau (x -152..-128, z 62..82)
mk("PitWall", Vector3.new(24, 30, 1), Vector3.new(-140, -14, 62.5), DARK)
mk("PitWall", Vector3.new(24, 30, 1), Vector3.new(-140, -14, 81.5), DARK)
mk("PitWall", Vector3.new(1, 30, 20), Vector3.new(-152.5, -14, 72), DARK)
mk("PitWall", Vector3.new(1, 30, 20), Vector3.new(-127.5, -14, 72), DARK)

do -- yard floor: now a FRAME around the map (map ground covers its own
	-- footprint at three elevations, so a slab underneath would bury the basin)
	for _, c in zone:GetChildren() do
		if c.Name == "BuildFloor" then
			c:Destroy()
		end
	end
	local function slab(size: Vector3, worldPos: Vector3)
		local pt = Instance.new("Part")
		pt.Name = "BuildFloor"
		-- the yard frame lives OUTSIDE the model so ScaleTo never touches it:
		-- scale it here about map centre so it still frames the bigger map
		local c = Vector3.new(CX, 0, CZ)
		pt.Size = size * MAP_SCALE
		pt.Position = c + (worldPos - c) * MAP_SCALE
		pt.Color = GREY_DK
		pt.Material = Enum.Material.SmoothPlastic
		pt.Anchored = true
		pt.Parent = zone
	end
	slab(Vector3.new(520, 4, 50), Vector3.new(0, -2, -815))   -- north apron
	slab(Vector3.new(520, 4, 50), Vector3.new(0, -2, -485))   -- south apron
	slab(Vector3.new(60, 4, 280), Vector3.new(-230, -2, -650)) -- west apron
	slab(Vector3.new(60, 4, 280), Vector3.new(230, -2, -650))  -- east apron
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
-- SCAFFOLD APPROACH (v81): no ramp — you climb crate -> container, then
-- JUMP the gap up onto the catwalk.
--   basin floor -13 | crate top -9 | container top -5 | catwalk 0.3
--   container east end x -39 vs catwalk west end x -33 = 6-stud gap
-- SCAFFOLD CLIMB (v84): no wooden crates — a stacked CONTAINER YARD instead.
-- The basin-floor -> catwalk climb is ~19 studs after scaling and a 7-stud
-- jump caps each hop, so three surfaces are required. Two containers give
-- that without any brown boxes:
--   basin floor -> A (+6.0) -> B (+6.5) -> catwalk (+6.8)
-- and B sits back far enough that the final leap is a ~9.5-stud gap
-- (roughly double the old 5.8) — needs a sprint run-up, which is the
-- physics ceiling for a 6.8-stud rise.
mk("ScafContainer", Vector3.new(26, 8, 10), Vector3.new(-80, 1.14, -29.2), Color3.fromRGB(140, 90, 90))
mk("ScafContainer2", Vector3.new(26, 8, 10), Vector3.new(-52.55, 5.62, -29.2), Color3.fromRGB(90, 110, 140))
-- plaza crates on SOLID ground only ({-6,48} used to strand over the south pit)
for _, cdef in { { 46, 10 }, { -14, 16 }, { 48, -34 }, { -44, 44 } } do
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

-- ══ LANE BUILDINGS: two DIFFERENT structures flanking the pits ══════════════
-- (Both were dropped in the v26 rewrite; restored here so they survive
-- rebuilds. They are NOT the same building.)
--
-- NORTH = two-story BOARDING HALL. Raised floor-1 podium you enter via E/W
-- walk-up ramps; only the outer (N) wall is solid; the inner face is open to
-- the pit so you board the rising containers and bail onto floor 2. Solid
-- tower cap to y64.
do
	local hz, backZ, frontZ = -104, -125.25, -82.75
	mk("NB_Podium", Vector3.new(48, 4, 44), Vector3.new(0, 2, hz))
	local outer = mk("NB_Wall", Vector3.new(48, 14, 1.5), Vector3.new(0, 11, backZ))
	label(outer, "NORTH HALL — ramps E/W; inner face open to the pit, floor 2 above")
	-- open-face pillars only, inset so their 3-stud footprint lands INSIDE
	-- the podium edge instead of hanging off it
	mk("NB_HallPillar", Vector3.new(3, 14, 3), Vector3.new(-22.5, 11, hz + 20.5))
	mk("NB_HallPillar", Vector3.new(3, 14, 3), Vector3.new(22.5, 11, hz + 20.5))
	mk("NB_Floor2", Vector3.new(48, 1, 44), Vector3.new(0, 18.5, hz))
	-- floor 2 is an OPEN level with real headroom (posts + roof), THEN the
	-- solid tower cap above — not a slab crushed under the tower
	-- NB_UpperWall already carries the boundary side, so posts there were
	-- redundant AND overhung the slab: open-face pair only, inset.
	for _, sx in { -22.5, 22.5 } do
		mk("NB_UpperPost", Vector3.new(3, 20, 3), Vector3.new(sx, 29, hz + 20.5))
	end
	-- boundary-side wall: floor 2 is open on posts, so seal the outer face
	-- (this side borders the map edge — nothing should be thrown out here)
	mk("NB_UpperWall", Vector3.new(48, 20, 1.5), Vector3.new(0, 29, backZ))
	mk("NB_UpperRoof", Vector3.new(48, 1, 44), Vector3.new(0, 39.5, hz))
	mk("NB_Tower", Vector3.new(48, 24, 44), Vector3.new(0, 52, hz)) -- solid cap y40..64
	wedge("NB_Ramp", Vector3.new(12, 4, 14), Vector3.new(-28, 2, hz), 90, GREY_LT)
	wedge("NB_Ramp", Vector3.new(12, 4, 14), Vector3.new(28, 2, hz), -90, GREY_LT)
end
--
-- SOUTH = solid PERCH tower. No interior/underpass; a SOLID block to y16 with
-- an open sniper DECK on top (corner posts + roof), reached ONLY by parkour up
-- the outside: crate (top y4) -> container (top y10) -> deck (y16.5), on both
-- the E and W faces. Solid tower cap to y64 over the roof.
do
	local pz = 104
	mk("Room_Base", Vector3.new(48, 16, 44), Vector3.new(0, 8, pz)) -- solid, no way in
	local deck = mk("Room_Deck", Vector3.new(48, 1, 44), Vector3.new(0, 16.5, pz))
	label(deck, "SOUTH PERCH — solid; parkour crate->container->deck (both sides)")
	-- Room_DeckWall carries the boundary side; posts there were redundant and
	-- overhung the deck. Open-face pair only, inset inside the deck edge.
	for _, sx in { -22.5, 22.5 } do
		mk("Room_Post", Vector3.new(3, 20, 3), Vector3.new(sx, 26.5, pz - 20.5)) -- 20-stud headroom
	end
	-- boundary-side wall: the deck is open on posts, so seal the outer face
	mk("Room_DeckWall", Vector3.new(48, 19.5, 1.5), Vector3.new(0, 26.75, pz + 21.25))
	mk("Room_Roof", Vector3.new(48, 1, 44), Vector3.new(0, 37, pz))
	mk("Room_Tower", Vector3.new(48, 26.5, 44), Vector3.new(0, 50.75, pz)) -- solid cap y37.5..64
	for _, sgn in { -1, 1 } do
		mk("Room_Crate", Vector3.new(4, 4, 4), Vector3.new(sgn * 30, 2, pz))
		mk("Room_EntryContainer", Vector3.new(8, 10, 10), Vector3.new(sgn * 26, 5, pz), Color3.fromRGB(140, 90, 90))
	end
end

-- ══ SE: WRECKING BALL YARD (diagonal arc toward the core) ═══════════════════
mk("CraneMast", Vector3.new(6, 110, 6), Vector3.new(148, 55, 140)) -- OFF-MAP (past the bounds line): unreachable
-- SINGLE-POINT pendulum (owner's sketch): the arm ENDS at the pivot; the
-- chain+ball swing about that tip like a real wrecking ball. Dress-time
-- script: rotate the chain+ball assembly about the tip in the arm's plane.
mkCF("CraneArm", Vector3.new(4, 3, 102),
	CFrame.new(Vector3.new(112, 108, 104) + Vector3.new(CX, 0, CZ)) * CFrame.Angles(0, math.rad(45), 0))
mkCF("WreckChain", Vector3.new(1, 77.5, 1),
	CFrame.new(Vector3.new(76, 67.75, 68) + Vector3.new(CX, 0, CZ)))
local ball = mk("WreckBall", Vector3.new(26, 26, 26), Vector3.new(76, 16, 68), GREY_DK)
ball.Shape = Enum.PartType.Ball
label(ball, "WRECKING BALL — pendulum from the arm TIP (single pivot)")
local swing = mkCF("SwingZoneMark", Vector3.new(20, 0.25, 106), -- ±53: tip slid out, arc grazes nothing
	CFrame.new(Vector3.new(76, 1.2, 68) + Vector3.new(CX, 0, CZ)) * CFrame.Angles(0, math.rad(45), 0),
	Color3.fromRGB(190, 150, 150))
label(swing, "SWING PATH (diagonal, toward/away from the core)")
-- ══ NORTH LANE: SECOND CRANE (opposite lane from crane 1's southern arc) ════
-- WEST corridor of the north flank: arc LOW at z -100 (past the north pit),
-- endpoints at the pit flank (z ~-35) and the map edge (z ~-140). The MAST
-- stands OUTSIDE the playable bounds — only the arm reaches in.
mk("CraneMast2", Vector3.new(6, 110, 6), Vector3.new(-40, 55, -152)) -- extra-tall: arc runs the void's full length
mk("CraneArm2", Vector3.new(4, 3, 52), Vector3.new(-40, 108, -126)) -- mast -> tip
mk("WreckChain2", Vector3.new(1, 77.5, 1), Vector3.new(-40, 67.75, -100))
local ball2 = mk("WreckBall2", Vector3.new(26, 26, 26), Vector3.new(-40, 16, -100), GREY_DK)
ball2.Shape = Enum.PartType.Ball
label(ball2, "WRECKING BALL 2 — pendulum from the arm TIP (single pivot)")
-- pendulum reach ~±75 (chain 77.5): ground-contact z -153..-47, then the
-- ball rides at container-jumper height across the pit to its far edge —
-- bailing off a ride threads the swing window
local swing2 = mk("SwingZoneMark2", Vector3.new(20, 0.25, 135), Vector3.new(-40, 1.2, -92.5), Color3.fromRGB(190, 150, 150))
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
-- OUT-OF-BOUNDS corner masses: four tall solid buildings fill the corner
-- quadrants so play condenses into the lanes + center. Clearances: spawn
-- exit bands (z ±60) open, ball-2 line (x -40) clear, SE mass starts at
-- x 130 (the SE arc end reaches x ~126).
-- Corner clusters: the owner's drawn silhouettes as varied-height lobes
-- (32-48 tall). Footprints keep every clearance: spawn bands z ±60 open,
-- ball-2 line clear, SE bite = the ball-arc zone (x128..156, z60..90).
local GREY_BLD = Color3.fromRGB(150, 148, 152)
local corner = {
	-- SE (big + notch) — all corners ~1.5x taller (v57)
	{ Vector3.new(30, 72, 36), Vector3.new(165, 36, 108) },
	{ Vector3.new(24, 54, 36), Vector3.new(140, 27, 108) },
	{ Vector3.new(24, 62, 30), Vector3.new(168, 31, 75) },
	-- SW (wide + two fingers)
	{ Vector3.new(38, 70, 42), Vector3.new(-161, 35, 105) },
	{ Vector3.new(30, 50, 42), Vector3.new(-127, 25, 105) },
	{ Vector3.new(18, 58, 34), Vector3.new(-101, 29, 101) },
	{ Vector3.new(20, 40, 24), Vector3.new(-165, 20, 72) },
	{ Vector3.new(20, 46, 24), Vector3.new(-115, 23, 72) },
	-- NE (long + step)
	{ Vector3.new(45, 66, 40), Vector3.new(157.5, 33, -106) },
	{ Vector3.new(40, 52, 40), Vector3.new(115, 26, -106) },
	{ Vector3.new(40, 38, 26), Vector3.new(115, 19, -73) },
	-- NW: BUILDING CLUSTER — 82-tall tower + annexes; dressing rides the top
	{ Vector3.new(36, 82, 40), Vector3.new(-164, 41, -106) },
	{ Vector3.new(28, 64, 30), Vector3.new(-132, 32, -111) },
	{ Vector3.new(40, 38, 20), Vector3.new(-152, 19, -82) },
	{ Vector3.new(16, 50, 24), Vector3.new(-112, 25, -108) },
	{ Vector3.new(38, 1.5, 2), Vector3.new(-164, 82.75, -125) },
	{ Vector3.new(38, 1.5, 2), Vector3.new(-164, 82.75, -87) },
	{ Vector3.new(6, 3, 5), Vector3.new(-166, 83.5, -104) },
}
for i, def in corner do
	local blk = mk("CornerMass", def[1], def[2], GREY_BLD)
	if i == 1 then
		label(blk, "CORNER BUILDINGS — solid, out of bounds")
	end
end
-- SW finger void railing (hop it and drop) + the back divot filled flush
local rail = mk("VoidRail", Vector3.new(26, 2.5, 1), Vector3.new(-140, 2.25, 61.5))
label(rail, "RAIL VOID — hop the rail and you drop")
mk("CornerMass", Vector3.new(18, 40, 8), Vector3.new(-101, 20, 122), GREY_BLD)

-- ══ PERIMETER (skyscraper-top containment) ═══════════════════════════════════
-- CONSTRUCTION FENCING at 2.5x player height (player 5 -> fence 12.5 tall):
-- framed panels with dark posts, a top rail and orange safety-mesh infill.
-- Above them an invisible wall 400 studs tall so NOBODY can be thrown or
-- glided over the edge — the only way off the building is through one of the
-- FOUR drop gaps (no fence, no wall), staged with hazard pad, overhanging
-- plank, pallet and cones. G1 north (ball-2 corridor), G2 south (ball-1
-- reach), G3/G4 behind the east/west spawns.
do
	local FENCE_H = 20             -- 4x the 5-stud player: tall solid hoarding
	local FENCE_FLOOR = BASIN_TOP - 10 -- every segment's base: under the basin
	local BURY = 4                 -- panels reach below grade so a panel
	                               -- crossing a hillside never floats
	local POST = Color3.fromRGB(74, 72, 78)
	local STEEL = Color3.fromRGB(108, 116, 124)   -- solid site hoarding
	local STEEL_CAP = Color3.fromRGB(146, 152, 158)
	local HAZ = Color3.fromRGB(210, 180, 70)
	local PANEL_W = 14
	local PANEL_STEP = 15
	-- FULL perimeter coverage. Only two things interrupt a run: the four
	-- drop gaps, and the N/S centre buildings (x -25..25) whose own outer
	-- walls seal the boundary there.
	--   drop gaps: N x -60..-20 | S x 96..126 | E z -20..20 | W z -20..20
	local runs = {
		{ "x", -125.4, -182, -60 }, { "x", -125.4, 25, 182 },
		{ "x", 125.4, -182, -25 }, { "x", 125.4, 25, 96 }, { "x", 125.4, 126, 182 },
		{ "z", 181.4, -126, 60 }, { "z", 181.4, 96, 128 },
		{ "z", -181.4, -126, -96 }, { "z", -181.4, -60, 128 },
	}
	-- vertical layout, all relative to plateau grade (y=1); the band shift
	-- pass reseats each piece for its own x, so hillside panels follow the hill
	local infillH = FENCE_H + BURY
	local infillY = 1 + FENCE_H - infillH / 2
	local railY = 1 + FENCE_H - 0.4
	for _, r in runs do
		local axis, line, a, b = r[1], r[2], r[3], r[4]
		local len = b - a
		-- Solid metal wall, TERRAIN-FOLLOWING. Every segment's base is pinned
		-- to FENCE_FLOOR (below the basin) and its top to localGrade+FENCE_H,
		-- so the wall is never undercut where the ground drops and the pieces
		-- crossing the hillside are automatically TALLER to bridge the slope.
		-- Segments butt together (slight overlap) = no seams.
		local mid = (a + b) / 2
		if axis == "x" then
			local x = a
			while x < b - 0.01 do
				local ax = math.abs(x)
				-- fine steps across the hillside, long spans on flat ground
				local onSlope = ax > BAND - 8 and ax < BAND + SLOPE_RUN + 8
				local w = math.min(if onSlope then 6 else 26, b - x)
				local cx2 = x + w / 2
				local top = PLATEAU_TOP + bandDelta(cx2, line) + FENCE_H
				local h = top - FENCE_FLOOR
				local wall = mk("EdgeFence", Vector3.new(w + 0.4, h, 1.6), Vector3.new(cx2, FENCE_FLOOR + h / 2, line), STEEL)
				wall.Material = Enum.Material.DiamondPlate
				local cap = mk("EdgeFence", Vector3.new(w + 0.4, 1.2, 2.4), Vector3.new(cx2, top - 0.6, line), STEEL_CAP)
				cap.Material = Enum.Material.Metal
				x += w
			end
			for rx = a + 8, b - 8, 24 do
				local top = PLATEAU_TOP + bandDelta(rx, line) + FENCE_H
				local rib = mk("EdgeFence", Vector3.new(1.1, top - 1 - FENCE_FLOOR, 2.2), Vector3.new(rx, FENCE_FLOOR + (top - 1 - FENCE_FLOOR) / 2, line), POST)
				rib.Material = Enum.Material.Metal
			end
		else
			-- side runs sit out at |x| 181: always plateau grade, so one part
			local top = PLATEAU_TOP + FENCE_H
			local h = top - FENCE_FLOOR
			local wall = mk("EdgeFence", Vector3.new(1.6, h, len), Vector3.new(line, FENCE_FLOOR + h / 2, mid), STEEL)
			wall.Material = Enum.Material.DiamondPlate
			local cap = mk("EdgeFence", Vector3.new(2.4, 1.2, len), Vector3.new(line, top - 0.6, mid), STEEL_CAP)
			cap.Material = Enum.Material.Metal
			for rz = a + 6, b - 6, 24 do
				local rib = mk("EdgeFence", Vector3.new(2.2, h - 1, 1.1), Vector3.new(line, FENCE_FLOOR + (h - 1) / 2, rz), POST)
				rib.Material = Enum.Material.Metal
			end
		end
		-- invisible wall: 400 tall, based well below the basin so it seals at
		-- every elevation. Knockback + glider can't clear it; only the gaps.
		local BARRIER_H = 400
		local barrierY = -30 + BARRIER_H / 2
		local w
		if axis == "x" then
			w = mk("EdgeBarrier", Vector3.new(len, BARRIER_H, 1), Vector3.new((a + b) / 2, barrierY, line))
		else
			w = mk("EdgeBarrier", Vector3.new(1, BARRIER_H, len), Vector3.new(line, barrierY, (a + b) / 2))
		end
		w.Transparency = 1
		w.CanQuery = false -- the dodgeball's wall sweep ignores it
	end
	-- Drop gaps. NOTE: the E/W gaps used to sit at z -20..20, which is
	-- directly behind the spawn decks (z -25..25) — spawn-camping by
	-- knockback. They're staggered off the spawn backs now.
	local gaps = {
		{ -40, -126, 0, -1, 40 }, { 111, 126, 0, 1, 30 },
		{ 182, 78, 1, 0, 36 }, { -182, -78, -1, 0, 36 },
	}
	for _, g in gaps do
		local gx, gz, ox, oz, gw = g[1], g[2], g[3], g[4], g[5]
		local lx, lz = math.abs(oz), math.abs(ox)
		local padSize = if ox == 0 then Vector3.new(gw, 0.15, 6) else Vector3.new(6, 0.15, gw)
		mk("GapHazardPad", padSize, Vector3.new(gx - ox * 3.5, 1.28, gz - oz * 3.5), HAZ)
		local plankSize = if ox == 0 then Vector3.new(2, 0.4, 14) else Vector3.new(14, 0.4, 2)
		mk("GapPlank", plankSize, Vector3.new(gx + lx * 6, 1.6, gz + lz * 6), Color3.fromRGB(202, 122, 62))
		mk("GapPallet", Vector3.new(8, 4, 6), Vector3.new(gx - ox * 8 - lx * 10, 3, gz - oz * 8 - lz * 10))
		for _, sgn in { -1, 1 } do
			local cone = mk("GapCone", Vector3.new(2.2, 2.2, 2.2), Vector3.new(gx - ox * 5 + lx * sgn * 13, 2.1, gz - oz * 5 + lz * sgn * 13), Color3.fromRGB(235, 120, 50))
			cone.Shape = Enum.PartType.Cylinder
			cone.CFrame = cone.CFrame * CFrame.Angles(0, 0, math.rad(90))
		end
	end
end

-- ══ OUTWORLD RING (beyond the line — visual only, unreachable) ═══════════════
-- Near apron: equipment + dirt piles on all four sides. Backdrop: really
-- tall dusty buildings sealing every distant view (cranes lean in from this
-- skyline). Real-arena build: void/clouds beyond.
do
	local DIRT = Color3.fromRGB(124, 96, 62)
	local DUSTY = {
		Color3.fromRGB(168, 158, 140), Color3.fromRGB(150, 140, 124),
		Color3.fromRGB(140, 132, 120), Color3.fromRGB(158, 146, 128),
		Color3.fromRGB(146, 138, 130),
	}
	-- LAYERED SKYLINE — three concentric rings so there are NO gaps and the
	-- city reads with depth instead of as a flat fence:
	--   ring 1 (near): buildings OVERLAP (spacing < width) so the run is
	--                  continuous; these get the detailed construction meshes
	--   ring 2/3 (far): set back 64 / 132 studs, progressively TALLER, and
	--                  offset half a bay so they fill ring 1's seams and rise
	--                  above its roofline. Kept as tinted slabs — distant
	--                  silhouettes need no mesh detail (name = ...Far, which
	--                  the mesh swap below skips).
	local RINGS = {
		{ bump = 0, spacing = 76, w = 92, d = 26, hBase = 84, hVar = 62, off = 0, far = false },
		{ bump = 64, spacing = 88, w = 96, d = 28, hBase = 142, hVar = 38, off = 44, far = true },
		{ bump = 132, spacing = 96, w = 104, d = 30, hBase = 182, hVar = 44, off = 20, far = true },
	}
	local SIDES = {
		{ along = "x", nx = 0, nz = -1, dist = 185, from = -290, to = 290 },
		{ along = "x", nx = 0, nz = 1, dist = 185, from = -290, to = 290 },
		{ along = "z", nx = 1, nz = 0, dist = 235, from = -270, to = 270 },
		{ along = "z", nx = -1, nz = 0, dist = 235, from = -270, to = 270 },
	}
	local FAR_TINT = {
		Color3.fromRGB(178, 172, 160), Color3.fromRGB(166, 160, 150),
		Color3.fromRGB(158, 154, 148), Color3.fromRGB(172, 164, 152),
	}
	for si, side in SIDES do
		for ri, ring in RINGS do
			local a = side.from + ring.off
			local idx = 0
			while a <= side.to do
				idx += 1
				-- deterministic height jitter (same skyline on every rebuild)
				local jitter = ((idx * 37 + ri * 91 + si * 53) % 100) / 100
				local h = ring.hBase + jitter * ring.hVar
				-- DEPTH STAGGER (near ring): shove each building back by a
				-- varying amount so the run isn't a flat wallpaper plane.
				-- Ring 1's lateral overlap (92 wide on 76 spacing) plus the
				-- half-bay-offset ring 2 behind it keep the staggered notches
				-- sealed — verified by the ray audit.
				local back = if ring.far then 0 else ((idx * 3 + si * 2) % 5) * 8.5
				local dist = side.dist + ring.bump + back
				local size, pos
				if side.along == "x" then
					size = Vector3.new(ring.w, h, ring.d)
					pos = Vector3.new(a, h / 2, side.nz * dist)
				else
					size = Vector3.new(ring.d, h, ring.w)
					pos = Vector3.new(side.nx * dist, h / 2, a)
				end
				local palette = if ring.far then FAR_TINT else DUSTY
				mk(if ring.far then "OutworldTowerFar" else "OutworldTower",
					size, pos, palette[(idx + si) % #palette + 1])
				a += ring.spacing
			end
		end
	end
	-- diagonal corner fills: close the sight lines where the N/S runs meet
	-- the E/W runs (a straight ring leaves a wedge open at each corner)
	for ci, cdef in { { 250, -232 }, { 250, 232 }, { -250, -232 }, { -250, 232 } } do
		mk("OutworldTowerFar", Vector3.new(120, 158 + ci * 9, 120),
			Vector3.new(cdef[1], (158 + ci * 9) / 2, cdef[2]), FAR_TINT[ci % #FAR_TINT + 1])
	end
	local function dirtPile(x, z, sc)
		mk("OutworldDirt", Vector3.new(14 * sc, 4 * sc, 12 * sc), Vector3.new(x, 2 * sc, z), DIRT)
		mk("OutworldDirt", Vector3.new(9 * sc, 3 * sc, 8 * sc), Vector3.new(x + 2, 4.5 * sc, z - 1), DIRT)
		mk("OutworldDirt", Vector3.new(5 * sc, 2 * sc, 4 * sc), Vector3.new(x - 1, 6.4 * sc, z + 1), DIRT)
	end
	local function pipeStack(x, z)
		for i in ipairs({ 1, 2, 3 }) do
			local pipe = mk("OutworldPipe", Vector3.new(16, 3, 3), Vector3.new(x, if i == 3 then 4.2 else 1.7, z + (i - 1.5) * 2.2), Color3.fromRGB(120, 118, 122))
			pipe.Shape = Enum.PartType.Cylinder
		end
	end
	local function spool(x, z)
		local s1 = mk("OutworldSpool", Vector3.new(2.5, 8, 8), Vector3.new(x, 4, z), Color3.fromRGB(170, 130, 80))
		s1.Shape = Enum.PartType.Cylinder
	end
	local function genBox(x, z)
		mk("OutworldGen", Vector3.new(9, 6, 5), Vector3.new(x, 3, z), Color3.fromRGB(120, 116, 110))
		mk("OutworldGen", Vector3.new(2, 1.5, 2), Vector3.new(x + 2.5, 7, z), Color3.fromRGB(80, 78, 76))
	end
	local function barrels(x, z)
		for _, dx in { -1.8, 1.8 } do
			local b = mk("OutworldBarrel", Vector3.new(4, 3, 3), Vector3.new(x + dx, 2, z), Color3.fromRGB(96, 110, 130))
			b.Shape = Enum.PartType.Cylinder
			b.CFrame = b.CFrame * CFrame.Angles(0, 0, math.rad(90))
		end
	end
	dirtPile(-120, -145, 1.2); pipeStack(-75, -142); genBox(30, -144); dirtPile(75, -148, 1); spool(120, -143)
	dirtPile(-140, 145, 1.1); spool(-60, 146); genBox(0, 148); dirtPile(60, 150, 1.3); barrels(100, 144)
	dirtPile(196, -90, 1); spool(193, -40); barrels(194, 40); dirtPile(198, 90, 1.2); pipeStack(192, 0)
	pipeStack(-192, -90); dirtPile(-196, -30, 1.2); genBox(-193, 30); dirtPile(-198, 90, 1); spool(-192, 130)
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

-- ══ MESH DRESS PASS (post-process: swap primitives for generated meshes) ════
-- Five AI-generated originals (permanent asset IDs). Runs after the build so
-- primitives remain the fallback if a mesh fails to load.
do
	local AssetService = game:GetService("AssetService")
	local IDS = {
		ball = { 121033251049707, 90328631351540 },
		container = { 118557174191364, 115669725224597 }, -- weathered shipping container (v81)
		dirt = { 71501601810769, 139894024422338 },
		excavator = { 78595779734465, 126594719056235 },
		tower = { 105488940082739, 110958436568221 },
		-- construction-vibe building templates (v65)
		bldg_concrete = { 140013797007692, 104297449889312 }, -- clean solid glass tower (v65b)
		bldg_tarp = { 134344618023053, 89292694419511 }, -- solid tower, tarp top (v65d)
		bldg_brick = { 138397727486531, 85956331974645 }, -- clean solid brick (v65c)
		bldg_warehouse = { 123778151690244, 100579815563326 },
		-- centre-lane building components (v73): mapped 1:1 onto existing
		-- parts so shapes are unchanged; CollisionFidelity=Box keeps the
		-- collision mathematically identical to the primitives they replace
		-- COLOURED building components (v77). Colour must live in the TEXTURE:
		-- MeshPart.Color is ignored whenever a TextureID is set, so tinting a
		-- white mesh does nothing. Each of these was generated pre-coloured.
		bld_column = { 94789495761928, 84571403496041 },    -- WEATHERED concrete column (v80)
		bld_panel = { 79620855025586, 133234199177647 },    -- WEATHERED terracotta panel (v80)
		bld_mass_rust = { 101708963166511, 100682713317704 },-- WEATHERED rust warehouse (v80)
		bld_mass_sand = { 139752600350096, 139267083597521 },-- WEATHERED sand stucco (v80)
		-- crane kit (v72): lattice mast, jib boom, twisted steel rope
		crane_mast = { 126008349832708, 93528564387647 },
		crane_arm = { 92107200748996, 78274682935714 },
		crane_rope = { 117141007456779, 92312225022942 },
	}
	local cache = {}
	-- boxCollide: bake Box collision at creation. CollisionFidelity CANNOT be
	-- changed after CreateMeshPartAsync — it must be passed in the options, or
	-- the mesh keeps its default hull.
	local function meshPart(kind: string, boxCollide: boolean?): MeshPart?
		local def = IDS[kind]
		local key = if boxCollide then kind .. "#box" else kind
		if cache[key] == nil then
			local ok, mp = pcall(function()
				if boxCollide then
					return AssetService:CreateMeshPartAsync(Content.fromAssetId(def[1]),
						{ CollisionFidelity = Enum.CollisionFidelity.Box })
				end
				return AssetService:CreateMeshPartAsync(Content.fromAssetId(def[1]))
			end)
			if ok and mp then
				mp.TextureID = "rbxassetid://" .. def[2]
				mp.Anchored = true
				cache[key] = mp
			else
				cache[key] = false
			end
		end
		local t = cache[key]
		return if t then t:Clone() else nil
	end
	-- ferry containers + wrecking balls keep pose and labels
	for _, c in m:GetChildren() do
		-- every container in the map uses the shipping-container mesh. Its
		-- native long axis is X, so pit ferries (which run along Z) are built
		-- at X-long size and yawed 90 rather than cross-stretched.
		if c.Name:match("^Container") or c.Name == "Room_EntryContainer" or c.Name:match("^ScafContainer") then
			local mp = meshPart("container")
			if mp then
				mp.Name = c.Name
				if c.Name:match("^Container") then
					mp.Size = Vector3.new(26, 8, 10)
					mp.CFrame = CFrame.new(c.Position) * CFrame.Angles(0, math.rad(90), 0)
				elseif c.Name == "Room_EntryContainer" then
					mp.Size = Vector3.new(12, 10, 10)
					mp.CFrame = CFrame.new(c.Position)
				else -- ScafContainer / ScafContainer2
					mp.Size = Vector3.new(26, 8, 10)
					mp.CFrame = CFrame.new(c.Position)
				end
				-- NOTE: CollisionFidelity cannot be written from a script in
				-- any context here (edit or runtime — it needs the Plugin
				-- capability), so the mesh keeps Default. That is acceptable:
				-- Default is a convex-hull approximation and this mesh is a
				-- box, so the deck comes out effectively flat.
				local bb = c:FindFirstChildOfClass("BillboardGui")
				if bb then bb.Parent = mp end
				mp.Parent = m
				c:Destroy()
			end
		elseif c.Name == "WreckBall" or c.Name == "WreckBall2" then
			local mp = meshPart("ball")
			if mp then
				mp.Name = c.Name
				mp.Size = Vector3.new(26, 30, 26)
				mp.CFrame = c.CFrame + Vector3.new(0, 2, 0)
				local bb = c:FindFirstChildOfClass("BillboardGui")
				if bb then bb.Parent = mp end
				mp.Parent = m
				c:Destroy()
			end
		elseif c.Name == "CraneMast" or c.Name == "CraneMast2"
			or c.Name == "CraneArm" or c.Name == "CraneArm2"
			or c.Name == "WreckChain" or c.Name == "WreckChain2" then
			-- CRANE KIT: every template's long axis already matches its part
			-- (mast/rope = Y, jib = Z), so size carries straight over and the
			-- 45-degree jib keeps its CFrame.
			local kind = if c.Name:match("^CraneMast") then "crane_mast"
				elseif c.Name:match("^CraneArm") then "crane_arm"
				else "crane_rope"
			local mp = meshPart(kind)
			if mp then
				mp.Name = c.Name
				-- rope reads too thin at 1 stud: thicken so the strands show
				mp.Size = if kind == "crane_rope"
					then Vector3.new(2, c.Size.Y, 2)
					else c.Size
				mp.CFrame = c.CFrame
				mp.Parent = m
				c:Destroy()
			end
		end
	end
	-- outworld dirt clusters -> mesh mounds
	local dirtSpots = {}
	for _, c in m:GetChildren() do
		if c.Name == "OutworldDirt" then
			local lp = c.Position - Vector3.new(CX, 0, CZ)
			if c.Size.X > 10 then
				table.insert(dirtSpots, { lp.X, lp.Z, c.Size.X / 14 })
			end
			c:Destroy()
		end
	end
	for _, sp in dirtSpots do
		local mp = meshPart("dirt")
		if mp then
			mp.Name = "OutworldDirt"
			mp.Size = Vector3.new(16 * sp[3], 8 * sp[3], 14 * sp[3])
			mp.CFrame = CFrame.new(Vector3.new(sp[1], 4 * sp[3], sp[2]) + Vector3.new(CX, 0, CZ)) * CFrame.Angles(0, math.rad(sp[1] * 7 % 360), 0)
			mp.Parent = m
		end
	end
	-- excavator parked on the south apron
	-- ── CENTRE-LANE BUILDINGS: component mesh swap (v73) ────────────────
	-- north hall + core tower + south perch. Each mesh takes the exact size
	-- and CFrame of the part it replaces, so every walkable surface, opening
	-- and ramp line stays where it was.
	do
		local COLUMN = { TowerPillar = true, NB_HallPillar = true, NB_UpperPost = true, Room_Post = true }
		local PANEL = { TowerWallN = true, TowerWallE = true, TowerWallW = true, TowerWallS = true,
			NB_Wall = true, NB_UpperWall = true, Room_DeckWall = true }
		local MASS = { NB_Tower = true, Room_Tower = true, Room_Base = true }
		local targets = {}
		for _, c in m:GetChildren() do
			if COLUMN[c.Name] or PANEL[c.Name] or MASS[c.Name] then
				table.insert(targets, c)
			end
		end
		-- TINTS: the generated concrete textures are very pale, and MeshPart
		-- .Color multiplies against the texture — leaving it white reads as
		-- blank. Warm sandy-concrete tones, a distinct cast per structure so
		-- the three buildings don't look like one material.
		local TINT = {
			Tower = Color3.fromRGB(170, 142, 104),  -- core: warm ochre concrete
			NB_ = Color3.fromRGB(188, 146, 96),     -- north hall: sandy orange
			Room_ = Color3.fromRGB(150, 134, 112),  -- south perch: cooler stone
		}
		local function tintFor(name: string): Color3
			for prefix, col in TINT do
				if name:sub(1, #prefix) == prefix then
					return col
				end
			end
			return TINT.Tower
		end
		for _, c in targets do
			-- masses differ PER BUILDING so the three structures read as
			-- distinct places, not three copies of one material
			local kind
			if COLUMN[c.Name] then
				kind = "bld_column"
			elseif PANEL[c.Name] then
				kind = "bld_panel"
			else
				kind = if c.Name:sub(1, 3) == "NB_" then "bld_mass_rust" else "bld_mass_sand"
			end
			local mp = meshPart(kind, true) -- Box collision baked at creation
			if mp then
				mp.Name = c.Name
				-- MeshPart.Color is IGNORED while TextureID is set (verified:
				-- a mesh forced to pure red still rendered white). So colour
				-- MUST come from the texture itself — each building gets its
				-- own COLOURED mesh below rather than a tint on a white one.
				mp.Color = tintFor(c.Name)
				if kind == "bld_panel" and c.Size.Z > c.Size.X then
					-- panel's long axis is X: yaw the Z-running walls to match
					mp.Size = Vector3.new(c.Size.Z, c.Size.Y, c.Size.X)
					mp.CFrame = c.CFrame * CFrame.Angles(0, math.rad(90), 0)
				else
					mp.Size = c.Size
					mp.CFrame = c.CFrame
				end
				local bb = c:FindFirstChildOfClass("BillboardGui")
				if bb then bb.Parent = mp end
				mp.Parent = m
				c:Destroy()
			end
		end
	end

	-- ── WHOLE-BUILDING TINT (v74) ───────────────────────────────────────
	-- The meshed columns/walls were tinted at swap, but the floors, roofs,
	-- decks, podium and ramps are still plain primitives — they're the big
	-- flat surfaces, so leaving them grey is what read as "blank white".
	-- Slabs get a darker/warmer cast than walls so levels stay legible.
	do
		local WALLTONE = {
			Tower = Color3.fromRGB(146, 116, 78),
			NB_ = Color3.fromRGB(172, 118, 66),
			Room_ = Color3.fromRGB(124, 112, 96),
			Scaf = Color3.fromRGB(158, 126, 84),
		}
		local SLABTONE = {
			Tower = Color3.fromRGB(158, 124, 86),
			NB_ = Color3.fromRGB(184, 132, 74),
			Room_ = Color3.fromRGB(138, 124, 104),
			Scaf = Color3.fromRGB(168, 134, 92),
		}
		local KEEP = { Room_EntryContainer = true, ScafBracket = true }
		for _, c in m:GetChildren() do
			if c:IsA("BasePart") and not KEEP[c.Name] then
				for prefix, wall in WALLTONE do
					if c.Name:sub(1, #prefix) == prefix then
						local isSlab = c.Name:find("Floor") or c.Name:find("Roof")
							or c.Name:find("Deck") or c.Name:find("Podium") or c.Name:find("Ramp")
						c.Color = if isSlab then SLABTONE[prefix] else wall
						if c.Name:find("Crate") then
							c.Color = Color3.fromRGB(168, 122, 74) -- timber
							c.Material = Enum.Material.WoodPlanks
						elseif not c:IsA("MeshPart") then
							c.Material = Enum.Material.Concrete
						end
						break
					end
				end
			end
		end
	end

	-- ── LIGHTING (v74) ──────────────────────────────────────────────────
	-- The scene was washing every colour to white: Ambient sat at ~0.59, i.e.
	-- a 59% flat white fill on every surface regardless of shadow, with
	-- Brightness 2.9 on top. Tints were being applied correctly and then
	-- bleached out. Low warm ambient + a warm sky fill restores contrast and
	-- sets up the orange/sand direction.
	-- NOTE: Lighting is shared with the HQ map, whose own build script also
	-- sets it — whichever ran last wins.
	do
		local L = game:GetService("Lighting")
		L.Brightness = 2.4
		L.Ambient = Color3.fromRGB(62, 52, 42)
		L.OutdoorAmbient = Color3.fromRGB(132, 114, 92)
		L.ClockTime = 16.2
		L.FogColor = Color3.fromRGB(216, 188, 150)
		L.FogStart = 340
		L.FogEnd = 1500
		local cc = L:FindFirstChildOfClass("ColorCorrectionEffect")
		if cc then
			cc.Saturation = 0.22
			cc.Contrast = 0.12
			cc.TintColor = Color3.fromRGB(255, 246, 232)
		end
		local bl = L:FindFirstChildOfClass("BloomEffect")
		if bl then
			bl.Intensity = 0.35
		end
	end

	local exc = meshPart("excavator")
	if exc then
		exc.Name = "OutworldExcavator"
		exc.Size = Vector3.new(10, 10, 18)
		exc.CFrame = CFrame.new(Vector3.new(60, 5, 150) + Vector3.new(CX, 0, CZ)) * CFrame.Angles(0, math.rad(35), 0)
		exc.Parent = m
	end
		-- ALL corner masses + backdrop towers -> construction meshes; template
	-- picked by height, scaled to each footprint (grey primitive = fallback)
	local toSwap = {}
	for _, c in m:GetChildren() do
		if c.Name == "CornerMass" or c.Name == "OutworldTower" then
			table.insert(toSwap, c)
		end
	end
	for _, c in toSwap do
		local lp = c.Position - Vector3.new(CX, 0, CZ)
		local h = c.Size.Y
		local pick
		if h > 95 then
			pick = (math.floor(math.abs(lp.X)) % 2 == 0) and "bldg_concrete" or "bldg_tarp"
		elseif h > 58 then
			pick = (math.floor(math.abs(lp.Z)) % 2 == 0) and "bldg_tarp" or "bldg_brick"
		else
			pick = (math.floor(math.abs(lp.X + lp.Z)) % 2 == 0) and "bldg_warehouse" or "bldg_brick"
		end
		local mp = meshPart(pick)
		if mp then
			mp.Name = c.Name
			mp.Size = c.Size
			mp.CFrame = CFrame.new(c.Position) * CFrame.Angles(0, math.rad((lp.X * 3 + lp.Z) % 8 - 4), 0)
			mp.Parent = m
			c:Destroy()
		end
	end
-- ── GROUND + OUTER-BUILDING material pass (v64) ──────────────────────
		for _, c in m:GetChildren() do
			local n = c.Name
			if n == "Dirt" then
				c.Material = Enum.Material.Concrete
				c.Color = Color3.fromRGB(176, 170, 158)
			elseif n == "PitWall" then
				c.Material = Enum.Material.Slate
				c.Color = Color3.fromRGB(46, 46, 50)
			elseif n == "GapPlank" or n == "GapPallet" then
				c.Material = Enum.Material.WoodPlanks
				-- (EdgeFence keeps its own metal materials — set at build)
			elseif n == "SpawnDeck" then
				c.Material = Enum.Material.Concrete
			elseif n == "OutworldTowerFar" then
				-- distant rings: dusty masonry, no mesh detail needed
				c.Material = if c.Size.Y > 190 then Enum.Material.Concrete else Enum.Material.Limestone
			end
			-- (buildings are swapped for construction meshes in the mesh pass)
		end
		for _, pd in { { -70, -20, 22, 14 }, { 60, 30, 18, 12 }, { -100, 30, 16, 10 },
			{ 90, -40, 20, 12 }, { -50, 110, 18, 10 }, { 40, -115, 16, 10 } } do
			local pt = mk("DirtPatch", Vector3.new(pd[3], 0.12, pd[4]), Vector3.new(pd[1], 1.12, pd[2]),
				Color3.fromRGB(128, 102, 70))
			pt.Material = Enum.Material.Ground
			pt.CanCollide = false
		end
	end

-- ══ BAND SHIFT: drop everything standing in the basin ═══════════════════════
-- Ground/hillsides/pit walls are already authored at their final elevations,
-- and the out-of-bounds masses stay on plateau level, so both are skipped.
-- Everything else moves DOWN by bandDelta at its own x — props on a hillside
-- get a partial shift, so fences and equipment follow the slope.
do
	local SKIP = {
		Dirt = true, Hillside = true, RetainWall = true, PitWall = true,
		CornerMass = true, OutworldTower = true, OutworldTowerFar = true,
		OutworldDirt = true, OutworldPipe = true, OutworldSpool = true,
		OutworldGen = true, OutworldBarrel = true,
		CompassN = true, CompassS = true, CompassE = true, CompassW = true,
		EdgeFence = true, -- authored per-segment at its own grade already
		PlayBoundsMark = true,
	}
	-- each crane is RIGID: shift the whole assembly by the delta at its BALL,
	-- or the arm/chain/ball would shear apart across the hillside
	local CRANE1 = { CraneMast = true, CraneArm = true, WreckChain = true, WreckBall = true, SwingZoneMark = true }
	local CRANE2 = { CraneMast2 = true, CraneArm2 = true, WreckChain2 = true, WreckBall2 = true, SwingZoneMark2 = true }
	local crane1Delta = bandDelta(76, 68)   -- ball 1 hangs over x 76
	local crane2Delta = bandDelta(-40, -100) -- ball 2 over x -40

	for _, c in m:GetChildren() do
		if c:IsA("BasePart") and not SKIP[c.Name] then
			local lp = c.Position - Vector3.new(CX, 0, CZ)
			local d
			if CRANE1[c.Name] then
				d = crane1Delta
			elseif CRANE2[c.Name] then
				d = crane2Delta
			else
				d = bandDelta(lp.X, lp.Z)
			end
			if d ~= 0 then
				c.Position = c.Position + Vector3.new(0, d, 0)
			end
		end
	end

	-- out-of-bounds masses whose footprint reaches into the band/hillside would
	-- otherwise float over the excavation: extend their bases down to the pit
	for _, c in m:GetChildren() do
		if c:IsA("BasePart") and (c.Name == "CornerMass" or c.Name == "OutworldTower") then
			local lp = c.Position - Vector3.new(CX, 0, CZ)
			local innerX = math.abs(lp.X) - c.Size.X / 2
			if innerX < BAND + SLOPE_RUN and math.abs(lp.Z) < 150 then
				local top = c.Position.Y + c.Size.Y / 2
				local newH = top - (BASIN_TOP - 8)
				c.Size = Vector3.new(c.Size.X, newH, c.Size.Z)
				c.Position = Vector3.new(c.Position.X, top - newH / 2, c.Position.Z)
			end
		end
	end
end

-- ══ FULL-MAP PALETTE (v76) ══════════════════════════════════════════════════
-- Everything outside the three centre buildings was still sitting at Roblox
-- default grey (0.64) — cranes, corner masses, backdrop towers, spoil heaps,
-- the excavator. Pale generated textures then read as plain white. This pass
-- gives the WHOLE map a construction palette: safety yellow plant, warm
-- ochre/terracotta masonry with per-building variation, earth-brown spoil,
-- rust and steel accents.
do
	local YELLOW = Color3.fromRGB(228, 168, 44)      -- plant / heavy equipment
	local YELLOW_DK = Color3.fromRGB(186, 132, 30)
	local STEEL_DK = Color3.fromRGB(96, 98, 104)
	local IRON = Color3.fromRGB(74, 68, 64)
	local EARTH = Color3.fromRGB(132, 96, 58)
	local RUST = Color3.fromRGB(158, 88, 52)

	-- warm masonry spread for the out-of-bounds massing; picked per-part from
	-- position so the skyline varies but stays deterministic
	local MASONRY = {
		Color3.fromRGB(196, 138, 96),   -- terracotta
		Color3.fromRGB(178, 152, 116),  -- sandstone
		Color3.fromRGB(206, 172, 124),  -- warm ochre
		Color3.fromRGB(158, 122, 98),   -- weathered brick
		Color3.fromRGB(188, 166, 138),  -- pale limestone
		Color3.fromRGB(146, 130, 116),  -- grey stone
	}
	local FLAT = {
		CraneMast = YELLOW, CraneArm = YELLOW, CraneMast2 = YELLOW, CraneArm2 = YELLOW,
		WreckChain = STEEL_DK, WreckChain2 = STEEL_DK,
		WreckBall = IRON, WreckBall2 = IRON,
		OutworldDirt = EARTH, DirtPatch = EARTH,
		OutworldExcavator = YELLOW_DK,
		OutworldPipe = STEEL_DK, OutworldBarrel = RUST,
		OutworldSpool = Color3.fromRGB(150, 108, 68),
		OutworldGen = Color3.fromRGB(120, 124, 128),
		GapCone = Color3.fromRGB(238, 118, 40),
		GapHazardPad = Color3.fromRGB(226, 182, 52),
		GapPlank = Color3.fromRGB(178, 128, 76), GapPallet = Color3.fromRGB(178, 128, 76),
		Pallets = Color3.fromRGB(178, 128, 76), PipePile = STEEL_DK,
		PlazaCrate = Color3.fromRGB(168, 122, 74),
		ScafBracket = Color3.fromRGB(164, 116, 70),
		SpawnDeck = Color3.fromRGB(176, 154, 122),
		SpawnLip = Color3.fromRGB(206, 178, 128),
		SpawnRamp = Color3.fromRGB(186, 162, 128),
		RetainWall = Color3.fromRGB(112, 100, 88),
		Hillside = Color3.fromRGB(184, 156, 116),
	}
	for _, c in m:GetChildren() do
		if c:IsA("BasePart") then
			local flat = FLAT[c.Name]
			if flat then
				c.Color = flat
			elseif c.Name == "CornerMass" or c.Name == "OutworldTower" or c.Name == "OutworldTowerFar" then
				local seed = math.floor(math.abs(c.Position.X) * 0.37 + math.abs(c.Position.Z) * 0.11)
				c.Color = MASONRY[seed % #MASONRY + 1]
			end
		end
	end
end

-- ══ CENTRE TOWER: timber scaffolding only (v78) ══════════════════════════════
-- Owner: in the centre building ONLY the scaffolding is brown, and it should
-- read as wooden planks. So the catwalks / ramp / diagonal struts go to
-- WoodPlanks timber, and the tower FLOORS get pulled back to concrete grey
-- so the brown doesn't bleed across the whole structure.
do
	local WOOD = Color3.fromRGB(158, 108, 58)
	local WOOD_DK = Color3.fromRGB(132, 88, 48)
	local CONCRETE = Color3.fromRGB(172, 168, 160)
	local TIMBER = { ScafN = true, ScafE = true, ScafW = true, ScafS = true, ScafRamp = true }
	for _, c in m:GetChildren() do
		if c:IsA("BasePart") then
			if TIMBER[c.Name] then
				c.Color = WOOD
				c.Material = Enum.Material.WoodPlanks
			elseif c.Name == "ScafBracket" then
				c.Color = WOOD_DK -- struts a shade darker so they read separately
				c.Material = Enum.Material.Wood
			elseif c.Name == "TowerFloor2" or c.Name == "TowerFloor3" then
				c.Color = CONCRETE
				c.Material = Enum.Material.Concrete
			end
		end
	end
end

-- ══ MATCH MARKERS + TEST SPAWN (v82) ════════════════════════════════════════
-- MatchService contract: RedSpawn1..3 / BlueSpawn1..3 / BallSpawn, plus
-- ScoreboardN|S each holding a SurfaceGui TextLabel named ScoreLabel.
-- All markers are invisible, non-colliding and CanQuery=false so they can
-- never block a throw or a raycast.
do
	local function marker(name: string, pos: Vector3)
		local mk2 = mk(name, Vector3.new(2, 2, 2), pos)
		mk2.Transparency = 1
		mk2.CanCollide = false
		mk2.CanQuery = false
		mk2.CanTouch = false
		return mk2
	end
	-- spawn decks sit at x ±155 (top y 3, no band shift out there); root sits
	-- ~3 studs above the deck
	for i, dz in { -18, 0, 18 } do
		marker("RedSpawn" .. i, Vector3.new(155, 6, dz))
		marker("BlueSpawn" .. i, Vector3.new(-155, 6, dz))
	end
	-- ball starts mid-map on the basin floor
	marker("BallSpawn", Vector3.new(0, BASIN_TOP + 3, 0))

	-- scoreboards on the two centre buildings' inward faces
	local function scoreboard(name: string, pos: Vector3, face: Enum.NormalId)
		local panel = mk(name, Vector3.new(34, 7, 1), pos, Color3.fromRGB(24, 22, 28))
		panel.Material = Enum.Material.Metal
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.Parent = panel
		local lbl = Instance.new("TextLabel")
		lbl.Name = "ScoreLabel"
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextScaled = true
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.Text = "RED 0 — 0 BLUE"
		lbl.Parent = gui
	end
	scoreboard("ScoreboardN", Vector3.new(0, 6, -80), Enum.NormalId.Front)
	scoreboard("ScoreboardS", Vector3.new(0, 6, 80), Enum.NormalId.Back)

	-- TEST SPAWN: lets you walk the blockout without wiring MatchService.
	-- ENABLED by default, and the HQ garage spawn is switched off below, so
	-- hitting Play always lands you in the blockout. (Previously this was
	-- built disabled, which meant every rebuild silently left BOTH spawns
	-- off and dropped the player at world origin with no way back.)
	-- To go back to lobby testing, run in the command bar:
	--   workspace.BuildZone.ScaffoldRowBlockout.TestSpawn.Enabled = false
	--   workspace.BalloutMap.GarageSpawn.Enabled = true
	local ts = Instance.new("SpawnLocation")
	ts.Name = "TestSpawn"
	ts.Size = Vector3.new(12, 1, 12)
	ts.Position = Vector3.new(155, 3.5, 0) + Vector3.new(CX, 0, CZ)
	ts.Anchored = true
	ts.Transparency = 1
	ts.CanCollide = false
	ts.Neutral = true
	ts.Duration = 0
	ts.Enabled = true
	ts.Parent = m
	-- exactly ONE spawn should ever be live, or Roblox picks between them
	local hq = Workspace:FindFirstChild("BalloutMap")
	local garage = hq and hq:FindFirstChild("GarageSpawn")
	if garage and garage:IsA("SpawnLocation") then
		garage.Enabled = false
	end
end

-- ══ SURFACE PASS (v79): kill the smooth-toy look ═════════════════════════════
-- mk() defaults every part to SmoothPlastic, which is exactly why surfaces
-- read as moulded plastic. Give everything a material that matches what it
-- is meant to BE. Deliberately-set surfaces (fence steel, tower timber,
-- dev markers) are excluded so this can't stomp them.
do
	local MAT = {
		-- ground / earthworks
		Hillside = Enum.Material.Sand,
		RetainWall = Enum.Material.Concrete,
		DirtPatch = Enum.Material.Ground,
		-- spawn structures
		SpawnLip = Enum.Material.Concrete,
		SpawnRamp = Enum.Material.Concrete,
		-- timber goods
		Pallets = Enum.Material.WoodPlanks,
		PlazaCrate = Enum.Material.WoodPlanks,
		OutworldSpool = Enum.Material.WoodPlanks,
		-- metal goods
		PipePile = Enum.Material.CorrodedMetal,
		OutworldPipe = Enum.Material.CorrodedMetal,
		OutworldBarrel = Enum.Material.CorrodedMetal,
		OutworldGen = Enum.Material.DiamondPlate,
		OutworldExcavator = Enum.Material.Metal,
		Room_EntryContainer = Enum.Material.CorrodedMetal,
		ContainerRed = Enum.Material.CorrodedMetal,
		ContainerBlue = Enum.Material.CorrodedMetal,
		ContainerRedS = Enum.Material.CorrodedMetal,
		ContainerBlueS = Enum.Material.CorrodedMetal,
		VoidRail = Enum.Material.Metal,
		-- plant: rusted iron ball, greased steel mast/arm
		WreckBall = Enum.Material.CorrodedMetal,
		WreckBall2 = Enum.Material.CorrodedMetal,
		WreckChain = Enum.Material.Metal,
		WreckChain2 = Enum.Material.Metal,
		CraneMast = Enum.Material.DiamondPlate,
		CraneMast2 = Enum.Material.DiamondPlate,
		CraneArm = Enum.Material.DiamondPlate,
		CraneArm2 = Enum.Material.DiamondPlate,
		-- masonry (textured meshes still pick up the roughness response)
		CornerMass = Enum.Material.Concrete,
		OutworldTower = Enum.Material.Concrete,
		OutworldDirt = Enum.Material.Ground,
		GapHazardPad = Enum.Material.Concrete,
		GapCone = Enum.Material.Plastic,
		-- centre buildings
		TowerPillar = Enum.Material.Concrete,
		TowerWallN = Enum.Material.Concrete, TowerWallE = Enum.Material.Concrete,
		TowerWallW = Enum.Material.Concrete, TowerWallS = Enum.Material.Concrete,
		NB_Wall = Enum.Material.CorrodedMetal, NB_UpperWall = Enum.Material.CorrodedMetal,
		NB_Tower = Enum.Material.CorrodedMetal, NB_HallPillar = Enum.Material.Concrete,
		NB_UpperPost = Enum.Material.Concrete,
		Room_Base = Enum.Material.Concrete, Room_Tower = Enum.Material.Concrete,
		Room_DeckWall = Enum.Material.Concrete, Room_Post = Enum.Material.Concrete,
	}
	-- never touch: deliberately-set surfaces + invisible dev geometry
	local KEEP = {
		EdgeFence = true, EdgeBarrier = true, PlayBoundsMark = true,
		SwingZoneMark = true, SwingZoneMark2 = true,
		CompassN = true, CompassS = true, CompassE = true, CompassW = true,
		ScafN = true, ScafE = true, ScafW = true, ScafS = true,
		ScafRamp = true, ScafBracket = true,
	}
	for _, c in m:GetChildren() do
		if c:IsA("BasePart") and not KEEP[c.Name] then
			local mat = MAT[c.Name]
			if mat then
				c.Material = mat
			elseif c.Material == Enum.Material.SmoothPlastic or c.Material == Enum.Material.Plastic then
				c.Material = Enum.Material.Concrete -- anything still on plastic
			end
		end
	end
end

m.Parent = zone
-- scale the finished map about its centre, pivot on the ground plane so it
-- grows outward and upward rather than away from the origin
if MAP_SCALE ~= 1 then
	m.WorldPivot = CFrame.new(CX, 0, CZ)
	m:ScaleTo(MAP_SCALE)
end
return "FRACTURED CORE built: " .. #m:GetChildren() .. " parts"
