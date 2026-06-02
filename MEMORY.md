# MEMORY.md

This file records significant decisions made during development sessions.
Read this at the start of every session before doing anything else.

---

## 2026-05-28 — Initial Setup

**Decision:** Create and maintain MEMORY.md as a persistent decision log.

**Why:** User requested that every significant architectural or implementation decision be recorded here — what was decided, why it was chosen, and what alternatives were rejected — so context survives across sessions.

**Rejected:** Relying on git commit messages alone (too terse, no rejection rationale) or a separate ADR folder (overkill for a single-developer iOS project).

---

## Project Overview (as of 2026-05-28)

**Repo:** `judahabadi/Spent` — iOS app for Screen Time monitoring/reporting.

**Key targets:**
- `Spent` — main iOS app
- `SpentActivityMonitor` — DeviceActivity extension that records usage
- `SpentActivityReport` — DeviceActivityReport extension (renders in-app screen time UI)
- `SpentWidgets` — WidgetKit extension
- `SpentTests` / `SpentUITests` — test targets

**Platform:** Swift / SwiftUI, Apple Screen Time / Family Controls / DeviceActivity framework.

**Recent work (last 10 commits):**
- Fixing DeviceActivityReport not loading screen time data
- Fixing extensions not embedded in app bundle (root cause of zero-app receipt)
- Switching to hourly monitoring schedules to fix empty receipts
- General bug fixes from codebase audit

**Active branch for Claude sessions:** `claude/bold-ride-UUXj4`

---

## 2026-05-28 — CLAUDE.md Created

**Decision:** Create `CLAUDE.md` as a Claude Code–specific developer guide, separate from `README.md`.

**Why:** `README.md` covers user-facing project info and one-time setup. `CLAUDE.md` is for the AI agent — it captures non-obvious constraints, the data flow between extensions, gotchas that have caused bugs (invisible DeviceActivityReport sizing, hourly vs daily schedules, extension embedding), and the exact files to touch for each concern. Without this, each session requires re-exploring the codebase.

**What's in it:** Architecture, data flow, key files table, build/test commands, 10 explicit gotchas, entitlements matrix, branch strategy, link back to MEMORY.md.

**Rejected:** Embedding all this in MEMORY.md (wrong audience — MEMORY.md is decision history, not a how-to guide) or expanding README.md (README is for humans setting up the project, not for AI context).

---
