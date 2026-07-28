--!strict
-- Ballout | Main (server entry point)
-- Boots the ball system, spawns the training dummy, and registers players.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BallService = require(ServerScriptService.BallService)
local BotService = require(ServerScriptService.BotService)
local AvatarService = require(ServerScriptService.AvatarService)
local MatchService = require(ServerScriptService.MatchService)
local QueueService = require(ServerScriptService.QueueService)
local HazardService = require(ServerScriptService.HazardService)
local CarryService = require(ServerScriptService.CarryService)
local LobbyMap = require(ServerStorage.Maps.Lobby)

print("[Ballout] Booting throw/catch prototype…")

-- Fast respawn: lingering corpses read as "cloned" characters (they hold
-- their pose and even the welded ball until cleanup).
Players.RespawnTime = 2

-- Lobby overlay FIRST (safe zone + ball spawn markers over the HQ city):
-- BallService.Start reads its BallSpawn marker.
LobbyMap.Build()

BallService.Start()
MatchService.Start() -- builds the arena, hooks KO scoring
QueueService.Start() -- watches the queue-room pads
HazardService.Start() -- swings the wrecking balls, runs the pit ferries
CarryService.Start() -- scoop balled-up players, chains + break-out mash

-- Spawn the training dummy on its own (lower) training roof, KC-style.
-- The map marks the spot with a "DummyPad" part; fall back to midfield.
local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
local center = spawn and spawn.Position or Vector3.new(0, 3, 0)
local hqMap = Workspace:FindFirstChild("BalloutMap")
local dummyPad = hqMap and hqMap:FindFirstChild("DummyPad")
local botPos = if dummyPad and dummyPad:IsA("BasePart")
	then dummyPad.Position + Vector3.new(0, 0.9, 0)
	else center + Vector3.new(0, 0, -40)
local botModel, botRoot = BotService.Spawn(botPos, botPos + Vector3.new(0, 0, 50)) -- face due north, same as the owner stood

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
		-- ...and one canonical BODY for everyone. Equal jump height is not
		-- equal reach: a taller avatar clears a higher ledge on the same jump
		-- and is a bigger target. Locking scale keeps the map's climb gates
		-- honest and keeps future cosmetics purely cosmetic.
		AvatarService.Normalize(humanoid)
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
		team = nil, -- lobby free-for-all: nil team = lockable/hittable by anyone
	})
	-- On death: release the ball and clean up IMMEDIATELY — never leave a
	-- corpse holding the ball (the "clone" illusion).
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			BallService.UnregisterFighter(character)
		end)
	end
	-- Mid-match respawns go back to the arena on their team (no-op in lobby).
	MatchService.HandleRespawn(player, character, root)
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
	elseif cmd == "locks" then
		return BallService.DebugLocks(character)
	elseif cmd == "catch" then
		BallService.RegisterCatch(character)
		return "catch registered"
	elseif cmd == "scoop" then
		-- character = the CARRIER; the victim is the first balled player found
		local CarryService = require(ServerScriptService.CarryService)
		local plr = game:GetService("Players"):GetPlayers()[1]
		if plr and plr.Character then
			return CarryService.ForceScoop(character, plr.Character) and "scooped" or "scoop failed"
		end
		return "no victim"
	elseif cmd == "carrythrow" then
		local CarryService = require(ServerScriptService.CarryService)
		return CarryService.ForceThrow(character, aim) and "thrown" or "throw failed"
	elseif cmd == "carrystate" then
		local CarryService = require(ServerScriptService.CarryService)
		return CarryService.DebugState(character)
	end
	return "unknown cmd"
end
debugFn.Parent = game:GetService("ServerStorage")

print("[Ballout] Prototype ready. Walk into the ball to pick it up, hold LMB to charge & throw, RMB to catch.")
