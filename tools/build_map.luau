-- Ballout | HQ map generator (v2 — Knockout City Hideout remake)
-- Run in EDIT mode (execute_luau). Rebuilds Workspace.BalloutMap from scratch.
--
-- Layout (researched from the KC Hideout wiki + in-game screenshots):
--   MAIN DECK (top Y=0, x -40..60, z -60..40): the wide open practice space.
--     - GARAGE (west): interior with trophy case + jukebox, walkable roof,
--       hidden nook behind it with a basketball hoop + crates
--     - RADIO TOWER outside the garage (two-tier lattice + red beacon)
--     - SPAWN DRUM (south-east): raised teal round tank cap you spawn on,
--       steps down to the deck (KC spawn vibe)
--     - Launch pads with light beams + golden halo rings (matchmaking pads)
--     - Basketball hoops, solar panels, chimneys, water tower, plank pile
--   DUMMY ROOF (top Y=-6, x 75..135, z -80..10): smaller SEPARATE LOWER roof
--     - lawn + hedges, training dummy pad, 5 special-ball spawner pods
--     - SOCCER COURT behind it (north half): 2 goals + giant pushable ball
--     - wooden planks bridge the gap from the main deck
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
	p.Parent = map
	return p
end

local BRICK_A = Color3.fromRGB(152, 88, 66)
local BRICK_B = Color3.fromRGB(128, 72, 56)
local BRICK_DARK = Color3.fromRGB(118, 64, 50)
local TEAL = Color3.fromRGB(70, 150, 140)
local TAR = Color3.fromRGB(58, 55, 61)
local PAVE = Color3.fromRGB(196, 188, 172)
local TILE = Color3.fromRGB(219, 211, 197)
local GRASS = Color3.fromRGB(112, 175, 66)
local GRASS_DK = Color3.fromRGB(88, 148, 52)
local METAL_DK = Color3.fromRGB(70, 68, 66)
local PURPLE = Color3.fromRGB(170, 80, 255)

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
-- lawn (south half) + court base (north half)
part({ Size = Vector3.new(56, 0.16, 52), Position = Vector3.new(105, -5.92, -23),
	Color = GRASS, Material = Enum.Material.Grass })
part({ Size = Vector3.new(44, 0.16, 30), Position = Vector3.new(105, -5.92, -65),
	Color = GRASS_DK, Material = Enum.Material.Grass })

-- Dummy pad (Main.server.luau spawns the training dummy here)
part({ Name = "DummyPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7, 7),
	CFrame = CFrame.new(105, -5.8, -30) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(150, 120, 88), Material = Enum.Material.Ground })

