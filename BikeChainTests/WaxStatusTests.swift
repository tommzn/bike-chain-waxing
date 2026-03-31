//
//  WaxStatusTests.swift
//  BikeChainTests
//
//  Created by Thomas Schenker on 30.03.26.
//

import Testing
@testable import BikeChain

@Suite("WaxStatus", .serialized)
struct WaxStatusTests {

    // MARK: remainingKm

    @Test func remainingKmIsPositiveWhenNotDue() {
        let status = WaxStatus(riddenKm: 80, durationKm: 200)
        #expect(status.remainingKm == 120)
    }

    @Test func remainingKmIsNegativeWhenOverdue() {
        let status = WaxStatus(riddenKm: 250, durationKm: 200)
        #expect(status.remainingKm == -50)
    }

    // MARK: isDue

    @Test func isNotDueWhenBelowThreshold() {
        let status = WaxStatus(riddenKm: 199.9, durationKm: 200)
        #expect(!status.isDue)
    }

    @Test func isDueWhenExactlyAtThreshold() {
        let status = WaxStatus(riddenKm: 200, durationKm: 200)
        #expect(status.isDue)
    }

    @Test func isDueWhenAboveThreshold() {
        let status = WaxStatus(riddenKm: 201, durationKm: 200)
        #expect(status.isDue)
    }

    // MARK: progress

    @Test func progressIsZeroWithNoRides() {
        let status = WaxStatus(riddenKm: 0, durationKm: 200)
        #expect(status.progress == 0)
    }

    @Test func progressIsHalfway() {
        let status = WaxStatus(riddenKm: 100, durationKm: 200)
        #expect(status.progress == 0.5)
    }

    @Test func progressIsCappedAtOneWhenOverdue() {
        let status = WaxStatus(riddenKm: 400, durationKm: 200)
        #expect(status.progress == 1.0)
    }

    // MARK: summary

    @Test func summaryFormat() {
        let status = WaxStatus(riddenKm: 123.4, durationKm: 200.0)
        #expect(status.summary == "123.4 km of 200.0 km")
    }

    @Test func summaryFormatsToOneDecimalPlace() {
        let status = WaxStatus(riddenKm: 99.99, durationKm: 200.0)
        #expect(status.summary == "100.0 km of 200.0 km")
    }
}
