--!strict
-- Ballout | Client
-- Input: hold Throw to charge & release to throw, tap Catch to catch.
-- HUD: a charge meter + a status line driven by server Feedback.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallConfig = require(ReplicatedStorage.BallConfig)
local Remotes = require(ReplicatedStorage.Remotes)

local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Locked third-person camera (KC-style shift-lock) ───────────────────────
-- Mouse steers the camera, the character always faces the camera's yaw, and
-- the view sits over the right shoulder with a center crosshair.
player.CameraMinZoomDistance = BallConfig.CAMERA_MIN_ZOOM
player.CameraMaxZoomDistance = BallConfig.CAMERA_MAX_ZOOM
-- Land the camera at the KC default distance: pin the zoom for a beat,
-- then hand the range back to the player's scroll wheel.
task.spawn(function()
	player.CameraMinZoomDistance = BallConfig.CAMERA_DEFAULT_ZOOM
	player.CameraMaxZoomDistance = BallConfig.CAMERA_DEFAULT_ZOOM
	task.wait(0.4)
	player.CameraMinZoomDistance = BallConfig.CAMERA_MIN_ZOOM
	player.CameraMaxZoomDistance = BallConfig.CAMERA_MAX_ZOOM
end)

-- Trick jumps (KC-accurate): E = spin jump, Q = flip jump. Releasing the
-- throw during the trick window turns the throw into a curve (spin) or a
-- lob (flip). The spin/flip visuals are layered onto the camera-facing yaw.
local spinEndsAt = 0
local spinDir = 0
local flipEndsAt = 0
local trickKind: string? = nil -- "spin" | "flip"
local trickEndsAt = 0
local trickDir = 0
local airHopUsed = false -- Q mid-air = ONE double jump per airtime

-- Aerial throw hang: hover briefly while the throw animation plays mid-air.
local hangEndsAt = 0


-- Charge state (declared here so the camera renderstep can see it).
local charging = false
local chargeStart = 0
local stickX = 0 -- last gamepad thumbstick X

-- Dash state. Phases: dive (dashEndsAt) -> parkour roll (dashRollEndsAt)
-- -> stand up. The humanoid rides the Physics state for the whole move, so
-- there's no walk animation, no input drift, no post-dash walking.
local dashEndsAt = 0
local dashRollEndsAt = 0
local dashRecovered = true
local dashDir = Vector3.zero
local dashReadyAt = 0

-- Ballform roll state (server-confirmed via "Ballform" feedback).
-- Momentum-based rolling: accelerate toward input, drift with drag,
-- capped under walk speed, with a gyro tumble in the travel direction.
local ballformOn = false
local rollVel = Vector3.zero
local rollCF = CFrame.identity
-- Smoothed body facing (world-space, flat). Eases between camera-forward
-- and sprint-diagonal directions instead of snapping.
local faceDir = Vector3.new(0, 0, -1)
local sprintLean = 0 -- eased 0..1: forward tilt while sprinting
local lastSprintSent = false
-- Sprint is a LATCH: one Shift press arms it; it persists through flips,
-- dashes and any animation. It only clears when forward input stops
-- (W released / S pressed) or Shift is tapped again.
local sprintLatched = false

-- Glider: Space while airborne deploys; Space again or landing stows.
-- It always travels FORWARD along a heading: A/D spin the heading, W speeds
-- up, S brakes to a stop (flare) — never backwards.
local gliding = false
local glideHeading = Vector3.new(0, 0, -1)
local glideSpeed = 0
local glideFlaring = false
local glideTilt = 0

local function stowGlider()
	if gliding then
		gliding = false
		glideFlaring = false
		Remotes.GlideRequest:FireServer(false)
	end
end

-- Camera rumble on hit.
local shakeEndsAt = 0

