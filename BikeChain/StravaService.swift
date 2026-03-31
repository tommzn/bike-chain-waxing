//
//  StravaService.swift
//  BikeChain
//
//  Created by Thomas Schenker on 30.03.26.
//

import Foundation
import AuthenticationServices
import Combine
import UIKit

// MARK: - Errors

enum StravaError: LocalizedError {
    case notAuthenticated
    case tokenRefreshFailed
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:     return "Not authenticated with Strava."
        case .tokenRefreshFailed:   return "Failed to refresh the Strava access token."
        case .invalidResponse:      return "Received an unexpected response from Strava."
        case .httpError(let code):  return "Strava API error (HTTP \(code))."
        }
    }
}

// MARK: - StravaService

/// Handles OAuth 2.0 authentication and data fetching from the Strava API.
///
/// Usage:
/// 1. Call `authorize(presentationAnchor:)` once to obtain tokens via the browser.
/// 2. Use `fetchBikes()` and `fetchRides(bikeId:from:to:)` to retrieve data.
///    Both methods refresh the access token automatically when it has expired.
@MainActor
final class StravaService: NSObject, ObservableObject, StravaAPIService {

    // MARK: Configuration – loaded from Info.plist (values injected via Config.xcconfig)

    private let clientId     = Bundle.main.object(forInfoDictionaryKey: "StravaClientId")     as? String ?? ""
    private let clientSecret = Bundle.main.object(forInfoDictionaryKey: "StravaClientSecret") as? String ?? ""
    private let redirectUri  = "bikechain://strava/callback"

    // MARK: Published state

    @Published private(set) var isAuthenticated = false

    // MARK: Private

    private let baseURL  = URL(string: "https://www.strava.com/api/v3")!
    private let tokenURL = URL(string: "https://www.strava.com/oauth/token")!

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiresAt: Date?

