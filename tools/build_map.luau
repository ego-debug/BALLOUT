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
-- facade variety: a real city block isn't one material
local PLASTER = Color3.fromRGB(236, 224, 200)  -- cream stucco buildings
local CORAL = Color3.fromRGB(222, 118, 92)     -- painted concrete buildings
local MUSTARD = Color3.fromRGB(228, 176, 84)   -- awning/trim pop color

-- ══ MAIN DECK ═══════════════════════════════════════════════════════════════
part({ Name = "MainDeck", Size = Vector3.new(100, 3, 100), Position = Vector3.new(10, -1.5, -10),
	Color = PAVE, Material = Enum.Material.Concrete })
part({ Name = "ShaftMain", Size = Vector3.new(100, 400, 100), Position = Vector3.new(10, -203, -10),
	Color = BRICK_A, Material = Enum.Material.Brick })

-- ══ DUMMY ROOF (lower training roof) ════════════════════════════════════════
part({ Name = "DummyRoof", Size = Vector3.new(60, 3, 90), Position = Vector3.new(105, -7.5, -35),
	Color = Color3.fromRGB(178, 168, 150), Material = Enum.Material.Concrete })
-- each tower is its own building: brick main, plaster training, coral queue
part({ Name = "ShaftDummy", Size = Vector3.new(60, 400, 90), Position = Vector3.new(105, -209, -35),
	Color = PLASTER, Material = Enum.Material.Limestone })
-- lawn (south half; the north half is the queue-rooms floor, built below)
part({ Size = Vector3.new(56, 0.16, 52), Position = Vector3.new(105, -5.92, -23),
	Color = GRASS, Material = Enum.Material.Grass })

-- Bot pad (Main.server.luau spawns the training bot here): south end of the
-- training roof, facing due north — placed exactly where the owner stood
part({ Name = "DummyPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 7, 7),
	CFrame = CFrame.new(105.5, -5.8, -69.7) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(150, 120, 88), Material = Enum.Material.Ground })

-- ══ WINDOW STRIPS down the outward faces ════════════════════════════════════
local GLASSC = Color3.fromRGB(24, 30, 46)
-- Cyberpunk skyscraper look: the middle strip of every face GLOWS (cyan on
-- x-faces, magenta on z-faces); the outer strips stay dark glass.
local function winStrips(cx, cz, w, d, topY, skipEast, skipWest)
	local cy = topY - 170
	for si, off in { -w * 0.3, 0, w * 0.3 } do
		local neon = si == 2
		local color = if neon then TEAL else GLASSC
		local mat = if neon then Enum.Material.SmoothPlastic else Enum.Material.Glass
		local tr = if neon then 0.35 else 0
		part({ Size = Vector3.new(3, 320, 0.5), Position = Vector3.new(cx + off, cy, cz - d / 2 - 0.3),
			Color = color, Material = mat, Transparency = tr })
		part({ Size = Vector3.new(3, 320, 0.5), Position = Vector3.new(cx + off, cy, cz + d / 2 + 0.3),
			Color = color, Material = mat, Transparency = tr })
	end
	for si, off in { -d * 0.3, 0, d * 0.3 } do
		local neon = si == 2
		local color = if neon then MAGENTA else GLASSC
		local mat = if neon then Enum.Material.SmoothPlastic else Enum.Material.Glass
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
		Color = TEAL, Material = Enum.Material.SmoothPlastic, Transparency = 0.25 })
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
-- plaster body with brick front trim: the hero building reads distinct
part({ Size = Vector3.new(37, 16, 1.5), Position = Vector3.new(-5, 8, -58.25),
	Color = PLASTER, Material = Enum.Material.Limestone }) -- back wall (butts the side walls: no overlap, no z-fight)
part({ Size = Vector3.new(1.5, 16, 32), Position = Vector3.new(-24.25, 8, -43),
	Color = PLASTER, Material = Enum.Material.Limestone }) -- west wall
part({ Size = Vector3.new(1.5, 16, 32), Position = Vector3.new(14.25, 8, -43),
	Color = PLASTER, Material = Enum.Material.Limestone }) -- east wall
