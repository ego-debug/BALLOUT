-- Ballout | HQ map generator (v2 — Knockout City Hideout remake)
-- Run in EDIT mode (execute_luau). Rebuilds Workspace.BalloutMap from scratch.
--
-- Layout (researched from the KC Hideout wiki + in-game screenshots):
--   MAIN DECK (top Y=0, x -40..60, z -60..40): the wide open practice space.
--     - GARAGE (north edge, by the hoops): spawn inside, door faces south so
--       the deck pans left/right on exit; trophy case + jukebox interior
--     - RADIO TOWER outside the garage (two-tier lattice + red beacon)
--     - SPAWN DRUM (south-east): raised teal round tank cap you spawn on,
--       steps down to the deck (KC spawn vibe)
--     - Launch pads with light beams + golden halo rings (matchmaking pads)
--     - Basketball hoops, solar panels, chimneys, water tower, plank pile
--   DUMMY ROOF (top Y=-6, x 75..135, z -80..10): smaller SEPARATE LOWER roof
--     - lawn + hedges, training bot pad, 5 special-ball spawner pods
--     - wooden planks bridge the gap from the main deck
--   QUEUE ROOF (top Y=4, x -140..-50, z -55..35): main-deck-sized WEST roof
--     - SIX walk-in queue rooms in two facing banks (two rooms per mode)
--     - stair bridge from the main deck's west edge
--   Barrier skyline + invisible walls + cloud void + dusk fog all around.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local old = Workspace:FindFirstChild("BalloutMap")
if old then old:Destroy() end
local map = Instance.new("Model")
map.Name = "BalloutMap"

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	-- CYBERPUNK knob: every wall that asks for Brick renders as dark metal
	-- paneling instead — one switch restyles the whole city.
	p.Parent = map
	return p
end

-- RETRO-FUTURE palette (KC "City of Tomorrow" MOOD, our own values): warm
-- brick, cream pavement, 50s turquoise trim, sunny grass — bright and
-- saturated. Neon (pink/purple/cyan) survives ONLY as sign + accent trim.
local BRICK_A = Color3.fromRGB(168, 96, 70)
local BRICK_B = Color3.fromRGB(146, 82, 62)
local BRICK_DARK = Color3.fromRGB(120, 66, 52)
local TEAL = Color3.fromRGB(64, 190, 180)    -- 50s turquoise trim
local MAGENTA = Color3.fromRGB(255, 110, 190) -- holo-pink sign accent
local TAR = Color3.fromRGB(74, 66, 62)
local PAVE = Color3.fromRGB(214, 202, 182)
local TILE = Color3.fromRGB(232, 222, 205)
local GRASS = Color3.fromRGB(110, 178, 68)
local GRASS_DK = Color3.fromRGB(90, 150, 55)
local METAL_DK = Color3.fromRGB(92, 88, 84)
local PURPLE = Color3.fromRGB(160, 85, 240)

-- ══ MAIN DECK ═══════════════════════════════════════════════════════════════
part({ Name = "MainDeck", Size = Vector3.new(100, 3, 100), Position = Vector3.new(10, -1.5, -10),
	Color = PAVE, Material = Enum.Material.Concrete })
part({ Name = "ShaftMain", Size = Vector3.new(100, 400, 100), Position = Vector3.new(10, -203, -10),
	Color = BRICK_A, Material = Enum.Material.Brick })

-- ══ DUMMY ROOF (lower training roof) ════════════════════════════════════════
part({ Name = "DummyRoof", Size = Vector3.new(60, 3, 90), Position = Vector3.new(105, -7.5, -35),
	Color = Color3.fromRGB(178, 168, 150), Material = Enum.Material.Concrete })
part({ Name = "ShaftDummy", Size = Vector3.new(60, 400, 90), Position = Vector3.new(105, -209, -35),
	Color = BRICK_B, Material = Enum.Material.Brick })
-- lawn (south half; the north half is the queue-rooms floor, built below)
part({ Size = Vector3.new(56, 0.16, 52), Position = Vector3.new(105, -5.92, -23),
	Color = GRASS, Material = Enum.Material.Grass })

-- Dummy pad (Main.server.luau spawns the training dummy here)
part({ Name = "DummyPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7, 7),
	CFrame = CFrame.new(105, -5.8, -30) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(150, 120, 88), Material = Enum.Material.Ground })