-- Sustained hit knockback (a one-frame impulse gets braked instantly by the
-- humanoid's walk controller — it must be held over a window, like the dash).
local knockEndsAt = 0
local knockVel = Vector3.zero

-- Hit stun: all actions locked out until this passes.
local stunnedUntil = 0

-- Catch root (KC): pressing catch plants you — but holding a direction gives
-- a CATCH-STEP: a slide of about a third of a dash that way, dying out as
-- the animation plays. A whiff extends the root through the stun.
local catchRootEndsAt = 0
local catchSlideDir = Vector3.zero
local catchSlideEndsAt = 0

local function isStunned(): boolean
	return os.clock() < stunnedUntil
end

-- Mute footsteps while rolling (the Running loop keeps playing otherwise).
local function setFootsteps(on: boolean)
	local char = player.Character
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")
	local running = rootPart and rootPart:FindFirstChild("Running")
	if running and running:IsA("Sound") then
		running.Volume = if on then 0.65 else 0
	end
end
local stickY = 0 -- gamepad thumbstick Y (X is tracked further down)

-- Steering input for the roll, read straight from keys/stick and rotated by
-- the camera. (Humanoid.MoveDirection can't be used: the Physics state the
-- ball rides in clears it every physics step.)
local function ballInputDir(camera: Camera): Vector3
	local x, z = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then z -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then z += 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then x -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then x += 1 end
	local look = camera.CFrame.LookVector
	local lookFlat = Vector3.new(look.X, 0, look.Z)
	lookFlat = if lookFlat.Magnitude > 0.01 then lookFlat.Unit else Vector3.zAxis
	local rightFlat = lookFlat:Cross(Vector3.yAxis)
	local dir = lookFlat * -z + rightFlat * x
	if dir.Magnitude < 0.05 then
		-- gamepad stick fallback
		dir = lookFlat * stickY + rightFlat * stickX
	end
	return if dir.Magnitude > 0.05 then dir.Unit else Vector3.zero
end

-- Lock-on indicator: targets inside the aim cone get a red outline.
local lockHighlights: { [Model]: Highlight } = {}

local function aimTargets(): { Model }
	local targets = {}
	local dummy = Workspace:FindFirstChild("TrainingDummy")
	if dummy then
		table.insert(targets, dummy)
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			table.insert(targets, other.Character)
		end
	end
	return targets
end

local function setLockOutline(model: Model, on: boolean)
	local hl = lockHighlights[model]
	if on then
		if not hl or hl.Parent ~= model then
			hl = Instance.new("Highlight")
			hl.Name = "BalloutLock"
			hl.FillTransparency = 1
			hl.OutlineColor = Color3.fromRGB(255, 60, 60)
			hl.OutlineTransparency = 0
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Parent = model
			lockHighlights[model] = hl
		end
		hl.Enabled = true
	elseif hl then
		hl.Enabled = false
	end
end

local aimCos = math.cos(math.rad(BallConfig.AIM_CONE_DEG))

-- Current lock target (first model inside the aim cone this frame).
local currentLockModel: Model? = nil

-- Where the ball will land: the locked target, else the crosshair's world
-- point (raycast through the dot, capped at 150 studs).
local landingRayParams = RaycastParams.new()
landingRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function computeLandingPoint(camera: Camera): Vector3
	local character = player.Character
	if currentLockModel then
		local troot = currentLockModel:FindFirstChild("HumanoidRootPart")
		if troot and troot:IsA("BasePart") then
			return troot.Position - Vector3.new(0, 2.6, 0)
		end
	end
	local exclude = {}
	if character then table.insert(exclude, character) end
	local ballPart = Workspace:FindFirstChild("Dodgeball")
	if ballPart then table.insert(exclude, ballPart) end
	local ret = Workspace:FindFirstChild("BalloutReticle")
	if ret then table.insert(exclude, ret) end
	landingRayParams.FilterDescendantsInstances = exclude
	local vp = camera.ViewportSize
	local ray = camera:ViewportPointToRay(vp.X * 0.5, vp.Y * BallConfig.CROSSHAIR_Y)
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 150, landingRayParams)
	if hit then
		return hit.Position
	end
	local endP = ray.Origin + ray.Direction * 150
	local down = Workspace:Raycast(endP, Vector3.new(0, -300, 0), landingRayParams)
	return if down then down.Position else endP
end

-- The reticle itself: glowing disc + three spinning chevrons (local-only).
local reticleModel: Model? = nil
local reticleSpin = 0

local function ensureReticle(): Model
	if reticleModel and reticleModel.Parent then
		return reticleModel
	end
	local model = Instance.new("Model")
	model.Name = "BalloutReticle"
	local disc = Instance.new("Part")
	disc.Name = "Disc"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.15, 2.6, 2.6)
	disc.Color = Color3.fromRGB(170, 220, 255)
	disc.Material = Enum.Material.Neon
	disc.Transparency = 0.35
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.Parent = model
	for i = 1, 3 do
		local chev = Instance.new("Part")
		chev.Name = "Chevron" .. i
		chev.Size = Vector3.new(1.0, 0.12, 0.3)
		chev.Color = Color3.fromRGB(235, 245, 255)
		chev.Material = Enum.Material.Neon
		chev.Transparency = 0.1
		chev.Anchored = true
		chev.CanCollide = false
		chev.CanQuery = false
		chev.CanTouch = false
		chev.Parent = model
	end
	model.PrimaryPart = disc
	model.Parent = Workspace
	reticleModel = model
	return model
end

local function updateReticle(point: Vector3?, dt: number)
	if not point then
		if reticleModel then
			reticleModel:Destroy()
			reticleModel = nil
		end
		return
	end
	local model = ensureReticle()
	reticleSpin += dt * 3.5
	local base = point + Vector3.new(0, 0.2, 0)
	local disc = model:FindFirstChild("Disc") :: BasePart
	disc.CFrame = CFrame.new(base) * CFrame.Angles(0, reticleSpin, math.rad(90))
	for i = 1, 3 do
		local chev = model:FindFirstChild("Chevron" .. i) :: BasePart
		local a = reticleSpin + (i - 1) * (math.pi * 2 / 3)
		local offset = Vector3.new(math.cos(a), 0, math.sin(a)) * 2.1
		chev.CFrame = CFrame.new(base + offset)
			* CFrame.Angles(0, -a + math.rad(90), 0)
	end
end


