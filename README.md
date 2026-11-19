# LinkFlow iOS SDK

Complete iOS SDK for deferred deep linking, attribution, and rewards.

## Features

- ✅ ATT (App Tracking Transparency) helper
- ✅ IDFA/IDFV retrieval
- ✅ Deferred deep link retrieval
- ✅ Universal Link handling
- ✅ Event tracking to attribution API
- ✅ **Reward validation and redemption** (Phase 3)

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/thelinkflow/linkflow-ios-sdk.git", from: "2.2.0")
]
```

### CocoaPods

```ruby
pod 'LinkFlowSDK', '~> 2.2'
```

## Quick Start

### 1. Configure the SDK and forward links

```swift
import LinkFlowSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        LinkFlowSDK.initialize(config: LinkFlowConfig(appKey: "lfa_..."))
            .setAttributionCallback { result in
                if result.attributed, let link = result.deepLinkValue {
                    // Deferred deep link (first launch after install)
                }
            }
        try? LinkFlowSDK.shared().handleAppLaunch(url: launchOptions?[.url] as? URL)
        return true
    }

    // Custom URL scheme
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        (try? LinkFlowSDK.shared().handleCustomURL(url: url)) ?? false
    }

    // Universal links
    func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        (try? LinkFlowSDK.shared().handleUniversalLink(userActivity: userActivity)) ?? false
    }
}
```

### 2. Entitlements and Info.plist

| Setting | Required | Value |
|---|---|---|
| Associated Domains entitlement (`com.apple.developer.associated-domains`) | For universal links | `applinks:<your LinkFlow link domain>` (e.g. `applinks:go.example.com`) |
| `CFBundleURLTypes` | For a custom URL scheme | your scheme, e.g. `myapp` |
| `NSUserTrackingUsageDescription` | Only if your app requests ATT | your purpose string (the SDK never shows the prompt) |
| `NSAdvertisingAttributionReportEndpoint`, `AttributionCopyEndpoint` | Optional, for developer copies of SKAN / AdAttributionKit postbacks | `https://<your verified LinkFlow custom domain>` |

React Native / Expo apps can let the `@linkflow/react-native-sdk` Expo config
plugin write all of these.

## What's new in 2.2

```swift
let sdk = try LinkFlowSDK.shared()

// Hold deep links while onboarding / login is showing...
sdk.holdDeepLinks()
// ...and deliver what arrived meanwhile once the app can navigate.
sdk.releaseDeepLinks()

// Optional dedicated handler for direct (universal / custom-scheme) links.
// Direct links still reach the attribution callback as in 2.1.
sdk.setDeepLinkCallback { url in /* route */ }

// How the server matched the install (nil against older servers).
sdk.getAttributionResult()?.match?.method   // install_referrer | click_token | advertising_id | probabilistic | organic

// Support snapshot. Contains no identifiers or personal data.
print(sdk.getDiagnostics())
```

- **Hold/release:** while held, the deferred deep link (an attributed result
  carrying a link) and direct deep links are queued. Only the latest of each
  kind is kept, and they are delivered in arrival order on release. Not held
  by default.
- **Organic installs:** servers from 2.2 return an install id and token for
  unmatched installs too. The SDK stores them, so organic users' events,
  revenue and `setCustomerUserId` reach the server. With older servers
  nothing changes.
- **Diagnostics:** SDK version, API host, consent state, whether an install
  id/token exist, last resolve time and category (`attributed`, `organic`,
  `rejected`, `network_error`, `invalid_response`), match method, queued event
  count, hold state. *Why didn't my deep link fire?* Check `deepLinksHeld`,
  `consentState` (`pending` buffers the launch until `setConsent`),
  `attributionCallbackSet` and `lastResolveResult`.

## What's new in 2.1

```swift
LinkFlowSDK.initialize(config: LinkFlowConfig(
    appKey: "lfa_...",
    manageConversionValues: true   // opt-in: SKAN / AdAttributionKit values from your dashboard schema
))

// After login (nil on logout):
try? LinkFlowSDK.shared().setCustomerUserId("user-123")

// Granular consent — all optional:
try? LinkFlowSDK.shared().setConsent(LinkFlowConsent(
    attribution: true, gdprApplies: true, tcfString: tcString, adUserData: true, adPersonalization: false))
```

**Conversion values.** Approve a schema in *Measurement Lab → SKAN &
AdAttributionKit* (or accept the predicted-LTV recommendation). With
`manageConversionValues` on, the SDK registers the install on first launch and
raises the fine/coarse value as revenue and events arrive inside the first
measurement window — AdAttributionKit on iOS 17.4+, SKAdNetwork 4 on 16.1+.
To receive developer copies of postbacks, set `NSAdvertisingAttributionReportEndpoint`
and `AttributionCopyEndpoint` in Info.plist to your verified LinkFlow custom domain.

Everything is opt-in and 2.0 code compiles unchanged.

## Reward Integration (Phase 3)

### Validate and Redeem Reward

```swift
LinkFlowSDK.shared.validateReward(rewardId: "reward_id") { validation in
    if validation?.valid == true, let token = validation?.redemptionToken {
        LinkFlowSDK.shared.redeemReward(
            redemptionToken: token,
            purchaseAmount: 29.99
        ) { success, message in
            if success { print("Redeemed!") }
        }
    }
}
```

For complete examples and documentation, see Android SDK README.
