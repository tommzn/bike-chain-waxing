//
//  StravaEnvironment.swift
//  BikeChain
//
//  Created by Thomas Schenker on 30.03.26.
//

import SwiftUI

// Custom environment key so any StravaAPIService (real or mock) can be injected.
private struct StravaServiceKey: EnvironmentKey {
    static let defaultValue: (any StravaAPIService)? = nil
}

extension EnvironmentValues {
    var stravaService: (any StravaAPIService)? {
        get { self[StravaServiceKey.self] }
        set { self[StravaServiceKey.self] = newValue }
    }
}

// MARK: - Preview mock

#if DEBUG
@MainActor
final class MockStravaService: StravaAPIService {
    var isAuthenticated: Bool = true
    func authorize() async throws {}

    func fetchBikes() async throws -> [StravaBike] {
        return [
            StravaBike(id: "s1", name: "Canyon Gravel CF SL", distance: 4_320_000),
            StravaBike(id: "s2", name: "Trek Domane SL6",      distance: 8_100_000),
            StravaBike(id: "s4", name: "Giant TCR Advanced",   distance: 2_100_000),
        ]
    }

    func fetchRides(bikeId: String, from startDate: Date, to endDate: Date) async throws -> [StravaActivity] {
        []
    }
}
#endif
