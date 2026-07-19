--!strict
-- Ballout | MatchService — Team KO 3v3 (Phase 4)
--
-- One match at a time. Roster comes from QueueService; short teams are
-- filled with bots. Flow:
--   Idle -> Active (teleport in, ball at midcourt, first to MATCH_TARGET_KOS)
--        -> Ending (winner splash MATCH_END_LINGER) -> Idle (everyone home)
--
-- Score comes from BallService.OnKO. The arena scoreboards are the HUD (v1:
-- no client UI). The single global ball moves to the arena for the match and
-- back to the lobby after — the lobby is ball-less while a match runs.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BallConfig = require(ReplicatedStorage.BallConfig)
local BallService = require(ServerScriptService.BallService)
local BotService = require(ServerScriptService.BotService)
local ArenaMap = require(ServerStorage.Maps.ArenaBlockParty)

local MatchService = {}

local state = "Idle" -- "Idle" | "Active" | "Ending"
local score = { Red = 0, Blue = 0 }
local participants: { [Player]: string } = {} -- player -> "Red" | "Blue"
local matchBots: { { model: Model, root: BasePart, team: string, home: CFrame } } = {}
local arena: Model

local TEAM_COLORS = {
	Red = Color3.fromRGB(196, 60, 50),
	Blue = Color3.fromRGB(56, 110, 200),
}

local function spawnCFrame(team: string, slot: number): CFrame
	local marker = arena:FindFirstChild(team .. "Spawn" .. slot) :: BasePart?
	local pos = if marker then marker.Position else Vector3.new(0, 5, 400)
	-- face midcourt
	local ballMarker = arena:FindFirstChild("BallSpawn") :: BasePart?
	local look = if ballMarker then ballMarker.Position else Vector3.new(0, 3, 400)
	return CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z))
end

local function setScoreboards(text: string)
	for _, name in { "ScoreboardN", "ScoreboardS" } do
		local panel = arena:FindFirstChild(name)
		local gui = panel and panel:FindFirstChildOfClass("SurfaceGui")
		local label = gui and gui:FindFirstChild("ScoreLabel")
		if label and label:IsA("TextLabel") then
			label.Text = text
		end
	end
end

local function updateScore()
	setScoreboards(("RED %d — %d BLUE"):format(score.Red, score.Blue))
end

local function lobbyBallSpawn(): Vector3
	local lobby = Workspace:FindFirstChild("BalloutLobby")
	local marker = if lobby then lobby:FindFirstChild("BallSpawn") else nil
	return if marker and marker:IsA("BasePart") then marker.Position else Vector3.new(0, 4, -20)
end

local function garageSpawnCFrame(): CFrame
	local map = Workspace:FindFirstChild("BalloutMap")
	local pad = if map then map:FindFirstChild("GarageSpawn") else nil
	local pos = if pad and pad:IsA("BasePart") then pad.Position + Vector3.new(0, 4, 0) else Vector3.new(-24, 5, -22)
	return CFrame.new(pos)
end

local function despawnBots()
	for _, bot in matchBots do
		BallService.UnregisterFighter(bot.model)
		bot.model:Destroy()
	end
	table.clear(matchBots)
end

local function endMatch(winner: string?)
	if state ~= "Active" then
		return
	end
	state = "Ending"
	if winner then
		setScoreboards(("%s WINS!  (%d — %d)"):format(winner:upper(), score.Red, score.Blue))
	else
		setScoreboards("MATCH ABANDONED")
	end
	task.delay(if winner then BallConfig.MATCH_END_LINGER else 1, function()
		-- send players home + strip teams
		for player, _ in participants do
			local character = player.Character
			if character then
				BallService.SetTeam(character, nil)
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					root.CFrame = garageSpawnCFrame()
				end
			end
		end
		table.clear(participants)
		despawnBots()
		BallService.MakeFree(lobbyBallSpawn())
		setScoreboards("RED 0 — 0 BLUE")
		score.Red, score.Blue = 0, 0
		state = "Idle"
	end)
