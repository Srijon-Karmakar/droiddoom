# AGENTS.md — Instructions for AI coding agents (canonical)

> This file is the **single source of truth for how any AI agent works on this repo** (Claude Code, Codex, Cursor, Copilot, and so on).
> `CLAUDE.md` imports this file. Keep agent instructions here and nowhere else.

## 1. Project in one paragraph
**Droidoom** (working title) is a 2D top-down twin-stick action shooter with RPG upgrades, built in **Godot 4 (typed GDScript)** for **PC (Steam), Web and Mobile (Android/iOS)**. The player pilots **HOLLOW**, a human-driven droid with no onboard AI, through level-based zones occupied by the AI **AXIOM**'s droid army. Kills earn Scrap for upgrades, and the goal is to liberate every region of the world. Signature mechanics: **Reclaim** (temporarily turn enemy droids into allies), **Neural Sync** (perfect-dodge slow-motion) and **AXIOM Adapts** (enemies gain resistance to your most-used damage type).

## 2. ⚠️ Session protocol — MANDATORY

### At the START of every session (before writing any code)
1. Read **`docs/agent/PROGRESS.md`**. It tells you the current phase, the active task and the next steps.
2. Read the current phase section of **`docs/agent/TASKS.md`**.
3. Skim **`docs/agent/DECISIONS.md`** for anything related to your task. **Never contradict an Accepted decision without asking the user.**
4. Read only the relevant sections of the GDD / TDD:
   - Design questions → `docs/01_GAME_DESIGN_DOCUMENT.md`
   - Architecture, folders, systems → `docs/03_TECHNICAL_DESIGN.md`
   - Monetization / store questions → `docs/02_BUSINESS_MODEL.md`
5. Follow `docs/agent/CONVENTIONS.md` for all code.

### DURING the session (context can be compacted or lost at any time)
- **After each completed task** (not just at the end of the session):
  - Tick it in `TASKS.md` (`[ ]` → `[x]`) and add the date.
  - Update the "Current state" and "Next up" sections of `PROGRESS.md`.
- If you make a design or architecture choice that isn't already documented, add it to `DECISIONS.md` as **Proposed** and tell the user.
- If you find new work, add it to `TASKS.md` with a new ID. Don't silently expand scope.

### At the END of every session
1. Append an entry to **`docs/agent/SESSION_LOG.md`**: date, what was done, files touched, problems, next step.
2. Make sure **`PROGRESS.md` → "Next up"** is specific enough for a fresh agent with zero memory to continue immediately.
3. Run lint and tests (once they exist) and record the result in the log.

## 3. Golden rules
1. **The docs are the memory.** If it isn't written in `docs/`, the next session won't know it.
2. **Don't start a new phase** until the user approves it in `PROGRESS.md`.
3. **Data-driven:** balance values live in `game/data/*.tres`, never hard-coded in scripts.
4. **Platform isolation:** only `game/platform/` may touch Steam, ads, IAP, portal SDKs or `JavaScriptBridge`.
5. **Currency changes go through the `Economy` autoload only.**
6. **The web build must keep working.** Don't use C#, threads that require SharedArrayBuffer, or desktop-only APIs in gameplay code.
7. **Every save schema change needs a migration and a test.**
8. **No secrets in the repo** (keys, keystores, certificates). Use `.env` / CI secrets. Document new env vars in `.env.example` (no real values).
8a. **`docs/` and `projectdetails.md` are git-ignored on purpose** (D-012). They exist only locally. Never `git add -f` them, and never copy their contents into tracked files, commit messages or PR text.
9. **Original content only.** Don't copy names, art, music, levels or characters from existing games or franchises. Log every third-party asset in `docs/ASSET_LICENSES.md` with its license.
10. Keep changes small and focused. Prefer finishing one task fully over half-finishing three.
11. Commit only when the user asks. Use the Conventional Commits format (see CONVENTIONS).

## 4. Doc map
| File | Purpose | Update frequency |
|---|---|---|
| `projectdetails.md` | One-page overview + index | Rarely |
| `docs/01_GAME_DESIGN_DOCUMENT.md` | What the game is | When design changes (with user approval) |
| `docs/02_BUSINESS_MODEL.md` | Monetization, pricing, GTM, KPIs | Rarely |
| `docs/03_TECHNICAL_DESIGN.md` | Stack, architecture, folders, systems | When architecture changes |
| `docs/04_ROADMAP.md` | Phases, durations, exit criteria | Per phase |
| `docs/agent/PROGRESS.md` | **Live status. Read first.** | Every task |
| `docs/agent/TASKS.md` | Backlog with IDs + acceptance criteria | Every task |
| `docs/agent/DECISIONS.md` | Decision log (ADR) | When decisions are made |
| `docs/agent/SESSION_LOG.md` | Append-only session history | Every session |
| `docs/agent/CONVENTIONS.md` | Code style, naming, git | Rarely |

## 5. Commands
> To be filled in during Phase 0 (task P0-09), once the Godot project and tooling exist.

| Purpose | Command |
|---|---|
| Open editor | `godot --path game --editor` *(TBD: confirm the binary name/path)* |
| Run game | `godot --path game` |
| Run tests | `godot --path game --headless -s addons/gut/gut_cmdln.gd -gexit` *(TBD)* |
| Lint | `gdlint game/` |
| Format | `gdformat game/` |
| Export web | `godot --path game --headless --export-release "web_itch" ../build/web/index.html` *(TBD)* |
