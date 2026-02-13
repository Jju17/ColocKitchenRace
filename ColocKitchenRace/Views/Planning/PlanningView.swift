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
                        description: Text("Le planning de la soirée sera bientôt disponible !")
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
                        description: Text("Le planning de la soirée sera bientôt disponible !")
                    )
                }
            }
            .navigationTitle("Planning")
            .task {
                store.send(.onTask)
            }
        }
    }

    @ViewBuilder
    private func planningContent(_ planning: CKRMyPlanning) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // APÉRO
                stepCard(
                    emoji: "🍻",
                    title: "APÉRO",
                    step: planning.apero,
                    cohouseName: store.cohouse?.name
                )

                // DÎNER
                stepCard(
                    emoji: "🍽️",
                    title: "DÎNER",
                    step: planning.diner,
                    cohouseName: store.cohouse?.name
                )

                // TEUF
                partyCard(planning.party)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func stepCard(emoji: String, title: String, step: PlanningStep, cohouseName: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(emoji)
                    .font(.title)
                Text("\(title) - \(timeFormatter.string(from: step.startTime)) - \(timeFormatter.string(from: step.endTime))")
                    .font(.headline)
                    .bold()
            }

            if step.role == .host {
                Text("Vous recevez **\(step.cohouseName)** chez vous")
                    .font(.subheadline)
            } else {
                Text("Vous allez chez **\(step.cohouseName)**")
                    .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(step.address, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)

                if let hostPhone = step.hostPhone {
                    Label("Tel. hôte : \(hostPhone)", systemImage: "phone")
                        .font(.subheadline)
                }

                if let visitorPhone = step.visitorPhone {
                    Label("Tel. invité : \(visitorPhone)", systemImage: "phone")
                        .font(.subheadline)
                }
            }

            Text("Vous serez **\(step.totalPeople)** au total\(dietaryText(step.dietarySummary))")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func partyCard(_ party: PartyInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎉")
                    .font(.title)
                Text("\(party.name) - \(timeFormatter.string(from: party.startTime)) - \(timeFormatter.string(from: party.endTime))")
                    .font(.headline)
                    .bold()
            }

            Label(party.address, systemImage: "mappin.and.ellipse")
                .font(.subheadline)

            if let note = party.note, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .italic()
            }

            Text("Pas de bracelet, pas d'entrée !")
                .font(.subheadline)
                .bold()
                .underline()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func dietaryText(_ summary: [String: Int]) -> String {
        if summary.isEmpty { return "" }
        let items = summary.map { "\($0.value) \($0.key.lowercased())" }
        return " dont \(items.joined(separator: ", "))"
    }
}

#Preview {
    PlanningView(
        store: Store(initialState: PlanningFeature.State()) {
            PlanningFeature()
        }
    )
}
