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
    // Default to empty array — Strava may omit or null-out this field
    // for accounts with no bikes or restricted scopes.
    let bikes: [StravaBike]

    enum CodingKeys: String, CodingKey { case bikes }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bikes = (try? container.decode([StravaBike].self, forKey: .bikes)) ?? []
    }
}

// MARK: - Bike

struct StravaBike: Decodable, Identifiable {
    let id: String
    let name: String
    /// Total distance in meters as reported by Strava.
    let distance: Double

    var distanceKm: Double { distance / 1000 }

    enum CodingKeys: String, CodingKey { case id, name, distance }

    init(id: String, name: String, distance: Double) {
        self.id = id
        self.name = name
        self.distance = distance
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(String.self, forKey: .id)
        name     = (try? c.decode(String.self, forKey: .name)) ?? "Unnamed Bike"
        distance = (try? c.decode(Double.self, forKey: .distance)) ?? 0
    }
}

// MARK: - Gear

/// Response from GET /gear/{id} — used as fallback when athlete.bikes is empty.
struct StravaGear: Decodable {
    let id: String
    let name: String
    let distance: Double

    enum CodingKeys: String, CodingKey { case id, name, distance }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(String.self, forKey: .id)
        name     = (try? c.decode(String.self, forKey: .name)) ?? "Unnamed Bike"
        distance = (try? c.decode(Double.self, forKey: .distance)) ?? 0
    }

    var asStravaBike: StravaBike { StravaBike(id: id, name: name, distance: distance) }
}

// MARK: - Activity

struct StravaActivity: Decodable, Identifiable {
    let id: Int
    let name: String
    /// `type` is deprecated in newer Strava API versions; fall back to `sport_type`.
    let activityType: String
    let startDate: Date
    /// Distance in meters.
    let distance: Double
    let gearId: String?

    var distanceKm: Double { distance / 1000 }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case sportType = "sport_type"
        case startDate = "start_date"
        case distance
        case gearId    = "gear_id"
    }

    init(id: Int, name: String, type: String, startDate: Date = Date(), distance: Double, gearId: String? = nil) {
        self.id = id
        self.name = name
        self.activityType = type
        self.startDate = startDate
        self.distance = distance
        self.gearId = gearId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(Int.self,    forKey: .id)
        name         = try c.decode(String.self, forKey: .name)
        activityType = (try? c.decode(String.self, forKey: .type))
                    ?? (try? c.decode(String.self, forKey: .sportType))
                    ?? "Ride"
        startDate    = try c.decode(Date.self,   forKey: .startDate)
        distance     = try c.decode(Double.self, forKey: .distance)
        gearId       = try? c.decode(String.self, forKey: .gearId)
    }
}