-- Hedges around the lawn (KC's dummy roof has hedge rows)
local function hedge(x, z, sx, sz, y)
	part({ Size = Vector3.new(sx, 3.4, sz), Position = Vector3.new(x, y + 1.7, z),
		Color = Color3.fromRGB(58, 118, 48), Material = Enum.Material.Grass })
end
hedge(88, 4, 20, 2.2, -6)
hedge(124, 4, 16, 2.2, -6)
hedge(88, -44, 18, 2.2, -6)

-- ══ WINDOW STRIPS down the outward faces ════════════════════════════════════
local GLASSC = Color3.fromRGB(24, 30, 46)
-- Cyberpunk skyscraper look: the middle strip of every face GLOWS (cyan on
-- x-faces, magenta on z-faces); the outer strips stay dark glass.
local function winStrips(cx, cz, w, d, topY, skipEast, skipWest)
	local cy = topY - 170
	for si, off in { -w * 0.3, 0, w * 0.3 } do
		local neon = si == 2
		local color = if neon then TEAL else GLASSC
		local mat = if neon then Enum.Material.Neon else Enum.Material.Glass
		local tr = if neon then 0.35 else 0
		part({ Size = Vector3.new(3, 320, 0.5), Position = Vector3.new(cx + off, cy, cz - d / 2 - 0.3),
			Color = color, Material = mat, Transparency = tr })
		part({ Size = Vector3.new(3, 320, 0.5), Position = Vector3.new(cx + off, cy, cz + d / 2 + 0.3),
			Color = color, Material = mat, Transparency = tr })
	end
	for si, off in { -d * 0.3, 0, d * 0.3 } do
		local neon = si == 2
		local color = if neon then MAGENTA else GLASSC
		local mat = if neon then Enum.Material.Neon else Enum.Material.Glass
		local tr = if neon then 0.35 else 0
		if not skipEast then
			part({ Size = Vector3.new(0.5, 320, 3), Position = Vector3.new(cx + w / 2 + 0.3, cy, cz + off),
				Color = color, Material = mat, Transparency = tr })
		end
		if not skipWest then
			part({ Size = Vector3.new(0.5, 320, 3), Position = Vector3.new(cx - w / 2 - 0.3, cy, cz + off),
				Color = color, Material = mat, Transparency = tr })
		end
	end
end
winStrips(10, -10, 100, 100, -3, true, false)
winStrips(105, -35, 60, 90, -9, false, true)

-- ══ PARAPETS ════════════════════════════════════════════════════════════════
local function parapet(x, z, sx, sz, baseY)
	part({ Size = Vector3.new(sx, 4.2, sz), Position = Vector3.new(x, baseY + 2.1, z),
		Color = BRICK_DARK, Material = Enum.Material.Brick })
	-- glowing cyan cap: every rooftop edge in the city is a neon outline
	part({ Size = Vector3.new(sx + 0.6, 0.6, sz + 0.6), Position = Vector3.new(x, baseY + 4.5, z),
		Color = TEAL, Material = Enum.Material.Neon, Transparency = 0.25 })
end
-- Main deck (x -40..60, z -60..40); east opening z -26..-12 for the planks,
-- west opening z -20..0 for the queue-roof stairs
parapet(10, -59, 100, 2, 0)
parapet(10, 39, 100, 2, 0)
parapet(-39, -39, 2, 38, 0)
parapet(-39, 19, 2, 38, 0)
parapet(59, -42.5, 2, 33, 0)
parapet(59, 13.5, 2, 51, 0)
-- Dummy roof (x 75..135, z -80..10); west opening z -26..-12
parapet(105, -79, 60, 2, -6)
parapet(105, 9, 60, 2, -6)
parapet(134, -35, 2, 86, -6)
parapet(76, -53, 2, 52, -6)
parapet(76, -1, 2, 20, -6)

-- ══ PLANK BRIDGE (main deck -> dummy roof, drops 6 studs) ═══════════════════
for _, zc in { -18, -22 } do
	part({ Size = Vector3.new(16.8, 0.4, 2.6),
		CFrame = CFrame.new(67.5, -2.9, zc) * CFrame.Angles(0, 0, -0.3805),
		Color = Color3.fromRGB(202, 122, 62), Material = Enum.Material.WoodPlanks })
end

-- ══ GARAGE (north edge of the main deck, by the basketball hoops) ═══════════
-- Footprint x -25..15, z -59..-27, door facing SOUTH into the deck — spawning
-- players walk out with the whole deck panning left (training roof) and
-- right (radio tower + queue roof). 16-stud ceiling, 20x12 door.
part({ Size = Vector3.new(40, 16, 1.5), Position = Vector3.new(-5, 8, -58.25),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- back (north) wall
part({ Size = Vector3.new(1.5, 16, 32), Position = Vector3.new(-24.25, 8, -43),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- west wall
part({ Size = Vector3.new(1.5, 16, 32), Position = Vector3.new(14.25, 8, -43),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- east wall
part({ Size = Vector3.new(10, 16, 1.5), Position = Vector3.new(-20, 8, -27.75),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- front side piece
part({ Size = Vector3.new(10, 16, 1.5), Position = Vector3.new(10, 8, -27.75),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- front side piece
part({ Size = Vector3.new(20, 4, 1.5), Position = Vector3.new(-5, 14, -27.75),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- lintel over the door
local groof = part({ Name = "GarageRoof", Size = Vector3.new(42, 1.2, 34), Position = Vector3.new(-5, 16.6, -43),
	Color = TAR, Material = Enum.Material.Slate })
-- rolled-up door slats hint
for i = 0, 2 do
	part({ Size = Vector3.new(20, 0.7, 0.4), Position = Vector3.new(-5, 11.2 + i * 0.75, -27.1),
		Color = Color3.fromRGB(140, 140, 138), Material = Enum.Material.Metal })
end
-- interior glow
local glight = Instance.new("PointLight")
glight.Color = Color3.fromRGB(255, 214, 160)
glight.Range = 40
glight.Brightness = 1.4
glight.Parent = groof

-- SPAWN: everyone appears in the middle of the garage, facing the door —
-- you roll out of your hideout garage onto the deck (KC vibe). This replaces
-- the loose dev SpawnLocation that used to sit on the spawn drum.
local gspawn = Instance.new("SpawnLocation")
gspawn.Name = "GarageSpawn"
gspawn.Size = Vector3.new(10, 0.4, 10)
gspawn.CFrame = CFrame.new(-5, 0.2, -43) * CFrame.Angles(0, math.rad(180), 0) -- face SOUTH (the door)
gspawn.Color = TEAL
gspawn.Material = Enum.Material.SmoothPlastic
gspawn.Anchored = true
gspawn.Neutral = true
gspawn.Duration = 0 -- no forcefield flash
gspawn.TopSurface = Enum.SurfaceType.Smooth
gspawn.Parent = map
local oldSpawn = Workspace:FindFirstChild("SpawnLocation")
if oldSpawn then
	oldSpawn:Destroy()
end

local function sign(host, face, text, textColor, bg)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	g.Parent = host
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = bg
	l.TextColor3 = textColor
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.Parent = g
end

-- GARAGE marquee over the door + KO graffiti on the east wall (faces midfield)
local marquee = part({ Size = Vector3.new(16, 3.5, 0.6), Position = Vector3.new(-5, 18.3, -26.9),
	Color = Color3.fromRGB(30, 28, 34), Material = Enum.Material.Metal })
sign(marquee, Enum.NormalId.Back, "GARAGE", Color3.fromRGB(120, 235, 255), Color3.fromRGB(30, 28, 34))
local ko = part({ Size = Vector3.new(0.3, 10, 16), Position = Vector3.new(15.15, 8, -43),
	Color = BRICK_B, Material = Enum.Material.Brick })
sign(ko, Enum.NormalId.Right, "KO!!", Color3.fromRGB(255, 220, 60), Color3.fromRGB(96, 44, 150))

-- Trophy case (against the back/north wall)
part({ Size = Vector3.new(18, 10, 1.2), Position = Vector3.new(-5, 5, -56.9),
	Color = Color3.fromRGB(52, 44, 40), Material = Enum.Material.Wood })
for i, sy in { 3.8, 6.8 } do
	part({ Size = Vector3.new(17.2, 0.35, 1.4), Position = Vector3.new(-5, sy, -56.8),
		Color = Color3.fromRGB(84, 70, 60), Material = Enum.Material.Wood })
end
for _, tx in { -11, -5, 1 } do
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 1.4, 1.4),
		CFrame = CFrame.new(tx, 7.75, -56.7) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(230, 190, 70), Material = Enum.Material.Metal })
	part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.5, 1.5),
		Position = Vector3.new(tx, 8.9, -56.7),
		Color = Color3.fromRGB(240, 200, 80), Material = Enum.Material.Metal })
end

-- Jukebox (west interior wall)
part({ Size = Vector3.new(3, 6, 5), Position = Vector3.new(-22.2, 3, -36),
	Color = Color3.fromRGB(120, 34, 50), Material = Enum.Material.SmoothPlastic })
part({ Size = Vector3.new(3.1, 0.9, 5), Position = Vector3.new(-22.15, 6.45, -36),
	Color = Color3.fromRGB(120, 235, 255), Material = Enum.Material.Neon })
part({ Size = Vector3.new(0.25, 1.5, 3.6), Position = Vector3.new(-20.55, 4.6, -36),
	Color = Color3.fromRGB(255, 190, 90), Material = Enum.Material.Neon })
part({ Size = Vector3.new(0.2, 2.1, 3.9), Position = Vector3.new(-20.58, 1.9, -36),
	Color = Color3.fromRGB(40, 36, 42), Material = Enum.Material.Fabric })

-- Workbench (east interior wall)
part({ Size = Vector3.new(3.4, 0.6, 9), Position = Vector3.new(12.5, 3, -38),
	Color = Color3.fromRGB(120, 92, 60), Material = Enum.Material.WoodPlanks })
for _, lz in { -41.8, -34.2 } do
	part({ Size = Vector3.new(3, 2.7, 0.6), Position = Vector3.new(12.5, 1.35, lz),
		Color = METAL_DK, Material = Enum.Material.Metal })
end

-- Crate nook beside the hoops on the garage's west flank
part({ Size = Vector3.new(4, 4, 4), Position = Vector3.new(-34, 2, -48),
	Color = Color3.fromRGB(150, 105, 65), Material = Enum.Material.WoodPlanks })
part({ Size = Vector3.new(3, 3, 3), Position = Vector3.new(-33.4, 5.5, -47.4),
	Color = Color3.fromRGB(160, 112, 70), Material = Enum.Material.WoodPlanks })

-- ══ RADIO TOWER (outside the garage) ════════════════════════════════════════
local TWX, TWZ = -30, 18
for _, dx in { -4, 4 } do
	for _, dz in { -4, 4 } do
		part({ Size = Vector3.new(1.1, 30, 1.1), Position = Vector3.new(TWX + dx, 15, TWZ + dz),
			Color = METAL_DK, Material = Enum.Material.Metal })
	end
end
part({ Size = Vector3.new(10, 0.8, 10), Position = Vector3.new(TWX, 30.4, TWZ),
	Color = Color3.fromRGB(90, 86, 84), Material = Enum.Material.DiamondPlate })
for _, dx in { -2.2, 2.2 } do
	for _, dz in { -2.2, 2.2 } do
		part({ Size = Vector3.new(0.9, 24, 0.9), Position = Vector3.new(TWX + dx, 42.8, TWZ + dz),
			Color = METAL_DK, Material = Enum.Material.Metal })
	end
end
part({ Size = Vector3.new(6, 0.7, 6), Position = Vector3.new(TWX, 55.15, TWZ),
	Color = Color3.fromRGB(90, 86, 84), Material = Enum.Material.DiamondPlate })
part({ Size = Vector3.new(0.7, 18, 0.7), Position = Vector3.new(TWX, 64.5, TWZ),
	Color = METAL_DK, Material = Enum.Material.Metal })
part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), Position = Vector3.new(TWX, 74.2, TWZ),
	Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon })
-- cross braces
for _, by in { 10, 22 } do
	part({ Size = Vector3.new(9.5, 0.6, 0.6), Position = Vector3.new(TWX, by, TWZ - 4), Color = METAL_DK, Material = Enum.Material.Metal })
	part({ Size = Vector3.new(9.5, 0.6, 0.6), Position = Vector3.new(TWX, by, TWZ + 4), Color = METAL_DK, Material = Enum.Material.Metal })
	part({ Size = Vector3.new(0.6, 0.6, 9.5), Position = Vector3.new(TWX - 4, by, TWZ), Color = METAL_DK, Material = Enum.Material.Metal })
	part({ Size = Vector3.new(0.6, 0.6, 9.5), Position = Vector3.new(TWX + 4, by, TWZ), Color = METAL_DK, Material = Enum.Material.Metal })
end

-- ══ SPAWN DRUM (raised teal tank cap, KC vibe — garage-scale) ═══════════════
part({ Name = "SpawnDrum", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 24, 24),
	CFrame = CFrame.new(34, 5, 26) * CFrame.Angles(0, 0, math.rad(90)),
	Color = BRICK_DARK, Material = Enum.Material.Brick })
part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 24.8, 24.8),
	CFrame = CFrame.new(34, 10.3, 26) * CFrame.Angles(0, 0, math.rad(90)),
	Color = TEAL, Material = Enum.Material.Metal })
