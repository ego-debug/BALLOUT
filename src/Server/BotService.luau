--!strict
-- Ballout | BotService
-- Spawns a blocky ROBOT rig in classic Roblox-character shape (head, torso,
-- two arms, two legs) that BallService treats as a fighter. The rig is
-- grounded by raycast so its feet sit ON the floor, never in it.
--
-- Rig contract:
--   HumanoidRootPart — invisible anchored root (the only anchored part; the
--     limbs are unanchored + welded so root.CFrame teleports move the whole
--     bot — two anchored parts ignore their weld and separate)
--   RightHand — small hand part; BallService's handOf() welds the held ball here
--   Torso/Visor/Core — the accent parts MatchService recolors per team

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BallConfig = require(ReplicatedStorage.BallConfig)

local BotService = {}

local BODY = Color3.fromRGB(105, 105, 114) -- gunmetal
local JOINT = Color3.fromRGB(62, 62, 70)
local ACCENT = Color3.fromRGB(90, 200, 190) -- teal default; matches recolor per team

local function makePart(name: string, size: Vector3, color: Color3, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Metal
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function BotService.Spawn(position: Vector3, facePosition: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = BallConfig.BOT_NAME

	-- Ground the rig: feet ON whatever floor is under the requested spot.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local hit = Workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	local floorY = if hit then hit.Position.Y else position.Y - 3.3
	local rootPos = Vector3.new(position.X, floorY + 3.3, position.Z) -- legs 2.2 + half torso 1.1
	local rootCF = CFrame.lookAt(rootPos, Vector3.new(facePosition.X, rootPos.Y, facePosition.Z))

	-- Root: invisible, ANCHORED — the one part scripts move.
	local root = makePart("HumanoidRootPart", Vector3.new(2, 2.2, 1.1), BODY, model)
	root.Anchored = true
	root.Transparency = 1
	root.CFrame = rootCF

	local function attach(p: BasePart, offset: CFrame)
		p.CFrame = rootCF * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = root
	end

	-- Torso + glowing core
	local torso = makePart("Torso", Vector3.new(2, 2.2, 1.1), BODY, model)
	attach(torso, CFrame.new(0, 0, 0))
	local core = makePart("Core", Vector3.new(0.8, 0.8, 0.2), ACCENT, model)
	core.Material = Enum.Material.Neon
	attach(core, CFrame.new(0, 0.35, -0.6))

	-- Head: boxy with a neon visor + antenna
	local head = makePart("Head", Vector3.new(1.5, 1.3, 1.3), BODY, model)
	attach(head, CFrame.new(0, 1.85, 0))
	local visor = makePart("Visor", Vector3.new(1.1, 0.35, 0.15), ACCENT, model)
	visor.Material = Enum.Material.Neon
	attach(visor, CFrame.new(0, 1.95, -0.65))
	local antenna = makePart("Antenna", Vector3.new(0.15, 0.9, 0.15), JOINT, model)
	attach(antenna, CFrame.new(0.45, 2.9, 0))
	local tip = makePart("AntennaTip", Vector3.new(0.3, 0.3, 0.3), Color3.fromRGB(255, 80, 80), model)
	tip.Material = Enum.Material.Neon
	tip.Shape = Enum.PartType.Ball
	attach(tip, CFrame.new(0.45, 3.45, 0))

	-- Arms (shoulder joints read as robot shoulders)
	for _, side in { -1, 1 } do
		local shoulder = makePart("Shoulder", Vector3.new(0.6, 0.6, 0.6), JOINT, model)
		attach(shoulder, CFrame.new(side * 1.25, 0.9, 0))
		local arm = makePart(if side == 1 then "RightArm" else "LeftArm", Vector3.new(0.9, 2.1, 0.9), BODY, model)
		attach(arm, CFrame.new(side * 1.5, -0.1, 0))
	end
	-- hand: where BallService welds the held ball
	local hand = makePart("RightHand", Vector3.new(0.8, 0.6, 0.8), JOINT, model)
	attach(hand, CFrame.new(1.5, -1.35, 0))

	-- Legs
	for _, side in { -1, 1 } do
		local leg = makePart(if side == 1 then "RightLeg" else "LeftLeg", Vector3.new(0.9, 2.2, 0.9), JOINT, model)
		attach(leg, CFrame.new(side * 0.5, -2.2, 0))
	end

	-- Billboard label.
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 32)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = true
	bb.Parent = head
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = "🤖 Training Bot"
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.3
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Parent = bb

	model.PrimaryPart = root
	model.Parent = Workspace

	return model, root
end

return BotService
