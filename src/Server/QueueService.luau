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

local function findPad(): BasePart?
	local map = Workspace:FindFirstChild("BalloutMap")
	local pad = if map then map:FindFirstChild("QueuePadTeamKO") else nil
	return if pad and pad:IsA("BasePart") then pad else nil
end

local function setSign(text: string)
	local map = Workspace:FindFirstChild("BalloutMap")
	local panel = if map then map:FindFirstChild("QueuePadTeamKOSign") else nil
	local gui = if panel then panel:FindFirstChildOfClass("SurfaceGui") else nil
	local label = if gui then gui:FindFirstChildOfClass("TextLabel") else nil
	if label then
		label.Text = text
	end
end

local function playersOnPad(pad: BasePart): { Player }
	local standing = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local rel = root.Position - pad.Position
			if math.abs(rel.X) <= pad.Size.X / 2 + 1.5
				and math.abs(rel.Z) <= pad.Size.Z / 2 + 1.5
				and rel.Y > -1 and rel.Y < 8 then
				table.insert(standing, player)
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
			local pad = findPad()
			if not pad then
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
			local standing = playersOnPad(pad)
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