-- steps down the north side
for i = 1, 5 do
	local top = 10.3 - i * 1.72
	part({ Size = Vector3.new(8, top, 2.6), Position = Vector3.new(34, top / 2, 14.2 - i * 2.6),
		Color = Color3.fromRGB(160, 152, 138), Material = Enum.Material.Concrete })
end

-- ══ LAUNCH PADS (light beam + golden halo rings) ════════════════════════════
local function launchPad(x, z, baseY)
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 11, 11),
		CFrame = CFrame.new(x, baseY + 0.15, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(235, 232, 226), Material = Enum.Material.SmoothPlastic })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 7.5, 7.5),
		CFrame = CFrame.new(x, baseY + 0.42, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 50, 45), Material = Enum.Material.SmoothPlastic })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 3, 3),
		CFrame = CFrame.new(x, baseY + 0.62, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(235, 232, 226), Material = Enum.Material.SmoothPlastic })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(150, 2.6, 2.6),
		CFrame = CFrame.new(x, baseY + 75, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(140, 235, 255), Material = Enum.Material.Neon,
		Transparency = 0.72, CanCollide = false, CanQuery = false, CastShadow = false })
	for i, h in { 10, 18, 27 } do
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 9 - i, 9 - i),
			CFrame = CFrame.new(x, baseY + h, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 214, 90), Material = Enum.Material.Neon,
			Transparency = 0.45, CanCollide = false, CanQuery = false, CastShadow = false })
	end
