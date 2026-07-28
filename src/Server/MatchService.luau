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
local Remotes = require(ReplicatedStorage.Remotes)
local BallService = require(ServerScriptService.BallService)
local BotService = require(ServerScriptService.BotService)
local BotAI = require(ServerScriptService.BotAI)
-- Scaffold Row replaced Block Party as the match arena (see STATUS.md);
-- ArenaBlockParty stays in Maps/ for a future rotation.
local ArenaMap = require(ServerStorage.Maps.ArenaScaffoldRow)

local MatchService = {}

local state = "Idle" -- "Idle" | "Countdown" | "Active" | "Ending"
local score = { Red = 0, Blue = 0 }
local participants: { [Player]: string } = {} -- player -> "Red" | "Blue"
local matchBots: { { model: Model, root: BasePart, team: string, home: CFrame } } = {}
local arena: Model?
-- Dedupe for fall deaths: a thrown KO also kills the humanoid, so Died fires
-- right after onKO. Only a Died with no recent scored KO is a fall.
local recentKO: { [Model]: number } = {}
local diedConns: { [Model]: RBXScriptConnection } = {}

local TEAM_COLORS = {
	Red = Color3.fromRGB(196, 60, 50),
	Blue = Color3.fromRGB(56, 110, 200),
}

local function arenaBallPos(): Vector3
	local marker = arena and arena:FindFirstChild("BallSpawn")
	return if marker and marker:IsA("BasePart") then marker.Position else Vector3.new(0, 5, -650)
end

local function spawnCFrame(team: string, slot: number): CFrame
	local marker = arena and arena:FindFirstChild(team .. "Spawn" .. slot) :: BasePart?
	local pos = if marker then marker.Position else Vector3.new(0, 5, -650)
	-- face midcourt
	local look = arenaBallPos()
	return CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z))
end

local function setScoreboards(text: string)
	for _, name in { "ScoreboardN", "ScoreboardS" } do
		local panel = arena and arena:FindFirstChild(name)
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

-- KC-style roster for the HUD: every combatant (humans AND bots) with
-- team, live HP (2-hit model), ball possession, and KO/respawn state.
local function buildRoster(): { { [string]: any } }
	local roster = {}
	for plr, team in participants do
		local character = plr.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local dead = not character or not hum or hum.Health <= 0
		local status = if character then BallService.FighterStatus(character) else { hits = 0, holding = false }
		table.insert(roster, {
			name = plr.Name,
			team = team,
			hp = if dead then 0 else math.max(0, BallConfig.HITS_TO_KO - status.hits),
			holding = status.holding and not dead,
			dead = dead,
			isBot = false,
		})
	end
	for _, bot in matchBots do
		local status = BallService.FighterStatus(bot.model)
		table.insert(roster, {
			name = bot.model.Name:gsub("Bot_", ""):gsub("(%a+)(%d)", "%1 Bot %2"),
			team = bot.team,
			hp = math.max(0, BallConfig.HITS_TO_KO - status.hits),
			holding = status.holding,
			dead = false, -- bots hop straight back to their post
			isBot = true,
		})
	end
	return roster
end

-- HUD sync: every client mirrors match state on-screen (arena scoreboards
-- stay as the in-world set dressing). `extra` merges into the payload.
local function announce(extra: { [string]: any }?)
	local teams: { [string]: string } = {}
	for plr, team in participants do
		teams[plr.Name] = team
	end
	local payload: { [string]: any } = {
		state = state,
		red = score.Red,
		blue = score.Blue,
		target = BallConfig.MATCH_TARGET_KOS,
		teams = teams,
		roster = buildRoster(),
		mapName = ArenaMap.DisplayName,
	}
	if extra then
		for k, v in extra do
			payload[k] = v
		end
	end
	Remotes.MatchState:FireAllClients(payload)
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
		BotAI.Unregister(bot.model)
		BallService.UnregisterFighter(bot.model)
		bot.model:Destroy()
	end
	table.clear(matchBots)
end

local function endMatch(winner: string?)
	if state ~= "Active" and state ~= "Countdown" then
		return
	end
	state = "Ending"
	if winner then
		setScoreboards(("%s WINS!  (%d — %d)"):format(winner:upper(), score.Red, score.Blue))
	else
		setScoreboards("MATCH ABANDONED")
	end
	announce({ winner = winner })
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
		for _, conn in diedConns do
			conn:Disconnect()
		end
		table.clear(diedConns)
		table.clear(recentKO)
		-- ball home: back to the lobby, and the void-respawn point with it
		BallService.SetPrimarySpawn(lobbyBallSpawn())
		BallService.MakeFree(lobbyBallSpawn())
		setScoreboards("RED 0 — 0 BLUE")
		score.Red, score.Blue = 0, 0
		state = "Idle"
		announce()
	end)
