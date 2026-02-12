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

    /// Default countdown start: 1 month before the registration deadline.
    static func defaultCountdown(for deadline: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: -1, to: deadline) ?? deadline
    }

    /// Minimum gap between consecutive dates (1 hour).
    static let minimumDateGap: TimeInterval = 3600

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
            let deadline = CKRGameFormFeature.defaultDeadline(for: gameDate)
            self.wipCKRGame = CKRGame(
                startCKRCountdown: CKRGameFormFeature.defaultCountdown(for: deadline),
                nextGameDate: gameDate,
                registrationDeadline: deadline
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
                if state.wipCKRGame.registrationDeadline > state.wipCKRGame.nextGameDate.addingTimeInterval(-Self.minimumDateGap)
                    || state.wipCKRGame.registrationDeadline < Date() {
                    state.wipCKRGame.registrationDeadline = newDeadline
                }
                // Ensure countdown stays at least 1h before deadline
                if state.wipCKRGame.startCKRCountdown > state.wipCKRGame.registrationDeadline.addingTimeInterval(-Self.minimumDateGap) {
                    state.wipCKRGame.startCKRCountdown = Self.defaultCountdown(for: state.wipCKRGame.registrationDeadline)
                }
                return .none
            case .binding(\.wipCKRGame.registrationDeadline):
                // Ensure countdown stays at least 1h before deadline
                if state.wipCKRGame.startCKRCountdown > state.wipCKRGame.registrationDeadline.addingTimeInterval(-Self.minimumDateGap) {
                    state.wipCKRGame.startCKRCountdown = Self.defaultCountdown(for: state.wipCKRGame.registrationDeadline)
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
                    "CKR Countdown start",
                    selection: $store.wipCKRGame.startCKRCountdown,
                    in: ...store.wipCKRGame.registrationDeadline.addingTimeInterval(-CKRGameFormFeature.minimumDateGap),
                    displayedComponents: [.date, .hourAndMinute]
                )

                DatePicker(
                    "Registration deadline",
                    selection: $store.wipCKRGame.registrationDeadline,
                    in: store.wipCKRGame.startCKRCountdown.addingTimeInterval(CKRGameFormFeature.minimumDateGap)...store.wipCKRGame.nextGameDate.addingTimeInterval(-CKRGameFormFeature.minimumDateGap),
                    displayedComponents: [.date, .hourAndMinute]
                )

                DatePicker(
                    "Game date",
                    selection: $store.wipCKRGame.nextGameDate,
                    in: store.wipCKRGame.registrationDeadline.addingTimeInterval(CKRGameFormFeature.minimumDateGap)...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section("Participants") {
                Picker("Max participants", selection: $store.wipCKRGame.maxParticipants) {
                    ForEach(CKRGameFormFeature.participantOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
            }

            Section("Pricing") {
                HStack {
                    Text("Price per person")
                    Spacer()
                    TextField(
                        "5.00",
                        value: Binding(
                            get: { Double(store.wipCKRGame.pricePerPersonCents) / 100.0 },
                            set: { store.wipCKRGame.pricePerPersonCents = Int(($0 * 100).rounded()) }
                        ),
                        format: .number.precision(.fractionLength(2))
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    Text("€")
                        .foregroundStyle(.secondary)
                }

                Text("Stored as \(store.wipCKRGame.pricePerPersonCents) cents — displayed as \(store.wipCKRGame.formattedPricePerPerson)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