end
launchPad(52, -52, 0)
launchPad(-32, 32, 0)

-- ══ BASKETBALL HOOPS ════════════════════════════════════════════════════════
local function hoop(x, z, baseY, faceDir)
	part({ Size = Vector3.new(0.8, 13, 0.8), Position = Vector3.new(x, baseY + 6.5, z),
		Color = METAL_DK, Material = Enum.Material.Metal })
	local bb = part({ Size = Vector3.new(0.5, 4.5, 6.5),
		CFrame = CFrame.new(x, baseY + 12, z) * CFrame.Angles(0, math.rad(faceDir), 0),
		Color = Color3.fromRGB(235, 232, 226), Material = Enum.Material.SmoothPlastic })
	local off = CFrame.new(x, baseY + 10.4, z) * CFrame.Angles(0, math.rad(faceDir), 0) * CFrame.new(2.2, 0, 0)
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.4, 3.4),
		CFrame = CFrame.new(off.Position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Metal })
end
hoop(-30, -52, 0, -90)    -- west of the garage, faces south
hoop(20, -56, 0, -90)     -- east of the garage, faces south
hoop(95, 5, -6, 90)       -- dummy roof south edge, faces north

-- ══ SPECIAL-BALL SPAWNER PODS (decorative, purple hover pods) ═══════════════
local function ballPod(x, z, baseY)
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 5, 5),
		CFrame = CFrame.new(x, baseY + 0.7, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(50, 46, 56), Material = Enum.Material.Metal })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4.3, 4.3),
		CFrame = CFrame.new(x, baseY + 2.1, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = PURPLE, Material = Enum.Material.Neon, Transparency = 0.35,
		CanCollide = false, CanQuery = false })
	local b = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4),
		Position = Vector3.new(x, baseY + 4.4, z),
		Color = Color3.fromRGB(150, 70, 230), Material = Enum.Material.SmoothPlastic,
		CanCollide = false, CanQuery = false })
	local pl = Instance.new("PointLight")
	pl.Color = PURPLE
	pl.Range = 10
	pl.Brightness = 0.8
	pl.Parent = b
end
for i = 0, 4 do -- five special-ball pods along the dummy roof's east wall
	ballPod(130, -44 + i * 8, -6)
end
ballPod(10, -52, 0)  -- basic ball pod in the garage (east corner)
ballPod(-24, -20, 0) -- basic/boomerang pod on the open deck

-- ══ TRAINING LAWN (north half of the dummy roof) ════════════════════════════
-- Open practice ground around the training bot — the queue rooms moved to
-- their own west QUEUE ROOF (below).
part({ Size = Vector3.new(44, 0.16, 30), Position = Vector3.new(105, -5.92, -65),
	Color = GRASS_DK, Material = Enum.Material.Grass })

