//
//  PlanningView.swift
//  ColocKitchenRace
//
//  Created by Julien Rahier on 13/02/2026.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct PlanningFeature {

    @ObservableState
    struct State: Equatable {
        @Shared(.ckrGame) var ckrGame
        @Shared(.cohouse) var cohouse
        var planning: CKRMyPlanning?
        var isLoading: Bool = false
        var errorMessage: String?

        var isRevealed: Bool {
            ckrGame?.isRevealed ?? false
        }

        var isRegistered: Bool {
            guard let game = ckrGame, let cohouse else { return false }
            return game.cohouseIDs.contains(cohouse.id.uuidString)
        }
    }

    enum Action {
        case onTask
        case planningLoaded(CKRMyPlanning)
        case planningFailed(String)
    }

    @Dependency(\.ckrClient) var ckrClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onTask:
                guard let game = state.ckrGame,
                      let cohouse = state.cohouse,
                      game.isRevealed
                else { return .none }

                state.isLoading = true
                let gameId = game.id.uuidString
                let cohouseId = cohouse.id.uuidString

                return .run { send in
                    do {
                        let planning = try await self.ckrClient.getMyPlanning(gameId, cohouseId)
                        await send(.planningLoaded(planning))
                    } catch {
                        await send(.planningFailed(error.localizedDescription))
                    }
                }
            case let .planningLoaded(planning):
                state.isLoading = false
                state.planning = planning
                state.errorMessage = nil
                return .none
            case let .planningFailed(message):
                state.isLoading = false
                state.errorMessage = message
                return .none
            }
        }
    }
}

// MARK: - View

struct PlanningView: View {
    let store: StoreOf<PlanningFeature>

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH'h'mm"
        f.timeZone = TimeZone(identifier: "Europe/Brussels")
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if !store.isRevealed || !store.isRegistered {
                    ContentUnavailableView(
                        "Planning pas encore disponible",
                        systemImage: "calendar.badge.clock",
                        description: Text("Le planning de la soiree sera bientot disponible !")
                    )
                } else if store.isLoading {
                    ProgressView("Chargement du planning...")
                } else if let error = store.errorMessage {
                    ContentUnavailableView(
                        "Erreur",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if let planning = store.planning {
                    planningContent(planning)
                } else {
                    ContentUnavailableView(
                        "Planning pas encore disponible",
                        systemImage: "calendar.badge.clock",
                        description: Text("Le planning de la soiree sera bientot disponible !")
                    )
                }
            }
            .navigationTitle("Planning")
            .task {
                store.send(.onTask)
            }
        }
    }

    // MARK: - Planning Content (Timeline)

    @ViewBuilder
    private func planningContent(_ planning: CKRMyPlanning) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                timelineRow(style: .apero, startTime: planning.apero.startTime, isLast: false) {
                    PlanningStepCardView(
                        step: planning.apero,
                        style: .apero,
                        timeFormatter: timeFormatter
                    )
                }

                timelineRow(style: .diner, startTime: planning.diner.startTime, isLast: false) {
                    PlanningStepCardView(
                        step: planning.diner,
                        style: .diner,
                        timeFormatter: timeFormatter
                    )
                }

                timelineRow(style: .party, startTime: planning.party.startTime, isLast: true) {
                    PlanningPartyCardView(
                        party: planning.party,
                        style: .party,
                        timeFormatter: timeFormatter
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Timeline Row

    @ViewBuilder
    private func timelineRow<Content: View>(
        style: StepStyle,
        startTime: Date,
        isLast: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Text(timeFormatter.string(from: startTime))
                    .font(.custom("BaksoSapi", size: 14))
                    .foregroundStyle(.secondary)

                Circle()
                    .fill(style.color)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .fill(Color(.systemBackground))
                            .frame(width: 6, height: 6)
                    )

                if !isLast {
                    Rectangle()
                        .fill(style.color.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 50)

            content()
                .padding(.bottom, isLast ? 0 : 20)
        }
    }
}

// MARK: - Preview

#Preview {
    PlanningView(
        store: Store(
            initialState: {
                var state = PlanningFeature.State()
                state.planning = CKRMyPlanning(
                    apero: PlanningStep(
                        role: .visitor,
                        cohouseName: "Les Joyeux Lurons",
                        address: "Rue de la Loi 42, 1000 Bruxelles",
                        hostPhone: "+32 471 123456",
                        visitorPhone: "+32 472 654321",
                        totalPeople: 8,
                        dietarySummary: ["Vegetarien": 2, "Sans gluten": 1],
                        startTime: Date().addingTimeInterval(3600),
                        endTime: Date().addingTimeInterval(3600 * 3)
                    ),
                    diner: PlanningStep(
                        role: .host,
                        cohouseName: "La Bande a Manu",
                        address: "Avenue Louise 88, 1050 Ixelles",
                        hostPhone: "+32 472 654321",
                        visitorPhone: nil,
                        totalPeople: 6,
                        dietarySummary: ["Sans gluten": 1],
                        startTime: Date().addingTimeInterval(3600 * 3),
                        endTime: Date().addingTimeInterval(3600 * 5)
                    ),
                    party: PartyInfo(
                        name: "CKR Party",
                        address: "Rue Blaes 208, 1000 Bruxelles",
                        startTime: Date().addingTimeInterval(3600 * 5),
                        endTime: Date().addingTimeInterval(3600 * 10),
                        note: "Ramene ta bonne humeur !"
                    )
                )
                return state
            }()
        ) {
            PlanningFeature()
        }
    )
}
