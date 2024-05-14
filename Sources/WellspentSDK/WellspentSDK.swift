import Foundation
import RuntimeLog
import UIKit

public final class WellspentSDK {
    public static let shared = WellspentSDK()

    var configuration: WellspentSDKConfiguration?

    /// - Returns: `true` if the WellspentSDK does support connecting
    ///   the Wellspent app on  this device and if and only if the Wellspent app itself
    ///   is also going to be supported.
    ///
    /// - Note: This requires iPhone and iOS 17 for App Clips and Screen Time API
    ///   being fully supported.
    ///
    public static var isSupported: Bool {
        if #available(iOS 17, *) {
            return UIDevice.current.userInterfaceIdiom == .phone
        }
        return false
    }

    /// - Returns: `true` if the WellspentSDK instance is configured.
    ///
    public var isConfigured: Bool {
        configuration != nil
    }

    private init() {}

    public func configure(
        with configuration: WellspentSDKConfiguration
    ) throws {
        guard Self.isSupported else { return }
        guard !configuration.partnerId.isEmpty else {
            throw WellspentSDKError.invalidSDKConfiguration
        }
        guard !configuration.localizedAppName.isEmpty else {
            throw WellspentSDKError.invalidSDKConfiguration
        }
        self.configuration = configuration
    }

    private var plistPath: String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let path = paths.first else {
            ws_preconditionFailure("Path for persistent user data could not be formed.")
        }
        return path.appendingPathComponent("WellspentSDK.plist").path
    }

    @available(iOS 17.0, *)
    private var plistDict: [String: String] {
        get {
            let fm = FileManager()
            guard fm.fileExists(atPath: plistPath) else {
                return [:]
            }
            let dict = NSDictionary(contentsOfFile: plistPath)
            guard let dict = dict else {
                ws_assertionFailure("Persistent user data is malformed.")
                return [:]
            }
            return dict.reduce(into: [:]) { dict, item in
                let (key, value) = item
                guard let key = key as? String, let value = value as? String else {
                    ws_assertionFailure("Persistent user data is malformed.")
                    return
                }
                dict[key] = value
            }
        }
        set {
            let dict = newValue as NSDictionary
            do {
                try dict.write(to: URL(filePath: plistPath))
            } catch {
                ws_runtimeWarning("Could not persist user data.")
            }
        }
    }

    @available(iOS 17.0, *)
    private var storedUserId: String? {
        get {
            plistDict["userId"]
        }
        set {
            plistDict["userId"] = newValue
        }
    }

    /// This can be also achieved  by just calling `presentOnboarding` with the `userId`
    /// configured in the provided `WellspentSDKProperties`, but in some apps the user
    /// ID might not be easily available.
    /// So the `identify` method can be called on successful authentication of a user.
    /// This will also ensure in multi-user apps, that if a user can log out and log in with a different
    /// identify, that this does not require to present the onboarding again.
    ///
    @discardableResult
    public func identify(
        as userId: String
    ) -> WellspentSDKUserIdentificationResult {
        guard #available(iOS 17, *) else {
            return .unsupported
        }
        if userId == storedUserId {
            return .known
        }
        storedUserId = userId
        return .mismatched
    }

    /// Logout tears the connection between this user and the Wellspent app.
    ///
    /// This**should be** used when the application, which is integrating the Wellspent SDK,
    /// has a user experiennce, allowing users to logout.
    ///
    public func logout() {
        guard #available(iOS 17, *) else {
            return
        }
        storedUserId = nil
    }

    // TODO: Document when this method returns
    // TODO: Document when the completion handler is being called
    /// Presents the partner-specific onboarding to establish
    /// a connection to the Wellspent app.
    ///
    /// If Wellspent is not installed yet, this will open the App Clip for initiating the
    /// partner-specific onboarding.
    /// If Wellspent is installed, this will open the app with a deep link, which will
    /// initiate the partner-specific in-app onboarding.
    ///
    /// In case of configurations errors, the completion handler can be called
    /// synchronously with an error.
    ///
    /// - Parameter properties: Properties to be passed to the Wellspent app.
    ///   These will be passed to the App Clip or the App via URL query parameters.
    /// - Parameter completion: A completion handler that will be called when opening
    ///   the App Clip or the App was successful.
    ///
    @MainActor
    public func presentOnboarding(
        using properties: WellspentSDKProperties = WellspentSDKProperties(),
        completion: @escaping (Error?) -> Void
    ) {
        do {
            guard #available(iOS 17, *) else {
                throw WellspentSDKError.sdkIsNotSupported
            }

            try ensureSupported()
            let configuration = try ensureConfigured()

            // TODO: Store trackedProperties in private plist
            //     if let userId = properties.userId {
            //         identify(as: userId)
            //      }

            var url = URL(string: "https://appclip.apple.com/id?=co.mindamins.wellspent.Clip")!
            let queryItems: [URLQueryItem] = [
                URLQueryItem(name: "partnerId", value: configuration.partnerId),
                URLQueryItem(name: "localizedAppName", value: configuration.localizedAppName),
                URLQueryItem(name: "redirectionURL", value: configuration.redirectionURL.absoluteString),
            ]
            url.append(queryItems: queryItems)

            // TODO: Check if Wellspent is installed

            UIApplication.shared.open(url, options: [:]) { wasSuccessful in
                if !wasSuccessful {
                    completion(WellspentSDKError.appClipCouldNotBeLaunched)
                    return
                }
                completion(nil)
            }
        } catch {
            completion(error)
            return
        }
    }

    /// Parses the URL of the partner app on launch and tracks that a redirection did occur,
    /// relying on `trackedProperties` to ensure end-to-end tracking.
    ///
    @MainActor
    public func receivedAppRedirect(with url: URL) {
        // TODO: Not implemented yet.
    }

    /// Send HTTP request to Wellspent backend.
    public func completeDailyGoal() {
        // TODO: Not implemented yet.
    }
}

