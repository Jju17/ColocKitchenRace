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

    // Note: Date() in static default — acceptable for form initialization, cannot use @Dependency in static context.
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

    // MARK: - State

    @ObservableState
    struct State {
        var wipCKRGame: CKRGame
        var isEditing: Bool

        var isValid: Bool {
            guard let gameDate = wipCKRGame.nextGameDate,
                  let deadline = wipCKRGame.registrationDeadline,
                  let countdown = wipCKRGame.startCKRCountdown
            else { return false }
            return wipCKRGame.maxParticipants > 0
                && wipCKRGame.pricePerPersonCents > 0
                && gameDate > Date()
                && deadline > Date()
                && deadline < gameDate
                && countdown < deadline
        }

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
        case pricePerPersonEurosChanged(Double)
    }

    // MARK: - Body

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.wipCKRGame.nextGameDate):
                // Auto-update deadline when game date changes (keep 2 weeks before)
                guard let gameDate = state.wipCKRGame.nextGameDate else { return .none }
                let newDeadline = Self.defaultDeadline(for: gameDate)
                let deadline = state.wipCKRGame.registrationDeadline ?? newDeadline
                if deadline > gameDate.addingTimeInterval(-Self.minimumDateGap)
                    || deadline < Date() {
                    state.wipCKRGame.registrationDeadline = newDeadline
                }
                // Ensure countdown stays at least 1h before deadline
                let updatedDeadline = state.wipCKRGame.registrationDeadline ?? newDeadline
                if let countdown = state.wipCKRGame.startCKRCountdown,
                   countdown > updatedDeadline.addingTimeInterval(-Self.minimumDateGap) {
                    state.wipCKRGame.startCKRCountdown = Self.defaultCountdown(for: updatedDeadline)
                }
                return .none
            case .binding(\.wipCKRGame.registrationDeadline):
                // Ensure countdown stays at least 1h before deadline
                guard let deadline = state.wipCKRGame.registrationDeadline else { return .none }
                if let countdown = state.wipCKRGame.startCKRCountdown,
                   countdown > deadline.addingTimeInterval(-Self.minimumDateGap) {
                    state.wipCKRGame.startCKRCountdown = Self.defaultCountdown(for: deadline)
                }
                return .none
            case let .pricePerPersonEurosChanged(euros):
                state.wipCKRGame.pricePerPersonCents = Int((euros * 100).rounded())
                return .none
            case .binding:
                return .none
            }
        }
    }
}

struct CKRGameFormView: View {
    @Bindable var store: StoreOf<CKRGameFormFeature>

    // Unwrapped date bindings (these dates are always set via init defaults)
    private var countdownBinding: Binding<Date> {
        Binding(
            get: { store.wipCKRGame.startCKRCountdown ?? Date() },
            set: { store.wipCKRGame.startCKRCountdown = $0 }
        )
    }
    private var deadlineBinding: Binding<Date> {
        Binding(
            get: { store.wipCKRGame.registrationDeadline ?? Date() },
            set: { store.wipCKRGame.registrationDeadline = $0 }
        )
    }
    private var gameDateBinding: Binding<Date> {
        Binding(
            get: { store.wipCKRGame.nextGameDate ?? Date() },
            set: { store.wipCKRGame.nextGameDate = $0 }
        )
    }

    private var countdown: Date { store.wipCKRGame.startCKRCountdown ?? Date() }
    private var deadline: Date { store.wipCKRGame.registrationDeadline ?? Date() }
    private var gameDate: Date { store.wipCKRGame.nextGameDate ?? Date() }

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
                    selection: countdownBinding,
                    in: ...deadline.addingTimeInterval(-CKRGameFormFeature.minimumDateGap),
                    displayedComponents: [.date, .hourAndMinute]
                )

                DatePicker(
                    "Registration deadline",
                    selection: deadlineBinding,
                    in: countdown.addingTimeInterval(CKRGameFormFeature.minimumDateGap)...gameDate.addingTimeInterval(-CKRGameFormFeature.minimumDateGap),
                    displayedComponents: [.date, .hourAndMinute]
                )

                DatePicker(
                    "Game date",
                    selection: gameDateBinding,
                    in: deadline.addingTimeInterval(CKRGameFormFeature.minimumDateGap)...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section("Participants") {
                HStack {
                    Text("Max participants:")
                    Spacer()
                    TextField(
                        "1000",
                        value: $store.wipCKRGame.maxParticipants,
                        format: .number
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
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
                            set: { store.send(.pricePerPersonEurosChanged($0)) }
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
