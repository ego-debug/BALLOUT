--!strict
-- Ballout | CarryService — pick up players in ballform (KC ball-up carry)
--
-- Walk into a balled-up player with empty hands and you scoop them overhead.
-- The scooped player STAYS balled — no need to keep the ballform key down.
--
--   FRIENDLY scoop: a willing ride. One Space press hops them out; thrown,
--   they're a free ball on landing (KC's teammate super-throw).
--
--   ENEMY scoop: CHAINS wrap the ball. The victim must mash Space
--   PLAYER_BALL_BREAK_PRESSES times to burst free — a floating counter over
--   the ball (and their own HUD) shows presses left, chains flash on every
--   press. Being thrown does NOT free them: they fly, land, and keep mashing.
--
--   A THROWN player-ball is an INSTANT KO on any enemy of the thrower it
--   touches — hearts don't matter (safe-zone rule still wins in the lobby).
--
-- Physics: the victim's root welds to the carrier overhead (one assembly, the
-- carrier's client owns it — zero lag). Thrown flight reuses the proven
-- wreck-launch pattern: PlatformStand + per-frame horizontal re-assert,
-- gravity shapes the arc, server owns the root for the duration.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local BallConfig = require(ReplicatedStorage.BallConfig)
local Remotes = require(ReplicatedStorage.Remotes)
local SoundKit = require(ReplicatedStorage.SoundKit)
local BallService = require(ServerScriptService.BallService)
local BallformService = require(ServerScriptService.BallformService)

local CarryService = {}

type Carry = {
	victim: Model,
	victimRoot: BasePart,
	victimPlayer: Player?,
	carrier: Model?, -- nil once thrown/dropped
	weld: WeldConstraint?,
	chained: boolean,
	pressesLeft: number,
	chainsModel: Model?,
	countLabel: TextLabel?,
	state: string, -- "held" | "flying" | "grounded"
	thrower: Model?,
	flyFrom: number,
	flyUntil: number,
	flyVel: Vector3,
	koVictims: { [Model]: boolean }, -- KO'd once per flight each
}

local carries: { [Model]: Carry } = {} -- keyed by victim character
local carrying: { [Model]: Model } = {} -- carrier -> victim

local CHAIN_COLOR = Color3.fromRGB(70, 68, 74)
local CHAIN_FLASH = Color3.fromRGB(200, 200, 210)

local function victimFeedback(c: Carry, kind: string, data: any?)
	if c.victimPlayer then
		Remotes.Feedback:FireClient(c.victimPlayer, kind, data)
	end
end

