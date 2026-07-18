--!strict
-- Ballout | BotService
-- Spawns a simple stationary training dummy that the BallService treats as a
-- fighter. With BOT_ALWAYS_CATCH it perfect-catches every ball and throws back.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BallConfig = require(ReplicatedStorage.BallConfig)

local BotService = {}

local function makePart(name: string, size: Vector3, color: Color3, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function BotService.Spawn(position: Vector3, facePosition: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = BallConfig.BOT_NAME

	-- Root/torso (named HumanoidRootPart so BallService can use it as the ref part).
	local root = makePart("HumanoidRootPart", Vector3.new(2, 3, 1), Color3.fromRGB(70, 130, 200), model)
	local look = Vector3.new(facePosition.X, position.Y, facePosition.Z)
	root.CFrame = CFrame.lookAt(position, look)

	-- Head.
	local head = makePart("Head", Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(90, 160, 230), model)
	head.Shape = Enum.PartType.Ball
	head.CFrame = root.CFrame * CFrame.new(0, 2.2, 0)
	local weldH = Instance.new("WeldConstraint"); weldH.Part0 = root; weldH.Part1 = head; weldH.Parent = root

	-- Feet marker so it reads as a character.
	local base = makePart("Base", Vector3.new(2.2, 0.4, 1.4), Color3.fromRGB(40, 80, 140), model)
	base.CFrame = root.CFrame * CFrame.new(0, -1.7, 0)
	local weldB = Instance.new("WeldConstraint"); weldB.Part0 = root; weldB.Part1 = base; weldB.Parent = root

	-- Billboard label.
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 32)
	bb.StudsOffset = Vector3.new(0, 3.4, 0)
	bb.AlwaysOnTop = true
	bb.Parent = head
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = "🎯 Training Dummy"
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