end

function MatchService.IsActive(): boolean
	return state ~= "Idle"
end

-- Fired by BallService for every KO anywhere; we only score arena teams.
local function onKO(f: { character: Model, root: BasePart, isBot: boolean, player: Player?, team: string? })
	if state ~= "Active" then
		return
	end
	local victimTeam = f.team
	if victimTeam ~= "Red" and victimTeam ~= "Blue" then
		return
	end
	local scorer = if victimTeam == "Red" then "Blue" else "Red"
	score[scorer] += 1
	updateScore()
	-- KO'd bot: hop back to its post after a beat (players respawn via Roblox)
	if f.isBot then
		for _, bot in matchBots do
			if bot.model == f.character then
				task.delay(1.5, function()
					if bot.model.Parent and state == "Active" then
						bot.root.CFrame = bot.home
					end
				end)
				break
			end
		end
	end
	if score[scorer] >= BallConfig.MATCH_TARGET_KOS then
		endMatch(scorer)
	end
end

-- Roster in, match on. Returns false if a match is already running.
function MatchService.StartMatch(queued: { Player }): boolean
	if state ~= "Idle" or #queued == 0 then
		return false
	end
	state = "Active"
	score.Red, score.Blue = 0, 0
	updateScore()

	-- split humans across teams (alternating), cap at 3v3
	local rosters: { [string]: { Player } } = { Red = {}, Blue = {} }
	for i, player in queued do
		if i > BallConfig.MATCH_TEAM_SIZE * 2 then
			break
		end
		local team = if i % 2 == 1 then "Red" else "Blue"
		table.insert(rosters[team], player)
	end

	for _, team in { "Red", "Blue" } do
		local slot = 0
		for _, player in rosters[team] do
			slot += 1
			participants[player] = team
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if character and root and root:IsA("BasePart") then
				BallService.SetTeam(character, team)
				root.CFrame = spawnCFrame(team, slot)
			end
		end
		-- bots fill the rest of the team
		for i = slot + 1, BallConfig.MATCH_TEAM_SIZE do
			local cf = spawnCFrame(team, i)
			local model, root = BotService.Spawn(cf.Position, (arena.BallSpawn :: BasePart).Position)
			model.Name = ("Bot_%s%d"):format(team, i)
			root.Color = TEAM_COLORS[team]
			-- retag the billboard
			local head = model:FindFirstChild("Head")
			local bb = head and head:FindFirstChildOfClass("BillboardGui")
			local label = bb and bb:FindFirstChildOfClass("TextLabel")
			if label then
				label.Text = ("🤖 %s Bot"):format(team)
				label.TextColor3 = TEAM_COLORS[team]
			end
			BallService.RegisterFighter({
				character = model,
				root = root,
				isBot = true,
				player = nil,
				team = team,
				catchChance = BallConfig.MATCH_BOT_CATCH_CHANCE,
			})
			table.insert(matchBots, { model = model, root = root, team = team, home = cf })
		end
	end

	-- ball to midcourt
	BallService.MakeFree((arena.BallSpawn :: BasePart).Position)
	return true
end

-- Called by Main after a respawned character re-registers: put match players
-- back on their team and back in the arena.
function MatchService.HandleRespawn(player: Player, character: Model, root: BasePart)
	local team = participants[player]
	if not team or state ~= "Active" then
		return
	end
	BallService.SetTeam(character, team)
	root.CFrame = spawnCFrame(team, 1)
end

function MatchService.Start()
	arena = ArenaMap.Build()
	BallService.OnKO = onKO
	-- a match with zero humans left is over
	Players.PlayerRemoving:Connect(function(player)
		if participants[player] then
			participants[player] = nil
			local humansLeft = 0
			for _ in participants do
				humansLeft += 1
			end
			if humansLeft == 0 and state == "Active" then
				endMatch(nil)
			end
		end
	end)
end

return MatchService
