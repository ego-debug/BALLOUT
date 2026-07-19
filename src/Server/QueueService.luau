--!strict
-- Ballout | QueueService — walk-in queue rooms (Phase 3)
--
-- Watches the QueuePadTeamKO neon pad in the queue rooms (map-side contract,
-- see tools/build_map.luau). Stand on the pad to queue; the first person
-- starts a countdown, everyone still standing there when it hits zero is in.
-- MatchService fills short teams with bots, so one player is enough.
-- The bay's marquee sign doubles as the queue status display.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallConfig = require(ReplicatedStorage.BallConfig)
local MatchService = require(ServerScriptService.MatchService)

local QueueService = {}

local IDLE_TEXT = "TEAM KO 3v3"

-- There are multiple TeamKO rooms (QueuePadTeamKO_A/_B…): every pad whose
-- name starts with the prefix is the same queue, and all their signs show
-- the same status.
local function findPads(): { BasePart }
	local map = Workspace:FindFirstChild("BalloutMap")
	local pads = {}
	if map then
		for _, c in map:GetChildren() do
			if c:IsA("BasePart") and c.Name:sub(1, 14) == "QueuePadTeamKO" and c.Name:sub(-4) ~= "Sign" then
				table.insert(pads, c)
			end
		end
	end
	return pads
end

local function setSign(text: string)
	local map = Workspace:FindFirstChild("BalloutMap")
	if not map then
		return
	end
	for _, panel in map:GetChildren() do
		if panel.Name:sub(1, 14) == "QueuePadTeamKO" and panel.Name:sub(-4) == "Sign" then
			local gui = panel:FindFirstChildOfClass("SurfaceGui")
			local label = if gui then gui:FindFirstChildOfClass("TextLabel") else nil
			if label then
				label.Text = text
			end
		end
	end
end

local function playersOnPads(pads: { BasePart }): { Player }
	local standing = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			for _, pad in pads do
				local rel = root.Position - pad.Position
				if math.abs(rel.X) <= pad.Size.X / 2 + 1.5
					and math.abs(rel.Z) <= pad.Size.Z / 2 + 1.5
					and rel.Y > -1 and rel.Y < 8 then
					table.insert(standing, player)
					break
				end
			end
		end
	end
	return standing
end

function QueueService.Start()
	task.spawn(function()
		local firstQueuedAt: number? = nil
		local wasLive = false
		while true do
			task.wait(0.25)
			local pads = findPads()
			if #pads == 0 then
				continue
			end
			if MatchService.IsActive() then
				firstQueuedAt = nil
				wasLive = true
				setSign("MATCH LIVE")
				continue
			end
			if wasLive then
				-- match just wrapped: pad goes back to inviting
				wasLive = false
				setSign(IDLE_TEXT)
			end
			local standing = playersOnPads(pads)
			if #standing == 0 then
				if firstQueuedAt ~= nil then
					firstQueuedAt = nil
					setSign(IDLE_TEXT)
				end
				continue
			end
			if firstQueuedAt == nil then
				firstQueuedAt = os.clock()
			end
			local fullSize = BallConfig.MATCH_TEAM_SIZE * 2
			-- Humans first: a full pad starts NOW. Otherwise wait for real
			-- players up to QUEUE_BOT_FALLBACK before bots fill — unless
			-- everyone in the server is already queued (no one left to wait
			-- for), which shortens the wait to QUEUE_ALL_IN_TIME.
			local waited = os.clock() - firstQueuedAt
			local allIn = #standing >= #Players:GetPlayers()
			local waitTarget = if allIn then BallConfig.QUEUE_ALL_IN_TIME else BallConfig.QUEUE_BOT_FALLBACK
			if #standing >= fullSize or waited >= waitTarget then
				firstQueuedAt = nil
				if MatchService.StartMatch(standing) then
					setSign("MATCH LIVE")
				else
					setSign(IDLE_TEXT)
				end
			else
				local left = math.ceil(waitTarget - waited)
				setSign(("%d/%d — BOTS IN %d:%02d"):format(#standing, fullSize, left // 60, left % 60))
			end
		end
	end)
end

return QueueService
