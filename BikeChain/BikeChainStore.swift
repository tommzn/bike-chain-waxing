//
//  BikeChainStore.swift
//  BikeChain
//
//  Created by Thomas Schenker on 30.03.26.
//

import Foundation
import Combine
import SwiftData

// MARK: - WaxStatus

/// The result of a wax interval calculation for a single bike.
struct WaxStatus {
    /// Kilometers ridden since the last waxing.
    let riddenKm: Double
    /// Configured wax interval from AppSettings.
    let durationKm: Double

    /// Kilometers remaining until the next waxing is due. Negative when overdue.
    var remainingKm: Double { durationKm - riddenKm }

    /// True when the chain needs waxing.
    var isDue: Bool { riddenKm >= durationKm }

    /// Progress in the range 0…1 (capped at 1 when overdue).
    var progress: Double { min(riddenKm / durationKm, 1.0) }

    /// Human-readable summary, e.g. "123.4 km of 200.0 km".
    var summary: String {
        String(format: "%.1f km of %.1f km", riddenKm, durationKm)
    }
}

// MARK: - BikeChainStore

/// Orchestrates data flow between the Strava API and the local SwiftData store.
@MainActor
final class BikeChainStore: ObservableObject {

    // MARK: Published state

    /// Bikes returned by Strava — not yet persisted locally.
    @Published private(set) var availableStravaBikes: [StravaBike] = []

    @Published private(set) var isLoading = false
    @Published var error: Error?

    // MARK: Dependencies

    private let strava: any StravaAPIService
    private let modelContext: ModelContext

    // MARK: Init

    init(strava: any StravaAPIService, modelContext: ModelContext) {
        self.strava = strava
        self.modelContext = modelContext
    }

    // MARK: - Bike listing & import

    /// Fetches all bikes from the authenticated Strava account.
    /// Results are stored in `availableStravaBikes` for the UI to display.
    func loadStravaBikes() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            availableStravaBikes = try await strava.fetchBikes()
        } catch {
            self.error = error
        }
    }

    /// Imports a Strava bike into the local SwiftData store.
    /// If the bike is already stored (matched by Strava ID) the name is updated instead.
    ///
    /// - Returns: The persisted `Bike` object.
    @discardableResult
    func importBike(_ stravaBike: StravaBike) throws -> Bike {
        if let existing = try fetchLocalBike(stravaId: stravaBike.id) {
            existing.name = stravaBike.name
            return existing
        }

        let bike = Bike(stravaId: stravaBike.id, name: stravaBike.name)
        modelContext.insert(bike)
        return bike
    }

    // MARK: - Ride refresh

    /// Fetches rides for `bike` from Strava and inserts any new ones into the local store.
    ///
    /// The start of the fetch window is determined automatically:
    /// - If the bike has been waxed before, fetching starts from the most recent wax date
    ///   so only rides that count towards the next waxing interval are loaded.
    /// - Otherwise all rides up to today are fetched (capped at one year to keep the
    ///   initial import manageable).
    func refreshRides(for bike: Bike) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let (startDate, endDate) = refreshDateRange(for: bike)
            let stravaRides = try await strava.fetchRides(
                bikeId: bike.stravaId,
                from: startDate,
                to: endDate
            )
            try insertNewRides(stravaRides, into: bike)
        } catch {
            self.error = error
        }
    }

    // MARK: - Wax entries

    /// Records a waxing event for `bike` at the given point in time (defaults to now).
    @discardableResult
    func addWaxEntry(to bike: Bike, date: Date = .now) -> WaxEntry {
        if let existing = bike.lastWaxEntry {
            modelContext.delete(existing)
        }
        let entry = WaxEntry(date: date)
        modelContext.insert(entry)
        bike.lastWaxEntry = entry
        return entry
    }

    /// Removes the wax entry from the store.
    func deleteWaxEntry(from bike: Bike) {
        if let existing = bike.lastWaxEntry {
            modelContext.delete(existing)
            bike.lastWaxEntry = nil
        }
    }

    // MARK: - Wax status calculation

    /// Calculates how many kilometers have been ridden since the last waxing
    /// and returns a `WaxStatus` relative to the configured wax interval.
    ///
    /// - If no wax entry exists all stored rides are counted.
    /// - If no settings record exists a default interval of 200 km is used.
    func waxStatus(for bike: Bike) throws -> WaxStatus {
        let durationKm = try fetchAppSettings()?.waxDurationKm ?? 200.0
        let lastWaxDate = bike.lastWaxEntry?.date

        let riddenKm = bike.rides
            .filter { lastWaxDate == nil || $0.date > lastWaxDate! }
            .reduce(0.0) { $0 + $1.distanceKm }

        return WaxStatus(riddenKm: riddenKm, durationKm: durationKm)
    }

    // MARK: - Helpers

    private func refreshDateRange(for bike: Bike) -> (start: Date, end: Date) {
        let end = Date()
        let lastWax = bike.lastWaxEntry?.date
        let start = lastWax ?? Calendar.current.date(byAdding: .year, value: -1, to: end)!
        return (start, end)
    }

    /// Inserts rides that are not yet stored locally (identified by Strava activity ID).
    private func insertNewRides(_ stravaRides: [StravaActivity], into bike: Bike) throws {
        let existingIds = Set(bike.rides.map(\.stravaActivityId))

        for activity in stravaRides where !existingIds.contains(activity.id) {
            let ride = Ride(
                stravaActivityId: activity.id,
                date: activity.startDate,
                distanceKm: activity.distanceKm
            )
            modelContext.insert(ride)
            bike.rides.append(ride)
        }
    }

    /// Fetches a locally stored bike by its Strava ID, or returns nil if not found.
    private func fetchLocalBike(stravaId: String) throws -> Bike? {
        try modelContext.fetch(FetchDescriptor<Bike>()).first { $0.stravaId == stravaId }
    }

    /// Returns the first AppSettings record, or nil if none has been created yet.
    private func fetchAppSettings() throws -> AppSettings? {
        return try modelContext.fetch(FetchDescriptor<AppSettings>()).first
    }
}
