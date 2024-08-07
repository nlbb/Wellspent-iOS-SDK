# Wellspent iOS SDK

Welcome to the Wellspent iOS SDK, the cornerstone of digital wellness and mindful usage for the next generation of iOS applications. Designed with a vision to foster healthier digital habits, our SDK seamlessly integrates with applications aimed at promoting personal growth, such as language learning, fitness, and meditation apps. By leveraging our technology, partners can encourage their users to spend time wisely on their devices, ensuring a balance between digital engagement and real-world experiences.

## Key Features

* **Deep Linking Integration**: Facilitate smooth transitions between your app and partners’ applications, enriching the user's journey towards building positive habits.
* **Customizable User Goals**: Empower users to set and achieve personal goals, with the flexibility to define what success looks like in their journey of learning, meditation, or fitness.
* **Dynamic Reward System**: Unlock new levels of user engagement by rewarding progress and encouraging consistent app usage through a thoughtful balance of incentives.
* **Privacy-Centric Design**: Built from the ground up with user privacy and data protection in mind, ensuring compliance with GDPR, CCPA, and more, fostering trust and safety.

## Getting Started

This SDK is tailored for developers looking to make a positive impact on user habits through their iOS applications. Whether you're integrating Wellspent into an existing app or building from scratch, our straightforward setup process, detailed documentation, and dedicated support team will help you every step of the way.

## Prerequisites

* iOS 17.0+ (because of ScreenTime API and App Clip availability)
* Swift 5.8+
* Xcode 15.0+

## Quick Overview

```swift
extension WellspentSDK {
    static var shared: WellspentSDK

    func configure(
        with configuration: WellspentSDKConfiguration = .init()
    ) throws

    func identify(as userId: String) -> WellspentSDKUserIdentificationResult

    func logout()

    func presentOnboarding(
        using properties: WellspentSDKProperties = WellspentSDKProperties(),
        completion: @escaping (WellspentSDKError?) -> Void
    )

    func receivedAppRedirect(with url: URL)

    func completeDailyHabit() async throws
}
```

## Initialization with API Key and Partner Name

To initialize the SDK with support for API keys and partner names, you can use a
configuration structure.
Call this as early as possible on app launch to ensure the SDK is ready for use.

```swift
struct WellspentSDKConfiguration {
    //let apiKey: String // TODO: Omitted for now
    let partnerId: String
    let localizedAppName: String
    let redirectionURL: URL
}
```

> [!CAUTION]
> The `redirectionURL` must be correctly configured in your app.
> This can be a [Universal Link](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app),
> which also works on the web in case your app is not installed anymore,
> or a [Link with a Custom URL Scheme](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app).
> In either case, the URL must be correctly configured and should allow to open
> your app seamlessly without any additional steps.
> This is used by the Wellspent app to launch your app after an intervention,
> e.g. while the user is scrolling on social media.
> So ideally you will provide a deep link to a habit or exercise within your app.

## Integrating the Swift SDK

### 1. Import

Ensure the SDK is added to your project via Swift Package Manager.

```swift
dependencies: [
    .package(url: "https://github.com/wellspent-app/Wellspent-iOS-SDK.git", from: "0.1.0")
]
```

### 2. Initialize on Launch

Initialize it in your application's entry point with the provided API key and
further properties, using the initialize method.

Doing this as early as possible ensures the SDK is ready for use.
This method will fail synchronously if and only if the passed arguments are
invalid. This method doesn't depend on network connectivity.

```swift
do {
    try WellspentSDK.shared.configure(
        with: WellspentSDKConfiguration(
            partnerId: "example",
            localizedAppName: "Example App",
            redirectionURL: URL(string: "exampleApp://example")!
        )
    )
} catch {
    print("Error initializing SDK: \(error?.localizedDescription ?? "")")
}
```

### 3. User Authentication

You can kick-off user onboarding and authentication by invoking the `establishConnection`
method with the necessary `WellspentProperties`, including user details and any
additional partner-specific properties.

Usually this call should be initiated in response some user action, such as
tapping a "Connect" button.

```swift
let properties = WellspentSDKProperties(
    userId: "user123",
    trackedProperties: ["userLevel": "10"]
)
WellspentSDK.shared.presentOnboarding(using: properties) { error in
    if let error {
        // Handle connection error
    } else {
        // Proceed with enabling SDK functionality
    }
}
```

For reference, these are the possible properties you can pass:

```swift
struct WellspentProperties {
    var userId: String?
    var trackedProperties: [String: String]
}
```

Alternatively, you can handle user authentication explicitly by calling the `identify(as userId: String)` method. 
This is useful in multi-user apps where a user can log out and log in with a different identity without needing to present onboarding again.

```swift
WellspentSDK.shared.identify(as: "user123")
```

### 4. Handling Received Redirects

When the Wellspent app redirects back to your app from a shield, you need to
notify the SDK for proper functionality. This can be achieved by calling the
receivedAppRedirect(with: url) method in your AppDelegate or SceneDelegate.
This ensures that the SDK is aware of the redirection and can process it accordingly.

After this you should handle the deep link as needed.

Example for AppDelegate:
```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    WellspentSDK.shared.receivedAppRedirect(with: url)

    // your custom logic
}
```

#### Best Practices for URL Parsing
To ensure seamless redirection and integration tracking, you should provide
a unique deep link for the redirectionURL. This link should be recognizable as
coming from Wellspent and allow for tracking and measuring the success of the Wellspent integration.

Deep Link Example:
```
dailyWisdom://daily?wellspentUserId=123
```

#### Important Guidelines:
1. **Use URL Parsing**: Avoid using regex for parsing the full URL to prevent errors and maintain flexibility.

2. **Handle Extra Query Parameters Gracefully**: Ensure your URL parsing logic can
handle additional query parameters without breaking. This allows for future
extensions and modifications without impacting the existing functionality.

Following these best practices will help ensure a smooth integration process
and accurate tracking of user interactions driven by Wellspent.

### 5. Propagating goal completion

On completion of the user's daily goal, you should propagate this back to the Wellspent backend.
This will trigger a cascade of background updates, which ensures that the intervention mechanism will
consider that the user's daily goal was completed.

```swift
WellspentSDK.shared.completeDailyHabit()
```

Alternatively this can also happen as a server-to-server REST API call.
Please contact us for more information on this.

> [!CAUTION]
Always initialize the WellspentSDK at app launch.
If initialization at app launch is not possible, ensure it is done before calling any methods that interact with the SDK.
i.e Make sure to call `configure(with: WellspentSDKConfiguration)` before calling `completeDailyHabit()`. 
