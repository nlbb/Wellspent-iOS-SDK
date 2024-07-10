import Foundation
import LinkPresentation
import RuntimeLog
import UIKit
import SwiftUI


public final class WellspentSDK {
    public static let shared = WellspentSDK()

    var configuration: WellspentSDKConfiguration?
    var api: WellspentAPI?
    var store = PersistentStore()
    private var authenticationTask: Task<String, any Error>?

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
            throw WellspentSDKError.state(.invalidSDKConfiguration)
        }
        guard !configuration.localizedAppName.isEmpty else {
            throw WellspentSDKError.state(.invalidSDKConfiguration)
        }
        self.configuration = configuration
        self.api = WellspentAPI(
            partnerId: configuration.partnerId,
            environment: configuration.environment
        )
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
    ) throws -> WellspentSDKUserIdentificationResult {
        guard #available(iOS 17, *) else {
            return .unsupported
        }

        /// If the user ID has not changed, we don't need to request a new token
        if userId == store.userId {
            return .known
        }
        let isNew = store.userId != nil

        /// Store the user ID
        store.storeUserId(userId)

        /// Cancel in-flight task if there is any
        authenticationTask?.cancel()
        authenticationTask = nil

        /// Start a new task to authenticate
        authenticationTask = Task {
            let token = try await authenticateUser(id: userId)
            authenticationTask = nil
            return token
        }

        return isNew ? .new : .mismatched
    }

    private func authenticateUser(id userId: String) async throws -> String {
        let api = try ensureAPI()
        let token = try await api.authenticateUser(id: userId)
        store.storePartnerToken(token)
        return token
    }

    /// Logout tears the connection between this user and the Wellspent app.
    ///
    /// This**should be** used when the application, which is integrating the Wellspent SDK,
    /// has a user experiennce, allowing users to logout.
    ///
    public func logout() {
        store.clearCredentials()
    }

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
    /// This method will return after basic configuration checks.
    /// This method runs an asynchronous detached task, which will
    /// eventually launch a task on the `MainActor` to open a deep link.
    ///
    /// - Parameter properties: Properties to be passed to the Wellspent app.
    ///   These will be passed to the App Clip or the App via URL query parameters.
    /// - Parameter completion: A completion handler that will be called when opening
    ///   the App Clip or the App was successful.
    ///
    public func presentOnboarding(
        using properties: WellspentSDKProperties = WellspentSDKProperties(),
        completion: @escaping (WellspentSDKError?) -> Void
    ) {
        @Sendable func propagateError(_ error: Error) {
            let error = WellspentSDKError(error)
            Task { @MainActor in
                completion(error)
            }
        }

        do {
            guard #available(iOS 17, *) else {
                throw WellspentSDKError.state(.sdkIsNotSupported)
            }

            try ensureSupported()
            let configuration = try ensureConfigured()

            Task {
                // TODO: Store trackedProperties in private plist

                let token: String
                do {
                    token = try await ensurePartnerToken(with: properties.userId)
                } catch {
                    propagateError(error)
                    return
                }

                Task { @MainActor in
                    var url = configuration.appClipURL
                    url.append(path: configuration.localizedAppName.lowercased())
                    let queryItems: [URLQueryItem] = [
                        URLQueryItem(name: "partnerId", value: configuration.partnerId),
                        URLQueryItem(name: "localizedAppName", value: configuration.localizedAppName),
                        URLQueryItem(name: "redirectionURL", value: configuration.redirectionURL.absoluteString),
                        URLQueryItem(name: "token", value: token),
                    ]
                    url.append(queryItems: queryItems)

                    // TODO: Check if Wellspent is installed

                    presentAppClipModal(with: url)
                }
            }
        } catch {
            propagateError(error)
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

    /// Send an asynchronous HTTPS request to the Wellspent backend, which will be propagated
    /// to the Wellspent app to change the intervention behavior, so that the user doesn't see any
    /// further reminders about their daily habit.
    ///
    public func completeDailyHabit() async throws {
        let api = try ensureAPI()
        let token = try await ensurePartnerToken()
        try await api.completeDailyHabit(partnerToken: token)
    }
}

extension WellspentSDK {
    private func ensureSupported() throws {
        guard Self.isSupported else {
            throw WellspentSDKError.state(.sdkIsNotSupported)
        }
    }

