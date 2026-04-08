//
//  Settings.swift
//  BikeChain
//
//  Created by Thomas Schenker on 30.03.26.
//

import Foundation
import SwiftData

@Model
final class AppSettings {
    /// Distance in kilometers after which the chain needs to be waxed again.
    var waxDurationKm: Double = 200.0

    init(waxDurationKm: Double = 200.0) {
        self.waxDurationKm = waxDurationKm
    }
}