end

function MatchService.IsActive(): boolean
	return state ~= "Idle"
end

-- Pretty display name for feeds ("Bot_Red2" -> "Red Bot 2").
local function combatantName(model: Model): string
	return (model.Name:gsub("Bot_", ""):gsub("(%a+)(%d)", "%1 Bot %2"))
end

-- One KO scored for the enemy of `victimTeam`, whatever the cause.
local function scoreKO(victimTeam: string, victimName: string, killerName: string?, cause: string?)
	local scorer = if victimTeam == "Red" then "Blue" else "Red"
	score[scorer] += 1
	updateScore()
	announce({ event = "ko", victim = victimName, victimTeam = victimTeam, killer = killerName, cause = cause })
	if score[scorer] >= BallConfig.MATCH_TARGET_KOS then
		endMatch(scorer)
	end
end

-- Fired by BallService for every thrown KO anywhere; we only score arena teams.
local function onKO(f: { character: Model, root: BasePart, isBot: boolean, player: Player?, team: string? }, killer: Model?)
	if state ~= "Active" then
		return
	end
	local victimTeam = f.team
	if victimTeam ~= "Red" and victimTeam ~= "Blue" then
		return
	end
	recentKO[f.character] = os.clock() -- the Died that follows is NOT a fall
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
	scoreKO(victimTeam, combatantName(f.character), if killer then combatantName(killer) else nil, "throw")
end

-- Falling off Scaffold Row (void pits, wrecking-ball punts, the 4 edge gaps)
-- KOs you — KC rules. A Died with no freshly-scored throw KO is a fall.
local function hookFallDeath(player: Player, character: Model)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if diedConns[character] then
		diedConns[character]:Disconnect()
	end
	diedConns[character] = hum.Died:Connect(function()
		if state ~= "Active" then
			return
		end
		local team = participants[player]
		if not team then
			return
		end
		if os.clock() - (recentKO[character] or -math.huge) < 1.5 then
			return -- already scored as a thrown KO
		end
		scoreKO(team, player.Name, nil, "fall")
	end)
end

-- Roster in, match on. Returns false if a match is already running.
function MatchService.StartMatch(queued: { Player }): boolean
	if state ~= "Idle" or #queued == 0 or arena == nil then
		return false
	end
	state = "Countdown"
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
				hookFallDeath(player, character)
			end
		end
		-- bots fill the rest of the team
		for i = slot + 1, BallConfig.MATCH_TEAM_SIZE do
			local cf = spawnCFrame(team, i)
			local model, root = BotService.Spawn(cf.Position, arenaBallPos())
			model.Name = ("Bot_%s%d"):format(team, i)
			-- team-color the robot's accent parts (root is invisible)
			for _, partName in { "Torso", "Visor", "Core" } do
				local p = model:FindFirstChild(partName)
				if p and p:IsA("BasePart") then
					p.Color = TEAM_COLORS[team]
				end
			end
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
			-- give it a brain: wander, chase the ball, close in and throw
			BotAI.Register(model, root, team, cf.Position)
		end
	end

	-- KC-style round intro: everyone's placed, big 3-2-1-GO on every HUD,
	-- and the ball only drops at GO — no head start on the scramble.
	announce({ event = "start" })
	task.spawn(function()
		task.wait(0.8) -- let the map-name splash breathe
		for n = 3, 1, -1 do
			if state ~= "Countdown" then
				return -- abandoned mid-countdown
			end
			announce({ event = "countdown", n = n })
			task.wait(1)
		end
		if state ~= "Countdown" then
			return
		end
		state = "Active"
		-- ball to midcourt; void pits respawn it right back at midcourt too
		BallService.SetPrimarySpawn(arenaBallPos())
		BallService.MakeFree(arenaBallPos())
		announce({ event = "go" })
	end)
	return true
end

-- Called by Main after a respawned character re-registers: put match players
-- back on their team and back in the arena.
function MatchService.HandleRespawn(player: Player, character: Model, root: BasePart)
	local team = participants[player]
	if not team or (state ~= "Active" and state ~= "Countdown") then
		return
	end
	BallService.SetTeam(character, team)
	root.CFrame = spawnCFrame(team, 1)
	hookFallDeath(player, character) -- fresh character, fresh Died hook
end

function MatchService.Start()
	arena = ArenaMap.Build()
	if arena then
		print("[Ballout] Match arena ready: " .. ArenaMap.DisplayName)
	else
		warn("[Ballout] Scaffold Row blockout missing — matches disabled")
	end
	BallService.OnKO = onKO
	-- KC-style HUD needs LIVE rosters (HP pips, ball possession, KO states),
	-- not just event edges — tick the full payload out while a match runs.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if state == "Active" or state == "Countdown" then
				announce()
			end
		end
	end)
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