-- ══ QUEUE ROOF (main-deck-sized WEST building: SIX queue rooms) ═════════════
-- Two facing banks of three garage-scale bays across a central plaza —
-- TWO rooms per mode (the TeamKO rooms sit diagonal from each other).
-- QueuePad names are the queue system's contract: it matches the
-- "QueuePadTeamKO" prefix, so both TeamKO_A and TeamKO_B count.
local QX, QZ, QTOP = -95, -10, 4
part({ Name = "QueueRoof", Size = Vector3.new(90, 3, 90), Position = Vector3.new(QX, QTOP - 1.5, QZ),
	Color = PAVE, Material = Enum.Material.Concrete })
part({ Name = "ShaftQueue", Size = Vector3.new(90, 400, 90), Position = Vector3.new(QX, QTOP - 203, QZ),
	Color = BRICK_A, Material = Enum.Material.Brick })
winStrips(QX, QZ, 90, 90, QTOP - 3, true, false)
-- parapets: full N/S/W, east side leaves a z -20..0 gap for the stairs
parapet(QX, QZ - 44, 90, 2, QTOP)
parapet(QX, QZ + 44, 90, 2, QTOP)
parapet(QX - 44, QZ, 2, 86, QTOP)
parapet(-51, -37, 2, 34, QTOP)
parapet(-51, 17, 2, 34, QTOP)
-- stair bridge from the main deck (y 0) up to the roof (y 4)
for i = 1, 3 do
	local top = i * 4 / 3
	part({ Size = Vector3.new(3.4, top, 20), Position = Vector3.new(-40 - i * 3.4 + 1.7, top / 2, -10),
		Color = Color3.fromRGB(160, 152, 138), Material = Enum.Material.Concrete })
