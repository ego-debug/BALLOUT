--!strict
-- Ballout | BotAI — makes match bots move and play like people (v1)
--
-- The bot rig has NO Humanoid (anchored root, welded limbs), so movement is
-- KINEMATIC: every Heartbeat the root CFrame steps toward the current goal at
-- BOT_WALK_SPEED, grounded by raycast (same trick as BotService's spawn
-- grounding), with a walk bob + facing so it reads as walking, not sliding.
--
-- Brain (sensed every ~0.25s, cheap):
--   HOLDING  -> close on the nearest enemy; BallService releases the throw
--               once inside BOT_THROW_RANGE (BOT_MAX_HOLD failsafe)
--   FETCH    -> primary ball Free/Loose within BOT_FETCH_RANGE and hands
--               empty -> run at it (auto-pickup does the rest)
--   THREAT   -> an ENEMY holds the ball nearby -> strafe sideways (juke)
--   WANDER   -> stroll to random points around the bot's post, short pauses
--
-- EDGE GUARD: before every step, raycast the floor at the NEXT position —
-- no floor (Scaffold Row pit/gap) means don't take the step and pick a new
-- wander goal. Bots never walk themselves into the void.
--
-- Only MATCH bots get a brain (MatchService registers/unregisters them);
-- the lobby training bot stays planted at its drill.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BallConfig = require(ReplicatedStorage.BallConfig)
local BallService = require(ServerScriptService.BallService)

local BotAI = {}

type Brain = {
	model: Model,
	root: BasePart,
	team: string,
	home: Vector3,
	goal: Vector3?,        -- where the bot is walking to (nil = standing)
	pauseUntil: number,    -- wander breather between strolls
	nextSense: number,     -- next think tick
	mode: string,          -- "wander" | "fetch" | "attack" | "strafe"
	strafeSign: number,    -- which way the current juke goes
	bobPhase: number,
	lastPos: Vector3,      -- teleport detection (KO hop-home)
}

local brains: { [Model]: Brain } = {}
local started = false

local ROOT_HOVER = 3.3 -- feet-on-floor root height (BotService rig contract)

local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude

-- Floor height at a point, ignoring the bot itself. nil = void/gap.
local function floorAt(brain: Brain, pos: Vector3): number?
	floorParams.FilterDescendantsInstances = { brain.model }
	local hit = Workspace:Raycast(Vector3.new(pos.X, brain.root.Position.Y + 6, pos.Z), Vector3.new(0, -40, 0), floorParams)
	return if hit then hit.Position.Y else nil
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function pickWander(brain: Brain): Vector3
	-- a stroll target around the post that actually has floor under it
	for _ = 1, 6 do
		local ang = math.random() * math.pi * 2
		local r = 8 + math.random() * BallConfig.BOT_WANDER_RADIUS
		local candidate = brain.home + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
		if floorAt(brain, candidate) then
			return candidate
		end
	end
	return brain.home
end

-- Nearest ENEMY position, team-aware — BallService applies the same rule
-- throws use, so the bot advances on real opponents, never teammates.
local function nearestEnemyPos(brain: Brain): Vector3?
	return BallService.NearestEnemyPos(brain.model)
end

