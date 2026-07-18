---
name: ballout-project
description: "Ballout — a Roblox dodgeball game, clone of Knockout City with changes"
metadata:
  type: project
---

**Ballout** is a new Roblox game the user is building: a clone of **Knockout City** (Velan Studios' dodgeball game) with timing-based catches, ball-ups, ball rolls, etc. — but rebranded as "Ballout" with some things changed.

Setup (as of 2026-07-13):
- Project folder: `C:\Users\Owner\Downloads\roblox game saves\BALLOUT FILE\` (live place file is now `BALLOUT.rbxl`; `Place1.rbxl` is a stale 7/13 copy).
- Rojo 7.7.0 at `/c/Tools/Rojo/rojo`; project = `default.project.json` syncing `src/{Server,Client,Shared,First,ServerStorage}`.
- Roblox Studio MCP connects **one Studio window at a time** — had to close the other game ("Food Truck TAKEOVER!", a SEPARATE unrelated game — do NOT modify it) so the Ballout window would connect.
- Started from a fresh blank baseplate.

**Design intent (locked 2026-07-13):** gameplay feel/mechanics/timing are a **1:1 clone** of Knockout City (mechanics aren't copyrightable). To stay clear of DMCA, only the copyrightable *expression* changes: original maps, environments, some reworked/renamed modes, original art/characters/UI/music, and our own naming (game = "Ballout"; special balls keep 1:1 behavior but get renamed). KO model confirmed: **2 hits to KO**, catch negates a hit, ball-form/cage/off-map = instant KO.

Full spec lives in `DESIGN.md`. See [[research-focus-game-feel]] and [[ballout-git-sync]].

**HQ map (2026-07-14):** the game's start point is a remake of KC's Hideout — main deck (garage w/ trophy case+jukebox, radio tower, spawn drum, launch pads) + LOWER dummy-roof (training dummy, 5 purple pod props, soccer court w/ pushable giant ball) bridged by planks, ringed by taller barrier towers over a cloud void. Map is PLACE-SIDE (not Rojo): regenerate via `tools/build_map.luau` run in Edit-mode execute_luau (destroys+rebuilds Workspace.BalloutMap). Deck tops: main Y=0, dummy roof Y=-6 — ball floor logic is raycast-based (floorYBelow in BallService), NOT a flat plane. Main.server.luau finds "DummyPad" part for bot spawn and resets "SoccerBall" if it falls. User must Ctrl+S in Studio to keep map changes.
