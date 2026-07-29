--!strict
-- Ballout | Match HUD (KC-functional)
--
-- Mirrors Knockout City's in-match HUD FUNCTIONALLY (visual design is
-- Ballout's own neon-city look — original UI, never copied art):
--   * top-center team scores, first-to-N target, map name
--   * squad tiles under each score: every combatant's name, LIVE 2-hit HP
--     pips, ball-possession dot, KO/respawn state (yours is highlighted)
--   * KO feed with killer credit ("X knocked out Y!", "Y fell!")
--   * round intro: map splash -> 3 - 2 - 1 - GO! (ball drops at GO)
--   * personal beats: "KNOCKED OUT!" when you die, "KO!" when you score
--   * end: VICTORY! / DEFEAT for players, "X WINS!" for spectators
--
-- Driven entirely by Remotes.MatchState payloads (MatchService announces on
-- events + a 0.5s live ticker while a match runs).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Remotes)

local player = Players.LocalPlayer

local RED = Color3.fromRGB(255, 82, 70)
local BLUE = Color3.fromRGB(80, 150, 255)
local PANEL = Color3.fromRGB(16, 14, 22)
local NEON = Color3.fromRGB(64, 224, 255)
local WHITE = Color3.fromRGB(240, 240, 245)
local GOLD = Color3.fromRGB(255, 214, 90)
local DIM = Color3.fromRGB(130, 130, 140)
local ORANGE = Color3.fromRGB(255, 150, 40)

local TEAM_COLOR: { [string]: Color3 } = { Red = RED, Blue = BLUE }

local gui = Instance.new("ScreenGui")
gui.Name = "BalloutMatchHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- ── Scoreboard (top center) ─────────────────────────────────────────────────
local board = Instance.new("Frame")
board.Name = "Score"
board.AnchorPoint = Vector2.new(0.5, 0)
board.Position = UDim2.new(0.5, 0, 0, 14)
board.Size = UDim2.fromOffset(380, 64)
board.BackgroundTransparency = 1
board.Parent = gui

local function teamPanel(name: string, color: Color3, onLeft: boolean): (Frame, TextLabel)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(if onLeft then 0 else 1, 0)
	panel.Position = UDim2.new(if onLeft then 0 else 1, 0, 0, 0)
	panel.Size = UDim2.fromOffset(140, 54)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.25
	panel.Parent = board
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Transparency = 0.35
	stroke.Parent = panel

	local tag = Instance.new("TextLabel")
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.GothamBlack
	tag.TextSize = 14
	tag.TextColor3 = color
	tag.Text = name:upper()
	tag.Size = UDim2.new(1, 0, 0, 16)
	tag.Position = UDim2.fromOffset(0, 4)
	tag.Parent = panel

	local num = Instance.new("TextLabel")
	num.Name = "Count"
	num.BackgroundTransparency = 1
	num.Font = Enum.Font.GothamBlack
	num.TextSize = 28
	num.TextColor3 = WHITE
	num.Text = "0"
	num.Size = UDim2.new(1, 0, 0, 30)
	num.Position = UDim2.fromOffset(0, 20)
	num.Parent = panel

	return panel, num
end

local redPanel, redCount = teamPanel("Red", RED, true)
local bluePanel, blueCount = teamPanel("Blue", BLUE, false)

local mid = Instance.new("TextLabel")
mid.BackgroundTransparency = 1
mid.Font = Enum.Font.GothamBold
mid.TextSize = 13
mid.TextColor3 = NEON
mid.Text = "FIRST TO 10"
mid.AnchorPoint = Vector2.new(0.5, 0)
mid.Position = UDim2.new(0.5, 0, 0, 12)
mid.Size = UDim2.fromOffset(90, 30)
mid.Parent = board

-- Round pips (best-of-3): one dot per round win, each side of the center.
local pips: { [string]: { Frame } } = { Red = {}, Blue = {} }
for _, team in { "Red", "Blue" } do
	for i = 1, 2 do
		local pip = Instance.new("Frame")
		pip.AnchorPoint = Vector2.new(0.5, 0)
		local sideSign = if team == "Red" then -1 else 1
		pip.Position = UDim2.new(0.5, sideSign * (52 + (i - 1) * 14), 0, 2)
		pip.Size = UDim2.fromOffset(9, 9)
		pip.BackgroundColor3 = Color3.fromRGB(45, 42, 52)
		pip.Parent = board
		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(1, 0)
		pc.Parent = pip
		pips[team][i] = pip
	end
end

local function updatePips(redWins: number, blueWins: number)
	for i, pip in pips.Red do
		pip.BackgroundColor3 = if i <= redWins then RED else Color3.fromRGB(45, 42, 52)
	end
	for i, pip in pips.Blue do
		pip.BackgroundColor3 = if i <= blueWins then BLUE else Color3.fromRGB(45, 42, 52)
	end
end

