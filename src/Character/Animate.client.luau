--!strict
-- Ballout | Animate
-- Replaces Roblox's default Animate script so EVERY player runs the same
-- standard animation set (no purchased animation bundles). This is also the
-- hook where custom Ballout animations get swapped in later — replace the
-- asset ids below.

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local animator = humanoid:WaitForChild("Animator") :: Animator

-- Standard R15 animation set (Roblox's documented defaults).
local ASSETS = {
	idle = "rbxassetid://507766666",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
	jump = "rbxassetid://507765000",
	fall = "rbxassetid://507767968",
	climb = "rbxassetid://507765644",
	swim = "rbxassetid://507784897",
}

local tracks: { [string]: AnimationTrack } = {}
for name, id in ASSETS do
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Core
	tracks[name] = track
end

local current: AnimationTrack? = nil

local function play(name: string, fade: number?, speed: number?)
	local track = tracks[name]
	if not track then return end
	if current == track then
		if speed then track:AdjustSpeed(speed) end
		return
	end
	if current then
		current:Stop(fade or 0.15)
	end
	track:Play(fade or 0.15)
	if speed then track:AdjustSpeed(speed) end
	current = track
end

-- Walk/run blend: scale playback to actual speed so feet don't slide.
local lastSpeed = 0
humanoid.Running:Connect(function(speed)
	lastSpeed = speed
	if speed > 0.5 then
		play("run", 0.15, speed / 16)
	else
		play("idle", 0.2)
	end
end)

-- Directional playback: with the locked camera the body always faces
-- forward, so backpedaling plays the run REVERSED (legs read as moving
-- backwards). Proper side-step strafe animations need uploaded animation
-- assets — they come with the custom Ballout animation pass.
local RunService = game:GetService("RunService")
local root = character:WaitForChild("HumanoidRootPart")
RunService.Heartbeat:Connect(function()
	local track = tracks.run
	if current == track and track.IsPlaying and lastSpeed > 0.5 then
		local dir = humanoid.MoveDirection
		if dir.Magnitude > 0.1 then
			local look = root.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				local dot = dir.Unit:Dot(flat.Unit)
				local rate = math.max(lastSpeed, 4) / 16
				track:AdjustSpeed(if dot < -0.3 then -rate else rate)
			end
		end
	end
end)

humanoid.Jumping:Connect(function(active)
	if active then
		play("jump", 0.08)
	end
end)

humanoid.FreeFalling:Connect(function(active)
	if active then
		play("fall", 0.2)
	end
end)

humanoid.Climbing:Connect(function(speed)
	play("climb", 0.15, speed / 5)
end)

humanoid.Swimming:Connect(function(speed)
	if speed > 1 then
		play("swim", 0.2, speed / 10)
	end
end)

humanoid.Died:Connect(function()
	if current then
		current:Stop(0.1)
		current = nil
	end
end)

-- Physics state = fully scripted movement (dash dive/roll, ballform):
-- stop all core animations so the legs go still. They resume on the next
-- Running event after the humanoid recovers.
humanoid.StateChanged:Connect(function(_, newState)
	if newState == Enum.HumanoidStateType.Physics and current then
		current:Stop(0.1)
		current = nil
	end
end)

play("idle", 0.1)