part({ Size = Vector3.new(8.5, 16, 1.5), Position = Vector3.new(-19.25, 8, -27.75),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- front side piece (butts the west wall)
part({ Size = Vector3.new(8.5, 16, 1.5), Position = Vector3.new(9.25, 8, -27.75),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- front side piece (butts the east wall)
part({ Size = Vector3.new(20, 4, 1.5), Position = Vector3.new(-5, 14, -27.75),
	Color = BRICK_B, Material = Enum.Material.Brick }) -- lintel over the door
-- striped awning over the door (alternating teal/cream slats, angled out)
for i = 0, 5 do
	local color = if i % 2 == 0 then TEAL else TILE
	part({ Size = Vector3.new(3.4, 0.35, 5),
		CFrame = CFrame.new(-13.5 + i * 3.4, 12.6, -25.2) * CFrame.Angles(math.rad(18), 0, 0),
		Color = color, Material = Enum.Material.Fabric })
end
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
gspawn.Color = Color3.fromRGB(44, 48, 62) -- dark mat: sits quiet in the man cave
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

-- ── Custom MESH signs (generated boards; recreated from asset IDs) ──────────
-- The mesh is the decorative frame; a thin plate flush with its face carries
-- the SurfaceGui text. plateName is kept for signs QueueService updates.
local AssetServiceSign = game:GetService("AssetService")
local SIGN_MESHES = {
	board = { mesh = 121691879000330, tex = 87169891897581 },   -- marquee board
	hanging = { mesh = 133466664753062, tex = 93563060312343 }, -- bracket + hanging board
}
local signMeshCache = {}
local function signMeshClone(kind)
	local def = SIGN_MESHES[kind]
	if signMeshCache[kind] == nil then
		local ok, mp = pcall(function()
			return AssetServiceSign:CreateMeshPartAsync(Content.fromAssetId(def.mesh))
		end)
		if ok and mp then
			mp.TextureID = "rbxassetid://" .. def.tex
			mp.Anchored = true
			mp.CanCollide = false
			mp.CanQuery = false
			signMeshCache[kind] = mp
		else
			signMeshCache[kind] = false
		end
	end
	local t = signMeshCache[kind]
	return if t then t:Clone() else nil
end

-- Marquee-board sign; yawDeg 0 = text faces -Z (Front convention).
local function meshSign(x, y, z, sx, sy, yawDeg, text, textColor, plateName)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	local board = signMeshClone("board")
	if board then
		board.Size = Vector3.new(sx, sy, 1.6)
		board.CFrame = cf
		board.Parent = map
	end
	-- the generated frame's border eats ~30% of the width: the plate must fit
	-- the INNER panel or it overhangs the frame (the "not put together" look)
	local plate = part({ Size = Vector3.new(sx * 0.56, sy * 0.4, 0.3),
		CFrame = cf * CFrame.new(-sx * 0.055, 0, -0.95),
		Color = Color3.fromRGB(26, 24, 30), Material = Enum.Material.Metal })
	if plateName then
		plate.Name = plateName
	end
	sign(plate, Enum.NormalId.Front, text, textColor, Color3.fromRGB(26, 24, 30))
end

-- Small hanging bracket sign (posts/poles); same yaw convention.
local function hangSign(x, y, z, yawDeg, text, textColor)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	local m = signMeshClone("hanging")
	if m then
		m.Size = Vector3.new(6.5, 7, 0.9)
		m.CFrame = cf
		m.Parent = map
	end
	local plate = part({ Size = Vector3.new(4.2, 2, 0.3),
		CFrame = cf * CFrame.new(0, -1.7, -0.6),
		Color = Color3.fromRGB(26, 24, 30), Material = Enum.Material.Metal })
	sign(plate, Enum.NormalId.Front, text, textColor, Color3.fromRGB(26, 24, 30))
end

-- GARAGE marquee over the door + KO graffiti on the east wall (faces midfield)
meshSign(-5, 18.3, -26.5, 16, 4.4, 180, "GARAGE", Color3.fromRGB(120, 235, 255))
-- BALLOUT graffiti tag on the garage's east wall — a collage of tilted
-- letter plates over spray splats and drips, not a flat font block
do
	local wallX = 15.05 -- just proud of the east wall face
	-- each splat sits at its own depth: overlapping co-planar discs z-fight
	for si, sp in {
		{ z = -50, y = 8.2, r = 8, c = PURPLE },
		{ z = -43, y = 7.2, r = 10, c = Color3.fromRGB(38, 34, 46) },
		{ z = -36.5, y = 8.8, r = 7, c = MAGENTA },
	} do
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, sp.r, sp.r),
			CFrame = CFrame.new(wallX + si * 0.05, sp.y, sp.z),
			Color = sp.c, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false })
	end
	for _, d in { { z = -47, h = 3.2 }, { z = -41.5, h = 4.6 }, { z = -38, h = 2.6 } } do
		part({ Size = Vector3.new(0.12, d.h, 0.5), Position = Vector3.new(wallX, 4.6 - d.h / 2, d.z),
			Color = Color3.fromRGB(38, 34, 46), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false })
	end
	local word = "BALLOUT"
	local paints = { MAGENTA, TEAL, MUSTARD }
	for i = 1, #word do
		-- plates stay FLAT (tilting the part swings its edges ~0.4 studs in
		-- depth and they clip through the splats = flicker); the tilt comes
		-- from TextLabel.Rotation in gui space instead.
		local plate = part({ Size = Vector3.new(0.25, 5.6, 3.1),
			-- viewed from the east (+X), the viewer's LEFT is +Z: letters must
			-- march toward -Z or the word renders mirrored
			CFrame = CFrame.new(wallX + 0.3, 8 + (if i % 2 == 0 then -0.7 else 0.5), -29.7 - i * 2.9),
			Transparency = 1, CanCollide = false, CanQuery = false })
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Right
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 20
		g.Parent = plate
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.TextColor3 = paints[(i - 1) % #paints + 1]
		l.TextStrokeTransparency = 0
		l.TextStrokeColor3 = Color3.fromRGB(20, 18, 24)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.Text = word:sub(i, i)
		l.Rotation = if i % 2 == 0 then 9 else -7 -- the graffiti tilt, in gui space
		l.Parent = g
	end
end

-- (garage interior is furnished with MAN CAVE meshes — see MESH DRESSING)

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
	Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.SmoothPlastic })