local mapLabel = Instance.new("TextLabel")
mapLabel.BackgroundTransparency = 1
mapLabel.Font = Enum.Font.GothamBold
mapLabel.TextSize = 11
mapLabel.TextColor3 = DIM
mapLabel.Text = ""
mapLabel.AnchorPoint = Vector2.new(0.5, 0)
mapLabel.Position = UDim2.new(0.5, 0, 0, 36)
mapLabel.Size = UDim2.fromOffset(120, 14)
mapLabel.Parent = board

-- ── Squad tiles (KC: live status for every combatant, under the scores) ─────
local TILE_H = 24

local function tileStack(parent: Frame, onLeft: boolean): Frame
	local stack = Instance.new("Frame")
	stack.Name = "Tiles"
	stack.AnchorPoint = Vector2.new(if onLeft then 0 else 1, 0)
	stack.Position = UDim2.new(if onLeft then 0 else 1, 0, 1, 6)
	stack.Size = UDim2.fromOffset(140, TILE_H * 3 + 8)
	stack.BackgroundTransparency = 1
	stack.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = stack
	return stack
end

local redTiles = tileStack(redPanel, true)
local blueTiles = tileStack(bluePanel, false)

local function makeTile(parent: Frame, entry: { [string]: any }, teamColor: Color3, order: number)
	local isMe = entry.name == player.Name
	local dead = entry.dead == true

	local tile = Instance.new("Frame")
	tile.LayoutOrder = order
	tile.Size = UDim2.new(1, 0, 0, TILE_H)
	tile.BackgroundColor3 = PANEL
	tile.BackgroundTransparency = if dead then 0.6 else 0.3
	tile.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = tile
	if isMe then
		local stroke = Instance.new("UIStroke")
		stroke.Color = NEON
		stroke.Thickness = 1.5
		stroke.Transparency = 0.2
		stroke.Parent = tile
	end

	-- name (struck dim while KO'd)
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Font = if isMe then Enum.Font.GothamBlack else Enum.Font.GothamBold
	name.TextSize = 11
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextColor3 = if dead then DIM else WHITE
	name.Text = if dead then "✕ " .. tostring(entry.name) else tostring(entry.name)
	name.Position = UDim2.fromOffset(8, 0)
	name.Size = UDim2.new(1, -60, 1, 0)
	name.Parent = tile

	-- ball possession dot
	if entry.holding and not dead then
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(1, 0.5)
		dot.Position = UDim2.new(1, -44, 0.5, 0)
		dot.Size = UDim2.fromOffset(9, 9)
		dot.BackgroundColor3 = ORANGE
		dot.Parent = tile
		local dc = Instance.new("UICorner")
		dc.CornerRadius = UDim.new(1, 0)
		dc.Parent = dot
	end

	-- HP pips (the 2-hit model, live)
	local hp = tonumber(entry.hp) or 0
	for i = 1, 2 do
		local pip = Instance.new("Frame")
		pip.AnchorPoint = Vector2.new(1, 0.5)
		pip.Position = UDim2.new(1, -8 - (2 - i) * 16, 0.5, 0)
		pip.Size = UDim2.fromOffset(12, 8)
		pip.BackgroundColor3 = if i <= hp and not dead then teamColor else Color3.fromRGB(45, 42, 52)
		pip.Parent = tile
		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0, 3)
		pc.Parent = pip
	end
end

local function updateTiles(roster: { { [string]: any } }?)
	redTiles:ClearAllChildren()
	blueTiles:ClearAllChildren()
	local rl = Instance.new("UIListLayout")
	rl.Padding = UDim.new(0, 4)
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	rl.Parent = redTiles
	local bl = rl:Clone()
	bl.Parent = blueTiles
	if not roster then
		return
	end
	-- humans above bots, self first among humans
	table.sort(roster, function(a, b)
		local aScore = (if a.name == player.Name then 0 elseif a.isBot then 2 else 1)
		local bScore = (if b.name == player.Name then 0 elseif b.isBot then 2 else 1)
		if aScore ~= bScore then
			return aScore < bScore
		end
		return tostring(a.name) < tostring(b.name)
	end)
	local counts = { Red = 0, Blue = 0 }
	for _, entry in roster do
		local team = tostring(entry.team)
		local stack = if team == "Red" then redTiles else if team == "Blue" then blueTiles else nil
		if stack then
			counts[team] += 1
			makeTile(stack, entry, TEAM_COLOR[team] or WHITE, counts[team])
		end
	end
end

-- ── KO feed line (under the tiles, fades out) ───────────────────────────────
local feed = Instance.new("TextLabel")
feed.BackgroundTransparency = 1
feed.Font = Enum.Font.GothamBold
feed.TextSize = 16
feed.TextColor3 = WHITE
feed.TextStrokeTransparency = 0.5
feed.Text = ""
feed.AnchorPoint = Vector2.new(0.5, 0)
feed.Position = UDim2.new(0.5, 0, 0, 84)
feed.Size = UDim2.fromOffset(460, 20)
feed.TextTransparency = 1
feed.Parent = gui

local feedTween: Tween? = nil
local function showFeed(text: string, color: Color3)
	feed.Text = text
	feed.TextColor3 = color
	feed.TextTransparency = 0
	if feedTween then
		feedTween:Cancel()
	end
	local t = TweenService:Create(feed, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 2.2), { TextTransparency = 1 })
	feedTween = t
	t:Play()
