//
//  StravaModelsTests.swift
//  BikeChainTests
//
//  Created by Thomas Schenker on 30.03.26.
//

import Testing
import Foundation
@testable import BikeChain

@Suite("StravaModels – JSON decoding", .serialized)
struct StravaModelsTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        let formatterFull = ISO8601DateFormatter()
        formatterFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatterBasic = ISO8601DateFormatter()
        formatterBasic.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = formatterFull.date(from: string) { return date }
            if let date = formatterBasic.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Cannot parse date: \(string)")
        }
        return d
    }()

    // MARK: - StravaBike

    @Test func decodeBike() throws {
        let json = """
        {"id":"b12345","name":"My Road Bike","distance":150000.0}
        """.data(using: .utf8)!

        let bike = try decoder.decode(StravaBike.self, from: json)

        #expect(bike.id == "b12345")
        #expect(bike.name == "My Road Bike")
        #expect(bike.distance == 150_000)
    }

    @Test func bikeDistanceKmConversion() throws {
        let json = """
        {"id":"b1","name":"Bike","distance":42000.0}
        """.data(using: .utf8)!

        let bike = try decoder.decode(StravaBike.self, from: json)

        #expect(bike.distanceKm == 42)
    }

    @Test func bikeWithNullNameFallsBackToDefault() throws {
        let json = """
        {"id":"b1","name":null,"distance":0}
        """.data(using: .utf8)!

        let bike = try decoder.decode(StravaBike.self, from: json)

        #expect(bike.name == "Unnamed Bike")
    }

    // MARK: - StravaActivity

    @Test func decodeActivity() throws {
        let json = """
        {
          "id": 9876543,
          "name": "Morning Ride",
          "type": "Ride",
          "start_date": "2026-03-15T08:30:00Z",
          "distance": 52000.0,
          "gear_id": "b12345"
        }
        """.data(using: .utf8)!

        let activity = try decoder.decode(StravaActivity.self, from: json)

        #expect(activity.id == 9_876_543)
        #expect(activity.name == "Morning Ride")
        #expect(activity.activityType == "Ride")
        #expect(activity.distance == 52_000)
        #expect(activity.gearId == "b12345")
    }

    @Test func decodeActivityWithSportTypeOnly() throws {
        let json = """
        {
          "id": 1,
          "name": "Morning Ride",
          "sport_type": "Ride",
          "start_date": "2026-03-15T08:30:00Z",
          "distance": 52000.0
        }
        """.data(using: .utf8)!

        let activity = try decoder.decode(StravaActivity.self, from: json)

        #expect(activity.activityType == "Ride")
    }

    @Test func decodeActivityWithNilGearId() throws {
        let json = """
        {
          "id": 1,
          "name": "Run",
          "type": "Run",
          "start_date": "2026-03-15T08:30:00Z",
          "distance": 10000.0
        }
        """.data(using: .utf8)!

        let activity = try decoder.decode(StravaActivity.self, from: json)

        #expect(activity.gearId == nil)
    }

    @Test func activityDistanceKmConversion() throws {
        let json = """
        {
          "id": 1,
          "name": "Ride",
          "type": "Ride",
          "start_date": "2026-03-15T08:30:00Z",
          "distance": 75500.0,
          "gear_id": "b1"
        }
        """.data(using: .utf8)!

        let activity = try decoder.decode(StravaActivity.self, from: json)

        #expect(activity.distanceKm == 75.5)
    }

    @Test func activityStartDateDecoding() throws {
        let json = """
        {
          "id": 1,
          "name": "Ride",
          "type": "Ride",
          "start_date": "2026-01-01T00:00:00Z",
          "distance": 0
        }
        """.data(using: .utf8)!

        let activity = try decoder.decode(StravaActivity.self, from: json)

        let components = Calendar(identifier: .gregorian)
            .dateComponents(in: TimeZone(identifier: "UTC")!, from: activity.startDate)
        #expect(components.year == 2026)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }

    @Test func activityStartDateWithFractionalSeconds() throws {
        let json = """
        {
          "id": 1,
          "name": "Ride",
          "type": "Ride",
          "start_date": "2026-01-01T00:00:00.000000Z",
          "distance": 0
        }
        """.data(using: .utf8)!

        let activity = try decoder.decode(StravaActivity.self, from: json)

        let components = Calendar(identifier: .gregorian)
            .dateComponents(in: TimeZone(identifier: "UTC")!, from: activity.startDate)
        #expect(components.year == 2026)
    }

    // MARK: - StravaTokenResponse

    @Test func decodeTokenResponse() throws {
        let json = """
        {
          "access_token": "abc123",
          "refresh_token": "xyz789",
          "expires_at": 1711900000
        }
        """.data(using: .utf8)!

        let token = try decoder.decode(StravaTokenResponse.self, from: json)

        #expect(token.accessToken == "abc123")
        #expect(token.refreshToken == "xyz789")
        #expect(token.expiresAt == 1_711_900_000)
    }

    // MARK: - StravaAthlete

    @Test func decodeAthleteWithBikes() throws {
        let json = """
        {
          "bikes": [
            {"id":"b1","name":"Bike One","distance":10000},
            {"id":"b2","name":"Bike Two","distance":20000}
          ]
        }
        """.data(using: .utf8)!

        let athlete = try decoder.decode(StravaAthlete.self, from: json)

        #expect(athlete.bikes.count == 2)
        #expect(athlete.bikes[0].id == "b1")
        #expect(athlete.bikes[1].id == "b2")
    }

    @Test func decodeAthleteWithNoBikes() throws {
        let json = """
        {"bikes": []}
        """.data(using: .utf8)!

        let athlete = try decoder.decode(StravaAthlete.self, from: json)

        #expect(athlete.bikes.isEmpty)
    }

    @Test func decodeAthleteWithMissingBikesKey() throws {
        let json = """
        {"id": 12345, "firstname": "Jane"}
        """.data(using: .utf8)!

        let athlete = try decoder.decode(StravaAthlete.self, from: json)

        #expect(athlete.bikes.isEmpty)
    }
}
