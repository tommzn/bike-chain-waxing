//
//  StravaModels.swift
//  BikeChain
//
//  Created by Thomas Schenker on 30.03.26.
//

import Foundation

// MARK: - OAuth

struct StravaTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: TimeInterval   // Unix timestamp

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt    = "expires_at"
    }
}

// MARK: - Athlete

struct StravaAthlete: Decodable {
    let bikes: [StravaBike]
}

// MARK: - Bike

struct StravaBike: Decodable, Identifiable {
    let id: String
    let name: String
    /// Total distance in meters as reported by Strava.
    let distance: Double

    var distanceKm: Double { distance / 1000 }
}

// MARK: - Activity

struct StravaActivity: Decodable, Identifiable {
    let id: Int
    let name: String
    let type: String
    let startDate: Date
    /// Distance in meters.
    let distance: Double
    let gearId: String?

    var distanceKm: Double { distance / 1000 }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case startDate = "start_date"
        case distance
        case gearId    = "gear_id"
    }
}