RunService:BindToRenderStep("BalloutLockedCamera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then return end

	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	humanoid.AutoRotate = false

	-- ONE camera mode, always: track the root position (never a body part,
	-- never a rotating frame) and apply the shoulder offset in CAMERA space
	-- below. The POV is identical in every state — walk, sprint, flip, roll.
	humanoid.CameraOffset = Vector3.zero

	-- Landing resets the air double-jump.
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		airHopUsed = false
	end

	-- Are we holding the ball? (used by the charge slow here AND the
	-- landing reticle below)
	local holdingBall = false
	do
		local ballPart = Workspace:FindFirstChild("Dodgeball")
		if ballPart then
			local weld = ballPart:FindFirstChildOfClass("WeldConstraint")
			holdingBall = weld ~= nil and weld.Part0 ~= nil and weld.Part0:IsDescendantOf(character)
		end
	end
	local chargingHeld = charging and holdingBall

	-- Sprint latch: cleared only by stopping forward movement or reversing.
	-- Winding up a throw kills the sprint too — you trudge while charging.
	if not UserInputService:IsKeyDown(Enum.KeyCode.W)
		or UserInputService:IsKeyDown(Enum.KeyCode.S)
		or chargingHeld then
		sprintLatched = false
	end
	local isSprinting = false
	if not ballformOn then
		isSprinting = sprintLatched
		humanoid.WalkSpeed = if isSprinting then BallConfig.SPRINT_SPEED else BallConfig.WALK_SPEED
		if chargingHeld then
			humanoid.WalkSpeed = BallConfig.WALK_SPEED * BallConfig.CHARGE_WALK_MULT
		end
	end
	-- Tell the server on sprint toggles (switches the ball-carry pose).
	if isSprinting ~= lastSprintSent then
		lastSprintSent = isSprinting
		Remotes.SprintRequest:FireServer(isSprinting)
	end
	-- Eased forward lean while sprinting.
	local leanTarget = if isSprinting then 1 else 0
	sprintLean += (leanTarget - sprintLean) * (1 - math.exp(-8 * dt))

	-- Catch root: feet stop, but a held direction gives the catch-step —
	-- ~1/3 of a dash sliding that way, decaying with the animation.
	if os.clock() < catchRootEndsAt and not ballformOn then
		humanoid.WalkSpeed = 0
		local v = root.AssemblyLinearVelocity
		if os.clock() < catchSlideEndsAt and catchSlideDir.Magnitude > 0.05 then
			local p = (catchSlideEndsAt - os.clock()) / BallConfig.CATCH_SLIDE_TIME
			-- Total slide distance = 1/3 of a dash (v0 = 2*d/T, linear decay).
			local slideDist = (BallConfig.DODGE_SPEED * BallConfig.DODGE_TIME) / 3
			local spd = (2 * slideDist / BallConfig.CATCH_SLIDE_TIME) * p
			root.AssemblyLinearVelocity = Vector3.new(catchSlideDir.X * spd, v.Y, catchSlideDir.Z * spd)
		else
			local decay = math.exp(-6 * dt)
			root.AssemblyLinearVelocity = Vector3.new(v.X * decay, v.Y, v.Z * decay)
		end
	end

	local camera = Workspace.CurrentCamera
	if camera and camera.CameraSubject ~= root then
		camera.CameraSubject = root
	end
	if camera and ballformOn then
		-- ── Rolling ball movement ──────────────────────────────────────
		-- Physics state = the humanoid controller fully lets go, so our
		-- roll velocity isn't braked back to zero every physics step.
		if humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end
		-- Momentum: build toward input, drift with drag, cap under walk.
		local moveDir = ballInputDir(camera)
		local flatVel = Vector3.new(rollVel.X, 0, rollVel.Z)
		if moveDir.Magnitude > 0.05 then
			flatVel += moveDir * BallConfig.BALLFORM_ACCEL * dt
		else
			flatVel *= math.max(0, 1 - BallConfig.BALLFORM_DRAG * dt)
		end
		if flatVel.Magnitude > BallConfig.BALLFORM_MAX_SPEED then
			flatVel = flatVel.Unit * BallConfig.BALLFORM_MAX_SPEED
		end
		rollVel = flatVel
		local v = root.AssemblyLinearVelocity
		-- Micro-bounce filter: tiny vertical jitters from contact resolution
		-- get zeroed; real falls/launches pass through untouched.
		local vy = if math.abs(v.Y) < 4 then 0 else v.Y
		root.AssemblyLinearVelocity = Vector3.new(flatVel.X, vy, flatVel.Z)

		-- Kill solver-accumulated spin so contacts can't fling us.
		root.AssemblyAngularVelocity = Vector3.zero

		-- Gyro tumble: rotate around the axis perpendicular to travel,
		-- at the rate a ball of this radius would actually spin.
		local speed = flatVel.Magnitude
		if speed > 0.5 then
			local dir = flatVel.Unit
			local axis = Vector3.yAxis:Cross(dir)
			if axis.Magnitude > 0.01 then
				local angle = (speed / BallConfig.BALLFORM_ROLL_RADIUS) * dt
				rollCF = CFrame.fromAxisAngle(axis.Unit, angle) * rollCF
			end
		end
		root.CFrame = CFrame.new(root.Position) * rollCF

	elseif camera and gliding then
		-- Glide: body faces the glide HEADING (A/D visibly spins you), tips
		-- slightly forward cruising, and flares back while braking — which
		-- tilts the whole welded glider with it.
		local tiltTarget = if glideFlaring
			then math.rad(BallConfig.GLIDE_TILT_FLARE)
			else math.rad(BallConfig.GLIDE_TILT_CRUISE)
		glideTilt += (tiltTarget - glideTilt) * (1 - math.exp(-8 * dt))
		faceDir = Vector3.new(glideHeading.X, 0, glideHeading.Z)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + faceDir)
			* CFrame.Angles(glideTilt, 0, 0)

	elseif camera and os.clock() < dashEndsAt and dashDir.Magnitude > 0.1 then
		-- Superman dive: the WHOLE BODY rotates to face the dash direction
		-- and tips prone — elbow and head leading, same pose every direction.
		-- Camera stays exactly where it is.
		faceDir = dashDir -- exiting the dash blends from this heading
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dashDir)
			* CFrame.Angles(-math.rad(BallConfig.DASH_PITCH_DEG), 0, 0)

	elseif camera and os.clock() < dashRollEndsAt and dashDir.Magnitude > 0.1 then
		-- Parkour landing roll: one fast forward tumble along the dash
		-- heading while the speed bleeds off, then stand.
		local p = 1 - (dashRollEndsAt - os.clock()) / BallConfig.DASH_ROLL_TIME
		faceDir = dashDir
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dashDir)
			* CFrame.Angles(-math.rad(BallConfig.DASH_PITCH_DEG) - p * math.pi * 2, 0, 0)

	elseif camera then
		-- Face the character along the camera's flat look direction —
		-- except while sprinting, where the body angles INTO the movement
		-- direction (diagonal sprints lean diagonal). The turn is SMOOTHED
		-- so transitions between directions ease instead of snapping.
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if isSprinting then
			local md = humanoid.MoveDirection
			local mdFlat = Vector3.new(md.X, 0, md.Z)
			if mdFlat.Magnitude > 0.1 then
				flat = mdFlat
			end
		end
		if flat.Magnitude > 0.01 then
			local alpha = 1 - math.exp(-BallConfig.FACE_TURN_RATE * dt)
			faceDir = faceDir:Lerp(flat.Unit, alpha)
		end
		if faceDir.Magnitude > 0.01 then
			local face = CFrame.lookAt(root.Position, root.Position + faceDir.Unit)
			-- Sprint: tip the body into the run.
			if sprintLean > 0.01 then
				face = face * CFrame.Angles(-math.rad(BallConfig.SPRINT_LEAN_DEG) * sprintLean, 0, 0)
			end
			local remaining = spinEndsAt - os.clock()
			if remaining > 0 then
				local progress = 1 - remaining / BallConfig.CURVE_SPIN_TIME
				face = face * CFrame.Angles(0, spinDir * progress * math.pi * 2, 0)
			end
			-- Double FRONT flip, ONLY once cleanly airborne. The 0.08s delay
			-- matters: at takeoff FloorMaterial flickers ground/air, and a
			-- rotated frame written while still touching ground gets shoved
			-- by the solver (the "thrown backwards" glitch).
			local remainingFlip = flipEndsAt - os.clock()
			local elapsedFlip = BallConfig.FLIP_TIME - remainingFlip
			if remainingFlip > 0 and elapsedFlip > 0.08 and humanoid.FloorMaterial == Enum.Material.Air then
				local progress = math.clamp((elapsedFlip - 0.08) / (BallConfig.FLIP_TIME - 0.08), 0, 1)
				face = face * CFrame.Angles(-progress * math.pi * 2 * BallConfig.FLIP_ROTATIONS, 0, 0)
			end
			root.CFrame = face
		end
	end

	-- Landing reticle: while holding the ball, show WHERE it will land —
	-- the locked target, or the crosshair point. Any throw type lands there.
	-- (holdingBall computed above with the charge slow.)
	-- Only while actually CHARGING a throw — otherwise just the crosshair.
	if holdingBall and charging and camera and not ballformOn then
		updateReticle(computeLandingPoint(camera), dt)
	else
		updateReticle(nil, dt)
	end

	-- Camera-space shoulder offset + eye-height lift, EVERY frame — the one
	-- and only POV, decoupled from body orientation entirely.
	if camera then
		camera.CFrame = camera.CFrame * CFrame.new(
			BallConfig.SHOULDER_OFFSET.X,
			BallConfig.SHOULDER_OFFSET.Y + BallConfig.CAMERA_LIFT,
			0
		)
		-- Hit rumble: decaying random jitter.
		local shakeLeft = shakeEndsAt - os.clock()
		if shakeLeft > 0 then
			local m = BallConfig.HIT_SHAKE_MAG * (shakeLeft / BallConfig.HIT_SHAKE_TIME)
			camera.CFrame = camera.CFrame
				* CFrame.new((math.random() - 0.5) * m, (math.random() - 0.5) * m, 0)
				* CFrame.Angles(0, 0, (math.random() - 0.5) * m * 0.03)
		end
	end

	-- Aerial throw hold: freeze VERTICAL position only — you and the ball
	-- stop at the same height and the throw fires from there. Horizontal
	-- air control stays completely free. (Applies only while airborne, so
	-- grounded throws are unaffected.)
	local nowT = os.clock()
	if nowT < hangEndsAt and humanoid.FloorMaterial == Enum.Material.Air then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
	end

	-- Dash: full-speed dive, then a fast decaying landing roll. Physics
	-- state the whole way — no walking, no input, no leg animation.
	if nowT < dashRollEndsAt then
		if not ballformOn and humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end
		local speed
		if nowT < dashEndsAt then
			speed = BallConfig.DODGE_SPEED
		else
			-- Roll phase: hard slowdown, decaying to a stop.
			local p = (dashRollEndsAt - nowT) / BallConfig.DASH_ROLL_TIME
			speed = BallConfig.DASH_ROLL_SPEED * p
		end
		-- ALTITUDE HOLD: the dash glides at a constant height through the
		-- whole dive + roll (air-chains stay flat); gravity only takes over
		-- once the roll finishes.
		root.AssemblyLinearVelocity = Vector3.new(dashDir.X * speed, 0, dashDir.Z * speed)
	elseif not dashRecovered then
		-- Roll finished: stand up, control returns.
		dashRecovered = true
		if not ballformOn then
			setFootsteps(true)
			if humanoid:GetState() == Enum.HumanoidStateType.Physics then
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end
	end

	-- Hit knockback: sustained decaying shove.
	if nowT < knockEndsAt then
		local frac = (knockEndsAt - nowT) / BallConfig.HIT_KNOCK_TIME
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(knockVel.X * frac, v.Y, knockVel.Z * frac)
	end

	-- Glider: constant gentle descent, forward-only travel along a heading.
	-- A/D turn the heading, W speeds up, S brakes toward a stop (flare).
	if gliding then
		if humanoid.FloorMaterial ~= Enum.Material.Air or ballformOn or nowT < dashRollEndsAt then
			stowGlider() -- landed (or a trick took over)
		else
			-- Loose mouse steering: the heading lazily chases where the
			-- camera looks — eased, never snapped to the crosshair.
			if camera then
				local look = camera.CFrame.LookVector
				local camFlat = Vector3.new(look.X, 0, look.Z)
				if camFlat.Magnitude > 0.01 then
					camFlat = camFlat.Unit
					local cross = glideHeading:Cross(camFlat).Y
					local dotp = math.clamp(glideHeading:Dot(camFlat), -1, 1)
					local angleDiff = math.atan2(cross, dotp)
					local step = angleDiff * (1 - math.exp(-BallConfig.GLIDE_MOUSE_FOLLOW * dt))
					glideHeading = CFrame.Angles(0, step, 0) * glideHeading
				end
			end

			-- Turn the heading with A/D (or stick X).
			local turn = 0
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then turn += 1 end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then turn -= 1 end
			if turn == 0 and math.abs(stickX) > 0.35 then
				turn = math.sign(stickX)
			end
			if turn ~= 0 then
				glideHeading = CFrame.Angles(0, -turn * math.rad(BallConfig.GLIDE_TURN_RATE) * dt, 0) * glideHeading
			end

			-- Brake / cruise / boost — speed eases toward the target.
			local braking = UserInputService:IsKeyDown(Enum.KeyCode.S) or stickY < -0.4
			local boosting = UserInputService:IsKeyDown(Enum.KeyCode.W) or stickY > 0.4
			local targetSpeed = if braking
				then 0
				elseif boosting then BallConfig.GLIDE_STEER_SPEED
				else BallConfig.WALK_SPEED * BallConfig.GLIDE_DRIFT_FRAC
			local rate = if braking then BallConfig.GLIDE_BRAKE else BallConfig.GLIDE_ACCEL
			glideSpeed += math.clamp(targetSpeed - glideSpeed, -rate * dt, rate * dt)

			-- Flare pose sync (legs forward while braking).
			if braking ~= glideFlaring then
				glideFlaring = braking
				Remotes.GlideRequest:FireServer("flare", braking)
			end

			root.AssemblyLinearVelocity = Vector3.new(
				glideHeading.X * glideSpeed,
				-BallConfig.GLIDE_FALL_SPEED,
				glideHeading.Z * glideSpeed
			)
		end
	end

	-- Lock-on outlines: red = inside the aim cone, throws will home in.
	local lockThisFrame: Model? = nil
	local camera2 = Workspace.CurrentCamera
	if camera2 then
		local camLook = camera2.CFrame.LookVector
		local camFlat = Vector3.new(camLook.X, 0, camLook.Z)
		camFlat = if camFlat.Magnitude > 0.01 then camFlat.Unit else Vector3.zAxis
		for _, model in aimTargets() do
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			local inCone = false
			if targetRoot and targetRoot:IsA("BasePart") then
				local to = targetRoot.Position - root.Position
				local toFlat = Vector3.new(to.X, 0, to.Z)
				if toFlat.Magnitude > 1 then
					inCone = camFlat:Dot(toFlat.Unit) >= aimCos
				end
			end
			setLockOutline(model, inCone)
			if inCone then
				lockThisFrame = lockThisFrame or model
			end
		end
		currentLockModel = lockThisFrame
	end