    // UserDefaults keys
    private let keyAccessToken  = "strava.accessToken"
    private let keyRefreshToken = "strava.refreshToken"
    private let keyExpiresAt    = "strava.expiresAt"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // Strava returns ISO 8601 dates both with and without fractional seconds
        // e.g. "2024-03-15T10:30:00Z" and "2024-03-15T10:30:00.000000Z".
        // The built-in .iso8601 strategy only handles the former, so we use a
        // custom strategy that tries both.
        let formatterFull = ISO8601DateFormatter()
        formatterFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatterBasic = ISO8601DateFormatter()
        formatterBasic.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = formatterFull.date(from: string) { return date }
            if let date = formatterBasic.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse date: \(string)"
            )
        }
        return d
    }()

    // MARK: Init

    override init() {
        super.init()
        loadStoredTokens()
    }

    // MARK: - OAuth

    /// Starts the Strava OAuth flow using an in-app browser session.
    func authorize() async throws {
        var components = URLComponents(string: "https://www.strava.com/oauth/authorize")!
        components.queryItems = [
            .init(name: "client_id",     value: clientId),
            .init(name: "redirect_uri",  value: redirectUri),
            .init(name: "response_type", value: "code"),
            .init(name: "approval_prompt", value: "auto"),
            .init(name: "scope",         value: "read,activity:read_all"),
        ]

        let authURL = components.url!
        let callbackScheme = "bikechain"

        let code: String = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard
                    let callbackURL,
                    let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                    let code = components.queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: StravaError.invalidResponse)
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        try await exchangeCode(code)
    }

    /// Exchanges an authorization code for access and refresh tokens.
    private func exchangeCode(_ code: String) async throws {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id":     clientId,
            "client_secret": clientSecret,
            "code":          code,
            "grant_type":    "authorization_code",
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let tokenResponse: StravaTokenResponse = try await perform(request, authorized: false)
        applyTokenResponse(tokenResponse)
    }

    /// Refreshes the access token using the stored refresh token.
    private func refreshAccessToken() async throws {
        guard let storedRefreshToken = refreshToken else {
            throw StravaError.notAuthenticated
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id":     clientId,
            "client_secret": clientSecret,
            "refresh_token": storedRefreshToken,
            "grant_type":    "refresh_token",
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let tokenResponse: StravaTokenResponse = try await perform(request, authorized: false)
        applyTokenResponse(tokenResponse)
    }

    // MARK: - Public API

    /// Returns all bikes registered for the authenticated athlete.
    func fetchBikes() async throws -> [StravaBike] {
        try await ensureValidToken()
        let athlete: StravaAthlete = try await get("athlete")
        return athlete.bikes
    }

    /// Returns all rides for the given Strava bike ID within the specified date range.
    /// Strava's activity endpoint is paginated; this method fetches all pages automatically.
    func fetchRides(bikeId: String, from startDate: Date, to endDate: Date) async throws -> [StravaActivity] {
        try await ensureValidToken()

        let after  = Int(startDate.timeIntervalSince1970)
        let before = Int(endDate.timeIntervalSince1970)

        var allRides: [StravaActivity] = []
        var page = 1
        let perPage = 200

        while true {
            let activities: [StravaActivity] = try await get(
                "athlete/activities",
                queryItems: [
                    .init(name: "after",    value: "\(after)"),
                    .init(name: "before",   value: "\(before)"),
                    .init(name: "per_page", value: "\(perPage)"),
                    .init(name: "page",     value: "\(page)"),
                ]
            )

            let rides = activities.filter { $0.activityType == "Ride" && $0.gearId == bikeId }
            allRides.append(contentsOf: rides)

            if activities.count < perPage { break }
            page += 1
        }

        return allRides
    }

    // MARK: - Helpers

    private func ensureValidToken() async throws {
        guard refreshToken != nil else { throw StravaError.notAuthenticated }

        if let expiresAt = tokenExpiresAt, expiresAt > Date() {
            return  // token still valid
        }
        try await refreshAccessToken()
    }

    private func get<T: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path),
                                       resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty { components.queryItems = queryItems }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        return try await perform(request, authorized: true)
    }

    private func perform<T: Decodable>(_ request: URLRequest, authorized: Bool) async throws -> T {
        var req = request
        if authorized, let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        #if DEBUG
        let method = req.httpMethod ?? "GET"
        let url = req.url?.absoluteString ?? "?"
        print("🌐 Strava → \(method) \(url)")
        if let body = req.httpBody, let bodyStr = String(data: body, encoding: .utf8) {
            print("   body: \(bodyStr)")
        }
        #endif

        let (data, response) = try await URLSession.shared.data(for: req)

        #if DEBUG
        if let http = response as? HTTPURLResponse {
            print("   ← HTTP \(http.statusCode)")
        }
        let raw = String(data: data, encoding: .utf8) ?? "<non-UTF8>"
        print("   body: \(raw)")
        #endif

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw StravaError.httpError(http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("⚠️ Strava decode error: \(error)")
            throw error
        }
    }

    // MARK: - Token persistence

    private func applyTokenResponse(_ response: StravaTokenResponse) {
        accessToken    = response.accessToken
        refreshToken   = response.refreshToken
        tokenExpiresAt = Date(timeIntervalSince1970: response.expiresAt)
        isAuthenticated = true
        persistTokens()
    }

    private func persistTokens() {
        let defaults = UserDefaults.standard
        defaults.set(accessToken,                              forKey: keyAccessToken)
        defaults.set(refreshToken,                             forKey: keyRefreshToken)
        defaults.set(tokenExpiresAt?.timeIntervalSince1970,    forKey: keyExpiresAt)
    }

    private func loadStoredTokens() {
        let defaults = UserDefaults.standard
        accessToken  = defaults.string(forKey: keyAccessToken)
        refreshToken = defaults.string(forKey: keyRefreshToken)
        if let ts = defaults.object(forKey: keyExpiresAt) as? TimeInterval {
            tokenExpiresAt = Date(timeIntervalSince1970: ts)
        }
        isAuthenticated = refreshToken != nil
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension StravaService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // This delegate method is always called on the main thread by the system.
        MainActor.assumeIsolated {
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            return windowScene.map { ASPresentationAnchor(windowScene: $0) }
                ?? ASPresentationAnchor()
        }
    }
}