-- ── Chains visual (welded ring of links + floating mash counter) ────────────
local function buildChains(c: Carry)
	local model = Instance.new("Model")
	model.Name = "CarryChains"
	local root = c.victimRoot
	local links: { BasePart } = {}
	local function link(cf: CFrame, size: Vector3)
		local p = Instance.new("Part")
		p.Name = "ChainLink"
		p.Size = size
		p.CFrame = cf
		p.Color = CHAIN_COLOR
		p.Material = Enum.Material.DiamondPlate
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		table.insert(links, p)
	end
	-- horizontal ring of links around the curled body
	local r = 1.75
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local pos = root.Position + Vector3.new(math.cos(a) * r, 0.1, math.sin(a) * r)
		link(CFrame.lookAt(pos, root.Position) * CFrame.Angles(0, 0, if i % 2 == 0 then math.rad(90) else 0),
			Vector3.new(0.55, 0.22, 0.95))
	end
	-- vertical cross of links over the top
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		local pos = root.Position + Vector3.new(math.cos(a) * r * 0.7, 1.15, math.sin(a) * r * 0.7)
		link(CFrame.lookAt(pos, root.Position + Vector3.new(0, 1.15, 0)) * CFrame.Angles(math.rad(90), 0, 0),
			Vector3.new(0.5, 0.2, 0.85))
	end
	-- padlock front
	local lockPos = root.Position + Vector3.new(0, -0.2, -r)
	link(CFrame.new(lockPos), Vector3.new(0.9, 1.1, 0.45))

	-- floating counter everyone can read
	local bb = Instance.new("BillboardGui")
	bb.Name = "BreakCount"
	bb.Size = UDim2.fromOffset(120, 54)
	bb.StudsOffset = Vector3.new(0, 3.4, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = root
	bb.Parent = model
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = tostring(c.pressesLeft)
	label.TextColor3 = Color3.fromRGB(255, 214, 90)
	label.TextStrokeColor3 = Color3.fromRGB(30, 24, 16)
	label.TextStrokeTransparency = 0.2
	label.Parent = bb

	model.Parent = c.victim
	c.chainsModel = model
	c.countLabel = label
end

local function flashChains(c: Carry)
	local model = c.chainsModel
	if not model then
		return
	end
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			p.Color = CHAIN_FLASH
		end
	end
	task.delay(0.09, function()
		if model.Parent then
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") then
					p.Color = CHAIN_COLOR
				end
			end
		end
	end)
end

local function burstChains(c: Carry)
	local model = c.chainsModel
	c.chainsModel = nil
	c.countLabel = nil
	if not model then
		return
	end
	if c.victimRoot.Parent then
		SoundKit.PlayAt(c.victimRoot, "chainBreak")
	end
	-- links fly apart: unweld, unfreeze, fling outward, clean up after
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			for _, w in p:GetChildren() do
				if w:IsA("WeldConstraint") then
					w:Destroy()
				end
			end
			p.Massless = false
			p.CanCollide = true
			local out = (p.Position - c.victimRoot.Position)
			out = if out.Magnitude > 0.1 then out.Unit else Vector3.yAxis
			p.AssemblyLinearVelocity = out * 26 + Vector3.new(0, 18, 0)
			p.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
		end
	end
	Debris:AddItem(model, 1.6)
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────
local function releaseGrip(c: Carry)
	if c.weld then
		c.weld:Destroy()
		c.weld = nil
	end
	if c.carrier then
		carrying[c.carrier] = nil
	end
	c.carrier = nil
end

-- Fully free the victim (chains done / friendly hop-out / cleanup).
-- `unball` pops them out of ballform and hands control back.
local function freeVictim(c: Carry, unball: boolean)
	carries[c.victim] = nil
	releaseGrip(c)
	burstChains(c)
	local hum = c.victim:FindFirstChildOfClass("Humanoid")
	local root = c.victimRoot
	if root.Parent then
		root.Massless = false
		pcall(function()
			root:SetNetworkOwnershipAuto()
		end)
	end
	if hum and hum.Health > 0 then
		hum.PlatformStand = false
	end
	if unball then
		if BallformService.Disable(c.victim) then
			victimFeedback(c, "Ballform", { on = false })
		end
		-- little liberation hop
		if root.Parent and hum and hum.Health > 0 then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 22), v.Z)
		end
	else
		BallformService.SetColliderEnabled(c.victim, true)
	end
	victimFeedback(c, "CarryFreed", nil)
end

