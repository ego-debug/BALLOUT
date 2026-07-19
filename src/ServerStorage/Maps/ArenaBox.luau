--!strict
-- Ballout | ArenaBox — temporary boxed match arena
--
-- A plain walled box far outside the lobby SafeZone (so damage is live).
-- Built once at boot and reused by every match; Phase 5 replaces this with
-- a real designed arena. "BalloutArena" is in BallService's wall-sweep root
-- list, so the ball bounces off everything here.
--
-- Markers MatchService reads:
--   RedSpawn1..3 / BlueSpawn1..3 — per-slot spawn points (invisible)
--   BallSpawn                    — midcourt ball spot (invisible)
--   ScoreboardN/S -> ScoreLabel  — SurfaceGui text MatchService updates

local Workspace = game:GetService("Workspace")

local ArenaBox = {}

local CENTER = Vector3.new(0, 0, 400) -- far north of the HQ (safe zone ends z≈88)
local FLOOR_W = 110 -- x
local FLOOR_D = 64 -- z
local WALL_H = 14

local COL_FLOOR = Color3.fromRGB(94, 90, 98)
local COL_WALL = Color3.fromRGB(66, 62, 72)
local COL_RED = Color3.fromRGB(196, 60, 50)
local COL_BLUE = Color3.fromRGB(56, 110, 200)
local COL_MID = Color3.fromRGB(230, 226, 218)

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

function ArenaBox.Build(): Model
	local old = Workspace:FindFirstChild("BalloutArena")
	if old then
		old:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "BalloutArena"

	-- floor (top at y = 0) + midline + team floor tints
	mk(model, "Floor", Vector3.new(FLOOR_W, 2, FLOOR_D), CENTER - Vector3.new(0, 1, 0), COL_FLOOR)
	mk(model, "MidLine", Vector3.new(1, 0.16, FLOOR_D), CENTER + Vector3.new(0, 0.08, 0), COL_MID, Enum.Material.SmoothPlastic)
	mk(model, "RedZone", Vector3.new(12, 0.16, FLOOR_D), CENTER + Vector3.new(-FLOOR_W / 2 + 6, 0.08, 0), COL_RED, Enum.Material.SmoothPlastic)
	mk(model, "BlueZone", Vector3.new(12, 0.16, FLOOR_D), CENTER + Vector3.new(FLOOR_W / 2 - 6, 0.08, 0), COL_BLUE, Enum.Material.SmoothPlastic)

	-- walls (ball bounces off these; nobody falls out of the box)
	local wallY = WALL_H / 2
	mk(model, "WallN", Vector3.new(FLOOR_W + 3, WALL_H, 1.5), CENTER + Vector3.new(0, wallY, -FLOOR_D / 2), COL_WALL, Enum.Material.Brick)
	mk(model, "WallS", Vector3.new(FLOOR_W + 3, WALL_H, 1.5), CENTER + Vector3.new(0, wallY, FLOOR_D / 2), COL_WALL, Enum.Material.Brick)
	mk(model, "WallW", Vector3.new(1.5, WALL_H, FLOOR_D + 3), CENTER + Vector3.new(-FLOOR_W / 2, wallY, 0), COL_WALL, Enum.Material.Brick)
	mk(model, "WallE", Vector3.new(1.5, WALL_H, FLOOR_D + 3), CENTER + Vector3.new(FLOOR_W / 2, wallY, 0), COL_WALL, Enum.Material.Brick)

	-- symmetric cover blocks (dodgeball needs peek-and-punish geometry)
	for _, side in { -1, 1 } do
		mk(model, "Cover", Vector3.new(3, 5, 10), CENTER + Vector3.new(side * 18, 2.5, 0), COL_WALL, Enum.Material.Brick)
		mk(model, "Cover", Vector3.new(8, 4, 3), CENTER + Vector3.new(side * 34, 2, -16), COL_WALL, Enum.Material.Brick)
		mk(model, "Cover", Vector3.new(8, 4, 3), CENTER + Vector3.new(side * 34, 2, 16), COL_WALL, Enum.Material.Brick)
	end

	-- spawn + ball markers (invisible, CanQuery=false: never block throws)
	local function marker(name: string, pos: Vector3)
		local p = mk(model, name, Vector3.new(2, 2, 2), pos, Color3.new(1, 1, 1))
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	for i, dz in { -18, 0, 18 } do
		marker("RedSpawn" .. i, CENTER + Vector3.new(-FLOOR_W / 2 + 8, 3, dz))
		marker("BlueSpawn" .. i, CENTER + Vector3.new(FLOOR_W / 2 - 8, 3, dz))
	end
	marker("BallSpawn", CENTER + Vector3.new(0, 3, 0))

	-- scoreboards on both long walls, facing in
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
	scoreboard("ScoreboardN", CENTER + Vector3.new(0, WALL_H + 4, -FLOOR_D / 2), Enum.NormalId.Back)
	scoreboard("ScoreboardS", CENTER + Vector3.new(0, WALL_H + 4, FLOOR_D / 2), Enum.NormalId.Front)

	model.Parent = Workspace
	return model
end

return ArenaBox