-- Hedges around the lawn (KC's dummy roof has hedge rows)
local function hedge(x, z, sx, sz, y)
	part({ Size = Vector3.new(sx, 2.4, sz), Position = Vector3.new(x, y + 1.2, z),
		Color = Color3.fromRGB(58, 118, 48), Material = Enum.Material.Grass })
end
hedge(88, 4, 20, 2.2, -6)
hedge(124, 4, 16, 2.2, -6)
hedge(88, -44, 18, 2.2, -6)

-- ══ WINDOW STRIPS down the outward faces ════════════════════════════════════
local GLASSC = Color3.fromRGB(38, 44, 58)
local function winStrips(cx, cz, w, d, topY, skipEast, skipWest)
	local cy = topY - 170
	for _, off in { -w * 0.3, 0, w * 0.3 } do
		part({ Size = Vector3.new(3, 320, 0.5), Position = Vector3.new(cx + off, cy, cz - d / 2 - 0.3),
			Color = GLASSC, Material = Enum.Material.Glass })
		part({ Size = Vector3.new(3, 320, 0.5), Position = Vector3.new(cx + off, cy, cz + d / 2 + 0.3),
			Color = GLASSC, Material = Enum.Material.Glass })
	end
	for _, off in { -d * 0.3, 0, d * 0.3 } do
		if not skipEast then
			part({ Size = Vector3.new(0.5, 320, 3), Position = Vector3.new(cx + w / 2 + 0.3, cy, cz + off),
				Color = GLASSC, Material = Enum.Material.Glass })
		end
		if not skipWest then
			part({ Size = Vector3.new(0.5, 320, 3), Position = Vector3.new(cx - w / 2 - 0.3, cy, cz + off),
				Color = GLASSC, Material = Enum.Material.Glass })
		end
	end
end
winStrips(10, -10, 100, 100, -3, true, false)
winStrips(105, -35, 60, 90, -9, false, true)

-- ══ PARAPETS ════════════════════════════════════════════════════════════════
local function parapet(x, z, sx, sz, baseY)
	part({ Size = Vector3.new(sx, 3.2, sz), Position = Vector3.new(x, baseY + 1.6, z),
		Color = BRICK_DARK, Material = Enum.Material.Brick })
	part({ Size = Vector3.new(sx + 0.6, 0.5, sz + 0.6), Position = Vector3.new(x, baseY + 3.45, z),
		Color = TEAL, Material = Enum.Material.Metal })
end
-- Main deck (x -40..60, z -60..40); east opening z -26..-12 for the planks
parapet(10, -59, 100, 2, 0)
parapet(10, 39, 100, 2, 0)
parapet(-39, -10, 2, 96, 0)
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

-- ══ GARAGE (west side of main deck) ═════════════════════════════════════════
-- Footprint x -40..-14, z -34..-10, open front facing EAST into the deck.
part({ Size = Vector3.new(1.5, 10, 24), Position = Vector3.new(-39.25, 5, -22),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- back (west) wall
part({ Size = Vector3.new(26, 10, 1.5), Position = Vector3.new(-27, 5, -33.25),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- north wall
part({ Size = Vector3.new(26, 10, 1.5), Position = Vector3.new(-27, 5, -10.75),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- south wall
part({ Size = Vector3.new(1.5, 8, 5), Position = Vector3.new(-14.75, 4, -31.5),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- front side piece
part({ Size = Vector3.new(1.5, 8, 5), Position = Vector3.new(-14.75, 4, -12.5),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- front side piece
part({ Size = Vector3.new(1.5, 2, 24), Position = Vector3.new(-14.75, 9, -22),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- lintel over the door
local groof = part({ Name = "GarageRoof", Size = Vector3.new(28, 1.2, 26), Position = Vector3.new(-27, 10.6, -22),
	Color = TAR, Material = Enum.Material.Slate })
-- rolled-up door slats hint
for i = 0, 2 do
	part({ Size = Vector3.new(0.4, 0.5, 14), Position = Vector3.new(-15.6, 7.3 + i * 0.55, -22),
		Color = Color3.fromRGB(140, 140, 138), Material = Enum.Material.Metal })
end
-- interior glow
local glight = Instance.new("PointLight")
glight.Color = Color3.fromRGB(255, 214, 160)
glight.Range = 24
glight.Brightness = 1.4
glight.Parent = groof

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

-- GARAGE marquee + KO graffiti on the south wall
local marquee = part({ Size = Vector3.new(12, 3, 0.6), Position = Vector3.new(-14.2, 11.9, -22),
	Color = Color3.fromRGB(30, 28, 34), Material = Enum.Material.Metal })
sign(marquee, Enum.NormalId.Right, "GARAGE", Color3.fromRGB(120, 235, 255), Color3.fromRGB(30, 28, 34))
local ko = part({ Size = Vector3.new(10, 7, 0.3), Position = Vector3.new(-27, 5, -9.85),
	Color = BRICK_B, Material = Enum.Material.Brick })
sign(ko, Enum.NormalId.Back, "KO!!", Color3.fromRGB(255, 220, 60), Color3.fromRGB(96, 44, 150))

-- Trophy case (against the back wall)
part({ Size = Vector3.new(1.2, 6.5, 12), Position = Vector3.new(-37.9, 3.25, -22),
	Color = Color3.fromRGB(52, 44, 40), Material = Enum.Material.Wood })
for i, sy in { 2.4, 4.4 } do
	part({ Size = Vector3.new(1.4, 0.3, 11.4), Position = Vector3.new(-37.8, sy, -22),
		Color = Color3.fromRGB(84, 70, 60), Material = Enum.Material.Wood })
end
for _, tz in { -26, -22, -18 } do
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 1, 1),
		CFrame = CFrame.new(-37.7, 5.05, tz) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(230, 190, 70), Material = Enum.Material.Metal })
	part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1),
		Position = Vector3.new(-37.7, 5.9, tz),
		Color = Color3.fromRGB(240, 200, 80), Material = Enum.Material.Metal })
end

-- Jukebox (north wall)
part({ Size = Vector3.new(3.4, 4, 2), Position = Vector3.new(-24, 2, -31.8),
	Color = Color3.fromRGB(120, 34, 50), Material = Enum.Material.SmoothPlastic })
part({ Size = Vector3.new(3.4, 0.6, 2.1), Position = Vector3.new(-24, 4.3, -31.75),
	Color = Color3.fromRGB(120, 235, 255), Material = Enum.Material.Neon })
part({ Size = Vector3.new(2.4, 1, 0.2), Position = Vector3.new(-24, 3.1, -30.7),
	Color = Color3.fromRGB(255, 190, 90), Material = Enum.Material.Neon })
part({ Size = Vector3.new(2.6, 1.4, 0.15), Position = Vector3.new(-24, 1.3, -30.72),
	Color = Color3.fromRGB(40, 36, 42), Material = Enum.Material.Fabric })

-- Workbench (south interior wall)
part({ Size = Vector3.new(6, 0.5, 2.4), Position = Vector3.new(-30, 2.4, -12.6),
	Color = Color3.fromRGB(120, 92, 60), Material = Enum.Material.WoodPlanks })
for _, lx in { -32.6, -27.4 } do
	part({ Size = Vector3.new(0.5, 2.2, 2.2), Position = Vector3.new(lx, 1.1, -12.6),
		Color = METAL_DK, Material = Enum.Material.Metal })
end

-- Hidden nook behind the garage (north alley between garage and parapet)
part({ Size = Vector3.new(4, 4, 4), Position = Vector3.new(-34, 2, -40),
	Color = Color3.fromRGB(150, 105, 65), Material = Enum.Material.WoodPlanks })
part({ Size = Vector3.new(3, 3, 3), Position = Vector3.new(-33.4, 5.5, -39.4),
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

-- ══ SPAWN DRUM (raised teal tank cap, KC spawn) ═════════════════════════════
part({ Name = "SpawnDrum", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 18, 18),
	CFrame = CFrame.new(34, 3.5, 30) * CFrame.Angles(0, 0, math.rad(90)),
	Color = BRICK_DARK, Material = Enum.Material.Brick })
part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 18.6, 18.6),
	CFrame = CFrame.new(34, 7.3, 30) * CFrame.Angles(0, 0, math.rad(90)),
	Color = TEAL, Material = Enum.Material.Metal })
-- steps down the north side
for i = 1, 4 do
	local top = 7.6 - i * 1.5
	part({ Size = Vector3.new(6, top, 2.2), Position = Vector3.new(34, top / 2, 20.8 - i * 2.2),
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
	part({ Size = Vector3.new(0.6, 10, 0.6), Position = Vector3.new(x, baseY + 5, z),
		Color = METAL_DK, Material = Enum.Material.Metal })
	local bb = part({ Size = Vector3.new(0.4, 3.2, 4.6),
		CFrame = CFrame.new(x, baseY + 9.2, z) * CFrame.Angles(0, math.rad(faceDir), 0),
		Color = Color3.fromRGB(235, 232, 226), Material = Enum.Material.SmoothPlastic })
	local off = CFrame.new(x, baseY + 8, z) * CFrame.Angles(0, math.rad(faceDir), 0) * CFrame.new(1.6, 0, 0)
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 2.6, 2.6),
		CFrame = CFrame.new(off.Position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Metal })
end
hoop(-27, -52, 0, -90)    -- hidden nook behind the garage, faces south
hoop(20, -56, 0, -90)     -- main deck north edge, faces south
hoop(95, 5, -6, 90)       -- dummy roof south edge, faces north

-- ══ SPECIAL-BALL SPAWNER PODS (decorative, purple hover pods) ═══════════════
local function ballPod(x, z, baseY)
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, 3.4, 3.4),
		CFrame = CFrame.new(x, baseY + 0.55, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(50, 46, 56), Material = Enum.Material.Metal })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 2.9, 2.9),
		CFrame = CFrame.new(x, baseY + 1.6, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = PURPLE, Material = Enum.Material.Neon, Transparency = 0.35,
		CanCollide = false, CanQuery = false })
	local b = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8),
		Position = Vector3.new(x, baseY + 3.3, z),
		Color = Color3.fromRGB(150, 70, 230), Material = Enum.Material.SmoothPlastic,
		CanCollide = false, CanQuery = false })
	local pl = Instance.new("PointLight")
	pl.Color = PURPLE
	pl.Range = 7
	pl.Brightness = 0.8
	pl.Parent = b
