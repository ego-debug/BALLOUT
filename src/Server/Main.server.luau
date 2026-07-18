--!strict
-- Ballout | Main (server entry point)
-- Boots the ball system, spawns the training dummy, and registers players.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local BallService = require(ServerScriptService.BallService)
local BotService = require(ServerScriptService.BotService)

print("[Ballout] Booting throw/catch prototype…")

-- Fast respawn: lingering corpses read as "cloned" characters (they hold
-- their pose and even the welded ball until cleanup).
Players.RespawnTime = 2

BallService.Start()

-- Spawn the training dummy on its own (lower) training roof, KC-style.
-- The map marks the spot with a "DummyPad" part; fall back to midfield.
local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
local center = spawn and spawn.Position or Vector3.new(0, 3, 0)
local hqMap = Workspace:FindFirstChild("BalloutMap")
local dummyPad = hqMap and hqMap:FindFirstChild("DummyPad")
local botPos = if dummyPad and dummyPad:IsA("BasePart")
	then dummyPad.Position + Vector3.new(0, 0.9, 0)
	else center + Vector3.new(0, 0, -40)
local botModel, botRoot = BotService.Spawn(botPos, Vector3.new(0, 0, -20))

BallService.RegisterFighter({
	character = botModel,
	root = botRoot,
	isBot = true,
	player = nil,
	team = "Dummies",
})

-- Register players (and re-register on respawn).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BallConfig = require(ReplicatedStorage.BallConfig)

local function onCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	-- Uniform movement stats for everyone (tuned in BallConfig).
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.WalkSpeed = BallConfig.WALK_SPEED
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = BallConfig.JUMP_HEIGHT
	end
	-- Limbs are ALWAYS massless (root carries all mass): animated limb
	-- movement (tuck poses, IK) would otherwise impart reaction forces
	-- that shove the body around — the Q-flip "fling" bug.
	local function limbMassless(inst: Instance)
		if inst:IsA("BasePart") and inst.Name ~= "HumanoidRootPart" then
			inst.Massless = true
		end
	end
	for _, inst in character:GetDescendants() do
		limbMassless(inst)
	end
	character.DescendantAdded:Connect(limbMassless)
	BallService.RegisterFighter({
		character = character,
		root = root,
		isBot = false,
		player = player,
		team = "Ballers", -- all players together (vs the dummy) for now
	})
	-- On death: release the ball and clean up IMMEDIATELY — never leave a
	-- corpse holding the ball (the "clone" illusion).
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			BallService.UnregisterFighter(character)
		end)
	end
end

local function onPlayer(player: Player)
	if player.Character then
		onCharacter(player, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	player.CharacterRemoving:Connect(function(char)
		BallService.UnregisterFighter(char)
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end

-- Dev bridge: lets MCP test scripts drive throws inside the game's VM
-- (execute_luau runs in a separate Luau VM, so require() there can't reach
-- this VM's module state).
local debugFn = Instance.new("BindableFunction")
debugFn.Name = "BalloutDebug"
debugFn.OnInvoke = function(cmd: string, character: Model, frac: number?, curve: number?, lob: boolean?, aim: Vector3?, aimPoint: Vector3?)
	if cmd == "throw" then
		local f = BallService.DebugFighter(character)
		if not f then
			return "no fighter"
		end
		BallService.Throw(f, frac or 1, curve or 0, lob == true, aim, aimPoint)
		return "thrown"
	elseif cmd == "state" then
		return BallService.DebugState()
	end
	return "unknown cmd"
end
debugFn.Parent = game:GetService("ServerStorage")

-- The HQ soccer court's giant ball is pure physics — if it gets punted off
-- the roof, put it back on the court.
task.spawn(function()
	while true do
		task.wait(3)
		local m = Workspace:FindFirstChild("BalloutMap")
		local sb = m and m:FindFirstChild("SoccerBall")
		if sb and sb:IsA("BasePart") and sb.Position.Y < -60 then
			sb.AssemblyLinearVelocity = Vector3.zero
			sb.AssemblyAngularVelocity = Vector3.zero
			sb.CFrame = CFrame.new(105, -2.5, -65)
		end
	end
end)

print("[Ballout] Prototype ready. Walk into the ball to pick it up, hold LMB to charge & throw, RMB to catch.")