end)

-- ── HUD ────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "BalloutHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local status = Instance.new("TextLabel")
status.Size = UDim2.fromOffset(520, 60)
status.Position = UDim2.new(0.5, -260, 0.2, 0)
status.BackgroundTransparency = 1
status.Text = "LMB throw · E spin · Q flip · RMB catch · F fake · Ctrl dash · Shift sprint · Alt ballform · G drop"
status.TextColor3 = Color3.fromRGB(255, 255, 255)
status.TextStrokeTransparency = 0.4
status.TextScaled = true
status.Font = Enum.Font.GothamBold
status.Parent = gui

-- Crosshair: a single tiny dot, riding ABOVE screen center (KC-style) —
-- subtle, and marks exactly where the ball throws to.
local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, BallConfig.CROSSHAIR_Y)
crosshair.Size = UDim2.fromOffset(4, 4)
crosshair.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
crosshair.BackgroundTransparency = 0.15
crosshair.BorderSizePixel = 0
crosshair.Parent = gui
local dotCorner = Instance.new("UICorner"); dotCorner.CornerRadius = UDim.new(1, 0); dotCorner.Parent = crosshair

-- Charge meter.
local meterBG = Instance.new("Frame")
meterBG.Size = UDim2.fromOffset(300, 22)
meterBG.Position = UDim2.new(0.5, -150, 0.85, 0)
meterBG.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
meterBG.BackgroundTransparency = 0.35
meterBG.BorderSizePixel = 0
meterBG.Parent = gui
local meterCorner = Instance.new("UICorner"); meterCorner.CornerRadius = UDim.new(0, 6); meterCorner.Parent = meterBG

