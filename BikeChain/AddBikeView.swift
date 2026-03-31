//
//  AddBikeView.swift
//  BikeChain
//
//  Created by Thomas Schenker on 30.03.26.
//

import SwiftUI
import SwiftData

struct AddBikeView: View {
    @ObservedObject var store: BikeChainStore
    @Query private var localBikes: [Bike]
    @Environment(\.dismiss) private var dismiss

    private var importedIds: Set<String> {
        Set(localBikes.map(\.stravaId))
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !store.isAuthenticated {
                    VStack(spacing: 16) {
                        Image(systemName: "link.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Connect to Strava to import your bikes.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Connect to Strava") {
                            Task {
                                await store.authorize()
                                if store.isAuthenticated {
                                    await store.loadStravaBikes()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.availableStravaBikes.isEmpty {
                    ContentUnavailableView(
                        "No Bikes Found",
                        systemImage: "bicycle",
                        description: Text("No bikes were found in your Strava account.")
                    )
                } else {
                    List(store.availableStravaBikes) { bike in
                        let isImported = importedIds.contains(bike.id)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bike.name)
                                    .font(.headline)
                                    .foregroundStyle(isImported ? .secondary : .primary)
                                Text(String(format: "%.0f km total", bike.distanceKm))
                                    .font(.caption)
                                    .foregroundStyle(isImported ? .secondary : .primary)
                            }
                            Spacer()
                            if isImported {
                                Label("Added", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button("Add") {
                                    try? store.importBike(bike)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                        .disabled(isImported)
                    }
                }
            }
            .navigationTitle("Add Bike")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Error",
                isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } }),
                actions: { Button("OK") { store.error = nil } },
                message: { Text(store.error?.localizedDescription ?? "") }
            )
        }
        .task {
            guard store.isAuthenticated else { return }
            await store.loadStravaBikes()
        }
    }
}

private func makeAddBikePreviewContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Bike.self, Ride.self, WaxEntry.self, AppSettings.self, configurations: config)
    // Pre-import two bikes so the "already added" state is visible in the preview.
    container.mainContext.insert(Bike(stravaId: "s1", name: "Canyon Gravel CF SL"))
    container.mainContext.insert(Bike(stravaId: "s2", name: "Trek Domane SL6"))
    return container
}

#Preview {
    let container = makeAddBikePreviewContainer()
    let store = BikeChainStore(strava: MockStravaService(), modelContext: container.mainContext)
    AddBikeView(store: store)
        .modelContainer(container)
}
