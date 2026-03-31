//
//  BikeChainStoreTests.swift
//  BikeChainTests
//
//  Created by Thomas Schenker on 30.03.26.
//

import Testing
import Foundation
import SwiftData
@testable import BikeChain

@Suite("BikeChainStore", .serialized)
@MainActor
struct BikeChainStoreTests {

    // MARK: Helpers

    /// Builds an isolated in-memory store, context, and mock for each test.
    func makeStore() throws -> (store: BikeChainStore, context: ModelContext, mock: MockStravaService) {
        let mock = MockStravaService()
        let config = ModelConfiguration(
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: Bike.self, Ride.self, WaxEntry.self, AppSettings.self,
            configurations: config
        )
        // Use ModelContext(container) rather than container.mainContext
        // to avoid a main-actor re-entrancy deadlock in synchronous test functions.
        let context = ModelContext(container)
        let store = BikeChainStore(strava: mock, modelContext: context)
        return (store, context, mock)
    }

    func makeStravaBike(id: String = "b1", name: String = "Road Bike") -> StravaBike {
        StravaBike(id: id, name: name, distance: 100_000)
    }

    func makeActivity(id: Int = 1, distanceMeters: Double = 50_000, gearId: String = "b1") -> StravaActivity {
        StravaActivity(
            id: id, name: "Ride \(id)", type: "Ride",
            startDate: Date(), distance: distanceMeters, gearId: gearId
        )
    }

    // MARK: - importBike

    @Test func importBikeCreatesBikeInStore() throws {
        let (store, context, _) = try makeStore()

        try store.importBike(makeStravaBike())

        let bikes = try context.fetch(FetchDescriptor<Bike>())
        #expect(bikes.count == 1)
        #expect(bikes[0].stravaId == "b1")
        #expect(bikes[0].name == "Road Bike")
    }

    @Test func importBikeUpdatesNameIfAlreadyImported() throws {
        let (store, context, _) = try makeStore()
        try store.importBike(makeStravaBike(name: "Old Name"))
        try store.importBike(makeStravaBike(name: "New Name"))

        let bikes = try context.fetch(FetchDescriptor<Bike>())
        #expect(bikes.count == 1)
        #expect(bikes[0].name == "New Name")
    }

    @Test func importBikeReturnsBikeObject() throws {
        let (store, _, _) = try makeStore()
        let bike = try store.importBike(makeStravaBike())
        #expect(bike.stravaId == "b1")
    }

    // MARK: - addWaxEntry

    @Test func addWaxEntrySetsLastWaxEntry() throws {
        let (store, _, _) = try makeStore()
        let bike = try store.importBike(makeStravaBike())

        store.addWaxEntry(to: bike)

        #expect(bike.lastWaxEntry != nil)
    }

    @Test func addWaxEntryUsesCurrentDateByDefault() throws {
        let (store, _, _) = try makeStore()
        let bike = try store.importBike(makeStravaBike())
        let before = Date()

        store.addWaxEntry(to: bike)

        let after = Date()
        let entryDate = try #require(bike.lastWaxEntry).date
        #expect(entryDate >= before && entryDate <= after)
    }

    @Test func addWaxEntryAcceptsCustomDate() throws {
        let (store, _, _) = try makeStore()
        let bike = try store.importBike(makeStravaBike())
        let customDate = Date(timeIntervalSinceNow: -86_400)

        store.addWaxEntry(to: bike, date: customDate)

        #expect(abs(try #require(bike.lastWaxEntry).date.timeIntervalSince(customDate)) < 1)
    }

    @Test func addWaxEntryReplacesExistingEntry() throws {
        let (store, _, _) = try makeStore()
        let bike = try store.importBike(makeStravaBike())
        let lastDate = Date(timeIntervalSinceNow: -100)

        store.addWaxEntry(to: bike, date: Date(timeIntervalSinceNow: -200))
        store.addWaxEntry(to: bike, date: lastDate)

        #expect(abs(try #require(bike.lastWaxEntry).date.timeIntervalSince(lastDate)) < 1)
    }

    // MARK: - deleteWaxEntry

    @Test func deleteWaxEntryRemovesItFromBike() throws {
        let (store, _, _) = try makeStore()
        let bike = try store.importBike(makeStravaBike())
        store.addWaxEntry(to: bike)

        store.deleteWaxEntry(from: bike)

        #expect(bike.lastWaxEntry == nil)
    }

    @Test func deleteWaxEntryWhenNoneExistsDoesNothing() throws {
        let (store, _, _) = try makeStore()
        let bike = try store.importBike(makeStravaBike())

        store.deleteWaxEntry(from: bike)

        #expect(bike.lastWaxEntry == nil)
    }

    // MARK: - waxStatus

    @Test func waxStatusReturnsZeroRiddenWhenNoRides() throws {
        let (store, _, _) = try makeStore()
        let bike = try store.importBike(makeStravaBike())

        let status = try store.waxStatus(for: bike)

        #expect(status.riddenKm == 0)
    }

    @Test func waxStatusUsesDefaultDurationWhenNoSettings() throws {
        let (store, _, _) = try makeStore()
        let bike = try store.importBike(makeStravaBike())

        let status = try store.waxStatus(for: bike)

        #expect(status.durationKm == 200)
    }