end
for i = 0, 4 do -- five special-ball pods along the dummy roof's east wall
	ballPod(130, -44 + i * 8, -6)
end
ballPod(-33, -28, 0) -- basic ball pod in the garage
ballPod(10, -54, 0)  -- basic/boomerang pod at the far end of the open area

-- ══ SOCCER COURT (north half of the dummy roof) ═════════════════════════════
-- markings
part({ Size = Vector3.new(40, 0.08, 0.5), Position = Vector3.new(105, -5.8, -51), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic })
part({ Size = Vector3.new(40, 0.08, 0.5), Position = Vector3.new(105, -5.8, -78), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic })
part({ Size = Vector3.new(0.5, 0.08, 27), Position = Vector3.new(105, -5.8, -64.5), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic })
part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 7, 7),
	CFrame = CFrame.new(105, -5.79, -64.5) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic })
part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.09, 6, 6),
	CFrame = CFrame.new(105, -5.78, -64.5) * CFrame.Angles(0, 0, math.rad(90)),
	Color = GRASS_DK, Material = Enum.Material.Grass })
-- goals (facing each other along X)
local function goal(x, faceSign)
	for _, gz in { -60.5, -68.5 } do
		part({ Size = Vector3.new(0.5, 3.4, 0.5), Position = Vector3.new(x, -4.3, gz),
			Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic })
	end
	part({ Size = Vector3.new(0.5, 0.5, 8.5), Position = Vector3.new(x, -2.35, -64.5),
		Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic })
	part({ Size = Vector3.new(0.3, 3.2, 8), Position = Vector3.new(x - faceSign * 1.2, -4.4, -64.5),
		Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic,
		Transparency = 0.65, CanCollide = false })
