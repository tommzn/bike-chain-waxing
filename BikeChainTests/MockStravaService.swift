//
//  MockStravaService.swift
//  BikeChainTests
//
//  Created by Thomas Schenker on 30.03.26.
//

import Foundation
import SwiftData
@testable import BikeChain

final class MockStravaService: StravaAPIService {

    // MARK: Configurable return values

    var bikesToReturn: [StravaBike] = []
    var ridesToReturn: [StravaActivity] = []
    var errorToThrow: Error?

    // MARK: Captured arguments

    private(set) var fetchRidesCallCount = 0
    private(set) var lastFetchRidesBikeId: String?
    private(set) var lastFetchRidesFrom: Date?
    private(set) var lastFetchRidesTo: Date?

    // MARK: StravaAPIService

    var isAuthenticated: Bool = true

    func authorize() async throws {
        if let error = errorToThrow { throw error }
    }

    func fetchBikes() async throws -> [StravaBike] {
        if let error = errorToThrow { throw error }
        return bikesToReturn
    }

    func fetchRides(bikeId: String, from startDate: Date, to endDate: Date) async throws -> [StravaActivity] {
        if let error = errorToThrow { throw error }
        fetchRidesCallCount += 1
        lastFetchRidesBikeId = bikeId
        lastFetchRidesFrom = startDate
        lastFetchRidesTo = endDate
        return ridesToReturn
    }
}
