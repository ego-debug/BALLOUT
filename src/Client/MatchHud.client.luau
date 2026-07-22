--!strict
-- Ballout | Match HUD
--
-- On-screen match state, driven by Remotes.MatchState broadcasts.
-- Functional layout follows arena-game convention (score top-center, KO feed
-- under it, big banners for match beats) — visual design is Ballout's own
-- neon-city look, per the project rule: original UI, never copied art.

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
board.Size = UDim2.fromOffset(340, 64)
board.BackgroundTransparency = 1
board.Parent = gui

local function teamPanel(name: string, color: Color3, onLeft: boolean): (Frame, TextLabel, Frame)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(if onLeft then 0 else 1, 0)
	panel.Position = UDim2.new(if onLeft then 0 else 1, 0, 0, 0)
	panel.Size = UDim2.fromOffset(130, 54)
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

	-- your-team underline (hidden until we know your side)
	local mine = Instance.new("Frame")
	mine.Name = "Mine"
	mine.AnchorPoint = Vector2.new(0.5, 1)
	mine.Position = UDim2.new(0.5, 0, 1, 6)
	mine.Size = UDim2.fromOffset(84, 3)
	mine.BackgroundColor3 = NEON
	mine.BorderSizePixel = 0
	mine.Visible = false
	mine.Parent = panel
	local mc = Instance.new("UICorner")
	mc.CornerRadius = UDim.new(1, 0)
	mc.Parent = mine

	return panel, num, mine
end

local _, redCount, redMine = teamPanel("Red", RED, true)
local _, blueCount, blueMine = teamPanel("Blue", BLUE, false)

local mid = Instance.new("TextLabel")
mid.BackgroundTransparency = 1
mid.Font = Enum.Font.GothamBold
mid.TextSize = 13
mid.TextColor3 = NEON
mid.Text = "FIRST TO 10"
mid.AnchorPoint = Vector2.new(0.5, 0)
mid.Position = UDim2.new(0.5, 0, 0, 20)
mid.Size = UDim2.fromOffset(90, 30)
mid.Parent = board

-- ── KO feed line (under the scoreboard, fades out) ──────────────────────────
local feed = Instance.new("TextLabel")
feed.BackgroundTransparency = 1
feed.Font = Enum.Font.GothamBold
feed.TextSize = 16
feed.TextColor3 = WHITE
feed.TextStrokeTransparency = 0.5
feed.Text = ""
feed.AnchorPoint = Vector2.new(0.5, 0)
feed.Position = UDim2.new(0.5, 0, 0, 84)
feed.Size = UDim2.fromOffset(420, 20)
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
	local t = TweenService:Create(feed, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.6), { TextTransparency = 1 })
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

-- ── State sync ──────────────────────────────────────────────────────────────
Remotes.MatchState.OnClientEvent:Connect(function(data: { [string]: any })
	local state = data.state
	if state == "Idle" then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	redCount.Text = tostring(data.red or 0)
	blueCount.Text = tostring(data.blue or 0)
	mid.Text = ("FIRST TO %d"):format(data.target or 10)

	-- highlight your side
	local myTeam = data.teams and data.teams[player.Name]
	redMine.Visible = myTeam == "Red"
	blueMine.Visible = myTeam == "Blue"

	if data.event == "start" then
		showBanner("MATCH START — FIRST TO " .. tostring(data.target or 10), NEON, 2)
	elseif data.event == "ko" then
		local color = if data.victimTeam == "Red" then RED else BLUE
		showFeed(("%s got KO'd!"):format(tostring(data.victim)), color)
	end

	if state == "Ending" then
		if data.winner then
			local color = if data.winner == "Red" then RED else BLUE
			showBanner(("%s WINS!"):format(string.upper(data.winner)), color, 3)
		else
			showBanner("MATCH ABANDONED", Color3.fromRGB(180, 180, 180), 2)
		end
	end
end)