-- cross braces
for _, by in { 10, 22 } do
	part({ Size = Vector3.new(9.5, 0.6, 0.6), Position = Vector3.new(TWX, by, TWZ - 4), Color = METAL_DK, Material = Enum.Material.Metal })
	part({ Size = Vector3.new(9.5, 0.6, 0.6), Position = Vector3.new(TWX, by, TWZ + 4), Color = METAL_DK, Material = Enum.Material.Metal })
	part({ Size = Vector3.new(0.6, 0.6, 9.5), Position = Vector3.new(TWX - 4, by, TWZ), Color = METAL_DK, Material = Enum.Material.Metal })
	part({ Size = Vector3.new(0.6, 0.6, 9.5), Position = Vector3.new(TWX + 4, by, TWZ), Color = METAL_DK, Material = Enum.Material.Metal })
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
end
launchPad(52, -52, 0)
launchPad(-32, 32, 0)

-- ══ BASKETBALL HOOPS ════════════════════════════════════════════════════════
-- Real basketball hoop: the rim is a RING of 10 small segments, so the
-- ball's sweep raycasts pass clean through the middle (lob one in!) but
-- bounce off the metal. The old rim was a solid disc you couldn't score on.
local function hoop(x, z, baseY, faceDir)
	local face = CFrame.new(x, baseY, z) * CFrame.Angles(0, math.rad(faceDir), 0)
	-- pole with base plate + double brace arms
	part({ Size = Vector3.new(1.1, 13.5, 1.1), Position = Vector3.new(x, baseY + 6.75, z),
		Color = Color3.fromRGB(52, 78, 92), Material = Enum.Material.Metal })
	part({ Size = Vector3.new(2.6, 0.5, 2.6), Position = Vector3.new(x, baseY + 0.25, z),
		Color = Color3.fromRGB(52, 78, 92), Material = Enum.Material.Metal })
	for _, dy in { 11.2, 12.4 } do
		part({ Size = Vector3.new(0.35, 0.35, 1.6), CFrame = face * CFrame.new(0.95, dy, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color = METAL_DK, Material = Enum.Material.Metal })
	end
	-- backboard: white board + mustard shooter square + trim frame
	part({ Size = Vector3.new(0.5, 4.8, 7),
		CFrame = face * CFrame.new(1.9, 12.2, 0),
		Color = Color3.fromRGB(240, 236, 228), Material = Enum.Material.SmoothPlastic })
	part({ Size = Vector3.new(0.12, 2.2, 3.2),
		CFrame = face * CFrame.new(2.2, 11.6, 0),
		Color = MUSTARD, Material = Enum.Material.SmoothPlastic })
	part({ Size = Vector3.new(0.55, 0.4, 7.2),
		CFrame = face * CFrame.new(1.9, 14.55, 0),
		Color = Color3.fromRGB(52, 78, 92), Material = Enum.Material.Metal })
	-- the rim: 10 segments around a 4.6-stud ring (opening ~3.9 > ball 1.8)
	local rimC = face * CFrame.new(4.6, 10.4, 0) -- ring center, out from the board
	local RIM_R = 2.3
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		part({ Size = Vector3.new(0.45, 0.35, 1.55),
			CFrame = rimC * CFrame.new(math.cos(a) * RIM_R, 0, math.sin(a) * RIM_R)
				* CFrame.Angles(0, -a, 0),
			Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Metal })
	end
	-- net: 8 tapered strips hanging from the rim (visual only — no collide,
	-- no query, so they never eat a made shot)
	for i = 0, 7 do
		local a = (i + 0.5) / 8 * math.pi * 2
		part({ Size = Vector3.new(0.18, 2.6, 0.18),
			CFrame = rimC * CFrame.new(math.cos(a) * (RIM_R - 0.5), -1.4, math.sin(a) * (RIM_R - 0.5))
				* CFrame.Angles(math.rad(math.sin(a) * 9), 0, math.rad(math.cos(a) * -9)),
			Color = Color3.fromRGB(235, 235, 235), Material = Enum.Material.Fabric,
			CanCollide = false, CanQuery = false })
	end
end
hoop(20, -56, 0, -90)     -- east of the garage, faces south
hoop(95, 5, -6, 90)       -- dummy roof south edge, faces north

-- ══ SPECIAL-BALL SPAWNER PODS (decorative, purple hover pods) ═══════════════
local function ballPod(x, z, baseY)
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 5, 5),
		CFrame = CFrame.new(x, baseY + 0.7, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(50, 46, 56), Material = Enum.Material.Metal })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4.3, 4.3),
		CFrame = CFrame.new(x, baseY + 2.1, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = PURPLE, Material = Enum.Material.SmoothPlastic, Transparency = 0.35,
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
	Color = CORAL, Material = Enum.Material.Concrete })
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
local function queueBank(shellZ, dir, wallColor, wallMat, defs)
	local backZ = shellZ - dir * 10.4
	local frontZ = shellZ + dir * 11
	part({ Size = Vector3.new(66, 0.16, 22), Position = Vector3.new(QX, QTOP + 0.08, shellZ),
		Color = TAR, Material = Enum.Material.Asphalt })
	part({ Size = Vector3.new(66, 15, 1.2), Position = Vector3.new(QX, QTOP + 7.5, backZ),
		Color = wallColor, Material = wallMat })
	part({ Size = Vector3.new(1.2, 15, 22), Position = Vector3.new(QX - 33, QTOP + 7.5, shellZ),
		Color = wallColor, Material = wallMat })
	part({ Size = Vector3.new(1.2, 15, 22), Position = Vector3.new(QX + 33, QTOP + 7.5, shellZ),
		Color = wallColor, Material = wallMat })
	part({ Size = Vector3.new(68, 1, 24), Position = Vector3.new(QX, QTOP + 15.5, shellZ),
		Color = TAR, Material = Enum.Material.Concrete })
	part({ Size = Vector3.new(66, 3, 1), Position = Vector3.new(QX, QTOP + 13.5, frontZ + dir * 0.5),
		Color = BRICK_DARK, Material = Enum.Material.Brick })
	for _, dx in { -11, 11 } do
		part({ Size = Vector3.new(1, 15, 18), Position = Vector3.new(QX + dx, QTOP + 7.5, shellZ - dir * 2),
			Color = wallColor, Material = wallMat })
	end
	-- rooftop clutter: AC box + a vent pipe per bank
	part({ Size = Vector3.new(5, 2.8, 4), Position = Vector3.new(QX - 20 * dir, QTOP + 17.4, shellZ),
		Color = Color3.fromRGB(152, 150, 147), Material = Enum.Material.Metal })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.2, 1.2),
		CFrame = CFrame.new(QX + 24 * dir, QTOP + 18, shellZ) * CFrame.Angles(0, 0, math.rad(90)),
		Color = METAL_DK, Material = Enum.Material.Metal })
	for _, def in defs do
		local cx = QX + def.dx
		part({ Name = def.name, Size = Vector3.new(12, 0.2, 12), Position = Vector3.new(cx, QTOP + 0.2, shellZ - dir * 3),
			Color = def.accent, Material = Enum.Material.SmoothPlastic })
		-- hang the board fully PROUD of the front face (the 1.6-deep mesh was
		-- half-buried in the header when centered at the old panel offset)
		meshSign(cx, QTOP + 13.5, frontZ + dir * 1.2, 14, 4, if dir == 1 then 180 else 0,
			def.text, def.accent, def.name .. "Sign")
		local light = Instance.new("PointLight")
		light.Color = def.accent
		light.Range = 18
		light.Brightness = 1.2
		light.Parent = part({ Size = Vector3.new(4, 0.3, 4), Position = Vector3.new(cx, QTOP + 14.7, shellZ),
			Color = def.accent, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false })
	end