local meterFill = Instance.new("Frame")
meterFill.Size = UDim2.fromScale(0, 1)
meterFill.BackgroundColor3 = Color3.fromRGB(255, 170, 40)
meterFill.BorderSizePixel = 0
meterFill.Parent = meterBG
local fillCorner = Instance.new("UICorner"); fillCorner.CornerRadius = UDim.new(0, 6); fillCorner.Parent = meterFill

-- ── Charge state ────────────────────────────────────────────────────────────
-- (charging / chargeStart / stickX are declared above the camera renderstep.)

local function setStatus(text: string, color: Color3)
	status.Text = text
	status.TextColor3 = color
end

-- KC-accurate trick throws: the throw only curves/lobs if released inside
-- the trick window opened by a spin (E) or flip (Q) jump.
local function currentCurveDir(): number
	if trickKind == "spin" and os.clock() < trickEndsAt then
		return trickDir
	end
	return 0
end

local function currentIsLob(): boolean
	return trickKind == "flip" and os.clock() < trickEndsAt
end

-- Held movement direction (decides which way a spin curves).
local function strafeDir(): number
	local dir = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= 1 end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += 1 end
	if dir == 0 and math.abs(stickX) > 0.35 then
		dir = math.sign(stickX)
	end
	return dir
end

local function flipHop()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and hum) then
		return
	end
	-- Standing flip = flip IN PLACE: kill horizontal momentum unless the
	-- player is actively moving.
	if hum.MoveDirection.Magnitude < 0.1 then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
	end
	if hum.FloorMaterial ~= Enum.Material.Air then
		-- Grounded: half-height snappy hop via a temporary JumpHeight.
		local original = hum.JumpHeight
		hum.JumpHeight = original * BallConfig.FLIP_HOP_FRAC
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		task.delay(0.15, function()
			if hum.Parent then
				hum.JumpHeight = original
			end
		end)
	elseif not airHopUsed then
		-- Mid-air: DOUBLE JUMP (once per airtime). Cancels the current
		-- vertical motion and fires a fresh half-jump from right here.
		airHopUsed = true
		local hopV = math.sqrt(2 * workspace.Gravity * hum.JumpHeight * BallConfig.FLIP_HOP_FRAC)
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, hopV, v.Z)
	end