extension WellspentSDK {
    private func ensureSupported() throws {
        guard Self.isSupported else {
            throw WellspentSDKError.sdkIsNotSupported
        }
    }

    @discardableResult
    private func ensureConfigured() throws -> WellspentSDKConfiguration {
        guard let configuration else {
            throw WellspentSDKError.sdkIsNotConfigured
        }
        return configuration
    }
}

public enum WellspentSDKError: Error {
    case sdkIsNotSupported
    case sdkIsNotConfigured
    case invalidSDKConfiguration
    case malformedSDKData
    case appClipCouldNotBeLaunched
}

/// These are the allowed return values of `identify(as: _)`.
///
public enum WellspentSDKUserIdentificationResult {
    /// The SDK is not supported, so no identification is attempted.
    case unsupported

    /// The user is known to the SDK because the user ID matches the stored user ID,
    /// which was stored when the current user has established a connection before.
    case known

    /// The user is not known to the SDK and the user ID doesn't match with the previously
    /// stored user ID.
    ///
    /// - Note: This is an indication that on logout, the user was not properly logged out
    ///   via `logout()`.
    ///
    case mismatched
}

public struct WellspentSDKConfiguration {
    //let apiKey: String
    let partnerId: String
    let localizedAppName: String
    let redirectionURL: URL

    public init(
        partnerId: String,
        localizedAppName: String,
        redirectionURL: URL
    ) {
        self.partnerId = partnerId
        self.localizedAppName = localizedAppName
        self.redirectionURL = redirectionURL
    }
}

public struct WellspentSDKProperties {
    /// Provide a stable, unique, pseudonymous user identifier.
    ///
    /// - Precondition: User IDs **must be stable throughout a user's lifetime.**
    ///
    /// - Precondition: User IDs **must be unique.** One user ID must always refer to the same
    ///   user.
    ///
    /// - Precondition: For compliance with GDPR, CCPA, etc., you **may only use pseudonyms**
    ///   as user IDs and not clear text identifiers like name, email address, etc.
    ///
    var userId: String?

    /// Provide properties which should be passed whenever events for this user are tracked.
    ///
    /// - Precondition: For compliance with GDPR, CCPA, etc., you **may not use
    ///   Personal-Identifiable Information (PII)** in this context.
    ///
    var trackedProperties: [String: String]

    public init(
        userId: String? = nil,
        trackedProperties: [String : String] = [:]
    ) {
        self.userId = userId
        self.trackedProperties = trackedProperties
    }
}