end
local Q_RED = Color3.fromRGB(255, 90, 70)
local Q_GRAY = Color3.fromRGB(200, 200, 205)
queueBank(-42, 1, BRICK_B, Enum.Material.Brick, { -- north bank: brick
	{ dx = -22, name = "QueuePadTeamKO_A", text = "TEAM KO 3v3", accent = Q_RED },
	{ dx = 0, name = "QueuePadSoon1_A", text = "COMING SOON", accent = Q_GRAY },
	{ dx = 22, name = "QueuePadSoon2_A", text = "COMING SOON", accent = Q_GRAY },
})
queueBank(22, -1, CORAL, Enum.Material.Concrete, { -- south bank: painted coral
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
meshSign(QX - 40 + 0.9, QTOP + 38, QZ, 34, 10, -90, "MATCH QUEUE", TEAL)
meshSign(QX - 40 - 0.9, QTOP + 38, QZ, 34, 10, 90, "MATCH QUEUE", TEAL)
-- pointer signs flanking the stair gap on the main deck
for _, sz in { -24.5, 4.5 } do
	part({ Size = Vector3.new(0.8, 6, 0.8), Position = Vector3.new(-38.5, 3, sz),
		Color = METAL_DK, Material = Enum.Material.Metal })
	hangSign(-37.9, 7.6, sz, -90, "QUEUE", TEAL)
end

-- ══ STREET FURNITURE (small props sell the "lived-in city" read) ════════════
-- fire hydrant
local function hydrant(x, z)
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 1.1, 1.1),
		CFrame = CFrame.new(x, 1.1, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(210, 60, 48), Material = Enum.Material.Metal })
	part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1), Position = Vector3.new(x, 2.3, z),
		Color = Color3.fromRGB(210, 60, 48), Material = Enum.Material.Metal })
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 0.7, 0.7),
		CFrame = CFrame.new(x, 1.35, z) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(235, 200, 90), Material = Enum.Material.Metal })
