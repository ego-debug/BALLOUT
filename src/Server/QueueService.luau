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
		local deadline: number? = nil
		local wasLive = false
		while true do
			task.wait(0.25)
			local pad = findPad()
			if not pad then
				continue
			end
			if MatchService.IsActive() then
				deadline = nil
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
				if deadline ~= nil then
					deadline = nil
					setSign(IDLE_TEXT)
				end
				continue
			end
			if deadline == nil then
				deadline = os.clock() + BallConfig.QUEUE_COUNTDOWN
			end
			local left = deadline - os.clock()
			if left <= 0 then
				deadline = nil
				if MatchService.StartMatch(standing) then
					setSign("MATCH LIVE")
				else
					setSign(IDLE_TEXT)
				end
			else
				setSign(("STARTING IN %d — %d IN"):format(math.ceil(left), #standing))
			end
		end
	end)
end

return QueueService
