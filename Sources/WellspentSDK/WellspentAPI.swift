import Foundation
import RuntimeLog

internal final class WellspentAPI {
    var partnerId: String
    var partnerToken: String?
    var environment: WellspentSDKEnvironment

    init(
        partnerId: String,
        environment: WellspentSDKEnvironment
    ) {
        self.partnerId = partnerId
        self.environment = environment
    }

    private func url(for request: WellspentAPIRequest) throws -> URL {
        let url = URL(string: request.path, relativeTo: environment.apiBaseURL)
        guard let url else {
            throw WellspentAPIRequestError.invalidURL
        }
        return url
    }

    private func request<T>(
        _ request: WellspentAPIRequest,
        closure: (URL) async throws -> T
    ) async throws -> T {
        do {
            let endpointURL = try url(for: request)
            return try await closure(endpointURL)
        } catch {
            if let error = error as? WellspentAPIRequestError {
                throw WellspentSDKError.api(
                    WellspentAPIError(request: request, error: error)
                )
            } else {
                throw WellspentSDKError(error)
            }
        }
    }

    internal func authenticateUser(id partnerUserId: String) async throws -> String {
        let token = try await request(.createBearerToken) { url in
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let requestBody = BearerTokenRequest(partnerUserId: partnerUserId, partnerId: partnerId)

            do {
                request.httpBody = try JSONEncoder().encode(requestBody)
            } catch {
                throw WellspentAPIRequestError.encodingFailed
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw WellspentAPIRequestError.requestFailed
            }

            do {
                let response = try JSONDecoder().decode(BearerTokenResponse.self, from: data)
                return response.token
            } catch {
                throw WellspentAPIRequestError.decodingFailed
            }
        }
        self.partnerToken = token
        return token
    }

    internal func completeDailyHabit(partnerToken: String) async throws {
        return try await request(.completeDailyHabit) { url in
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(partnerToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                // TODO: Propagate failure cause if possible
                throw WellspentAPIRequestError.requestFailed
            }

            do {
                let response = try JSONDecoder().decode(HabitCompletionResponse.self, from: data)
                _ = response.message
            } catch {
                throw WellspentAPIRequestError.decodingFailed
            }
        }
    }
}


// MARK: - Codable Artifacts

private struct BearerTokenRequest: Codable {
    let partnerUserId: String
    let partnerId: String
}

private struct BearerTokenResponse: Codable {
    let token: String
}

private struct HabitCompletionResponse: Codable {
    let message: String
}


// MARK: - Error Types

public enum WellspentAPIRequest {
    case createBearerToken
    case completeDailyHabit

    var path: String {
        switch self {
        case .createBearerToken:
            return "createBearerToken"
        case .completeDailyHabit:
            return "completeDailyHabit"
        }
    }
}

public struct WellspentAPIError: Error {
    var request: WellspentAPIRequest
    var error: WellspentAPIRequestError
}

public enum WellspentAPIRequestError: Error, Sendable {
    case invalidURL
    case encodingFailed
    case requestFailed
    case decodingFailed
}
