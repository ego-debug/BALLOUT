--!strict
-- Ballout | AnimService
-- Procedural throw/catch poses via IKControl (works with the new
-- AnimationConstraint rigs, where Motor6D C0 is read-only, and composes
-- cleanly with the default walk/idle animations).
-- All functions are safe no-ops for rigs without arms (the training dummy).

local TweenService = game:GetService("TweenService")

local AnimService = {}

type Rig = {
	humanoid: Humanoid,
	torso: BasePart,
	rightIK: IKControl,
	rightTarget: Attachment,
	leftIK: IKControl?,
	leftTarget: Attachment?,
	rightLegIK: IKControl?,
	rightLegTarget: Attachment?,
	leftLegIK: IKControl?,
	leftLegTarget: Attachment?,
	headIK: IKControl?,
	headTarget: Attachment?,
	carryPole: Attachment?, -- elbow aims at this (down by the hip) while carrying
}

local rigs: { [Model]: Rig } = {}
local pendingRelease: { [IKControl]: thread } = {}

-- Target positions in UpperTorso local space (+X right, +Y up, -Z forward).
local POSE = {
	WINDUP = Vector3.new(1.2, 1.7, 1.0),      -- arm cocked up & behind
	SWING = Vector3.new(0.7, 0.4, -2.6),      -- follow-through forward
	OPEN_R = Vector3.new(3.2, 0.7, 0.0),      -- STARFISH: arms fully extended
	OPEN_L = Vector3.new(-3.2, 0.7, 0.0),     -- straight out to the sides
	CLOSE_R = Vector3.new(0.25, -0.55, -1.0), -- BEAR HUG: both arms wrap the
	CLOSE_L = Vector3.new(-0.25, -0.55, -1.0),-- ball against the stomach
	CARRY = Vector3.new(1.7, 0.85, -0.05),    -- KC carry: an L leaned slightly out —
	                                          -- hand above shoulder height, clearly
	                                          -- OUTSIDE the head; the carry POLE
	                                          -- (below) forces the elbow DOWN
	CARRY_OFF = Vector3.new(-0.6, 0.3, -0.9), -- off-hand curled forward, guarding
	-- Curled-up ball pose: legs folded ALL the way up so the bundle is
	-- roughly torso-sized, arms wrapped around, head pitched down at the
	-- belly. Foot targets sit at lower-chest height = maximal fold.
	TUCK_ARM_R = Vector3.new(0.5, -0.55, -1.0),
	TUCK_ARM_L = Vector3.new(-0.5, -0.55, -1.0),
	TUCK_FOOT_R = Vector3.new(0.25, -0.4, -0.9),
	TUCK_FOOT_L = Vector3.new(-0.25, -0.4, -0.9),
	TUCK_HEAD_LOOK = Vector3.new(0, -1.4, -0.5), -- head LOOKS at the belly
}

local function makeIK(humanoid: Humanoid, chainRoot: Instance, endEffector: Instance, target: Attachment, ikType: Enum.IKControlType?): IKControl
	local ik = Instance.new("IKControl")
	ik.Type = ikType or Enum.IKControlType.Position
	ik.ChainRoot = chainRoot
	ik.EndEffector = endEffector
	ik.Target = target
	ik.SmoothTime = 0.07
	ik.Weight = 0
	ik.Enabled = true
	ik.Parent = humanoid
	return ik
end

