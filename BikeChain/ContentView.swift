//
//  ContentView.swift
//  BikeChain
//
//  Created by Thomas Schenker on 30.03.26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.stravaService) private var stravaService
    @Query(sort: \Bike.name) private var bikes: [Bike]
    @Query private var settings: [AppSettings]

    @State private var store: BikeChainStore?
    @State private var showAddBike = false
    @State private var bikeToWax: Bike?

    private var waxDurationKm: Double {
        settings.first?.waxDurationKm ?? 200.0
    }

    var body: some View {
        NavigationStack {
            List(bikes) { bike in
                BikeRowView(bike: bike, waxDurationKm: waxDurationKm) {
                    if bike.lastWaxEntry != nil {
                        bikeToWax = bike
                    } else {
                        addWaxEntry(to: bike)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteBike(bike)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                guard let store else { return }
                for bike in bikes {
                    await store.refreshRides(for: bike)
                }
            }
            .navigationTitle("My Bikes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAddBike = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AppSettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .overlay {
                if bikes.isEmpty {
                    ContentUnavailableView(
                        "No Bikes",
                        systemImage: "bicycle",
                        description: Text("Tap + to import bikes from Strava.")
                    )
                }
            }
            .confirmationDialog(
                "Log Wax",
                isPresented: Binding(get: { bikeToWax != nil }, set: { if !$0 { bikeToWax = nil } }),
                titleVisibility: .visible
            ) {
                Button("Log Wax") {
                    if let bike = bikeToWax { addWaxEntry(to: bike) }
                    bikeToWax = nil
                }
                Button("Cancel", role: .cancel) { bikeToWax = nil }
            } message: {
                if let bike = bikeToWax, let date = bike.lastWaxEntry?.date {
                    Text("This will replace the last wax entry from \(date.formatted(date: .long, time: .omitted)).")
                }
            }
            .sheet(isPresented: $showAddBike) {
                if let store {
                    AddBikeView(store: store)
                } else {
                    ProgressView()
                        .task {
                            guard let stravaService else { return }
                            store = BikeChainStore(strava: stravaService, modelContext: modelContext)
                        }
                }
            }
            .task {
                guard store == nil, let stravaService else { return }
                store = BikeChainStore(strava: stravaService, modelContext: modelContext)
            }
        }
    }

    private func deleteBike(_ bike: Bike) {
        modelContext.delete(bike)
    }

    private func addWaxEntry(to bike: Bike) {
        if let existing = bike.lastWaxEntry {
            modelContext.delete(existing)
        }
        let entry = WaxEntry(date: .now)
        modelContext.insert(entry)
        bike.lastWaxEntry = entry
    }
}

private func makePreviewContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Bike.self, Ride.self, WaxEntry.self, AppSettings.self,
        configurations: config
    )
    let ctx = container.mainContext

    let bike1 = Bike(stravaId: "s1", name: "Canyon Gravel")
    let bike2 = Bike(stravaId: "s2", name: "Trek Road")
    let bike3 = Bike(stravaId: "s3", name: "Specialized MTB")
    ctx.insert(bike1)
    ctx.insert(bike2)
    ctx.insert(bike3)

    let ride1 = Ride(stravaActivityId: 101, date: .now.addingTimeInterval(-86400 * 3), distanceKm: 80)
    let ride2 = Ride(stravaActivityId: 102, date: .now.addingTimeInterval(-86400), distanceKm: 55)
    ctx.insert(ride1)
    ctx.insert(ride2)
    bike1.rides = [ride1, ride2]

    let wax = WaxEntry(date: .now.addingTimeInterval(-86400 * 10))
    ctx.insert(wax)
    bike2.lastWaxEntry = wax

    // Overdue: 350 km ridden since last wax, default interval is 200 km
    let wax3 = WaxEntry(date: .now.addingTimeInterval(-86400 * 20))
    ctx.insert(wax3)
    bike3.lastWaxEntry = wax3
    let ride3 = Ride(stravaActivityId: 201, date: .now.addingTimeInterval(-86400 * 15), distanceKm: 180)
    let ride4 = Ride(stravaActivityId: 202, date: .now.addingTimeInterval(-86400 * 5), distanceKm: 170)
    ctx.insert(ride3)
    ctx.insert(ride4)
    bike3.rides = [ride3, ride4]

    return container
}

#Preview {
    ContentView()
        .modelContainer(makePreviewContainer())
        .environment(\.stravaService, MockStravaService())
}