end
hydrant(-18, -24)
hydrant(44, 8)

-- mailbox (rounded-top drop box on legs)
part({ Size = Vector3.new(2.4, 2.6, 1.8), Position = Vector3.new(24, 2.5, -34),
	Color = Color3.fromRGB(64, 106, 190), Material = Enum.Material.Metal })
part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 1.8, 1.8),
	CFrame = CFrame.new(24, 3.8, -34) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(64, 106, 190), Material = Enum.Material.Metal })
for _, lx in { 23.2, 24.8 } do
	part({ Size = Vector3.new(0.4, 1.2, 0.4), Position = Vector3.new(lx, 0.6, -34),
		Color = METAL_DK, Material = Enum.Material.Metal })
end

-- potted street plants
local function planter(x, z)
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 2.6, 2.6),
		CFrame = CFrame.new(x, 1, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(196, 120, 82), Material = Enum.Material.Concrete })
	part({ Shape = Enum.PartType.Ball, Size = Vector3.new(3, 2.6, 3), Position = Vector3.new(x, 3.2, z),
		Color = GRASS_DK, Material = Enum.Material.Grass })
end
planter(-14, 10)
planter(6, 26)
planter(52, -30)

-- stair bulkhead (the little rooftop-access shed every real roof has)
part({ Size = Vector3.new(8, 7, 8), Position = Vector3.new(38, 3.5, -50),
	Color = BRICK_DARK, Material = Enum.Material.Brick })
