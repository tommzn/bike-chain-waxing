//
//  StravaServiceProtocol.swift
//  BikeChain
//
//  Created by Thomas Schenker on 30.03.26.
//

import Foundation

@MainActor
protocol StravaAPIService {
    var isAuthenticated: Bool { get }
    func authorize() async throws
    func fetchBikes() async throws -> [StravaBike]
    func fetchRides(bikeId: String, from startDate: Date, to endDate: Date) async throws -> [StravaActivity]
}