end
-- one bank of three queue rooms; dir = +1 opens south (+Z), -1 opens north
local function queueBank(shellZ, dir, defs)
	local backZ = shellZ - dir * 10.4
	local frontZ = shellZ + dir * 11
	part({ Size = Vector3.new(66, 0.16, 22), Position = Vector3.new(QX, QTOP + 0.08, shellZ),
		Color = TAR, Material = Enum.Material.Asphalt })
	part({ Size = Vector3.new(66, 15, 1.2), Position = Vector3.new(QX, QTOP + 7.5, backZ),
		Color = BRICK_B, Material = Enum.Material.Brick })
	part({ Size = Vector3.new(1.2, 15, 22), Position = Vector3.new(QX - 33, QTOP + 7.5, shellZ),
		Color = BRICK_B, Material = Enum.Material.Brick })
	part({ Size = Vector3.new(1.2, 15, 22), Position = Vector3.new(QX + 33, QTOP + 7.5, shellZ),
		Color = BRICK_B, Material = Enum.Material.Brick })
	part({ Size = Vector3.new(68, 1, 24), Position = Vector3.new(QX, QTOP + 15.5, shellZ),
		Color = TAR, Material = Enum.Material.Concrete })
	part({ Size = Vector3.new(66, 3, 1), Position = Vector3.new(QX, QTOP + 13.5, frontZ + dir * 0.5),
		Color = BRICK_DARK, Material = Enum.Material.Brick })
	for _, dx in { -11, 11 } do
		part({ Size = Vector3.new(1, 15, 18), Position = Vector3.new(QX + dx, QTOP + 7.5, shellZ - dir * 2),
			Color = BRICK_B, Material = Enum.Material.Brick })
	end
	for _, def in defs do
		local cx = QX + def.dx
		part({ Name = def.name, Size = Vector3.new(12, 0.2, 12), Position = Vector3.new(cx, QTOP + 0.2, shellZ - dir * 3),
			Color = def.accent, Material = Enum.Material.Neon })
		local panel = part({ Name = def.name .. "Sign", Size = Vector3.new(14, 3, 0.6),
			Position = Vector3.new(cx, QTOP + 13.5, frontZ - dir * 0.4), Color = Color3.fromRGB(30, 28, 34),
			Material = Enum.Material.Metal })
		sign(panel, if dir == 1 then Enum.NormalId.Back else Enum.NormalId.Front, def.text, def.accent, Color3.fromRGB(30, 28, 34))
		local light = Instance.new("PointLight")
		light.Color = def.accent
		light.Range = 18
		light.Brightness = 1.2
		light.Parent = part({ Size = Vector3.new(4, 0.3, 4), Position = Vector3.new(cx, QTOP + 14.7, shellZ),
			Color = def.accent, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
	end
end
local Q_RED = Color3.fromRGB(255, 90, 70)
local Q_GRAY = Color3.fromRGB(200, 200, 205)
queueBank(-42, 1, { -- north bank, opens onto the plaza (south)
	{ dx = -22, name = "QueuePadTeamKO_A", text = "TEAM KO 3v3", accent = Q_RED },
	{ dx = 0, name = "QueuePadSoon1_A", text = "COMING SOON", accent = Q_GRAY },
	{ dx = 22, name = "QueuePadSoon2_A", text = "COMING SOON", accent = Q_GRAY },
})
queueBank(22, -1, { -- south bank, opens north — TeamKO diagonal from bank A
	{ dx = -22, name = "QueuePadSoon2_B", text = "COMING SOON", accent = Q_GRAY },
	{ dx = 0, name = "QueuePadSoon1_B", text = "COMING SOON", accent = Q_GRAY },
	{ dx = 22, name = "QueuePadTeamKO_B", text = "TEAM KO 3v3", accent = Q_RED },
})
-- plaza dressing between the banks
for _, dx in { -30, 30 } do
	part({ Size = Vector3.new(10, 3, 4), Position = Vector3.new(QX + dx, QTOP + 1.5, QZ),
		Color = BRICK_A, Material = Enum.Material.Brick })
	part({ Size = Vector3.new(9.4, 1.8, 3.4), Position = Vector3.new(QX + dx, QTOP + 3.9, QZ),
		Color = Color3.fromRGB(58, 118, 48), Material = Enum.Material.Grass })
end
-- QUEUE TOTEM: a huge lit sign towering over the west parapet so the queue
-- roof reads from anywhere on the deck (it used to vanish at some angles).
for _, tz in { QZ - 9, QZ + 9 } do
	part({ Size = Vector3.new(2, 36, 2), Position = Vector3.new(QX - 40, QTOP + 18, tz),
		Color = METAL_DK, Material = Enum.Material.Metal })
end
local totem = part({ Size = Vector3.new(1.2, 10, 34), Position = Vector3.new(QX - 40, QTOP + 38, QZ),
	Color = Color3.fromRGB(24, 22, 30), Material = Enum.Material.Metal })
sign(totem, Enum.NormalId.Right, "MATCH QUEUE", TEAL, Color3.fromRGB(24, 22, 30))
sign(totem, Enum.NormalId.Left, "MATCH QUEUE", TEAL, Color3.fromRGB(24, 22, 30))
part({ Size = Vector3.new(1.4, 0.8, 34.4), Position = Vector3.new(QX - 40, QTOP + 43.4, QZ),
	Color = MAGENTA, Material = Enum.Material.Neon, Transparency = 0.3 })
-- pointer signs flanking the stair gap on the main deck
for _, sz in { -24.5, 4.5 } do
	part({ Size = Vector3.new(0.8, 6, 0.8), Position = Vector3.new(-38.5, 3, sz),
		Color = METAL_DK, Material = Enum.Material.Metal })
	local ptr = part({ Size = Vector3.new(0.8, 3, 8), Position = Vector3.new(-38.5, 7.5, sz),
		Color = Color3.fromRGB(24, 22, 30), Material = Enum.Material.Metal })
	sign(ptr, Enum.NormalId.Right, "QUEUE", TEAL, Color3.fromRGB(24, 22, 30))
end

-- ══ MAIN DECK DRESSING ══════════════════════════════════════════════════════
local function patch(x, z, sx, sz, color, mat)
	part({ Size = Vector3.new(sx, 0.16, sz), Position = Vector3.new(x, 0.08, z), Color = color, Material = mat })
end
patch(-24, -16, 30, 20, GRASS, Enum.Material.Grass)
patch(30, -20, 22, 26, GRASS, Enum.Material.Grass)
patch(-10, 14, 16, 14, GRASS, Enum.Material.Grass)
patch(12, 0, 12, 46, TILE, Enum.Material.SmoothPlastic)
patch(28, 6, 26, 10, TILE, Enum.Material.SmoothPlastic)

local function chimney(x, z)
	part({ Size = Vector3.new(6, 11, 6), Position = Vector3.new(x, 5.5, z),
		Color = BRICK_DARK, Material = Enum.Material.Brick })
	part({ Size = Vector3.new(7.4, 1.2, 7.4), Position = Vector3.new(x, 11.6, z),
		Color = Color3.fromRGB(72, 64, 62), Material = Enum.Material.Concrete })
end
chimney(-30, -34)
chimney(54, 20)

local function waterTower(x, z, baseY, scale)
	local s = scale
	for _, dx in { -3.2 * s, 3.2 * s } do
		for _, dz in { -3.2 * s, 3.2 * s } do
			part({ Size = Vector3.new(1.2, 9 * s, 1.2), Position = Vector3.new(x + dx, baseY + 4.5 * s, z + dz),
				Color = Color3.fromRGB(80, 74, 72), Material = Enum.Material.Metal })
		end
	end
	part({ Size = Vector3.new(11 * s, 0.8, 11 * s), Position = Vector3.new(x, baseY + 9.4 * s, z),
		Color = Color3.fromRGB(90, 82, 80), Material = Enum.Material.Metal })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(9 * s, 10 * s, 10 * s),
		CFrame = CFrame.new(x, baseY + 14.3 * s, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(96, 142, 132), Material = Enum.Material.Metal })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 10.6 * s, 10.6 * s),
		CFrame = CFrame.new(x, baseY + 19.2 * s, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(112, 60, 48), Material = Enum.Material.Metal })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 2.6, 2.6),
		CFrame = CFrame.new(x, baseY + 20.9 * s, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(112, 60, 48), Material = Enum.Material.Metal })
end
waterTower(51, 31, 0, 1.25)

-- solar panels (tilted)
for i = 0, 2 do
	part({ Size = Vector3.new(12, 0.4, 8),
		CFrame = CFrame.new(2 + i * 13, 2, 33) * CFrame.Angles(math.rad(-22), 0, 0),
		Color = Color3.fromRGB(28, 34, 52), Material = Enum.Material.Glass })
end

-- plank pile
for i, ang in { 0.35, 1.15, 1.95 } do
	part({ Size = Vector3.new(10, 0.4, 2),
		CFrame = CFrame.new(14, 0.25 + (i - 1) * 0.42, -8) * CFrame.Angles(0, ang, 0),
		Color = Color3.fromRGB(202, 122, 62), Material = Enum.Material.WoodPlanks })
end

-- AC unit on the garage roof
part({ Size = Vector3.new(6, 3.4, 4.5), Position = Vector3.new(-12, 18.9, -50),
	Color = Color3.fromRGB(152, 150, 147), Material = Enum.Material.Metal })
