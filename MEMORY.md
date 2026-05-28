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