end

-- E: spin. Works anywhere — ground, air, mid-run — and never interrupts
-- movement. Throw released during the window = curveball in the held
-- direction (defaults right if you're not holding one).
local function doSpinJump()
	if isStunned() then return end
	local dir = strafeDir()
	if dir == 0 then dir = 1 end
	trickKind = "spin"
	trickDir = dir
	trickEndsAt = os.clock() + BallConfig.TRICK_WINDOW
	spinDir = dir
	spinEndsAt = os.clock() + BallConfig.CURVE_SPIN_TIME
	flipHop() -- same half-height levitation as the flip
end

-- Q: quick tuck (a brief ballform — no physics rotation, can't glitch) with
-- a tiny pop. Throw released during the window = lob, fired from wherever
-- you are vertically.
local flipBusyUntil = 0
local function doFlipJump()
	if isStunned() or os.clock() < flipBusyUntil then
		return -- stunned, or tuck already playing
	end
	stowGlider() -- tricks take the glider away
	flipBusyUntil = os.clock() + BallConfig.FLIP_TIME
	trickKind = "flip"
	trickDir = 0
	trickEndsAt = os.clock() + BallConfig.TRICK_WINDOW
	flipEndsAt = os.clock() + BallConfig.FLIP_TIME
	Remotes.FlipRequest:FireServer() -- server applies the knees-to-chest tuck
	flipHop()
end

local function startCharge()
	if isStunned() then return end
	charging = true
	chargeStart = os.clock()
	-- KC-style: you CAN jump while charging — releasing mid-hop is the lob.
	-- The release-freeze stops you at whatever point of the jump you're in.
	Remotes.ThrowRequest:FireServer("start")
end

local function releaseThrow()
	if not charging then return end
	charging = false
	local frac = math.clamp((os.clock() - chargeStart) / BallConfig.FULL_CHARGE_TIME, 0, 1)
	meterFill.Size = UDim2.fromScale(0, 1)
	-- Aim = camera look, NOT the character (the model may be mid-spin).
	local cam = Workspace.CurrentCamera
	local aim = cam and cam.CFrame.LookVector or Vector3.zAxis
	local aimPoint = cam and computeLandingPoint(cam) or nil
	Remotes.ThrowRequest:FireServer("release", frac, currentCurveDir(), currentIsLob(), aim, aimPoint)
	trickKind = nil -- trick consumed
	-- Pin our height IMMEDIATELY (don't wait for the server round-trip) so
	-- we stop at exactly the height the ball leaves from. The server's
	-- Throw feedback extends this to the full hang.
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.FloorMaterial == Enum.Material.Air then
		hangEndsAt = math.max(hangEndsAt, os.clock() + 0.12)
	end
end

-- Fake throw: fired OUT of a real LMB windup. The charge is KEPT — keep
-- holding LMB through the fake and release right after for the instant
-- real throw (fake → throw).
local function doFake()
	if isStunned() then return end
	Remotes.FakeRequest:FireServer(currentCurveDir(), currentIsLob())
	trickKind = nil -- trick consumed by the fake
	if charging then
		-- Re-cock the arm once the fake swing finishes; charge never dropped.
		task.delay(0.35, function()
			if charging then
				Remotes.ThrowRequest:FireServer("start")
			end
		end)
	end
end

local function doCatch()
	if isStunned() then return end
	-- No catching mid-animation: flips, spins, dashes and rolls must fully
	-- finish first. Get baited mid-trick and the hit is yours to eat.
	local nowT = os.clock()
	if nowT < flipEndsAt or nowT < spinEndsAt or nowT < dashRollEndsAt
		or gliding or ballformOn then
		return
	end
	catchRootEndsAt = os.clock() + BallConfig.CATCH_WINDOW + 0.25
	-- Catch-step: capture the held direction at the press.
	local cam = Workspace.CurrentCamera
	catchSlideDir = if cam then ballInputDir(cam) else Vector3.zero
	catchSlideEndsAt = os.clock() + BallConfig.CATCH_SLIDE_TIME
	Remotes.CatchRequest:FireServer()
	setStatus("catch!", Color3.fromRGB(120, 200, 255))
end

-- Ball decor: while the ball is server-driven (anchored — flight/loose/free),
-- the stripe + aura shell replicate as SEPARATE parts and interpolate out of
-- sync on the client (visible gap at flight speeds). Snap them onto the ball
-- locally every render frame — frame-perfect on screen. While HELD the ball
-- is unanchored and the server's welds carry them; don't touch.
local decorBall: BasePart? = nil
local decorStripe: BasePart? = nil
local decorShell: BasePart? = nil

local function snapBallDecor()
	if not (decorBall and decorBall.Parent) then
		decorBall = Workspace:FindFirstChild("Dodgeball") :: BasePart?
		decorStripe = nil
		decorShell = nil
	end
	local b = decorBall
	if not b or not b.Anchored then
		return
	end
	if not (decorStripe and decorStripe.Parent) then
		decorStripe = b:FindFirstChild("Stripe") :: BasePart?
	end
	if not (decorShell and decorShell.Parent) then
		decorShell = b:FindFirstChild("ChargeAura") :: BasePart?
	end
	if decorStripe then
		decorStripe.CFrame = b.CFrame * CFrame.Angles(0, 0, math.rad(90))
	end
	if decorShell then
		decorShell.CFrame = b.CFrame
	end
end

RunService.RenderStepped:Connect(function()
	snapBallDecor()
	if charging then
		local frac = math.clamp((os.clock() - chargeStart) / BallConfig.FULL_CHARGE_TIME, 0, 1)
		meterFill.Size = UDim2.fromScale(frac, 1)
		meterFill.BackgroundColor3 = frac >= 0.99
			and Color3.fromRGB(255, 80, 80)
			or Color3.fromRGB(255, 170, 40)
	end
end)

-- ── Input (mouse + gamepad) ─────────────────────────────────────────────────
local function doDash()
	if isStunned() then return end
	local nowT = os.clock()
	if nowT < dashReadyAt then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root) then
		return
	end
	-- Dash along current input direction; fall back to facing.
	local dir = hum.MoveDirection
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector
	end
	stowGlider() -- dashing takes the glider away
	dashDir = Vector3.new(dir.X, 0, dir.Z).Unit
	dashEndsAt = nowT + BallConfig.DODGE_TIME
	dashRollEndsAt = dashEndsAt + BallConfig.DASH_ROLL_TIME
	dashRecovered = false
	setFootsteps(false) -- no walking sound through the dive/roll
	-- Cooldown counts from the END of the landing roll: no dash chaining.
	dashReadyAt = dashRollEndsAt + BallConfig.DODGE_COOLDOWN
	-- Tell the server: a bash into a loose ball pops it into the air.
	Remotes.DashRequest:FireServer(dashDir)
	setStatus("dash!", Color3.fromRGB(150, 230, 150))
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.KeyCode == Enum.KeyCode.ButtonR2 then
		startCharge()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2
		or input.KeyCode == Enum.KeyCode.ButtonL2 then
		doCatch()
	elseif input.KeyCode == Enum.KeyCode.F
		or input.KeyCode == Enum.KeyCode.ButtonR3 then
		doFake() -- tap mid-windup: fake release; charge is kept
	elseif input.KeyCode == Enum.KeyCode.LeftControl
		or input.KeyCode == Enum.KeyCode.ButtonX then
		doDash()
	elseif input.KeyCode == Enum.KeyCode.E
		or input.KeyCode == Enum.KeyCode.ButtonB then
		doSpinJump() -- KC: spin -> release = curveball
	elseif input.KeyCode == Enum.KeyCode.Q
		or input.KeyCode == Enum.KeyCode.ButtonY then
		doFlipJump() -- KC: flip -> release = lob
	elseif input.KeyCode == Enum.KeyCode.Space
		or input.KeyCode == Enum.KeyCode.ButtonA then
		-- Airborne: Space toggles the glider (grounded Space = normal jump).
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if gliding then
			stowGlider()
		elseif hum and hum.FloorMaterial == Enum.Material.Air
			and not ballformOn and not isStunned() and os.clock() > dashRollEndsAt then
			gliding = true
			glideFlaring = false
			glideTilt = 0
			glideHeading = Vector3.new(faceDir.X, 0, faceDir.Z).Unit
			-- Start from your current forward momentum (capped at boost).
			local rootPart = char and char:FindFirstChild("HumanoidRootPart")
			if rootPart and rootPart:IsA("BasePart") then
				local v = rootPart.AssemblyLinearVelocity
				glideSpeed = math.min(Vector3.new(v.X, 0, v.Z).Magnitude, BallConfig.GLIDE_STEER_SPEED)
			else
				glideSpeed = BallConfig.WALK_SPEED * BallConfig.GLIDE_DRIFT_FRAC
			end
			Remotes.GlideRequest:FireServer(true)
		end
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		-- Toggle the sprint latch (only arms if moving forward).
		if sprintLatched then
			sprintLatched = false
		elseif UserInputService:IsKeyDown(Enum.KeyCode.W)
			and not UserInputService:IsKeyDown(Enum.KeyCode.S) then
			sprintLatched = true
		end
	elseif input.KeyCode == Enum.KeyCode.R
		or input.KeyCode == Enum.KeyCode.ButtonL1 then
		if not isStunned() then
			Remotes.PassRequest:FireServer() -- pass / request a pass
		end
	elseif input.KeyCode == Enum.KeyCode.G
		or input.KeyCode == Enum.KeyCode.DPadLeft then
		Remotes.DropRequest:FireServer()
	elseif input.KeyCode == Enum.KeyCode.LeftAlt
		or input.KeyCode == Enum.KeyCode.ButtonR1 then
		if not isStunned() then
			Remotes.BallformRequest:FireServer(true) -- hold to stay balled
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.KeyCode == Enum.KeyCode.ButtonR2 then
		releaseThrow()
	elseif input.KeyCode == Enum.KeyCode.LeftAlt
		or input.KeyCode == Enum.KeyCode.ButtonR1 then
		Remotes.BallformRequest:FireServer(false) -- release: unroll
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		stickX = input.Position.X
		stickY = input.Position.Y
	end
end)

-- ── Server feedback ─────────────────────────────────────────────────────────
Remotes.Feedback.OnClientEvent:Connect(function(kind: string, data: any?)
	if kind == "PerfectCatch" or kind == "Catch" then
		catchRootEndsAt = os.clock() + 0.25 -- close beat, then free
	end
	if kind == "PerfectCatch" then
		setStatus(("PERFECT CATCH!  Overcharge Tier %d"):format(data.tier), Color3.fromRGB(190, 110, 255))
	elseif kind == "Catch" then
		setStatus("caught", Color3.fromRGB(120, 200, 255))
	elseif kind == "Throw" then
		local flavor = ""
		if data then
			-- (Spin/flip visuals already played at the E/Q press, KC-style.)
			if data.curve and data.curve ~= 0 then
				flavor = data.curve > 0 and "  · CURVE →" or "  · ← CURVE"
			end
			if data.lob then
				flavor ..= "  · LOB"
			end
			-- Aerial throw: hold vertical position while the throw plays.
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.FloorMaterial == Enum.Material.Air then
				hangEndsAt = os.clock() + BallConfig.AIR_THROW_HANG
			end
		end
		if data and data.locked == false then
			setStatus("NO LOCK — thrown blind!" .. flavor, Color3.fromRGB(180, 180, 180))
		elseif data and data.charged then
			setStatus(("SUPERCHARGED THROW  (%d studs/s)%s"):format(math.floor(data.speed), flavor), Color3.fromRGB(255, 120, 120))
		else
			setStatus("throw" .. flavor, Color3.fromRGB(255, 200, 120))
		end
	elseif kind == "Ballform" then
		ballformOn = data and data.on == true
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if ballformOn then
			-- Start the roll from current motion & orientation, popped
			-- slightly into the air so the curl drops and bounces in.
			if root and root:IsA("BasePart") then
				local v = root.AssemblyLinearVelocity
				rollVel = Vector3.new(v.X, 0, v.Z)
				rollCF = root.CFrame.Rotation
				root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, BallConfig.BALLFORM_ENTRY_POP), v.Z)
			end
			setFootsteps(false) -- balls don't have footsteps
			setStatus("BALL UP! roll with WASD", Color3.fromRGB(120, 180, 255))
		else
			-- Hand control back to the humanoid.
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
			setFootsteps(true)
			setStatus("unrolled", Color3.fromRGB(200, 200, 200))
		end
	elseif kind == "Pass" then
		setStatus("passed!", Color3.fromRGB(150, 200, 255))
	elseif kind == "PassAsked" then
		setStatus("asked for a pass", Color3.fromRGB(200, 200, 200))
	elseif kind == "PassPing" then
		setStatus("TEAMMATE WANTS A PASS! (R)", Color3.fromRGB(255, 220, 90))
	elseif kind == "NoPass" then
		setStatus("no teammate to pass with", Color3.fromRGB(170, 170, 170))
	elseif kind == "ChargeFaded" then
		setStatus("overcharge faded", Color3.fromRGB(170, 170, 170))
	elseif kind == "Whiffed" then
		-- Caught air: rooted only until the hug animation finishes.
		stunnedUntil = os.clock() + BallConfig.WHIFF_STUN
		catchRootEndsAt = os.clock() + BallConfig.WHIFF_STUN
		setStatus("WHIFFED — vulnerable!", Color3.fromRGB(255, 160, 70))
	elseif kind == "PopUp" then
		setStatus("BASH! ball popped up", Color3.fromRGB(150, 230, 150))
	elseif kind == "Fake" then
		-- Identical release visuals to a real throw — including the aerial
		-- vertical hold — the only difference is the ball stays put.
		setStatus("FAKE!", Color3.fromRGB(255, 220, 90))
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.FloorMaterial == Enum.Material.Air then
			hangEndsAt = os.clock() + BallConfig.AIR_THROW_HANG
		end
	elseif kind == "Hit" then
		if data and data.ko then
			setStatus("KO'd!", Color3.fromRGB(255, 70, 70))
		else
			setStatus(("hit! (%d/%d)"):format(data.count, BallConfig.HITS_TO_KO), Color3.fromRGB(255, 140, 90))
		end
		-- Stunned + shoved + camera rumble.
		stunnedUntil = os.clock() + BallConfig.STUN_TIME
		shakeEndsAt = os.clock() + BallConfig.HIT_SHAKE_TIME
		if data and typeof(data.knock) == "Vector3" then
			local k = data.knock
			knockVel = Vector3.new(k.X, 0, k.Z) * BallConfig.HIT_KNOCKBACK
			knockEndsAt = os.clock() + BallConfig.HIT_KNOCK_TIME
		end
	elseif kind == "KO" then
		setStatus("KO'd!", Color3.fromRGB(255, 70, 70))
	end
end)

print("[Ballout] Client ready.")