end
goal(86, 1)
goal(124, -1)
-- south fence with an entrance gap (outer edges use the roof parapet)
part({ Size = Vector3.new(16, 2.4, 0.8), Position = Vector3.new(93, -4.8, -50),
	Color = METAL_DK, Material = Enum.Material.DiamondPlate })
part({ Size = Vector3.new(16, 2.4, 0.8), Position = Vector3.new(117, -4.8, -50),
	Color = METAL_DK, Material = Enum.Material.DiamondPlate })
-- the giant pushable soccer ball (pure physics)
local soccer = Instance.new("Part")
soccer.Name = "SoccerBall"
soccer.Shape = Enum.PartType.Ball
soccer.Size = Vector3.new(5.5, 5.5, 5.5)
soccer.Position = Vector3.new(105, -2.5, -65)
soccer.Color = Color3.fromRGB(240, 240, 235)
soccer.Material = Enum.Material.SmoothPlastic
soccer.CustomPhysicalProperties = PhysicalProperties.new(0.22, 0.35, 0.55, 1, 1)
soccer.Parent = map

-- ══ MAIN DECK DRESSING ══════════════════════════════════════════════════════
local function patch(x, z, sx, sz, color, mat)
	part({ Size = Vector3.new(sx, 0.16, sz), Position = Vector3.new(x, 0.08, z), Color = color, Material = mat })
end
patch(-2, -30, 30, 20, GRASS, Enum.Material.Grass)
patch(30, -20, 22, 26, GRASS, Enum.Material.Grass)
patch(-10, 14, 16, 14, GRASS, Enum.Material.Grass)
patch(12, 0, 12, 46, TILE, Enum.Material.SmoothPlastic)
patch(28, 6, 26, 10, TILE, Enum.Material.SmoothPlastic)

