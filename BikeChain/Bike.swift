//
//  Bike.swift
//  BikeChain
//
//  Created by Thomas Schenker on 30.03.26.
//

import Foundation
import SwiftData

@Model
final class Bike {
    var stravaId: String = ""
    var name: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Ride.bike)
    var rides: [Ride]?

    @Relationship(deleteRule: .cascade, inverse: \WaxEntry.bike)
    var lastWaxEntry: WaxEntry?

    init(stravaId: String, name: String) {
        self.stravaId = stravaId
        self.name = name
    }
}

@Model
final class Ride {
    /// Strava activity ID — used to prevent duplicate imports on refresh.
    var stravaActivityId: Int = 0
    var date: Date = Date.distantPast
    var distanceKm: Double = 0.0
    var bike: Bike?

    init(stravaActivityId: Int, date: Date, distanceKm: Double) {
        self.stravaActivityId = stravaActivityId
        self.date = date
        self.distanceKm = distanceKm
    }
}

@Model
final class WaxEntry {
    var date: Date = Date.distantPast
    var bike: Bike?

    init(date: Date) {
        self.date = date
    }
}