local function sense(brain: Brain, t: number)
	brain.nextSense = t + 0.2 + math.random() * 0.15
	local status = BallService.FighterStatus(brain.model)
	if status.stunned then
		brain.mode = "stunned"
		brain.goal = nil
		return
	end
	local myPos = brain.root.Position

	if status.holding then
		-- close the gap; BallService throws for us once we're in range
		brain.mode = "attack"
		local enemy = nearestEnemyPos(brain)
		if enemy then
			-- stop a little short of the target, don't hug them
			local to = flat(enemy - myPos)
			local stopAt = math.max(to.Magnitude - BallConfig.BOT_THROW_RANGE * 0.7, 0)
			brain.goal = if stopAt > 2 then myPos + to.Unit * stopAt else nil
		else
			brain.goal = nil
		end
		return
	end

	-- MULTI-BALL: hunt the NEAREST usable ball; fear the nearest armed enemy.
	local nearestFree: Vector3? = nil
	local nearestFreeDist = math.huge
	local nearestThreat: Vector3? = nil
	local nearestThreatDist = math.huge
	for _, info in BallService.BallsInfo() do
		if not info.isDrill then
			local d = (info.position - myPos).Magnitude
			if (info.state == "Free" or info.state == "Loose") and d < nearestFreeDist then
				nearestFree, nearestFreeDist = info.position, d
			elseif info.state == "Held" and info.holderTeam ~= nil
				and info.holderTeam ~= brain.team and d < nearestThreatDist then
				nearestThreat, nearestThreatDist = info.position, d
			end
		end
	end

	if nearestFree and nearestFreeDist <= BallConfig.BOT_FETCH_RANGE then
		brain.mode = "fetch"
		brain.goal = nearestFree
		return
	end

	-- armed enemy close by: juke sideways like a person trying not to get hit
	if nearestThreat and nearestThreatDist <= BallConfig.BOT_STRAFE_RANGE then
		if brain.mode ~= "strafe" then
			brain.strafeSign = if math.random() < 0.5 then 1 else -1
		end
		brain.mode = "strafe"
		local away = flat(myPos - nearestThreat)
		local side = Vector3.new(-away.Z, 0, away.X).Unit * brain.strafeSign
		brain.goal = myPos + side * 10 + away.Unit * 2
		return
	end

	-- otherwise: stroll around the post
	if brain.mode ~= "wander" then
		brain.mode = "wander"
		brain.goal = pickWander(brain)
	end
	if brain.goal == nil and t >= brain.pauseUntil then
		brain.goal = pickWander(brain)
	end
end

local function step(dt: number)
	local t = os.clock()
	for model, brain in brains do
		if model.Parent == nil or brain.root.Parent == nil then
			brains[model] = nil
			continue
		end
		-- teleported (KO hop back to post)? re-home quietly
		if (brain.root.Position - brain.lastPos).Magnitude > 25 then
			brain.goal = nil
			brain.pauseUntil = t + 0.8
		end
		if t >= brain.nextSense then
			sense(brain, t)
		end
		local goal = brain.goal
		if goal then
			local myPos = brain.root.Position
			local to = flat(goal - myPos)
			if to.Magnitude < 1.5 then
				brain.goal = nil
				brain.pauseUntil = t + 0.4 + math.random() * 1.2
			else
				local dir = to.Unit
				local stepLen = math.min(BallConfig.BOT_WALK_SPEED * dt, to.Magnitude)
				local nextPos = myPos + dir * stepLen
				local fy = floorAt(brain, nextPos)
				if fy == nil then
					-- EDGE: the next step is over a void — bail and rethink
					brain.goal = nil
					brain.pauseUntil = t + 0.3
				else
					brain.bobPhase += dt * 9
					local bob = math.sin(brain.bobPhase) * 0.12
					local face = CFrame.lookAt(
						Vector3.new(nextPos.X, fy + ROOT_HOVER + bob, nextPos.Z),
						Vector3.new(goal.X, fy + ROOT_HOVER + bob, goal.Z)
					)
					-- slight lean into the walk sells the motion
					brain.root.CFrame = face * CFrame.Angles(math.rad(-4), 0, 0)
				end
			end
		end
		brain.lastPos = brain.root.Position
	end
end

function BotAI.Register(model: Model, root: BasePart, team: string, home: Vector3)
	brains[model] = {
		model = model,
		root = root,
		team = team,
		home = home,
		goal = nil,
		pauseUntil = 0,
		nextSense = 0,
		mode = "wander",
		strafeSign = 1,
		bobPhase = math.random() * 6,
		lastPos = root.Position,
	}
	if not started then
		started = true
		RunService.Heartbeat:Connect(step)
	end
end

function BotAI.Unregister(model: Model)
	brains[model] = nil
end

return BotAI
