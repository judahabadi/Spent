# CLAUDE.md

Developer guide for Claude Code sessions on the Spent iOS project.

## Working Rules

1. **Ask, don't assume** — if something is unclear, ask before writing a single line. Never make silent assumptions.
2. **Simplest solution first** — always implement the simplest thing that could work. Don't add abstractions that weren't requested.
3. **Don't touch unrelated code** — if a file is not directly part of the current task, do not modify it. Ever.
4. **Flag uncertainty explicitly** — if you're not confident about an approach, say so before proceeding. Confidence without certainty causes more damage than admitting a gap.

## Essential Context

- **What it does:** Converts screen time into a financial receipt. Time on social apps = cost; time on productivity apps = investment.
- **Platform:** iOS only, Swift/SwiftUI, Xcode project (no Swift Package Manager).
- **Modern Swift:** Uses `@Observable` throughout — never introduce `ObservableObject`.
- **No external backend:** CloudKit handles storage, sync, and email auth. No REST API, no server.

## Targets & Roles

| Target | Bundle ID | Role |
|--------|-----------|------|
| `Spent` | `app.spent` | Main app |
| `SpentActivityMonitor` | `app.spent.activitymonitor` | DeviceActivity extension — woken on schedule/threshold events |
| `SpentActivityReport` | `app.spent.activityreport` | DeviceActivity report extension — reads raw screen time, writes receipt to shared storage |
| `SpentWidgets` | `app.spent.widgets` | WidgetKit home screen widgets |

**App Group:** `group.app.spent` — the only cross-process communication channel.  
**CloudKit container:** `iCloud.app.spent`

## Architecture

### Pattern: MVVM + Service Layer

```
AppViewModel (@Observable, single source of truth)
    ├── AuthService          — Sign in with Apple + email/CryptoKit auth
    ├── ScreenTimeService    — FamilyControls + DeviceActivity monitoring
    ├── CloudKitService      — receipt history, streak, email auth tokens
    ├── StoreKitService      — StoreKit 2 subscriptions
    ├── NotificationService  — daily reminders, streak milestones
    ├── CalculationEngine    — pure functions, no side effects
    └── CategoryClassifier   — bundle ID → Spent/Invested/Neutral + user overrides
```

### Data Flow

1. `SpentApp.initialize()` — requests Screen Time auth, starts 24 hourly monitoring schedules, loads today's receipt from shared UserDefaults.
2. `ReceiptView` embeds an **invisible** `DeviceActivityReport` — must have non-zero frame and non-zero opacity or the system won't allocate extension resources.
3. `SpentActivityReport` extension is woken by the system, reads `DeviceActivityResults` (one segment per hourly schedule), computes `DailyReceipt`, and writes JSON to shared UserDefaults.
4. Main app reads shared UserDefaults (via `SharedDataStore` in `AppViewModel`) and refreshes the UI every 60 seconds.
5. On "record day" tap → saves receipt to CloudKit, updates streak.
6. `SpentActivityMonitor` writes flags to shared UserDefaults to signal report refreshes.

### Inter-process Communication

All targets share data through `UserDefaults(suiteName: "group.app.spent")`.  
Keys are defined in `SharedDataStore` inside `AppViewModel.swift` — always add new keys there.

## Key Files

| File | Purpose |
|------|---------|
| `Spent/SpentApp.swift` | App entry point, root view, boot sequence |
| `Spent/ViewModels/AppViewModel.swift` | All app state, settings, SharedDataStore |
| `Spent/Services/CalculationEngine.swift` | Pure cost/GPA math — test everything here |
| `Spent/Services/CategoryClassifier.swift` | App → category mapping + user overrides |
| `Spent/Services/ScreenTimeService.swift` | Hourly monitoring schedule setup |
| `Spent/Views/ReceiptView.swift` | Main dashboard, invisible DeviceActivityReport embed |
| `SpentActivityReport/TotalActivityView.swift` | Processes raw DeviceActivity data → writes receipt |
| `SpentWidgets/SpentWidget.swift` | Widget timeline provider |

## Build & Test

```bash
# Open project
open Spent.xcodeproj

# Run unit tests (requires macOS with Xcode)
fastlane test

# Or directly
xcodebuild test -project Spent.xcodeproj -scheme Spent \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Tests live in `SpentTests/` — cover `CalculationEngine`, models, `StreakRecord`, `CategoryClassifier`.  
Do not write tests that require Screen Time permissions — they cannot run in CI.

## CI/CD

- **CI (tests):** GitHub Actions on push to `develop` or `feature/**` branches — self-hosted runner.
- **Deploy:** Xcode Cloud triggers on push to `main` → archives → TestFlight (internal).
- Claude feature branches (`claude/**`) are not on the CI trigger list by default.

## Subscriptions

| Product ID | Price | Mode |
|-----------|-------|------|
| `app.spent.standard.monthly` | $1.00/mo | Standard (hourly wage) |
| `app.spent.student.monthly` | $0.49/mo | Student (GPA impact) |

7-day free trial on sign-in. Day 8 without active subscription → degraded mode (amounts blurred).

## Gotchas & Non-Obvious Constraints

1. **Invisible DeviceActivityReport must be non-trivially sized.** If it has zero frame or zero opacity the system skips the extension. Don't "optimize" it away.
2. **24 hourly schedules, not one daily.** `ScreenTimeService.startMonitoring()` creates `DeviceActivitySchedule` for each hour of the day. This was a deliberate fix — daily schedules produced empty receipts.
3. **Extensions must be embedded in the app bundle.** If they're not, receipts show zero apps. Check Xcode → Spent target → Embed App Extensions build phase.
4. **No `ObservableObject` or `@Published`.** The whole codebase uses `@Observable` (Swift 5.9 macro). Keep it that way.
5. **Password hashing uses CryptoKit with email-as-salt.** Email auth is intentionally lightweight — this is not a security-hardened system; it's backed by CloudKit private DB.
6. **Category matching is lowercase substring.** `CategoryClassifier` does `contains` on lowercased Apple category strings, not exact equality.
7. **GPA impact coefficient is 0.152 points per net-spent hour** — treat this as a fixed constant, don't adjust without a cited source.
8. **Widget refresh is 15 minutes** — WidgetKit minimum. Don't try to push more frequent updates.
9. **`SharedDataStore` is the only safe way to share data between targets.** Don't reach into `UserDefaults` directly with raw string keys from extension code.
10. **CloudKit operations are async/await** — don't block the main actor. Services are called with `Task { }` from `AppViewModel`.

## Entitlements per Target

| Capability | Spent | ActivityMonitor | ActivityReport | Widgets |
|-----------|:-----:|:---------------:|:--------------:|:-------:|
| App Groups | ✓ | ✓ | ✓ | ✓ |
| CloudKit | ✓ | | | |
| Family Controls | ✓ | ✓ | ✓ | |
| Sign in with Apple | ✓ | | | |

## Branch Strategy

```
main        ← production (Xcode Cloud deploy)
develop     ← integration (CI tests run)
feature/**  ← feature work → PR to develop
claude/**   ← Claude Code sessions → PR to develop or main
```

## Decision Log

See `MEMORY.md` for a record of significant architectural decisions, rationale, and rejected alternatives.