local function getRig(character: Model): Rig?
	local cached = rigs[character]
	if cached and cached.humanoid.Parent then
		return cached
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local torso = character:FindFirstChild("UpperTorso")
	local rUpper = character:FindFirstChild("RightUpperArm")
	local rHand = character:FindFirstChild("RightHand")
	if not (humanoid and torso and torso:IsA("BasePart") and rUpper and rHand) then
		return nil -- bot / R6 / still loading: no pose support
	end

	local rightTarget = Instance.new("Attachment")
	rightTarget.Name = "BalloutIK_R"
	rightTarget.Parent = torso
	local rig: Rig = {
		humanoid = humanoid,
		torso = torso,
		rightIK = makeIK(humanoid, rUpper, rHand, rightTarget),
		rightTarget = rightTarget,
	}

	local lUpper = character:FindFirstChild("LeftUpperArm")
	local lHand = character:FindFirstChild("LeftHand")
	if lUpper and lHand then
		local leftTarget = Instance.new("Attachment")
		leftTarget.Name = "BalloutIK_L"
		leftTarget.Parent = torso
		rig.leftTarget = leftTarget
		rig.leftIK = makeIK(humanoid, lUpper, lHand, leftTarget)
	end

	-- Legs (for the curled ball-up / tuck pose).
	local rLeg = character:FindFirstChild("RightUpperLeg")
	local rFoot = character:FindFirstChild("RightFoot")
	if rLeg and rFoot then
		local t = Instance.new("Attachment")
		t.Name = "BalloutIK_RF"
		t.Parent = torso
		rig.rightLegTarget = t
		rig.rightLegIK = makeIK(humanoid, rLeg, rFoot, t)
	end
	local lLeg = character:FindFirstChild("LeftUpperLeg")
	local lFoot = character:FindFirstChild("LeftFoot")
	if lLeg and lFoot then
		local t = Instance.new("Attachment")
		t.Name = "BalloutIK_LF"
		t.Parent = torso
		rig.leftLegTarget = t
		rig.leftLegIK = makeIK(humanoid, lLeg, lFoot, t)
	end

	-- Carry pole: sits down by the right hip; while carrying, the arm chain
	-- bends TOWARD it, pinning the elbow to point at the ground.
	local carryPole = Instance.new("Attachment")
	carryPole.Name = "BalloutIK_Pole"
	carryPole.Position = Vector3.new(1.5, -1.8, 0.1)
	carryPole.Parent = torso
	rig.carryPole = carryPole

	-- Head (for the tuck): LookAt mode — the head PITCHES DOWN to face the
	-- target (position mode barely moves it; rotation is what scrunches).
	local head = character:FindFirstChild("Head")
	if head then
		local t = Instance.new("Attachment")
		t.Name = "BalloutIK_H"
		t.Parent = torso
		rig.headTarget = t
		rig.headIK = makeIK(humanoid, torso, head, t, Enum.IKControlType.LookAt)
	end

	rigs[character] = rig
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			rigs[character] = nil
		end
	end)
	return rig
end

local function engage(ik: IKControl, weight: number, duration: number)
	local pending = pendingRelease[ik]
	if pending then
		task.cancel(pending)
		pendingRelease[ik] = nil
	end
	TweenService:Create(ik, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Weight = weight }):Play()
end

local function releaseAfter(ik: IKControl, delay: number)
	pendingRelease[ik] = task.delay(delay, function()
		pendingRelease[ik] = nil
		engage(ik, 0, 0.2)
	end)
end

-- Arm cocked overhead while charging a throw. Held until Swing or Reset.
function AnimService.Windup(character: Model)
	local rig = getRig(character)
	if not rig then return end
	rig.rightIK.Pole = nil
	rig.rightTarget.Position = POSE.WINDUP
	engage(rig.rightIK, 1, 0.12)
end

-- Fast forward swing on release, then let the normal animation take over.
function AnimService.Swing(character: Model)
	local rig = getRig(character)
	if not rig then return end
	rig.rightIK.Pole = nil
	rig.rightTarget.Position = POSE.SWING
	engage(rig.rightIK, 1, 0.07)
	releaseAfter(rig.rightIK, 0.22)
	-- Drop the carry off-hand curl as the ball leaves.
	if rig.leftIK then
		engage(rig.leftIK, 0, 0.2)
	end
end

-- Catch attempt: arms spread WIDE OPEN for the whole window — the visible
-- "I'm trying to catch" tell. If no ball arrives, they drop (whiffed/faked).
function AnimService.CatchOpen(character: Model, holdTime: number)
	local rig = getRig(character)
	if not rig then return end
	rig.rightIK.Pole = nil
	rig.rightTarget.Position = POSE.OPEN_R
	engage(rig.rightIK, 1, 0.06)
	releaseAfter(rig.rightIK, holdTime)
	if rig.leftIK and rig.leftTarget then
		rig.leftTarget.Position = POSE.OPEN_L
		engage(rig.leftIK, 1, 0.06)
		releaseAfter(rig.leftIK, holdTime)
	end
end

-- Ball made contact: arms SNAP CLOSED around it, then settle into the carry.
function AnimService.CatchClose(character: Model)
	local rig = getRig(character)
	if not rig then return end
	rig.rightIK.Pole = nil
	rig.rightTarget.Position = POSE.CLOSE_R
	engage(rig.rightIK, 1, 0.05)
	if rig.leftIK and rig.leftTarget then
		rig.leftTarget.Position = POSE.CLOSE_L
		engage(rig.leftIK, 1, 0.05)
		releaseAfter(rig.leftIK, 0.25)
	end
	-- BallService transitions to the carry pose afterwards (it knows whether
	-- the catcher still holds the ball by then).
end

-- Persistent throw-ready carry: leaned-L arm, elbow pinned DOWN via the
-- carry pole, ball on the palm beside the head; off-hand curled forward.
function AnimService.Carry(character: Model)
	local rig = getRig(character)
	if not rig then return end
	rig.rightIK.Pole = rig.carryPole
	rig.rightTarget.Position = POSE.CARRY
	engage(rig.rightIK, 0.9, 0.15)
	if rig.leftIK and rig.leftTarget then
		rig.leftTarget.Position = POSE.CARRY_OFF
		engage(rig.leftIK, 0.75, 0.15)
	end
