import Foundation
import RuntimeLog

internal final class PersistentStore {
    /// Store a user ID.
    ///
    /// - Note: this clears the old token if the user ID has changed.
    ///
    internal func storeUserId(_ newUserId: String) {
        modifyData { data in
            if newUserId != data.userId {
                data.partnerToken = nil
            }
            data.userId = newUserId
        }
    }

    /// Store a partner token.
    ///
    internal func storePartnerToken(_ token: String) {
        partnerToken = token
    }

    /// Clear the user ID and partner token.
    ///
    internal func clearCredentials() {
        modifyData { data in
            data.userId = nil
            data.partnerToken = nil
        }
    }

    internal private(set) var userId: String? {
        get {
            persistentData.userId
        }
        set {
            persistentData.userId = newValue
        }
    }

    internal private(set) var partnerToken: String? {
        get {
            persistentData.partnerToken
        }
        set {
            persistentData.partnerToken = newValue
        }
    }

    private func modifyData<T>(_ transform: (inout PersistentData) -> T) -> T {
        var persistentData = self.persistentData
        let result = transform(&persistentData)
        self.persistentData = persistentData
        return result
    }

    private var persistentData: PersistentData {
        get {
            let fm = FileManager()
            guard fm.fileExists(atPath: plistURL.path) else {
                return .empty
            }
            do {
                return try readData()
            } catch {
                ws_assertionFailure("Persistent user data is malformed.")
                return .empty
            }
        }
        set {
            do {
                try storeData(newValue)
            } catch {
                ws_runtimeWarning("Could not persist user data.")
            }
        }
    }

    private func readData() throws -> PersistentData {
        let decoder = PropertyListDecoder()
        let data = try Data(contentsOf: plistURL)
        return try decoder.decode(PersistentData.self, from: data)
    }

    private func storeData(_ data: PersistentData) throws {
        let encoder = PropertyListEncoder()
        let data = try encoder.encode(data)
        try data.write(to: plistURL)
    }

    private var plistURL: URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let url = urls.first else {
            ws_preconditionFailure("Path for persistent user data could not be formed.")
        }
        return url.appendingPathComponent("WellspentSDK.plist")
    }
}

private struct PersistentData: Codable {
    static let empty = PersistentData()

    var userId: String?
    var partnerToken: String?
}
