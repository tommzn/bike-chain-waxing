//
//  BikeChainApp.swift
//  BikeChain
//
//  Created by Thomas Schenker on 30.03.26.
//

import SwiftUI
import SwiftData

@main
struct BikeChainApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            AppSettings.self,
            Bike.self,
            Ride.self,
            WaxEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject private var stravaService = StravaService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.stravaService, stravaService)
        }
        .modelContainer(sharedModelContainer)
    }
}
