--!strict
-- Ballout | SoundKit — every sound in the game, one place.
--
-- All catalog audio, licensed for any Roblox game: SFX are Pro Sound Effects
-- (Roblox partner library) plus a few community classics; music + stings are
-- APM Music (Roblox's licensed library) — electro swing, the same musical
-- identity KC had, without touching a single KC track.
--
-- Server: SoundKit.PlayAt(part, "name") — positional one-shot everyone hears
-- with 3D falloff (parented to the part, so it follows flights).
-- Client: SoundKit.Play2D("name") — flat local UI/feel sounds.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local SoundKit = {}

export type Spec = { id: number, volume: number, speed: number?, maxDist: number? }

SoundKit.SOUNDS = {
	-- combat
	throw = { id = 9120972444, volume = 0.8 },              -- air whoosh (Pro SFX)
	dash = { id = 9120972321, volume = 0.55, speed = 1.15 },-- shorter whoosh
	catch = { id = 9113574801, volume = 0.9 },              -- glove pop (Pro SFX)
	perfect = { id = 4612374393, volume = 0.85 },           -- clean bling chime
	pickup = { id = 9113574801, volume = 0.5, speed = 1.3 },-- soft scoop pop
	hit = { id = 9113565276, volume = 1 },                  -- hard bag hit (Pro SFX)
	ko = { id = 79476956608476, volume = 1 },               -- heavy downslam
	bounce = { id = 377958030, volume = 0.6 },              -- basketball bounce
	-- carry / chains
	chainRattle = { id = 9113763589, volume = 0.8 },        -- per mash press
	chainBreak = { id = 9125434836, volume = 1 },           -- burst free
	-- hazards
	clang = { id = 9125672562, volume = 1, maxDist = 300 }, -- wrecking ball hit
	-- match beats (client 2D)
	tick = { id = 4612374495, volume = 0.6, speed = 0.8 },  -- countdown 3-2-1
	whistle = { id = 9117264345, volume = 0.8 },            -- GO! referee blast
	winSting = { id = 1840076509, volume = 0.7 },           -- victory (APM)
	loseSting = { id = 115475565309914, volume = 0.6 },     -- defeat (APM)
	charge = { id = 95429388386736, volume = 0.45 },        -- windup charge-up
	-- music (APM electro swing — KC's genre, none of KC's tracks)
	lobbyMusic = { id = 9040344598, volume = 0.25 },
	matchMusic = { id = 1837102958, volume = 0.3 },
} :: { [string]: Spec }

local function build(name: string): Sound?
	local spec = SoundKit.SOUNDS[name]
	if not spec then
		warn("[SoundKit] unknown sound: " .. name)
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "Sfx_" .. name
	s.SoundId = "rbxassetid://" .. spec.id
	s.Volume = spec.volume
	s.PlaybackSpeed = spec.speed or 1
	s.RollOffMaxDistance = spec.maxDist or 160
	s.RollOffMinDistance = 12
	return s
end

-- Positional one-shot: parented to the part (follows it), self-cleaning.
function SoundKit.PlayAt(part: BasePart, name: string)
	if part.Parent == nil then
		return
	end
	local s = build(name)
	if s then
		s.Parent = part
		s:Play()
		Debris:AddItem(s, 6)
	end
end

-- Flat local one-shot (client only): UI beats, personal feel.
function SoundKit.Play2D(name: string)
	local s = build(name)
	if s then
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 6)
	end
end

-- A persistent, reusable sound (music loops, the charge windup).
function SoundKit.Create(name: string, looped: boolean): Sound?
	local s = build(name)
	if s then
		s.Looped = looped
		s.Parent = SoundService
	end
	return s
end

return SoundKit
