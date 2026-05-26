# Spent

> Turn screen time into a financial receipt.

Spent shows you the real cost of your screen time by converting hours into dollars (or GPA points for students). Every minute on Instagram costs money. Every minute on Duolingo earns credit.

## Architecture

| Target | Purpose |
|--------|---------|
| `Spent` | Main iOS app (SwiftUI, @Observable) |
| `SpentWidgets` | Home screen widgets (small, medium, large) |
| `SpentActivityReport` | DeviceActivity report extension — reads raw screen time |
| `SpentActivityMonitor` | DeviceActivity monitor — triggers on thresholds |
| `SpentTests` | Unit tests (calculation engine, models, streaks) |
| `SpentUITests` | UI tests (onboarding, receipt screen) |

## Tech Stack

- **SwiftUI** — `@Observable` pattern throughout (no ObservableObject)
- **FamilyControls + DeviceActivity** — screen time data
- **CloudKit** — receipt history, settings sync, email auth tokens
- **StoreKit 2** — subscriptions ($1/mo standard, $0.49/mo student)
- **Sign in with Apple** — primary auth; email auth backed by CloudKit
- **WidgetKit** — home screen widgets (small, medium, large)
- **MetricKit** — crash and performance reporting

## Bundle IDs

| Target | Bundle ID |
|--------|-----------|
| Spent | `app.spent` |
| SpentWidgets | `app.spent.widgets` |
| SpentActivityReport | `app.spent.activityreport` |
| SpentActivityMonitor | `app.spent.activitymonitor` |

App Group: `group.app.spent` · CloudKit container: `iCloud.app.spent`

## CI/CD

**Testing** — GitHub Actions (`.github/workflows/test.yml`) runs on push to `develop` and `feature/**` branches via self-hosted runner.

**Deployment** — [Xcode Cloud](https://appstoreconnect.apple.com/ci) triggers on push to `main`, archives, and posts to TestFlight automatically. No secrets to manage — uses your App Store Connect session.

### One-time Xcode Cloud setup

1. App Store Connect → Xcode Cloud → New Workflow
2. Start condition: branch `main`
3. Actions: Build (Archive) → Post-Action: TestFlight (internal)
4. Connect this GitHub repository
5. 25 free compute hours/month with Apple Developer Program membership

## Local Development

```bash
git clone https://github.com/judahabadi/spent.git
cd spent
open Spent.xcodeproj   # let Xcode resolve signing on first open
fastlane test          # run unit tests locally
```

## Entitlements & Capabilities

Configure these in Xcode → Signing & Capabilities for each target:

| Capability | Targets |
|-----------|---------|
| App Groups (`group.app.spent`) | All |
| CloudKit (`iCloud.app.spent`) | Spent |
| Family Controls | Spent, SpentActivityReport, SpentActivityMonitor |
| Sign in with Apple | Spent |

## Subscriptions

Create in App Store Connect → In-App Purchases before first TestFlight build:

| Product ID | Price | Trial |
|-----------|-------|-------|
| `app.spent.standard.monthly` | $1.00/mo | 7 days |
| `app.spent.student.monthly` | $0.49/mo | 7 days |

Day 8 without an active subscription → degraded mode (amounts blurred, paywall banner).

## App Category Classification

Apps default to:
- **Spent** — Social Networking, Entertainment, Games, Shopping, Sports
- **Invested** — Productivity, Education, Reference, Health & Fitness, Business
- **Neutral** — everything else

Users can override any app's category in Settings → App Categories.

## Branch Strategy

```
main        ← production, triggers Xcode Cloud deploy to TestFlight
develop     ← integration, requires passing tests
feature/**  ← feature branches, PR into develop
```
