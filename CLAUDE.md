# CLAUDE.md

@AGENTS.md

## Claude Code specifics
- Always start by reading `docs/agent/PROGRESS.md` (see the session protocol in AGENTS.md §2).
- Environment: Windows 11. Both PowerShell and Git Bash are available. The Godot project root is `game/`.
- When context is about to be compacted, or a long task finishes, update `docs/agent/PROGRESS.md` **first** so nothing is lost.
- When the user asks to "continue" or "resume", read PROGRESS.md and continue with the "Next up" item. Don't ask what to do if the docs already say.