end

-- Glider grip: hands up on the bar overhead-forward, body hanging.
-- bothHands=false grips with the LEFT hand only (right keeps the ball).
function AnimService.GlidePose(character: Model, bothHands: boolean)
	local rig = getRig(character)
	if not rig then return end
	if rig.leftIK and rig.leftTarget then
		rig.leftTarget.Position = Vector3.new(-0.85, 1.05, -0.6) -- left grip
		engage(rig.leftIK, 1, 0.1)
	end
	if bothHands then
		rig.rightIK.Pole = nil
		rig.rightTarget.Position = Vector3.new(0.85, 1.05, -0.6) -- right grip
		engage(rig.rightIK, 1, 0.1)
	end
end

-- Glide brake flare: legs swing forward while the body tilts back.
function AnimService.GlideFlare(character: Model, on: boolean)
	local rig = getRig(character)
	if not rig then return end
	if on then
		if rig.rightLegIK and rig.rightLegTarget then
			rig.rightLegTarget.Position = Vector3.new(0.35, -1.2, -1.6)
			engage(rig.rightLegIK, 1, 0.12)
		end
		if rig.leftLegIK and rig.leftLegTarget then
			rig.leftLegTarget.Position = Vector3.new(-0.35, -1.2, -1.6)
			engage(rig.leftLegIK, 1, 0.12)
		end
	else
		if rig.rightLegIK then engage(rig.rightLegIK, 0, 0.15) end
		if rig.leftLegIK then engage(rig.leftLegIK, 0, 0.15) end
	end
end

-- Sprint carry: ball hugged in FRONT with BOTH hands while running.
-- (Walking keeps the raised-L carry above.)
function AnimService.CarrySprint(character: Model)
	local rig = getRig(character)
	if not rig then return end
	rig.rightIK.Pole = nil
	rig.rightTarget.Position = Vector3.new(0.35, 0.15, -1.05)
	engage(rig.rightIK, 0.95, 0.15)
	if rig.leftIK and rig.leftTarget then
		rig.leftTarget.Position = Vector3.new(-0.35, 0.15, -1.05)
		engage(rig.leftIK, 0.95, 0.15)
	end
end


-- Curl into the ball-up pose: knees to chest, arms wrapped around the legs.
-- Still a human body — just balled up. Held until Untuck.
function AnimService.Tuck(character: Model)
	local rig = getRig(character)
	if not rig then return end
	rig.rightIK.Pole = nil
	rig.rightTarget.Position = POSE.TUCK_ARM_R
	engage(rig.rightIK, 1, 0.1)
	if rig.leftIK and rig.leftTarget then
		rig.leftTarget.Position = POSE.TUCK_ARM_L
		engage(rig.leftIK, 1, 0.1)
	end
	if rig.rightLegIK and rig.rightLegTarget then
		rig.rightLegTarget.Position = POSE.TUCK_FOOT_R
		engage(rig.rightLegIK, 1, 0.1)
	end
	if rig.leftLegIK and rig.leftLegTarget then
		rig.leftLegTarget.Position = POSE.TUCK_FOOT_L
		engage(rig.leftLegIK, 1, 0.1)
	end
	if rig.headIK and rig.headTarget then
		rig.headTarget.Position = POSE.TUCK_HEAD_LOOK
		engage(rig.headIK, 1, 0.1)
	end
end

function AnimService.Untuck(character: Model)
	local rig = rigs[character]
	if not rig then return end
	engage(rig.rightIK, 0, 0.15)
	if rig.leftIK then engage(rig.leftIK, 0, 0.15) end
	if rig.rightLegIK then engage(rig.rightLegIK, 0, 0.15) end
	if rig.leftLegIK then engage(rig.leftLegIK, 0, 0.15) end
	if rig.headIK then engage(rig.headIK, 0, 0.15) end
end

-- Brief tuck for the Q flip: curl, then release automatically.
function AnimService.TuckPulse(character: Model, duration: number)
	local rig = getRig(character)
	if not rig then return end
	AnimService.Tuck(character)
	for _, ik in { rig.rightIK, rig.leftIK, rig.rightLegIK, rig.leftLegIK, rig.headIK } do
		if ik then
			releaseAfter(ik, duration)
		end
	end
end