local function scoop(carrierF: { character: Model, root: BasePart, player: Player?, isBot: boolean }, victimF: { character: Model, root: BasePart, player: Player? })
	local victim = victimF.character
	local carrier = carrierF.character
	local enemies = BallService.AreEnemies(carrier, victim)

	local c: Carry = {
		victim = victim,
		victimRoot = victimF.root,
		victimPlayer = victimF.player,
		carrier = carrier,
		weld = nil,
		chained = enemies,
		pressesLeft = BallConfig.PLAYER_BALL_BREAK_PRESSES,
		chainsModel = nil,
		countLabel = nil,
		state = "held",
		thrower = nil,
		flyFrom = 0,
		flyUntil = 0,
		flyVel = Vector3.zero,
		koVictims = {},
	}
	carries[victim] = c
	carrying[carrier] = victim

	-- limp ball, no collider fighting the carrier, one welded assembly
	local hum = victim:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = true
	end
	BallformService.SetColliderEnabled(victim, false)
	c.victimRoot.Massless = true
	c.victimRoot.AssemblyLinearVelocity = Vector3.zero
	c.victimRoot.AssemblyAngularVelocity = Vector3.zero
	c.victimRoot.CFrame = carrierF.root.CFrame * CFrame.new(0, 4.4, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = carrierF.root
	weld.Part1 = c.victimRoot
	weld.Parent = c.victimRoot
	c.weld = weld

	if enemies then
		buildChains(c)
	end
	victimFeedback(c, "Carried", { chained = enemies, left = c.pressesLeft })
	if carrierF.player then
		Remotes.Feedback:FireClient(carrierF.player, "CarryScooped", { chained = enemies })
	end
end

-- ── Throw (carrier releases LMB — rides the existing ThrowRequest remote) ───
local function throwVictim(c: Carry, aimDir: Vector3?)
	local carrier = c.carrier
	if not carrier then
		return
	end
	local carrierRoot = carrier:FindFirstChild("HumanoidRootPart")
	c.thrower = carrier
	releaseGrip(c)

	local dir = if typeof(aimDir) == "Vector3" then aimDir else (carrierRoot and (carrierRoot :: BasePart).CFrame.LookVector or Vector3.zAxis)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis

	local root = c.victimRoot
	root.Massless = false
	BallformService.SetColliderEnabled(c.victim, true)
	pcall(function()
		root:SetNetworkOwner(nil) -- server drives the flight
	end)
	c.state = "flying"
	c.flyFrom = os.clock()
	c.flyUntil = c.flyFrom + BallConfig.PLAYER_BALL_FLY_TIME
	c.flyVel = flat * BallConfig.PLAYER_BALL_SPEED
	table.clear(c.koVictims)
	root.CFrame = root.CFrame + Vector3.new(0, 1.5, 0) -- clear the carrier's head
	root.AssemblyAngularVelocity = flat:Cross(Vector3.yAxis) * -8 -- tumble
	root.AssemblyLinearVelocity = Vector3.new(c.flyVel.X, BallConfig.PLAYER_BALL_UP, c.flyVel.Z)
	victimFeedback(c, "CarryThrown", { chained = c.chained })
end

-- ── The per-frame work ──────────────────────────────────────────────────────
local LAND_GRACE = 0.5

local function step()
	local t = os.clock()
	for victim, c in carries do
		-- victim gone or dead: clean up (no unball — they're respawning fresh)
		local hum = victim:FindFirstChildOfClass("Humanoid")
		if victim.Parent == nil or c.victimRoot.Parent == nil or not hum or hum.Health <= 0 then
			carries[victim] = nil
			releaseGrip(c)
			if c.chainsModel then
				c.chainsModel:Destroy()
				c.chainsModel = nil
			end
			victimFeedback(c, "CarryFreed", nil) -- client drops the mash UI
			continue
		end

		if c.state == "held" then
			local carrier = c.carrier
			local carrierGone = carrier == nil or carrier.Parent == nil
			local carrierDown = false
			if carrier and not carrierGone then
				local status = BallService.FighterStatus(carrier)
				local chum = carrier:FindFirstChildOfClass("Humanoid")
				carrierDown = status.stunned or (chum ~= nil and chum.Health <= 0)
			end
			if carrierGone or carrierDown then
				-- hit mid-carry (or carrier KO'd/left): the ball pops loose
				releaseGrip(c)
				c.state = "grounded"
				pcall(function()
					c.victimRoot:SetNetworkOwnershipAuto()
				end)
				c.victimRoot.Massless = false
				BallformService.SetColliderEnabled(victim, true)
				local v = c.victimRoot.AssemblyLinearVelocity
				c.victimRoot.AssemblyLinearVelocity = Vector3.new(v.X, 16, v.Z)
				if not c.chained then
					-- friendly ride ends when the carrier eats a hit
					freeVictim(c, false)
				end
			end
		elseif c.state == "flying" then
			local root = c.victimRoot
			local landed = t - c.flyFrom > LAND_GRACE and hum.FloorMaterial ~= Enum.Material.Air
			if t >= c.flyUntil or landed then
				c.state = "grounded"
				pcall(function()
					root:SetNetworkOwnershipAuto()
				end)
				if not c.chained then
					-- friendly throw: on landing they're a free rolling ball
					freeVictim(c, false)
				end
			else
				-- re-assert horizontal each frame (humanoid damps it otherwise);
				-- gravity owns Y — same pattern as the wrecking-ball launch
				local v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(c.flyVel.X, v.Y, c.flyVel.Z)
				-- KO sweep: any enemy of the thrower in reach gets flattened
				local thrower = c.thrower
				if thrower then
					for _, f in BallService.AllFighters() do
						if f.character ~= victim and f.character ~= thrower
							and f.character.Parent and f.root.Parent
							and not c.koVictims[f.character]
							and BallService.AreEnemies(thrower, f.character)
							and (f.root.Position - root.Position).Magnitude <= BallConfig.PLAYER_BALL_HIT_RADIUS then
							c.koVictims[f.character] = true
							BallService.InstantKO(f.character, thrower)
						end
					end
				end
			end
		end
		-- "grounded" + chained: a helpless chained ball on the floor — the
		-- victim's mash presses are the only way out (handled by the remote).
	end
end

-- ── Public API ──────────────────────────────────────────────────────────────
function CarryService.IsCarrying(character: Model): boolean
	return carrying[character] ~= nil
end

-- Dev hooks (BalloutDebug bridge): force a scoop/throw so the flow can be
-- tested without a second human.
function CarryService.ForceScoop(carrier: Model, victim: Model): boolean
	local cf = BallService.DebugFighter(carrier)
	local vf = BallService.DebugFighter(victim)
	if not (cf and vf) or carries[victim] ~= nil or carrying[carrier] ~= nil then
		return false
	end
	scoop(cf, vf)
	return true
end

function CarryService.ForceThrow(carrier: Model, aimDir: Vector3?): boolean
	local victim = carrying[carrier]
	local c = victim and carries[victim]
	if c and c.state == "held" then
		throwVictim(c, aimDir)
		return true
	end
	return false
end

function CarryService.DebugState(victim: Model)
	local c = carries[victim]
	if not c then
		return { carried = false }
	end
	return {
		carried = true,
		state = c.state,
		chained = c.chained,
		left = c.pressesLeft,
		carrier = c.carrier and c.carrier.Name or "nil",
	}
end

function CarryService.IsLockedBallform(character: Model): boolean
	local c = carries[character]
	-- carried OR chained: the server owns your ballform state
	return c ~= nil and (c.state == "held" or c.chained)
end

function CarryService.Start()
	BallService.HandsFullCheck = CarryService.IsCarrying
	BallService.BallformLockCheck = CarryService.IsLockedBallform

	-- Scoop scan: any empty-handed, un-balled, un-stunned fighter walking
	-- into a balled player picks them up.
	task.spawn(function()
		while true do
			task.wait(0.15)
			local all = BallService.AllFighters()
			for _, vf in all do
				local victim = vf.character
				if vf.player and victim.Parent and vf.root.Parent
					and BallformService.IsBalled(victim) and carries[victim] == nil then
					for _, cf in all do
						local carrier = cf.character
						if carrier ~= victim and carrier.Parent and cf.root.Parent
							and not cf.isBot -- bots don't scoop (yet)
							and carrying[carrier] == nil and carries[carrier] == nil
							and not BallformService.IsBalled(carrier) then
							local status = BallService.FighterStatus(carrier)
							if not status.holding and not status.stunned
								and (cf.root.Position - vf.root.Position).Magnitude <= BallConfig.PLAYER_BALL_PICKUP_RADIUS then
								scoop(cf, vf)
								break
							end
						end
					end
				end
			end
		end
	end)

	-- Space mash: chained victims fight the chains; friendly riders hop out.
	Remotes.CarryStruggle.OnServerEvent:Connect(function(player)
		local char = player.Character
		local c = char and carries[char]
		if not c then
			return
		end
		if not c.chained then
			-- willing passenger: one press = off you hop (only while held;
			-- mid-air friendly flights just ride out)
			if c.state == "held" then
				freeVictim(c, false)
			end
			return
		end
		c.pressesLeft -= 1
		if c.countLabel then
			c.countLabel.Text = tostring(math.max(c.pressesLeft, 0))
		end
		flashChains(c)
		SoundKit.PlayAt(c.victimRoot, "chainRattle")
		victimFeedback(c, "CarryTick", { left = math.max(c.pressesLeft, 0) })
		if c.pressesLeft <= 0 then
			freeVictim(c, true) -- chains burst, ballform pops, control returns
		end
	end)

	-- The carrier's LMB release doubles as the player-ball throw: the same
	-- ThrowRequest remote arrives here too (BallService's own handler no-ops
	-- for them — they hold no dodgeball).
	Remotes.ThrowRequest.OnServerEvent:Connect(function(player, phase, _chargeFrac, _curveDir, _isLob, aimDir)
		if phase ~= "release" then
			return
		end
		local char = player.Character
		local victim = char and carrying[char]
		local c = victim and carries[victim]
		if c and c.state == "held" then
			throwVictim(c, if typeof(aimDir) == "Vector3" then aimDir else nil)
		end
	end)

	RunService.Heartbeat:Connect(step)
end

return CarryService
