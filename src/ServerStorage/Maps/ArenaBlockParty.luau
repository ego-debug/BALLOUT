--!strict
-- Ballout | Arena "Block Party" — first real match arena
--
-- KC-style urban block, ORIGINAL layout (per DESIGN.md: clone the vibe,
-- never the maps): an enclosed street plaza between two team buildings with
-- walkable rooftops, ramp access, a raised center stage over the ball spawn,
-- kiosks/planters/crates for cover, alley flanks along the walls, and a
-- skyline rim. Built once at boot, far outside the lobby SafeZone.
-- "BalloutArena" is in the ball's wall-sweep roots — everything here bounces.
--
-- Markers MatchService reads (contract):
--   RedSpawn1..3 / BlueSpawn1..3 — team spawns (on the team rooftops)
--   BallSpawn                    — center-stage ball spot
--   ScoreboardN/S -> ScoreLabel  — score displays

local Workspace = game:GetService("Workspace")

local Arena = {}

local CENTER = Vector3.new(0, 0, 400)
local W = 150 -- x span
local D = 110 -- z span
local WALL_H = 18

local ASPHALT = Color3.fromRGB(52, 50, 56)
local PAVE = Color3.fromRGB(188, 180, 165)
local BRICK = Color3.fromRGB(140, 78, 60)
local BRICK_DK = Color3.fromRGB(112, 60, 48)
local METAL = Color3.fromRGB(70, 68, 66)
local RED = Color3.fromRGB(196, 60, 50)
local BLUE = Color3.fromRGB(56, 110, 200)
local NEON_W = Color3.fromRGB(235, 232, 226)
local GRASS = Color3.fromRGB(96, 158, 58)