part({ Size = Vector3.new(9, 0.7, 9), Position = Vector3.new(38, 7.35, -50),
	Color = TAR, Material = Enum.Material.Slate })
part({ Size = Vector3.new(3.4, 5.4, 0.3), Position = Vector3.new(38, 2.7, -45.9),
	Color = Color3.fromRGB(70, 96, 110), Material = Enum.Material.Metal }) -- door

-- traffic cones by the plank pile (someone's mid-repair)
for _, off in { Vector3.new(4, 0, -3), Vector3.new(7.5, 0, 1), Vector3.new(2, 0, 3.5) } do
	local c = part({ Size = Vector3.new(1.2, 1.6, 1.2), Position = Vector3.new(14, 0.8, -8) + off,
		Color = Color3.fromRGB(255, 130, 40), Material = Enum.Material.SmoothPlastic })
	part({ Size = Vector3.new(1.7, 0.18, 1.7), Position = c.Position - Vector3.new(0, 0.75, 0),
		Color = Color3.fromRGB(255, 130, 40), Material = Enum.Material.SmoothPlastic })
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


-- ══ PROP MESHES (generated with Studio's generate_mesh; original prompts) ══
-- Same pattern as the towers: geometry from CreateMeshPartAsync, paired
-- texture reapplied by hand, cached template cloned per placement.
local PropAssets = game:GetService("AssetService")
local PROP_MESHES = {
	water  = { mesh = 96976809130016, tex = 77005750947519 },   -- wooden rooftop water tank
	solar  = { mesh = 121984979647810, tex = 120499625068038 }, -- tilted solar array
	couch  = { mesh = 110486186801689, tex = 99273308728241 },  -- burnt-orange sofa
	media  = { mesh = 98033537025590, tex = 99379652460328 },   -- retro TV media wall
	arcade = { mesh = 75784229888285, tex = 123364029334806 },  -- arcade cabinet
	fridge = { mesh = 133543084994948, tex = 100659634387656 }, -- mint mini fridge
	table  = { mesh = 96675283363598, tex = 128019790656861 },  -- wooden coffee table
}
local propCache = {}
local function prop(kind, size, cf)
	local def = PROP_MESHES[kind]
	if propCache[kind] == nil then
		local ok, mp = pcall(function()
			return PropAssets:CreateMeshPartAsync(Content.fromAssetId(def.mesh))
		end)
		if ok and mp then
			mp.TextureID = "rbxassetid://" .. def.tex
			propCache[kind] = mp
		else
			propCache[kind] = false
		end
	end
	local template = propCache[kind]
	if not template then
		return nil -- offline: prop simply absent, nothing breaks
	end
	local m = template:Clone()
	m.Name = "Prop_" .. kind
	m.Size = size
	m.CFrame = cf
	m.Anchored = true
	m.Parent = map
	return m
end

-- rooftop water tank on the old drum corner (the drum + steps are gone)
prop("water", Vector3.new(16, 24, 16), CFrame.new(38, 12, 27) * CFrame.Angles(0, math.rad(-30), 0))
-- solar array along the south parapet
prop("solar", Vector3.new(24, 6, 10), CFrame.new(14, 3, 33))

-- MAN CAVE: the garage interior (everything else was stripped out) —
-- couch against the west wall facing a media wall on the east wall,
-- coffee table between them, arcade cabinet + mini fridge along the back
prop("couch", Vector3.new(13, 4.5, 5.5), CFrame.new(-20.5, 2.25, -43) * CFrame.Angles(0, math.rad(-90), 0))
prop("table", Vector3.new(7, 2, 4), CFrame.new(-13, 1, -43) * CFrame.Angles(0, math.rad(90), 0))
prop("media", Vector3.new(11, 8, 3), CFrame.new(11.9, 4, -43) * CFrame.Angles(0, math.rad(90), 0))
prop("arcade", Vector3.new(3.5, 7, 3.2), CFrame.new(-14, 3.5, -55.8) * CFrame.Angles(0, math.rad(180), 0))
prop("fridge", Vector3.new(3, 4.5, 3), CFrame.new(-19.5, 2.25, -55.9) * CFrame.Angles(0, math.rad(180), 0))
-- a rug under the seating area ties the room together
part({ Size = Vector3.new(16, 0.12, 12), Position = Vector3.new(-14, 0.06, -43),
	Color = Color3.fromRGB(158, 64, 52), Material = Enum.Material.Fabric })

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
		Color = Color3.fromRGB(255, 214, 130), Material = Enum.Material.SmoothPlastic,
		Transparency = 0.25, CanCollide = false, CanQuery = false })