    @Test func waxStatusUsesSettingsDuration() throws {
        let (store, context, _) = try makeStore()
        context.insert(AppSettings(waxDurationKm: 350))
        let bike = try store.importBike(makeStravaBike())

        let status = try store.waxStatus(for: bike)

        #expect(status.durationKm == 350)
    }

    @Test func waxStatusCountsAllRidesWhenNeverWaxed() throws {
        let (store, context, _) = try makeStore()
        let bike = try store.importBike(makeStravaBike())

        let ride1 = Ride(stravaActivityId: 1, date: Date(timeIntervalSinceNow: -500), distanceKm: 80)
        let ride2 = Ride(stravaActivityId: 2, date: Date(timeIntervalSinceNow: -200), distanceKm: 60)
        context.insert(ride1); bike.rides.append(ride1)
        context.insert(ride2); bike.rides.append(ride2)

        let status = try store.waxStatus(for: bike)

        #expect(status.riddenKm == 140)
    }

    @Test func waxStatusCountsOnlyRidesAfterLastWax() throws {
        let (store, context, _) = try makeStore()
        let bike = try store.importBike(makeStravaBike())

        let waxDate       = Date(timeIntervalSinceNow: -300)
        let rideBeforeWax = Ride(stravaActivityId: 1, date: Date(timeIntervalSinceNow: -500), distanceKm: 100)
        let rideAfterWax  = Ride(stravaActivityId: 2, date: Date(timeIntervalSinceNow: -100), distanceKm: 55)
        context.insert(rideBeforeWax); bike.rides.append(rideBeforeWax)
        context.insert(rideAfterWax);  bike.rides.append(rideAfterWax)
        store.addWaxEntry(to: bike, date: waxDate)

        let status = try store.waxStatus(for: bike)

        #expect(status.riddenKm == 55)
    }

    @Test func waxStatusIsNotDueBelowThreshold() throws {
        let (store, context, _) = try makeStore()
        let bike = try store.importBike(makeStravaBike())
        let ride = Ride(stravaActivityId: 1, date: Date(), distanceKm: 150)
        context.insert(ride); bike.rides.append(ride)

        let status = try store.waxStatus(for: bike)

        #expect(!status.isDue)
    }

    @Test func waxStatusIsDueAboveThreshold() throws {
        let (store, context, _) = try makeStore()
        let bike = try store.importBike(makeStravaBike())
        let ride = Ride(stravaActivityId: 1, date: Date(), distanceKm: 210)
        context.insert(ride); bike.rides.append(ride)

        let status = try store.waxStatus(for: bike)

        #expect(status.isDue)
    }

    // MARK: - refreshRides

    @Test func refreshRidesInsertsNewRides() async throws {
        let (store, _, mock) = try makeStore()
        let bike = try store.importBike(makeStravaBike())
        mock.ridesToReturn = [makeActivity(id: 1), makeActivity(id: 2)]

        await store.refreshRides(for: bike)

        #expect(bike.rides.count == 2)
    }

    @Test func refreshRidesSkipsDuplicateActivities() async throws {
        let (store, context, mock) = try makeStore()
        let bike = try store.importBike(makeStravaBike())

        let existing = Ride(stravaActivityId: 1, date: Date(), distanceKm: 50)
        context.insert(existing); bike.rides.append(existing)
        mock.ridesToReturn = [makeActivity(id: 1), makeActivity(id: 2)]

        await store.refreshRides(for: bike)

        #expect(bike.rides.count == 2)
    }

    @Test func refreshRidesUsesLastWaxDateAsWindowStart() async throws {
        let (store, _, mock) = try makeStore()
        let bike = try store.importBike(makeStravaBike())
        let waxDate = Date(timeIntervalSinceNow: -86_400)
        store.addWaxEntry(to: bike, date: waxDate)

        await store.refreshRides(for: bike)

        let capturedFrom = try #require(mock.lastFetchRidesFrom)
        #expect(abs(capturedFrom.timeIntervalSince(waxDate)) < 1)
    }

    @Test func refreshRidesFallsBackToOneYearWhenNeverWaxed() async throws {
        let (store, _, mock) = try makeStore()
        let bike = try store.importBike(makeStravaBike())

        await store.refreshRides(for: bike)

        let capturedFrom = try #require(mock.lastFetchRidesFrom)
        let expectedStart = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        #expect(abs(capturedFrom.timeIntervalSince(expectedStart)) < 2)
    }

    @Test func refreshRidesSetsErrorOnFailure() async throws {
        let (store, _, mock) = try makeStore()
        let bike = try store.importBike(makeStravaBike())
        mock.errorToThrow = StravaError.notAuthenticated

        await store.refreshRides(for: bike)

        #expect(store.error != nil)
    }

    @Test func loadStravaBikesPopulatesAvailableBikes() async throws {
        let (store, _, mock) = try makeStore()
        mock.bikesToReturn = [makeStravaBike(id: "b1"), makeStravaBike(id: "b2")]

        await store.loadStravaBikes()

        #expect(store.availableStravaBikes.count == 2)
    }

    @Test func loadStravaBikesSetsErrorOnFailure() async throws {
        let (store, _, mock) = try makeStore()
        mock.errorToThrow = StravaError.notAuthenticated

        await store.loadStravaBikes()

        #expect(store.error != nil)
    }
}
