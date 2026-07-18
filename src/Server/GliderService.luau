--!strict
-- Ballout | GliderService
-- KC-style hang glider: a swept wing floating clearly ABOVE the head,
-- suspension lines running down to biker-style handlebars that the
-- character grips at chest height.

local GliderService = {}

local gliders: { [Model]: Model } = {}

local WING_COLOR = Color3.fromRGB(62, 62, 68)
local TRIM_COLOR = Color3.fromRGB(205, 45, 48)
local BAR_COLOR = Color3.fromRGB(50, 50, 54)
local LINE_COLOR = Color3.fromRGB(235, 190, 90)

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function weldTo(anchor: BasePart, p: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = anchor
	w.Part1 = p
	w.Parent = p
end

function GliderService.Enable(character: Model)
	if gliders[character] then
		return
	end
	local torso = character:FindFirstChild("UpperTorso")
	if not (torso and torso:IsA("BasePart")) then
		return
	end
	local torsoCF = (torso :: BasePart).CFrame

	local model = Instance.new("Model")
	model.Name = "BalloutGlider"

	-- Center spar above and BEHIND the head, pitched so the wing slants
	-- back — visible above the character from the play camera.
	local spar = part({
		Name = "Spar",
		Size = Vector3.new(0.3, 0.25, 3.0),
		Color = BAR_COLOR,
		Material = Enum.Material.Metal,
		CFrame = torsoCF * CFrame.new(0, 3.3, 0.9) * CFrame.Angles(math.rad(14), 0, 0),
	})
	spar.Parent = model
	weldTo(torso :: BasePart, spar)

	-- Delta wing: a tapered two-panel span per side + nose piece.
	for _, side in { -1, 1 } do
		local inner = part({
			Name = "WingInner",
			Size = Vector3.new(2.8, 0.12, 2.7),
			Color = WING_COLOR,
			Material = Enum.Material.Fabric,
			CFrame = spar.CFrame
				* CFrame.new(side * 1.45, 0.05, 0.15)
				* CFrame.Angles(0, -side * math.rad(10), side * math.rad(5)),
		})
		inner.Parent = model
		weldTo(spar, inner)
		local innerTrim = part({
			Name = "Trim",
			Size = Vector3.new(2.8, 0.16, 0.35),
			Color = TRIM_COLOR,
			Material = Enum.Material.SmoothPlastic,
			CFrame = inner.CFrame * CFrame.new(0, 0.02, -1.3),
		})
		innerTrim.Parent = model
		weldTo(inner, innerTrim)

		local outer = part({
			Name = "WingOuter",
			Size = Vector3.new(2.7, 0.12, 1.9),
			Color = WING_COLOR,
			Material = Enum.Material.Fabric,
			CFrame = spar.CFrame
				* CFrame.new(side * 3.85, -0.12, 0.75)
				* CFrame.Angles(0, -side * math.rad(26), side * math.rad(12)),
		})
		outer.Parent = model
		weldTo(spar, outer)
		local outerTrim = part({
			Name = "Trim",
			Size = Vector3.new(2.7, 0.16, 0.35),
			Color = TRIM_COLOR,
			Material = Enum.Material.SmoothPlastic,
			CFrame = outer.CFrame * CFrame.new(0, 0.02, -0.9),
		})
		outerTrim.Parent = model
		weldTo(outer, outerTrim)
	end

	-- Nose piece at the wing's front point.
	local nose = part({
		Name = "Nose",
		Size = Vector3.new(0.9, 0.16, 1.3),
		Color = TRIM_COLOR,
		Material = Enum.Material.SmoothPlastic,
		CFrame = spar.CFrame * CFrame.new(0, 0.05, -1.5),
	})
	nose.Parent = model
	weldTo(spar, nose)

	-- Biker handlebars at chest height: center bar + two grips angled out.
	local bar = part({
		Name = "GripBar",
		Size = Vector3.new(1.5, 0.16, 0.16),
		Color = BAR_COLOR,
		Material = Enum.Material.Metal,
		CFrame = torsoCF * CFrame.new(0, 1.15, -0.6),
	})
	bar.Parent = model
	weldTo(torso :: BasePart, bar)
	for _, side in { -1, 1 } do
		local grip = part({
			Name = "Grip",
			Size = Vector3.new(0.14, 0.6, 0.14),
			Color = TRIM_COLOR,
			Material = Enum.Material.SmoothPlastic,
			CFrame = torsoCF * CFrame.new(side * 0.85, 1.0, -0.6) * CFrame.Angles(0, 0, side * math.rad(28)),
		})
		grip.Parent = model
		weldTo(bar, grip)
	end

	-- Golden suspension lines: wing underside down to the bar ends.
	local anchorsUp = {
		Vector3.new(-1.4, 3.35, 1.4), Vector3.new(1.4, 3.35, 1.4),
		Vector3.new(-1.4, 3.1, 0.1), Vector3.new(1.4, 3.1, 0.1),
	}
	local anchorsDown = {
		Vector3.new(-0.8, 1.15, -0.55), Vector3.new(0.8, 1.15, -0.55),
		Vector3.new(-0.8, 1.15, -0.55), Vector3.new(0.8, 1.15, -0.55),
	}
	for i, up in anchorsUp do
		local a = torsoCF:PointToWorldSpace(up)
		local b = torsoCF:PointToWorldSpace(anchorsDown[i])
		local len = (b - a).Magnitude
		local wire = part({
			Name = "Line",
			Size = Vector3.new(0.06, 0.06, len),
			Color = LINE_COLOR,
			Material = Enum.Material.Neon,
			CFrame = CFrame.lookAt((a + b) / 2, b),
		})
		wire.Parent = model
		weldTo(spar, wire)
	end

	model.Parent = character
	gliders[character] = model
end

function GliderService.Disable(character: Model)
	local model = gliders[character]
	if model then
		gliders[character] = nil
		model:Destroy()
	end
end

return GliderService