end

-- ══ BARRIER SKYLINE ═════════════════════════════════════════════════════════
local BARRIER_COLORS = {
	Color3.fromRGB(196, 130, 96), Color3.fromRGB(170, 108, 82), Color3.fromRGB(216, 168, 128),
	Color3.fromRGB(206, 190, 168), Color3.fromRGB(154, 96, 78),
}
local BARRIER_NEONS = { TEAL, MAGENTA, PURPLE }
local BARRIER_MATS = {
	Enum.Material.Brick, Enum.Material.Concrete, Enum.Material.Limestone,
	Enum.Material.Sandstone, Enum.Material.Concrete,
}
-- CUSTOM MESH TOWERS: five building designs generated with Studio's
-- generate_mesh (original prompts), recreated from their permanent asset IDs
-- and stretched to each slot's exact footprint. The mesh covers the visible
-- top 200 studs; a plain shaft in the tower's color continues down into the
-- cloud fog, so the skyline still sinks into the void like it always did.
local AssetService = game:GetService("AssetService")
local TOWER_MESHES = {
	-- v2 designs: strict floor rhythm (15-18 floors of small windows), sharp
	-- rectangular massing, crisp edges. Each generated mesh has a PAIRED
	-- texture asset — CreateMeshPartAsync rebuilds geometry only, so the
	-- TextureID must be reapplied by hand (it's script-writable; MeshId isn't).
	{ mesh = 121983418220311, tex = 104497216431792 }, -- terracotta apartment tower
	{ mesh = 81305040848998, tex = 80622997433818 },   -- dark brick office tower
	{ mesh = 80231644737854, tex = 103028928850752 },  -- tan art-deco tower
	{ mesh = 75318671248482, tex = 124411094570172 },  -- sandstone hotel tower
	{ mesh = 88960819929663, tex = 139192380214504 },  -- brick industrial loft
}
local TOWER_MESH_H = 200
local towerCache = {}
local function towerMeshFor(ci)
	local def = TOWER_MESHES[(ci - 1) % #TOWER_MESHES + 1]
	if towerCache[def.mesh] == nil then
		local ok, mp = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromAssetId(def.mesh))
		end)
		if ok and mp then
			mp.TextureID = "rbxassetid://" .. def.tex
			towerCache[def.mesh] = mp
		else
			towerCache[def.mesh] = false
		end
	end
	local template = towerCache[def.mesh]
	return if template then template:Clone() else nil