local function chimney(x, z)
	part({ Size = Vector3.new(4, 7, 4), Position = Vector3.new(x, 3.5, z),
		Color = BRICK_DARK, Material = Enum.Material.Brick })
	part({ Size = Vector3.new(5, 0.9, 5), Position = Vector3.new(x, 7.45, z),
		Color = Color3.fromRGB(72, 64, 62), Material = Enum.Material.Concrete })
end
chimney(0, -56)
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
waterTower(52, 32, 0, 0.85)

-- solar panels (tilted)
for i = 0, 2 do
	part({ Size = Vector3.new(9, 0.3, 6),
		CFrame = CFrame.new(2 + i * 10, 1.5, 33) * CFrame.Angles(math.rad(-22), 0, 0),
		Color = Color3.fromRGB(28, 34, 52), Material = Enum.Material.Glass })
end

-- plank pile
for i, ang in { 0.35, 1.15, 1.95 } do
	part({ Size = Vector3.new(7, 0.3, 1.4),
		CFrame = CFrame.new(14, 0.2 + (i - 1) * 0.32, -8) * CFrame.Angles(0, ang, 0),
		Color = Color3.fromRGB(202, 122, 62), Material = Enum.Material.WoodPlanks })
end

-- AC unit on the garage roof
part({ Size = Vector3.new(6, 3.4, 4.5), Position = Vector3.new(-30, 12.9, -28),
	Color = Color3.fromRGB(152, 150, 147), Material = Enum.Material.Metal })
part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 3, 3),
	CFrame = CFrame.new(-30, 14.9, -28) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(60, 58, 56), Material = Enum.Material.Metal })

-- chalkboard near the plank crossing
local board = part({ Size = Vector3.new(0.8, 5, 10), Position = Vector3.new(57, 3.2, 2),
	Color = Color3.fromRGB(35, 80, 55), Material = Enum.Material.SmoothPlastic })
sign(board, Enum.NormalId.Left, "KNOCK 'EM DOWN!", Color3.fromRGB(235, 235, 225), Color3.fromRGB(35, 80, 55))

-- string lights: garage roof corner -> radio tower platform
do
	local a = Vector3.new(-20, 11.5, -11)
	local b = Vector3.new(-30, 29, 14)
	local len = (b - a).Magnitude
	part({ Size = Vector3.new(0.15, 0.15, len),
		CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2),
		Color = Color3.fromRGB(255, 214, 130), Material = Enum.Material.Neon,
		Transparency = 0.25, CanCollide = false, CanQuery = false })
end