local function mk(parent: Instance, name: string, size: Vector3, cfOrPos: CFrame | Vector3, color: Color3, material: Enum.Material?, class: string?): BasePart
	local p = Instance.new((class or "Part") :: any) :: BasePart
	p.Name = name
	p.Size = size
	if typeof(cfOrPos) == "CFrame" then
		p.CFrame = cfOrPos
	else
		p.Position = cfOrPos
	end
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Arena.Build(): Model
	local old = Workspace:FindFirstChild("BalloutArena")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "BalloutArena"

	local cx, cz = CENTER.X, CENTER.Z

	-- ── Street floor + plaza dressing ────────────────────────────────────
	mk(model, "Floor", Vector3.new(W, 2, D), CENTER - Vector3.new(0, 1, 0), ASPHALT, Enum.Material.Asphalt)
	-- paved center plaza patch + road dashes ringing it
	mk(model, "PlazaPatch", Vector3.new(70, 0.16, 54), CENTER + Vector3.new(0, 0.08, 0), PAVE, Enum.Material.Concrete)
	for _, dz in { -32, 32 } do
		for i = -3, 3 do
			mk(model, "Dash", Vector3.new(6, 0.14, 1), CENTER + Vector3.new(i * 16, 0.07, dz), NEON_W, Enum.Material.SmoothPlastic)
		end
	end

	-- ── Perimeter walls + skyline rim ────────────────────────────────────
	mk(model, "WallN", Vector3.new(W + 3, WALL_H, 1.5), CENTER + Vector3.new(0, WALL_H / 2, -D / 2), BRICK_DK, Enum.Material.Brick)
	mk(model, "WallS", Vector3.new(W + 3, WALL_H, 1.5), CENTER + Vector3.new(0, WALL_H / 2, D / 2), BRICK_DK, Enum.Material.Brick)
	mk(model, "WallW", Vector3.new(1.5, WALL_H, D + 3), CENTER + Vector3.new(-W / 2, WALL_H / 2, 0), BRICK_DK, Enum.Material.Brick)
	mk(model, "WallE", Vector3.new(1.5, WALL_H, D + 3), CENTER + Vector3.new(W / 2, WALL_H / 2, 0), BRICK_DK, Enum.Material.Brick)
	-- skyline: stepped building silhouettes on the rim (pure vibe)
	local heights = { 8, 14, 6, 18, 10, 15, 7, 12 }
	for i, h in heights do
		local x = cx - W / 2 + 10 + (i - 1) * ((W - 20) / (#heights - 1))
		mk(model, "SkylineN", Vector3.new(14, h, 3), Vector3.new(x, WALL_H + h / 2, cz - D / 2 - 0.5), BRICK, Enum.Material.Brick)
		mk(model, "SkylineS", Vector3.new(14, heights[#heights + 1 - i], 3), Vector3.new(x, WALL_H + heights[#heights + 1 - i] / 2, cz + D / 2 + 0.5), BRICK, Enum.Material.Brick)
	end

	-- ── Team buildings (mirrored, walkable roofs, ramp access) ───────────
	-- Building: 24 deep (x) x 56 wide (z), roof at y=12 with parapet.
	for _, side in { -1, 1 } do
		local team = if side == -1 then "Red" else "Blue"
		local accent = if side == -1 then RED else BLUE
		local bx = cx + side * (W / 2 - 13) -- building center x
		mk(model, team .. "Building", Vector3.new(24, 12, 56), Vector3.new(bx, 6, cz), BRICK, Enum.Material.Brick)
		mk(model, team .. "Roof", Vector3.new(26, 1, 58), Vector3.new(bx, 12.5, cz), METAL, Enum.Material.DiamondPlate)
		-- inner-edge parapet so roof fights have a lip (low: hop over to drop in)
		mk(model, team .. "Parapet", Vector3.new(1, 2.5, 58), Vector3.new(bx - side * 12.5, 14.25, cz), BRICK_DK, Enum.Material.Brick)
		-- team neon strip along the building face
		mk(model, team .. "Strip", Vector3.new(0.4, 1.2, 50), Vector3.new(bx - side * 12.3, 10, cz), accent, Enum.Material.Neon)
		-- two ramps up: from the alleys at both z ends onto the roof
		for _, zEnd in { -1, 1 } do
			local rampLen = 26
			local rz = cz + zEnd * (28 + rampLen / 2)
			-- wedge ramp: rises toward the building (wedge height grows toward
			-- local +Z, so aim +Z at the building end)
			local yaw = if zEnd == 1 then 180 else 0
			mk(model, team .. "Ramp", Vector3.new(10, 13, rampLen),
				CFrame.new(bx, 6.5, rz) * CFrame.Angles(0, math.rad(yaw), 0),
				PAVE, Enum.Material.Concrete, "WedgePart")
		end
		-- spawns on the roof, facing mid
		for i, dz in { -18, 0, 18 } do
			local marker = mk(model, team .. "Spawn" .. i, Vector3.new(2, 2, 2), Vector3.new(bx, 14.5, cz + dz), Color3.new(1, 1, 1))
			marker.Transparency = 1
			marker.CanCollide = false
			marker.CanQuery = false
			marker.CanTouch = false
		end
	end

	-- ── Center stage (raised, 4 ramps, ball on top) ──────────────────────
	mk(model, "Stage", Vector3.new(30, 5, 30), CENTER + Vector3.new(0, 2.5, 0), PAVE, Enum.Material.Concrete)
	mk(model, "StageTrim", Vector3.new(31, 0.5, 31), CENTER + Vector3.new(0, 5.25, 0), NEON_W, Enum.Material.Neon)
	for _, side in { -1, 1 } do
		mk(model, "StageRampX", Vector3.new(12, 5, 14),
			CFrame.new(cx + side * 22, 2.5, cz) * CFrame.Angles(0, math.rad(if side == 1 then -90 else 90), 0),
			PAVE, Enum.Material.Concrete, "WedgePart")
		mk(model, "StageRampZ", Vector3.new(12, 5, 14),
			CFrame.new(cx, 2.5, cz + side * 22) * CFrame.Angles(0, math.rad(if side == 1 then 180 else 0), 0),
			PAVE, Enum.Material.Concrete, "WedgePart")
	end
	-- corner pillars on the stage: peek cover up top
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			mk(model, "StagePillar", Vector3.new(2.2, 7, 2.2), CENTER + Vector3.new(sx * 12, 9, sz * 12), METAL, Enum.Material.Metal)
		end
	end

	-- ── Mid-field cover: planters, crates, kiosks ────────────────────────
	for _, side in { -1, 1 } do
		-- brick planters with hedge tops (rotationally symmetric pair)
		for _, dz in { -20, 20 } do
			local px = cx + side * 34
			mk(model, "Planter", Vector3.new(10, 3, 4), Vector3.new(px, 1.5, cz + dz), BRICK, Enum.Material.Brick)
			mk(model, "PlanterHedge", Vector3.new(9.4, 1.8, 3.4), Vector3.new(px, 3.9, cz + dz), GRASS, Enum.Material.Grass)
		end
		-- crate stacks near the stage approaches
		local kx = cx + side * 14
		mk(model, "Crate", Vector3.new(4, 4, 4), Vector3.new(kx, 2, cz + side * 30), Color3.fromRGB(150, 105, 65), Enum.Material.WoodPlanks)
		mk(model, "Crate", Vector3.new(3, 3, 3), Vector3.new(kx + side * 3.4, 1.5, cz + side * 31), Color3.fromRGB(160, 112, 70), Enum.Material.WoodPlanks)
		-- food kiosk with awning (bigger cover, N and S mid)
		local kz = cz + side * 38
		mk(model, "Kiosk", Vector3.new(9, 7, 5), Vector3.new(cx + side * 4, 3.5, kz), Color3.fromRGB(120, 34, 50), Enum.Material.SmoothPlastic)
		mk(model, "KioskAwning", Vector3.new(11, 0.5, 7), Vector3.new(cx + side * 4, 7.3, kz), NEON_W, Enum.Material.Fabric)
	end

	-- ── Alley flank cover along N/S walls ────────────────────────────────
	for _, side in { -1, 1 } do
		for _, dx in { -28, 28 } do
			mk(model, "AlleyWall", Vector3.new(14, 4, 1.5), Vector3.new(cx + dx, 2, cz + side * (D / 2 - 10)), METAL, Enum.Material.DiamondPlate)
		end
	end

	-- ── Lamp posts at the plaza corners ──────────────────────────────────
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local lx, lz = cx + sx * 30, cz + sz * 22
			mk(model, "LampPole", Vector3.new(0.6, 10, 0.6), Vector3.new(lx, 5, lz), METAL, Enum.Material.Metal)
			local bulb = mk(model, "LampBulb", Vector3.new(1.4, 1.4, 1.4), Vector3.new(lx, 10.6, lz), Color3.fromRGB(255, 214, 120), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 214, 160)
			light.Range = 22
			light.Brightness = 1.1
			light.Parent = bulb
		end
	end

	-- ── Ball marker + scoreboards (contract) ─────────────────────────────
	local ballMarker = mk(model, "BallSpawn", Vector3.new(2, 2, 2), CENTER + Vector3.new(0, 8, 0), Color3.new(1, 1, 1))
	ballMarker.Transparency = 1
	ballMarker.CanCollide = false
	ballMarker.CanQuery = false
	ballMarker.CanTouch = false

	local function scoreboard(name: string, pos: Vector3, face: Enum.NormalId)
		local panel = mk(model, name, Vector3.new(34, 7, 1), pos, Color3.fromRGB(24, 22, 28), Enum.Material.Metal)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.Parent = panel
		local label = Instance.new("TextLabel")
		label.Name = "ScoreLabel"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = "RED 0 — 0 BLUE"
		label.Parent = gui
	end
	scoreboard("ScoreboardN", CENTER + Vector3.new(0, 12, -D / 2 + 1.6), Enum.NormalId.Back)
	scoreboard("ScoreboardS", CENTER + Vector3.new(0, 12, D / 2 - 1.6), Enum.NormalId.Front)

	model.Parent = Workspace
	return model
end

return Arena