    @discardableResult
    private func ensureConfigured() throws -> WellspentSDKConfiguration {
        guard let configuration else {
            throw WellspentSDKError.state(.sdkIsNotConfigured)
        }
        return configuration
    }

    private func ensureAPI() throws -> WellspentAPI {
        guard let api else {
            throw WellspentSDKError.state(.sdkIsNotConfigured)
        }
        return api
    }

    internal func ensureUserId(_ userId: String? = nil) throws -> String {
        if let userId = userId {
            if userId == store.userId {
                return userId
            }
            store.storeUserId(userId)
            return userId
        }

        guard let storedUserId = store.userId else {
            throw WellspentSDKError.state(.userIsNotIdentified)
        }
        return storedUserId
    }

    private func ensurePartnerToken(with userId: String? = nil) async throws -> String {
        if let task = authenticationTask {
            /// If a task is in-flight, that takes precedence.
            return try await task.value
        } else if let token = store.partnerToken {
            /// Otherwise fallback to an existing token.
            return token
        } else {
            /// If there is no token, then request one.
            let userId = try ensureUserId(userId)
            let task = Task {
                try await authenticateUser(id: userId)
            }
            authenticationTask = task
            return try await task.value
        }
    }
    
    @available(iOS 15.0, *)
    private func presentAppClipModal(with url: URL) {
        guard let topViewController = UIApplication.shared.topViewController() else { return }
        let rootViewController = UIHostingController(rootView: AppClipView(url: url))
        rootViewController.view.backgroundColor = .clear

        let customTransitioningDelegate = WSTransitioningDelegate()
        rootViewController.modalPresentationStyle = .custom
        rootViewController.transitioningDelegate = customTransitioningDelegate

        topViewController.present(rootViewController, animated: true)
    }
}

public enum WellspentSDKError: Error {
    case state(WellspentSDKStateError)
    case api(WellspentAPIError)
    case network(URLError)
    case unknown(underlying: NSError)

    public init(_ error: Error) {
        switch error {
        case let sdkError as WellspentSDKError:
            self = sdkError
        case let stateError as WellspentSDKStateError:
            self = .state(stateError)
        case let apiError as WellspentAPIError:
            self = .api(apiError)
        case let nsError as NSError where nsError.domain == NSURLErrorDomain:
            self = .network(URLError(_nsError: nsError))
        default:
            self = .unknown(underlying: error as NSError)
        }
    }

    internal static func api(
        request: WellspentAPIRequest,
        error: WellspentAPIRequestError
    ) -> Self {
        .api(WellspentAPIError(request: request, error: error))
    }
}

public enum WellspentSDKStateError: Error {
    case sdkIsNotSupported
    case sdkIsNotConfigured
    case invalidSDKConfiguration
    case malformedSDKData
    case userIsNotIdentified
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

    /// The user is not known to the SDK, but no user was previously logged in.
    ///
    case new

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

    /// This is `.production` by default.
    ///
    /// - Warning: This is only supposed to be used for internal development.
    ///   Do not change this in a production build of your app unless explicitly advised.
    ///
    let environment: WellspentSDKEnvironment

    public init(
        partnerId: String,
        localizedAppName: String,
        redirectionURL: URL,
        environment: WellspentSDKEnvironment = .production
    ) {
        self.partnerId = partnerId
        self.localizedAppName = localizedAppName
        self.redirectionURL = redirectionURL
        self.environment = environment
    }

    var appClipURL: URL {
        switch environment {
        case .production:
            return URL(string: "https://wellspent-api.netlify.app/")!

        case .staging:
            return URL(string: "https://appclip.apple.com/id?p=com.nlbb.Salomone.Clip")!
        }
    }
}

public enum WellspentSDKEnvironment {
    /// The Wellspent production environment.
    case production

    /// The Wellspent staging environment.
    ///
    /// - Warning: This is only supposed to be used for internal development.
    ///   Do not change this in a production build of your app unless explicitly advised.
    ///
    case staging

    var apiBaseURL: URL {
        switch self {
        case .production:
            return URL(string: "https://wellspent-app.web.app/api/v1/")!
        case .staging:
            return URL(string: "https://salomone-f1c40.web.app/api/v1")!
        }
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