end

local function barrier(name, cx, cz, w, d, top, ci)
	local color = BARRIER_COLORS[(ci - 1) % #BARRIER_COLORS + 1]
	-- yaw the design's front toward the arena
	local toX, toZ = 35 - cx, -22 - cz
	local yaw
	if math.abs(toX) * d > math.abs(toZ) * w then
		yaw = if toX > 0 then -90 else 90
	else
		yaw = if toZ > 0 then 180 else 0
	end
	local mesh = towerMeshFor(ci)
	if mesh then
		mesh.Name = name
		-- under a 90° yaw the local axes swap, so swap the stretch too
		mesh.Size = if yaw == 90 or yaw == -90
			then Vector3.new(d, TOWER_MESH_H, w)
			else Vector3.new(w, TOWER_MESH_H, d)
		mesh.CFrame = CFrame.new(cx, top - TOWER_MESH_H / 2, cz) * CFrame.Angles(0, math.rad(yaw), 0)
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanQuery = false
		mesh.Parent = map
		-- shaft below the mesh, sinking into the clouds
		local baseTop = top - TOWER_MESH_H
		part({ Name = name .. "Base", Size = Vector3.new(w, baseTop + 400, d),
			Position = Vector3.new(cx, (baseTop - 400) / 2, cz), Color = color,
			Material = BARRIER_MATS[(ci - 1) % #BARRIER_MATS + 1] })
	else
		-- offline fallback: the old flat slab so the skyline never vanishes
		part({ Name = name, Size = Vector3.new(w, top + 400, d),
			Position = Vector3.new(cx, (top - 400) / 2, cz), Color = color,
			Material = BARRIER_MATS[(ci - 1) % #BARRIER_MATS + 1] })
	end
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

prop("water", Vector3.new(20, 30, 20), CFrame.new(10, 105, -160) * CFrame.Angles(0, math.rad(20), 0))
prop("water", Vector3.new(15, 23, 15), CFrame.new(-190, 96.5, 30) * CFrame.Angles(0, math.rad(-45), 0))
prop("water", Vector3.new(13, 20, 13), CFrame.new(130, 135, 100))
local function antenna(x, z, baseY)
	part({ Size = Vector3.new(0.9, 32, 0.9), Position = Vector3.new(x, baseY + 16, z),
		Color = METAL_DK, Material = Enum.Material.Metal })
	part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8),
		Position = Vector3.new(x, baseY + 32.5, z),
		Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.SmoothPlastic })
end
antenna(205, 20, 140)
antenna(-80, -150, 120)

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
part({ Name = "CloudHi", Size = Vector3.new(1500, 45, 1500), Position = Vector3.new(35, -220, -22),
	Color = Color3.fromRGB(140, 118, 170), Material = Enum.Material.SmoothPlastic,
	Transparency = 0.12, CanCollide = false, CanQuery = false, CastShadow = false })
part({ Name = "CloudLo", Size = Vector3.new(1600, 70, 1600), Position = Vector3.new(35, -270, -22),
	Color = Color3.fromRGB(108, 92, 140), Material = Enum.Material.SmoothPlastic,
	Transparency = 0, CanCollide = false, CanQuery = false, CastShadow = false })
local puffs = {
	{ 40, -215, -90, 46 }, { 120, -210, 10, 38 }, { -70, -218, 40, 52 }, { -140, -208, -60, 40 },
	{ 170, -220, -110, 44 }, { 0, -212, 110, 48 }, { -180, -216, 80, 42 }, { 90, -207, 150, 36 },
	{ -110, -210, -170, 50 }, { 200, -214, 90, 40 },
}
for _, q in puffs do
	part({ Shape = Enum.PartType.Ball, Size = Vector3.new(q[4], q[4] * 0.45, q[4]),
		Position = Vector3.new(q[1], q[2], q[3]),
		Color = Color3.fromRGB(150, 128, 180), Material = Enum.Material.SmoothPlastic,
		Transparency = 0.04, CanCollide = false, CanQuery = false, CastShadow = false })
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
