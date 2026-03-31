//
//  BikeRowView.swift
//  BikeChain
//
//  Created by Thomas Schenker on 30.03.26.
//

import SwiftUI

struct BikeRowView: View {
    let bike: Bike
    let waxDurationKm: Double
    let onAddWaxEntry: () -> Void

    private var lastWaxDate: Date? {
        bike.lastWaxEntry?.date
    }

    private var riddenKm: Double {
        let cutoff = lastWaxDate
        return bike.rides
            .filter { cutoff == nil || $0.date > cutoff! }
            .reduce(0.0) { $0 + $1.distanceKm }
    }

    private var progress: Double {
        min(riddenKm / waxDurationKm, 1.0)
    }

    private var isOverdue: Bool { riddenKm >= waxDurationKm }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Name + wax button
            HStack(alignment: .center) {
                Text(bike.name)
                    .font(.headline)
                Spacer()
                Button(action: onAddWaxEntry) {
                    Label("Log Wax", systemImage: "checkmark.seal")
                        .foregroundStyle(isOverdue ? .white : .black)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(isOverdue ? .red : .blue)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 10)
                    Capsule()
                        .fill(isOverdue ? Color.red : Color.green)
                        .frame(width: max(geo.size.width * progress, progress > 0 ? 10 : 0), height: 10)
                }
            }
            .frame(height: 10)

            // km label + last wax date
            HStack {
                Text(String(format: "%.0f / %.0f km", riddenKm, waxDurationKm))
                    .font(.caption)
                    .foregroundStyle(isOverdue ? .red : .primary)
                Spacer()
                if let lastWaxDate {
                    Text("Last waxed \(lastWaxDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.primary)
                } else {
                    Text("Never waxed")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
