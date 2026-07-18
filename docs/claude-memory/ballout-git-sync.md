---
name: ballout-git-sync
description: "Ballout is on GitHub (ego-debug/BALLOUT); user works across a desktop and a laptop"
metadata:
  type: project
---

As of 2026-07-18, [[ballout-project]] is version-controlled and synced between
the user's **desktop and laptop**.

- Repo: `https://github.com/ego-debug/BALLOUT.git` (branch `main`)
- Desktop path: `C:\Users\Owner\Downloads\roblox game saves\BALLOUT FILE`
- Safety backup of pre-git state: `_BALLOUT_BACKUP_20260714_2100` (same parent folder)

**The live place file is `BALLOUT.rbxl`.** `Place1.rbxl` is a stale 2026-07-13
copy kept only as a fallback — never open it.

**Why this matters:** the HQ map lives *inside* the binary `.rbxl`, not in Rojo,
so it **cannot be merged**. `.gitattributes` marks `*.rbxl` as binary so git
never applies CRLF conversion (which would corrupt it). The workflow the user
must follow is **`git pull` before starting, `git push` after stopping** — if
the map is edited on both machines without syncing, one version has to be
thrown away.

**How to apply:** when the user reports missing work or a "reverted" map,
suspect an unpushed session on the other machine before suspecting a bug. Check
`git log` / `git status` on both. Also remind them that Ctrl+S in Studio is
required after map changes — Rojo does not carry them.

Setup docs live in the repo itself: `README.md` (machine setup + workflow) and
`CLAUDE.md` (project context, auto-loaded by Claude Code).
