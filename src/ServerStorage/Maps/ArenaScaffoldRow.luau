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
