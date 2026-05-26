# Spent
Spent shows you the real cost of your screen time

## Setup on your Mac

### 1. Install XcodeGen
```bash
brew install xcodegen
```

### 2. Clone and generate the Xcode project
```bash
git clone https://github.com/judahabadi/spent
cd spent
xcodegen generate
open Spent.xcodeproj
```

### 3. Configure signing (in Xcode)
- Select the **Spent** target → Signing & Capabilities → set your Team
- Select the **SpentActivityReport** target → Signing & Capabilities → set your Team
- Change bundle IDs if needed (default: `com.spent.app`)

### 4. Add capabilities (in Xcode, for both targets)
- **App Groups** → add `group.com.spent.app`
- **Family Controls** (see note below)

### 5. Run on your iPhone
Plug in your iPhone, select it as the destination, press ▶

---

## Family Controls entitlement

The Screen Time API requires a special restricted entitlement.  
Apply here: https://developer.apple.com/contact/request/family-controls-distribution

Apple typically approves these within a few days for individual developers.  
Without it, the app will launch and show the onboarding screen but Screen Time authorization will fail.

---

## Project structure

```
Spent/                        Main app target
  Views/
    OnboardingView.swift      Permission request screen
    HomeView.swift            Today's cost (embeds extension view)
    SettingsView.swift        Set hourly rate
  SpentStore.swift            FamilyControls auth state
  SpentApp.swift

SpentActivityReport/          DeviceActivity report extension
  TotalActivityScene.swift    Reads Screen Time data, computes cost
  TotalActivityView.swift     Renders cost card + per-app breakdown
  TotalActivityModel.swift    Data model

Shared/
  ActivityReportContext.swift  Shared context key (used by both targets)
```

The hourly rate is stored in a shared App Group (`group.com.spent.app`) so
the extension can read it when computing costs.
