//
//  AppSettingsView.swift
//  BikeChain
//
//  Created by Thomas Schenker on 30.03.26.
//

import SwiftUI
import SwiftData

struct AppSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]

    private var currentAppSettings: AppSettings {
        if let existing = settings.first {
            return existing
        }
        let new = AppSettings()
        modelContext.insert(new)
        return new
    }

    // Local binding-friendly state, initialized from persisted value
    @State private var waxDuration: Double = 200

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Wax Interval")
                        Spacer()
                        Text("\(Int(waxDuration)) km")
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                    }
                    Slider(value: $waxDuration, in: 0...800, step: 1)
                        .onChange(of: waxDuration) { _, newValue in
                            currentAppSettings.waxDurationKm = newValue
                        }
                    HStack {
                        Text("0 km")
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("800 km")
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Chain Waxing")
            } footer: {
                Text("Distance after which you should wax your chain again.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            waxDuration = currentAppSettings.waxDurationKm
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: AppSettings.self, configurations: config)
    NavigationStack {
        AppSettingsView()
    }
    .modelContainer(container)
}