-- Superman dive dash: the lead arm punches STRAIGHT FORWARD along the body
-- axis with the head aligned down the same line; the other arm sweeps back
-- along the side; legs stay straight (trailing). The pose itself is always
-- identical — the whole BODY rotates to face the dash on the client, so the
-- dive leads with elbow + head no matter the direction.
function AnimService.DashPose(character: Model)
	local rig = getRig(character)
	if not rig then return end
	local dur = 0.3
	-- Lunge pose (KC reference, top-down): body leans ~38 forward; fist
	-- punched forward under the chin; left knee DRIVEN UP toward the chest;
	-- right leg trailing back.

	-- Lead (right) arm: fist punched straight forward at chest height.
	rig.rightIK.Pole = nil
	rig.rightTarget.Position = Vector3.new(0.35, 0.5, -1.9)
	engage(rig.rightIK, 1, 0.05)
	releaseAfter(rig.rightIK, dur)

	-- Trailing arm: swept back along the body.
	if rig.leftIK and rig.leftTarget then
		rig.leftTarget.Position = Vector3.new(-0.45, -0.3, 1.1)
		engage(rig.leftIK, 1, 0.05)
		releaseAfter(rig.leftIK, dur)
	end

	-- Head: eyes level on the horizon (compensates the forward lean).
	if rig.headIK and rig.headTarget then
		rig.headTarget.Position = Vector3.new(0, 3.5, -5)
		engage(rig.headIK, 1, 0.05)
		releaseAfter(rig.headIK, dur)
	end

	-- Left knee driven UP toward the chest.
	if rig.leftLegIK and rig.leftLegTarget then
		rig.leftLegTarget.Position = Vector3.new(-0.3, -1.1, -0.9)
		engage(rig.leftLegIK, 1, 0.05)
		releaseAfter(rig.leftLegIK, dur)
	end
	-- Right leg: trailing straight back, unposed.
end

-- Hit reaction, direction-aware:
--  FRONT hit: knocked back, arms/legs whip forward (dodgeball to the chest).
--  BEHIND hit: shoved forward, arms SPREAD WIDE and trail loosely back —
--  arms can't reach straight behind, so the spread reads natural instead
--  of contorted.
function AnimService.HitReact(character: Model, fromBehind: boolean)
	local rig = getRig(character)
	if not rig then return end
	rig.rightIK.Pole = nil
	if fromBehind then
		rig.rightTarget.Position = Vector3.new(1.7, 0.15, 0.8)
		engage(rig.rightIK, 0.85, 0.05)
		releaseAfter(rig.rightIK, 0.35)
		if rig.leftIK and rig.leftTarget then
			rig.leftTarget.Position = Vector3.new(-1.7, 0.15, 0.8)
			engage(rig.leftIK, 0.85, 0.05)
			releaseAfter(rig.leftIK, 0.35)
		end
		if rig.rightLegIK and rig.rightLegTarget then
			rig.rightLegTarget.Position = Vector3.new(0.4, -1.5, 0.9)
			engage(rig.rightLegIK, 0.9, 0.05)
			releaseAfter(rig.rightLegIK, 0.3)
		end
		if rig.leftLegIK and rig.leftLegTarget then
			rig.leftLegTarget.Position = Vector3.new(-0.4, -1.5, 0.9)
			engage(rig.leftLegIK, 0.9, 0.05)
			releaseAfter(rig.leftLegIK, 0.3)
		end
	else
		rig.rightTarget.Position = Vector3.new(0.7, 0.3, -1.9)
		engage(rig.rightIK, 1, 0.05)
		releaseAfter(rig.rightIK, 0.35)
		if rig.leftIK and rig.leftTarget then
			rig.leftTarget.Position = Vector3.new(-0.7, 0.3, -1.9)
			engage(rig.leftIK, 1, 0.05)
			releaseAfter(rig.leftIK, 0.35)
		end
		if rig.rightLegIK and rig.rightLegTarget then
			rig.rightLegTarget.Position = Vector3.new(0.35, -1.3, -1.6)
			engage(rig.rightLegIK, 1, 0.05)
			releaseAfter(rig.rightLegIK, 0.3)
		end
		if rig.leftLegIK and rig.leftLegTarget then
			rig.leftLegTarget.Position = Vector3.new(-0.35, -1.3, -1.6)
			engage(rig.leftLegIK, 1, 0.05)
			releaseAfter(rig.leftLegIK, 0.3)
		end
	end
end

-- Drop any pose immediately (holder lost the ball, KO, etc).
function AnimService.Reset(character: Model)
	local rig = rigs[character]
	if not rig then return end
	engage(rig.rightIK, 0, 0.15)
	if rig.leftIK then engage(rig.leftIK, 0, 0.15) end
	if rig.rightLegIK then engage(rig.rightLegIK, 0, 0.15) end
	if rig.leftLegIK then engage(rig.leftLegIK, 0, 0.15) end
	if rig.headIK then engage(rig.headIK, 0, 0.15) end
end

return AnimService