-- ══ BARRIER SKYLINE ═════════════════════════════════════════════════════════
local BARRIER_COLORS = {
	Color3.fromRGB(150, 88, 66), Color3.fromRGB(128, 72, 56), Color3.fromRGB(168, 120, 96),
	Color3.fromRGB(165, 155, 142), Color3.fromRGB(122, 82, 70),
}
local function barrier(name, cx, cz, w, d, top, ci)
	local color = BARRIER_COLORS[(ci - 1) % #BARRIER_COLORS + 1]
	part({ Name = name, Size = Vector3.new(w, top + 400, d),
		Position = Vector3.new(cx, (top - 400) / 2, cz), Color = color, Material = Enum.Material.Brick })
	local pc = Color3.new(color.R * 0.8, color.G * 0.8, color.B * 0.8)
	part({ Size = Vector3.new(w, 3, 2), Position = Vector3.new(cx, top + 1.5, cz - d / 2 + 1), Color = pc, Material = Enum.Material.Brick })
	part({ Size = Vector3.new(w, 3, 2), Position = Vector3.new(cx, top + 1.5, cz + d / 2 - 1), Color = pc, Material = Enum.Material.Brick })
	part({ Size = Vector3.new(2, 3, d), Position = Vector3.new(cx - w / 2 + 1, top + 1.5, cz), Color = pc, Material = Enum.Material.Brick })
	part({ Size = Vector3.new(2, 3, d), Position = Vector3.new(cx + w / 2 - 1, top + 1.5, cz), Color = pc, Material = Enum.Material.Brick })
end
barrier("N1", -80, -150, 100, 80, 120, 1)
barrier("N2", 10, -160, 90, 90, 90, 2)
barrier("N3", 100, -150, 85, 75, 130, 3)
barrier("E1", 200, -60, 80, 100, 100, 4)
barrier("E2", 205, 20, 90, 80, 140, 5)
barrier("S1", -60, 105, 100, 70, 110, 1)
barrier("S2", 40, 115, 110, 80, 80, 2)
barrier("S3", 130, 100, 80, 90, 125, 3)
barrier("W1", -140, -40, 80, 90, 110, 4)
barrier("W2", -135, 30, 90, 70, 85, 5)

waterTower(10, -160, 90, 1.4)
waterTower(-135, 30, 85, 1.1)
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
wall(35, -205, 444, 4)
wall(35, 160, 444, 4)
wall(255, -22.5, 4, 369)
wall(-185, -22.5, 4, 369)

-- ══ CLOUD VOID ══════════════════════════════════════════════════════════════
part({ Name = "CloudHi", Size = Vector3.new(1500, 24, 1500), Position = Vector3.new(35, -225, -22),
	Color = Color3.fromRGB(216, 208, 220), Material = Enum.Material.SmoothPlastic,
	Transparency = 0.3, CanCollide = false, CanQuery = false, CastShadow = false })
part({ Name = "CloudLo", Size = Vector3.new(1600, 30, 1600), Position = Vector3.new(35, -262, -22),
	Color = Color3.fromRGB(198, 190, 205), Material = Enum.Material.SmoothPlastic,
	Transparency = 0.05, CanCollide = false, CanQuery = false, CastShadow = false })
local puffs = {
	{ 40, -215, -90, 46 }, { 120, -210, 10, 38 }, { -70, -218, 40, 52 }, { -140, -208, -60, 40 },
	{ 170, -220, -110, 44 }, { 0, -212, 110, 48 }, { -180, -216, 80, 42 }, { 90, -207, 150, 36 },
	{ -110, -210, -170, 50 }, { 200, -214, 90, 40 },
}
for _, q in puffs do
	part({ Shape = Enum.PartType.Ball, Size = Vector3.new(q[4], q[4] * 0.45, q[4]),
		Position = Vector3.new(q[1], q[2], q[3]),
		Color = Color3.fromRGB(232, 226, 235), Material = Enum.Material.SmoothPlastic,
		Transparency = 0.15, CanCollide = false, CanQuery = false, CastShadow = false })
end

map.Parent = Workspace

-- ══ SPAWN + WORLD SETTINGS ══════════════════════════════════════════════════
local spawnLoc = Workspace:FindFirstChildOfClass("SpawnLocation")
if not spawnLoc then
	spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Parent = Workspace
end
spawnLoc.Anchored = true
spawnLoc.Size = Vector3.new(12, 0.4, 12)
spawnLoc.CFrame = CFrame.lookAt(Vector3.new(34, 7.85, 30), Vector3.new(0, 7.85, -20))
spawnLoc.Transparency = 1
spawnLoc.CanCollide = false
spawnLoc.Duration = 0
for _, d in spawnLoc:GetChildren() do
	if d:IsA("Decal") then d:Destroy() end
end

local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate then baseplate:Destroy() end
Workspace.FallenPartsDestroyHeight = -330

local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
if atmo then atmo:Destroy() end
Lighting.ClockTime = 17.45
Lighting.Brightness = 2.5
Lighting.Ambient = Color3.fromRGB(95, 82, 105)
Lighting.OutdoorAmbient = Color3.fromRGB(135, 112, 138)
Lighting.ColorShift_Top = Color3.fromRGB(255, 185, 120)
Lighting.FogColor = Color3.fromRGB(200, 178, 200)
Lighting.FogStart = 200
Lighting.FogEnd = 800

local terrain = Workspace:FindFirstChildOfClass("Terrain")
if terrain and not terrain:FindFirstChildOfClass("Clouds") then
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.65
	clouds.Density = 0.3
	clouds.Parent = terrain
end

return "Ballout HQ built: " .. #map:GetChildren() .. " parts"