part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 3, 3),
	CFrame = CFrame.new(-12, 20.9, -50) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(60, 58, 56), Material = Enum.Material.Metal })

-- chalkboard near the plank crossing
local board = part({ Size = Vector3.new(0.8, 7, 14), Position = Vector3.new(57, 4.2, 2),
	Color = Color3.fromRGB(35, 80, 55), Material = Enum.Material.SmoothPlastic })
sign(board, Enum.NormalId.Left, "KNOCK 'EM DOWN!", Color3.fromRGB(235, 235, 225), Color3.fromRGB(35, 80, 55))

-- string lights: garage roof corner -> radio tower platform
do
	local a = Vector3.new(-22, 17.4, -28)
	local b = Vector3.new(-30, 29, 14)
	local len = (b - a).Magnitude
	part({ Size = Vector3.new(0.15, 0.15, len),
		CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2),
		Color = Color3.fromRGB(255, 214, 130), Material = Enum.Material.Neon,
		Transparency = 0.25, CanCollide = false, CanQuery = false })
end

-- ══ STREET LAMPS (cool light pools so the decks read at night) ══════════════
local function streetLamp(x, z, baseY)
	part({ Size = Vector3.new(0.6, 12, 0.6), Position = Vector3.new(x, baseY + 6, z),
		Color = METAL_DK, Material = Enum.Material.Metal })
	local head = part({ Size = Vector3.new(2.6, 0.5, 1.2), Position = Vector3.new(x, baseY + 12.2, z),
		Color = Color3.fromRGB(200, 240, 255), Material = Enum.Material.Neon })
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(190, 225, 255)
	pl.Range = 36
	pl.Brightness = 2.0
	pl.Parent = head
end
streetLamp(30, -10, 0)
streetLamp(-15, 12, 0)
streetLamp(45, -35, 0)
streetLamp(0, 28, 0)
streetLamp(-70, -20, 4)   -- queue roof plaza
streetLamp(-115, -5, 4)
streetLamp(95, -15, -6)   -- training roof
streetLamp(120, -55, -6)

-- ══ BARRIER SKYLINE ═════════════════════════════════════════════════════════
local BARRIER_COLORS = {
	Color3.fromRGB(196, 130, 96), Color3.fromRGB(170, 108, 82), Color3.fromRGB(216, 168, 128),
	Color3.fromRGB(206, 190, 168), Color3.fromRGB(154, 96, 78),
}
local BARRIER_NEONS = { TEAL, MAGENTA, PURPLE }
local function barrier(name, cx, cz, w, d, top, ci)
	local color = BARRIER_COLORS[(ci - 1) % #BARRIER_COLORS + 1]
	part({ Name = name, Size = Vector3.new(w, top + 400, d),
		Position = Vector3.new(cx, (top - 400) / 2, cz), Color = color, Material = Enum.Material.Brick })
	-- glowing roofline ring: each skyline tower is outlined in its own neon
	local pc = BARRIER_NEONS[(ci - 1) % #BARRIER_NEONS + 1]
	part({ Size = Vector3.new(w, 3, 2), Position = Vector3.new(cx, top + 1.5, cz - d / 2 + 1), Color = pc, Material = Enum.Material.Neon, Transparency = 0.45 })
	part({ Size = Vector3.new(w, 3, 2), Position = Vector3.new(cx, top + 1.5, cz + d / 2 - 1), Color = pc, Material = Enum.Material.Neon, Transparency = 0.45 })
	part({ Size = Vector3.new(2, 3, d), Position = Vector3.new(cx - w / 2 + 1, top + 1.5, cz), Color = pc, Material = Enum.Material.Neon, Transparency = 0.45 })
	part({ Size = Vector3.new(2, 3, d), Position = Vector3.new(cx + w / 2 - 1, top + 1.5, cz), Color = pc, Material = Enum.Material.Neon, Transparency = 0.45 })
end
barrier("N1", -80, -150, 100, 80, 120, 1)
barrier("N2", 10, -160, 90, 90, 90, 2)
barrier("N3", 100, -150, 85, 75, 130, 3)
barrier("E1", 200, -60, 80, 100, 100, 4)
barrier("E2", 205, 20, 90, 80, 140, 5)
barrier("S1", -60, 105, 100, 70, 110, 1)
barrier("S2", 40, 115, 110, 80, 80, 2)
barrier("S3", 130, 100, 80, 90, 125, 3)
barrier("W1", -195, -40, 80, 90, 110, 4)
barrier("W2", -190, 30, 90, 70, 85, 5)

waterTower(10, -160, 90, 1.4)
waterTower(-190, 30, 85, 1.1)
local function antenna(x, z, baseY)
	part({ Size = Vector3.new(0.9, 32, 0.9), Position = Vector3.new(x, baseY + 16, z),
		Color = METAL_DK, Material = Enum.Material.Metal })
	part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8),
		Position = Vector3.new(x, baseY + 32.5, z),
		Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon })
end
antenna(205, 20, 140)
antenna(-80, -150, 120)

-- billboards facing the arena
local bb1 = part({ Size = Vector3.new(30, 14, 1), Position = Vector3.new(10, 55, -114.4),
	Color = Color3.fromRGB(40, 38, 44), Material = Enum.Material.Metal })
sign(bb1, Enum.NormalId.Back, "ORBIT SODA", Color3.fromRGB(120, 235, 255), Color3.fromRGB(28, 40, 78))
local bb2 = part({ Size = Vector3.new(30, 14, 1), Position = Vector3.new(40, 50, 74.4),
	Color = Color3.fromRGB(40, 38, 44), Material = Enum.Material.Metal })
