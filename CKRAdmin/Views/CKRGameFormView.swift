//
//  CKRGameFormView.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 20/05/2025.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct CKRGameFormFeature {

    // MARK: - Defaults

    /// Default game date: 2 months from now.
    static func defaultGameDate() -> Date {
        Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date()
    }

    /// Default registration deadline: 2 weeks before the game.
    static func defaultDeadline(for gameDate: Date) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: -2, to: gameDate) ?? gameDate
    }

    /// Allowed max participants values (multiples of 4, from 4 to 100).
    static let participantOptions: [Int] = stride(from: 20, through: 400, by: 4).map { $0 }

    // MARK: - State

    @ObservableState
    struct State {
        var wipCKRGame: CKRGame
        var isEditing: Bool

        /// Create mode — new game with smart defaults.
        init() {
            let gameDate = CKRGameFormFeature.defaultGameDate()
            self.wipCKRGame = CKRGame(
                nextGameDate: gameDate,
                registrationDeadline: CKRGameFormFeature.defaultDeadline(for: gameDate)
            )
            self.isEditing = false
        }

        /// Edit mode — pre-fill with existing game.
        init(game: CKRGame) {
            self.wipCKRGame = game
            self.isEditing = true
        }
    }

    // MARK: - Action

    enum Action: BindableAction {
        case binding(BindingAction<State>)
    }

    // MARK: - Body

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.wipCKRGame.nextGameDate):
                // Auto-update deadline when game date changes (keep 2 weeks before)
                let newDeadline = Self.defaultDeadline(for: state.wipCKRGame.nextGameDate)
                if state.wipCKRGame.registrationDeadline > state.wipCKRGame.nextGameDate
                    || state.wipCKRGame.registrationDeadline < Date() {
                    state.wipCKRGame.registrationDeadline = newDeadline
                }
                return .none
            case .binding:
                return .none
            }
        }
    }
}

struct CKRGameFormView: View {
    @Bindable var store: StoreOf<CKRGameFormFeature>

    var body: some View {
        Form {
            Section("Edition") {
                Stepper(
                    "Edition #\(store.wipCKRGame.editionNumber)",
                    value: $store.wipCKRGame.editionNumber,
                    in: 1...999
                )
            }

            Section("Dates") {
                DatePicker(
                    "Game date",
                    selection: $store.wipCKRGame.nextGameDate,
                    in: Date()...,
                    displayedComponents: [.date]
                )

                DatePicker(
                    "Registration deadline",
                    selection: $store.wipCKRGame.registrationDeadline,
                    in: Date()...store.wipCKRGame.nextGameDate,
                    displayedComponents: [.date]
                )
            }

            Section("Participants") {
                Picker("Max participants", selection: $store.wipCKRGame.maxParticipants) {
                    ForEach(CKRGameFormFeature.participantOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
            }
        }
    }
}

#Preview {
    CKRGameFormView(
        store: Store(initialState: CKRGameFormFeature.State()) {
            CKRGameFormFeature()
        }
    )
}
