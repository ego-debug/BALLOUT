--!strict
-- Ballout | Arena "Scaffold Row" — the construction-site map, promoted from
-- dev blockout to a real match arena.
--
-- The geometry itself is PLACE-SIDE: `BuildZone.ScaffoldRowBlockout`, authored
-- by tools/build_scaffold_row.luau (source of truth — rebuild there, not here).
-- This module does the runtime promotion at boot:
--   1. pulls the blockout out of the dev yard and renames it "BalloutArena"
--      (the name BallService's ball wall-sweep roots look for)
--   2. strips the dev furniture: TestSpawn, billboard labels, compass +
--      bounds + swing-zone markers
--   3. hides the rest of the dev yard (runtime only — the Edit-mode place
--      keeps BuildZone for authoring)
--
-- Match markers are already authored in the blockout (same contract as
-- Block Party): RedSpawn1..3 / BlueSpawn1..3 / BallSpawn / ScoreboardN/S.

local Workspace = game:GetService("Workspace")

local Arena = {}

Arena.DisplayName = "SCAFFOLD ROW"

-- Dev-only markers to strip when the blockout becomes the live arena.
local DEV_PARTS = {
	"TestSpawn",
	"CompassN", "CompassE", "CompassS", "CompassW",
	"PlayBoundsMark", "SwingZoneMark", "SwingZoneMark2",
}

function Arena.Build(): Model?
	local existing = Workspace:FindFirstChild("BalloutArena")
	local zone = Workspace:FindFirstChild("BuildZone")
	local blockout = zone and zone:FindFirstChild("ScaffoldRowBlockout")
	if not blockout then
		-- already promoted this session, or the place is missing the blockout
		return if existing and existing:IsA("Model") then existing else nil
	end
	if existing then
		existing:Destroy() -- stale arena from a previous Build
	end

	-- dev cleanup (runtime only)
	local strip: { Instance } = {}
	for _, name in DEV_PARTS do
		for _, d in blockout:GetChildren() do
			if d.Name == name then
				table.insert(strip, d)
			end
		end
	end
	for _, d in blockout:GetDescendants() do
		if d:IsA("BillboardGui") then
			table.insert(strip, d)
		end
	end
	for _, d in strip do
		d:Destroy()
	end

	-- make sure the scoreboards speak MatchService's contract
	for _, name in { "ScoreboardN", "ScoreboardS" } do
		local panel = blockout:FindFirstChild(name)
		local gui = panel and panel:FindFirstChildOfClass("SurfaceGui")
		if gui then
			local label = gui:FindFirstChildOfClass("TextLabel")
			if label then
				label.Name = "ScoreLabel"
			end
		end
	end

	-- ── Ball spawner pads (KC: several balls, always one nearby) ─────────
	-- Circle devices on the floor; BallService docks a levitating ball over
	-- each part named "BallSpawnerPad". Heights are raycast onto whatever
	-- floor is at each spot, so the list is just x/z.
	local PAD_SPOTS = {
		Vector3.new(65, 0, -650),   -- midcourt basin (the old single-ball spot)
		Vector3.new(190, 0, -676),  -- east approach, off the Red spawn yard
		Vector3.new(-190, 0, -676), -- west approach, off the Blue spawn yard
		Vector3.new(0, 0, -740),    -- north basin, toward the boarding hall
		Vector3.new(0, 0, -560),    -- south basin, toward the perch building
	}
	local padRay = RaycastParams.new()
	padRay.FilterType = Enum.RaycastFilterType.Include
	padRay.FilterDescendantsInstances = { blockout }
	for _, spot in PAD_SPOTS do
		local hit = Workspace:Raycast(Vector3.new(spot.X, 120, spot.Z), Vector3.new(0, -400, 0), padRay)
		local floorY = if hit then hit.Position.Y else 0
		local base = Instance.new("Part")
		base.Name = "BallSpawnerPad"
		base.Shape = Enum.PartType.Cylinder
		base.Size = Vector3.new(0.5, 7, 7)
		base.CFrame = CFrame.new(spot.X, floorY + 0.25, spot.Z) * CFrame.Angles(0, 0, math.rad(90))
		base.Color = Color3.fromRGB(38, 36, 44)
		base.Material = Enum.Material.Metal
		base.Anchored = true
		base.Parent = blockout
		local ring = Instance.new("Part")
		ring.Name = "BallSpawnerRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.15, 5.6, 5.6)
		ring.CFrame = CFrame.new(spot.X, floorY + 0.55, spot.Z) * CFrame.Angles(0, 0, math.rad(90))
		ring.Color = Color3.fromRGB(255, 170, 60)
		ring.Material = Enum.Material.Neon
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.Parent = blockout
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 170, 60)
		glow.Range = 12
		glow.Brightness = 0.9
		glow.Parent = ring
	end

	-- promote
	local model = blockout :: Model
	model.Name = "BalloutArena"
	model.Parent = Workspace

	-- the dev yard (floors, borders, scale guides) disappears for the session
	if zone then
		zone:Destroy()
	end

	return model
end

return Arena
