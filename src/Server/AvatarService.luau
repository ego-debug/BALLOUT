--!strict
-- Ballout | AvatarService
-- Locks every player to ONE canonical body build.
--
-- WHY THIS EXISTS (two reasons, both load-bearing):
--
-- 1. FAIRNESS. Jump *height* is already uniform (Main sets Humanoid.JumpHeight
--    from BallConfig), but that is not enough on its own: a taller avatar's
--    feet clear a higher ledge from the same jump, and its head/torso occupy
--    more space as a target. Scaffold Row's climb is gated on exact hop
--    heights (floor -> container -> container -> catwalk, ~6.5 studs each), so
--    an unlocked avatar scale would silently break those gates for some
--    players and not others.
--
-- 2. COSMETICS. With the BODY fixed, everything a shop can sell later —
--    outfits, intros, poses, trails — is pure appearance and can never affect
--    hitbox, reach or movement. That keeps monetisation cosmetic-only rather
--    than pay-to-win.
--
-- WHAT IS LOCKED: body scale (height/width/depth/head) and the blocky classic
-- proportions. WHAT IS NOT (yet): clothing and accessories, so players keep
-- their own look for now. A future shop can swap those freely — call
-- AvatarService.ApplyOutfit() on top of Normalize() and the body stays put.

local AvatarService = {}

-- The canonical Ballout build. Scale 1 = Roblox default height; body/proportion
-- 0 = classic blocky (not the slim "Rthro" proportions).
local CANON = {
	HeightScale = 1,
	WidthScale = 1,
	DepthScale = 1,
	HeadScale = 1,
	BodyTypeScale = 0,   -- 0 = blocky classic, 1 = Rthro
	ProportionScale = 0,
}

-- Roblox exposes avatar scale in two places depending on rig/version: as
-- NumberValue children of the Humanoid, and through HumanoidDescription.
-- Writing the NumberValues is instant and cannot fail; ApplyDescription is
-- authoritative but rebuilds the character (slow, and it re-parents limbs).
-- Do the cheap write first so the size is right immediately, then reconcile
-- through the description only if it actually differs.
local SCALE_VALUES = {
	BodyHeightScale = "HeightScale",
	BodyWidthScale = "WidthScale",
	BodyDepthScale = "DepthScale",
	HeadScale = "HeadScale",
}

function AvatarService.Normalize(humanoid: Humanoid)
	for valueName, canonKey in SCALE_VALUES do
		local nv = humanoid:FindFirstChild(valueName)
		if nv and nv:IsA("NumberValue") then
			nv.Value = CANON[canonKey]
		end
	end

	-- Reconcile through the description too, so proportions (blocky vs Rthro)
	-- are correct and the scale sticks against anything that re-applies an
	-- appearance later. Wrapped: ApplyDescription throws if the character is
	-- being removed mid-call (common on fast respawns).
	task.spawn(function()
		local ok, desc = pcall(function()
			return humanoid:GetAppliedDescription()
		end)
		if not ok or not desc then
			return
		end
		local dirty = false
		for key, want in CANON do
			if (desc :: any)[key] ~= want then
				(desc :: any)[key] = want
				dirty = true
			end
		end
		if dirty then
			pcall(function()
				humanoid:ApplyDescription(desc)
			end)
		end
	end)
end

-- Hook for the future cosmetics shop: swap clothing/accessories while the
-- locked body scale above is left untouched.
function AvatarService.ApplyOutfit(humanoid: Humanoid, outfitDescription: HumanoidDescription)
	local desc = outfitDescription:Clone()
	for key, want in CANON do
		(desc :: any)[key] = want
	end
	pcall(function()
		humanoid:ApplyDescription(desc)
	end)
end

return AvatarService
