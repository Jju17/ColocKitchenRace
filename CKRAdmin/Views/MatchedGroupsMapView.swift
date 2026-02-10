//
//  MatchedGroupsMapView.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 10/02/2026.
//

import ComposableArchitecture
import MapKit
import SwiftUI

// MARK: - Feature

@Reducer
struct MatchedGroupsMapFeature {
    @ObservableState
    struct State: Equatable {
        var matchedGroups: [MatchedGroup]
        var cohouses: [CohouseMapItem] = []
        var isLoading: Bool = true
        var errorMessage: String?
        var selectedCohouseId: String?
    }

    enum Action {
        case onAppear
        case cohousesLoaded(Result<[CohouseMapItem], CohouseError>)
        case cohouseTapped(String?)
    }

    @Dependency(\.cohouseClient) var cohouseClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let allIds = Array(Set(state.matchedGroups.flatMap(\.cohouseIds)))
                return .run { send in
                    let result = await cohouseClient.getCohouses(allIds)
                    await send(.cohousesLoaded(result))
                }
            case let .cohousesLoaded(.success(cohouses)):
                state.cohouses = cohouses
                state.isLoading = false
                state.errorMessage = nil
                return .none
            case let .cohousesLoaded(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            case let .cohouseTapped(id):
                state.selectedCohouseId = state.selectedCohouseId == id ? nil : id
                return .none
            }
        }
    }
}

// MARK: - View

struct MatchedGroupsMapView: View {
    @Bindable var store: StoreOf<MatchedGroupsMapFeature>

    private static let groupColors: [Color] = [
        .red, .blue, .green, .orange, .purple,
        .pink, .cyan, .yellow, .mint, .indigo,
    ]

    var body: some View {
        Group {
            if store.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading cohouses...")
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage = store.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else {
                mapContent
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(isPresented: Binding(
            get: { store.selectedCohouseId != nil },
            set: { if !$0 { store.send(.cohouseTapped(nil)) } }
        )) {
            if let selectedId = store.selectedCohouseId,
               let cohouse = store.cohouses.first(where: { $0.id == selectedId }),
               let groupIndex = groupIndex(for: selectedId) {
                let color = Self.groupColors[groupIndex % Self.groupColors.count]
                cohouseDetailSheet(cohouse: cohouse, groupIndex: groupIndex, color: color)
            }
        }
    }

    @ViewBuilder
    private var mapContent: some View {
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.85, longitude: 4.35),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )

        Map(initialPosition: .region(initialRegion)) {
            ForEach(Array(store.matchedGroups.enumerated()), id: \.offset) { groupIndex, group in
                let color = Self.groupColors[groupIndex % Self.groupColors.count]

                ForEach(group.cohouseIds, id: \.self) { cohouseId in
                    if let cohouse = store.cohouses.first(where: { $0.id == cohouseId }) {
                        Annotation(
                            cohouse.name,
                            coordinate: CLLocationCoordinate2D(
                                latitude: cohouse.latitude,
                                longitude: cohouse.longitude
                            ),
                            anchor: .bottom
                        ) {
                            mapPin(
                                cohouse: cohouse,
                                groupIndex: groupIndex,
                                color: color
                            )
                        }
                    }
                }
            }
        }
        .mapStyle(.standard)
    }

    @ViewBuilder
    private func mapPin(cohouse: CohouseMapItem, groupIndex: Int, color: Color) -> some View {
        Button {
            store.send(.cohouseTapped(cohouse.id))
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 36, height: 36)
                    .shadow(radius: 2)
                Text("\(groupIndex + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func cohouseDetailSheet(cohouse: CohouseMapItem, groupIndex: Int, color: Color) -> some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Name", value: cohouse.name)
                    LabeledContent("ID", value: cohouse.id)
                    LabeledContent("Group", value: "\(groupIndex + 1)")
                }

                Section("Members") {
                    if cohouse.userNames.isEmpty {
                        Text("No members")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(cohouse.userNames, id: \.self) { name in
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(color)
                                Text(name)
                            }
                        }
                    }
                }
            }
            .textSelection(.enabled)
            .navigationTitle(cohouse.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func groupIndex(for cohouseId: String) -> Int? {
        store.matchedGroups.firstIndex { $0.cohouseIds.contains(cohouseId) }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MatchedGroupsMapView(
            store: Store(
                initialState: MatchedGroupsMapFeature.State(
                    matchedGroups: [
                        MatchedGroup(cohouseIds: ["c1", "c2", "c3", "c4"]),
                        MatchedGroup(cohouseIds: ["c5", "c6", "c7", "c8"]),
                    ],
                    cohouses: [
                        CohouseMapItem(id: "c1", name: "Les Fous", latitude: 50.850, longitude: 4.350, userNames: ["Alice", "Bob"]),
                        CohouseMapItem(id: "c2", name: "Zone 88", latitude: 50.852, longitude: 4.352, userNames: ["Charlie"]),
                        CohouseMapItem(id: "c3", name: "La Baraque", latitude: 50.848, longitude: 4.348, userNames: ["David", "Eve"]),
                        CohouseMapItem(id: "c4", name: "Le Nid", latitude: 50.854, longitude: 4.354, userNames: ["Frank"]),
                        CohouseMapItem(id: "c5", name: "Chez Nous", latitude: 50.860, longitude: 4.370, userNames: ["Grace", "Heidi"]),
                        CohouseMapItem(id: "c6", name: "La Casa", latitude: 50.862, longitude: 4.372, userNames: ["Ivan"]),
                        CohouseMapItem(id: "c7", name: "Le Phare", latitude: 50.858, longitude: 4.368, userNames: ["Judy", "Karl"]),
                        CohouseMapItem(id: "c8", name: "Le Refuge", latitude: 50.864, longitude: 4.374, userNames: ["Leo"]),
                    ],
                    isLoading: false
                )
            ) {
                MatchedGroupsMapFeature()
            }
        )
        .navigationTitle("Matched Groups")
    }
}