sign(bb2, Enum.NormalId.Front, "BALLOUT", Color3.fromRGB(255, 220, 60), Color3.fromRGB(96, 44, 150))
local bb3 = part({ Size = Vector3.new(1, 12, 26), Position = Vector3.new(159.4, 62, -60),
	Color = Color3.fromRGB(40, 38, 44), Material = Enum.Material.Metal })
sign(bb3, Enum.NormalId.Left, "WHIRL FM", Color3.fromRGB(255, 150, 220), Color3.fromRGB(50, 24, 66))

-- glowing "portal ring" decoration (KC City-of-Tomorrow vibe)
part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 16, 16),
	CFrame = CFrame.new(100, 60, -111.9) * CFrame.Angles(0, math.rad(90), 0),
	Color = Color3.fromRGB(30, 30, 38), Material = Enum.Material.Metal })
part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 13.5, 13.5),
	CFrame = CFrame.new(100, 60, -111.5) * CFrame.Angles(0, math.rad(90), 0),
	Color = Color3.fromRGB(80, 160, 255), Material = Enum.Material.Neon, Transparency = 0.2 })
part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 10, 10),
	CFrame = CFrame.new(100, 60, -111.2) * CFrame.Angles(0, math.rad(90), 0),
	Color = Color3.fromRGB(24, 26, 34), Material = Enum.Material.SmoothPlastic })

-- ══ INVISIBLE GLIDE WALLS ═══════════════════════════════════════════════════
local function wall(x, z, sx, sz)
	part({ Name = "Barrier", Size = Vector3.new(sx, 270, sz), Position = Vector3.new(x, 125, z),
		Transparency = 1, CanQuery = false, CastShadow = false })
end
wall(10, -205, 500, 4)
wall(10, 160, 500, 4)
wall(255, -22.5, 4, 369)
wall(-240, -22.5, 4, 369)

-- ══ CLOUD VOID ══════════════════════════════════════════════════════════════
part({ Name = "CloudHi", Size = Vector3.new(1500, 24, 1500), Position = Vector3.new(35, -225, -22),
	Color = Color3.fromRGB(140, 118, 170), Material = Enum.Material.SmoothPlastic,
	Transparency = 0.3, CanCollide = false, CanQuery = false, CastShadow = false })
part({ Name = "CloudLo", Size = Vector3.new(1600, 30, 1600), Position = Vector3.new(35, -262, -22),
	Color = Color3.fromRGB(108, 92, 140), Material = Enum.Material.SmoothPlastic,
	Transparency = 0.05, CanCollide = false, CanQuery = false, CastShadow = false })
local puffs = {
	{ 40, -215, -90, 46 }, { 120, -210, 10, 38 }, { -70, -218, 40, 52 }, { -140, -208, -60, 40 },
	{ 170, -220, -110, 44 }, { 0, -212, 110, 48 }, { -180, -216, 80, 42 }, { 90, -207, 150, 36 },
	{ -110, -210, -170, 50 }, { 200, -214, 90, 40 },
}
for _, q in puffs do
	part({ Shape = Enum.PartType.Ball, Size = Vector3.new(q[4], q[4] * 0.45, q[4]),
		Position = Vector3.new(q[1], q[2], q[3]),
		Color = Color3.fromRGB(150, 128, 180), Material = Enum.Material.SmoothPlastic,
		Transparency = 0.15, CanCollide = false, CanQuery = false, CastShadow = false })
end

map.Parent = Workspace

-- ══ WORLD SETTINGS ══════════════════════════════════════════════════════════
-- (Spawning is the GarageSpawn pad, created in the GARAGE section. The old
-- loose-SpawnLocation bootstrap that used to live here silently re-created a
-- competing invisible spawn on the drum every rebuild — gone for good.)

local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate then baseplate:Destroy() end
Workspace.FallenPartsDestroyHeight = -330

local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
if atmo then atmo:Destroy() end
-- CYBERPUNK night: deep dusk, purple haze, bloom so every neon edge blooms.
-- Bright retro-future afternoon: sunny with a golden lean, pastel haze far
-- out. The world reads warm and saturated; neon signs still pop at dusk-less
-- brightness because they're Neon material, not the light source.
Lighting.ClockTime = 15.8
Lighting.Brightness = 2.9
Lighting.Ambient = Color3.fromRGB(150, 142, 132)
Lighting.OutdoorAmbient = Color3.fromRGB(172, 162, 148)
Lighting.ColorShift_Top = Color3.fromRGB(255, 208, 150)
Lighting.FogColor = Color3.fromRGB(222, 204, 196)
Lighting.FogStart = 180
Lighting.FogEnd = 750
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if not bloom then
	bloom = Instance.new("BloomEffect")
	bloom.Parent = Lighting
end
bloom.Intensity = 0.55
bloom.Size = 40
bloom.Threshold = 1.1
local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
if not cc then
	cc = Instance.new("ColorCorrectionEffect")
	cc.Parent = Lighting
end
cc.Saturation = 0.12
cc.Contrast = 0.06
cc.TintColor = Color3.fromRGB(235, 240, 255)

local terrain = Workspace:FindFirstChildOfClass("Terrain")
if terrain and not terrain:FindFirstChildOfClass("Clouds") then
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.65
	clouds.Density = 0.3
	clouds.Parent = terrain
end

return "Ballout HQ built: " .. #map:GetChildren() .. " parts"