end

-- ── Center banner (match beats) ─────────────────────────────────────────────
local banner = Instance.new("TextLabel")
banner.BackgroundTransparency = 1
banner.Font = Enum.Font.GothamBlack
banner.TextSize = 44
banner.TextColor3 = WHITE
banner.TextStrokeColor3 = Color3.fromRGB(20, 16, 30)
banner.TextStrokeTransparency = 0.2
banner.Text = ""
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.new(0.5, 0, 0.3, 0)
banner.Size = UDim2.fromOffset(700, 60)
banner.Visible = false
banner.Parent = gui

local bannerTween: Tween? = nil
local function showBanner(text: string, color: Color3, holdFor: number)
	banner.Text = text
	banner.TextColor3 = color
	banner.TextTransparency = 0
	banner.Visible = true
	if bannerTween then
		bannerTween:Cancel()
	end
	local t = TweenService:Create(banner, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, holdFor), { TextTransparency = 1 })
	bannerTween = t
	t:Play()
end

-- ── Countdown (big center pop: 3 - 2 - 1 - GO!) ─────────────────────────────
local count = Instance.new("TextLabel")
count.BackgroundTransparency = 1
count.Font = Enum.Font.GothamBlack
count.TextColor3 = WHITE
count.TextStrokeColor3 = Color3.fromRGB(20, 16, 30)
count.TextStrokeTransparency = 0.15
count.Text = ""
count.AnchorPoint = Vector2.new(0.5, 0.5)
count.Position = UDim2.new(0.5, 0, 0.42, 0)
count.Size = UDim2.fromOffset(300, 130)
count.TextSize = 100
count.Visible = false
count.Parent = gui
local countScale = Instance.new("UIScale")
countScale.Parent = count

local countTween: Tween? = nil
local function popCount(text: string, color: Color3)
	count.Text = text
	count.TextColor3 = color
	count.TextTransparency = 0
	count.Visible = true
	countScale.Scale = 1.6
	if countTween then
		countTween:Cancel()
	end
	local shrink = TweenService:Create(countScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	shrink:Play()
	local fade = TweenService:Create(count, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.55), { TextTransparency = 1 })
	countTween = fade
	fade:Play()
end

-- ── State sync ──────────────────────────────────────────────────────────────
local myTeam: string? = nil

Remotes.MatchState.OnClientEvent:Connect(function(data: { [string]: any })
	local state = data.state
	if state == "Idle" then
		gui.Enabled = false
		myTeam = nil
		return
	end
	gui.Enabled = true
	redCount.Text = tostring(data.red or 0)
	blueCount.Text = tostring(data.blue or 0)
	mid.Text = ("RD %d · TO %d"):format(data.round or 1, data.target or 10)
	updatePips(data.roundsRed or 0, data.roundsBlue or 0)
	if data.mapName then
		mapLabel.Text = tostring(data.mapName)
	end
	myTeam = data.teams and data.teams[player.Name]
	updateTiles(data.roster)

	-- event beats
	if data.event == "start" then
		showBanner(("%s — BEST OF 3 · FIRST TO %d"):format(tostring(data.mapName or "MATCH"), data.target or 10), NEON, 1.6)
	elseif data.event == "countdown" then
		popCount(tostring(data.n), WHITE)
	elseif data.event == "go" then
		popCount("GO!", GOLD)
	elseif data.event == "round" then
		local winner = tostring(data.roundWinner)
		local color = TEAM_COLOR[winner] or WHITE
		if myTeam then
			showBanner(if winner == myTeam then "ROUND WON!" else "ROUND LOST", color, 2.5)
		else
			showBanner(("%s TAKES THE ROUND!"):format(winner:upper()), color, 2.5)
		end
	elseif data.event == "roundstart" then
		showBanner(("ROUND %d"):format(data.round or 2), NEON, 1.4)
	elseif data.event == "ko" then
		local victim = tostring(data.victim)
		local killer = data.killer and tostring(data.killer) or nil
		local color = TEAM_COLOR[tostring(data.victimTeam)] or WHITE
		if data.cause == "fall" then
			showFeed(("%s fell off the block!"):format(victim), color)
		elseif killer then
			showFeed(("%s knocked out %s!"):format(killer, victim), color)
		else
			showFeed(("%s got KO'd!"):format(victim), color)
		end
		-- personal beats, KC-style
		if victim == player.Name then
			showBanner("KNOCKED OUT!", RED, 1.2)
		elseif killer == player.Name then
			showBanner("KO!", GOLD, 1.0)
		end
	end

	if state == "Ending" then
		if data.winner then
			local winner = tostring(data.winner)
			if myTeam then
				if winner == myTeam then
					showBanner("VICTORY!", GOLD, 4)
				else
					showBanner("DEFEAT", DIM, 4)
				end
			else
				showBanner(("%s WINS!"):format(winner:upper()), TEAM_COLOR[winner] or WHITE, 3)
			end
		else
			showBanner("MATCH ABANDONED", DIM, 2)
		end
	end
end)
