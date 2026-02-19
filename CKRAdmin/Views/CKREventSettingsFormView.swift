//
//  CKREventSettingsFormView.swift
//  CKRAdmin
//
//  Created by Julien Rahier on 13/02/2026.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct CKREventSettingsFormFeature {

    @ObservableState
    struct State {
        var settings: CKREventSettings

        /// Create mode — new settings with defaults based on game date.
        init(gameDate: Date) {
            let calendar = Calendar.current
            let aperoStart = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: gameDate) ?? gameDate
            let aperoEnd = calendar.date(bySettingHour: 20, minute: 30, second: 0, of: gameDate) ?? gameDate
            let dinerStart = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: gameDate) ?? gameDate
            let dinerEnd = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: gameDate) ?? gameDate
            let nextDay = calendar.date(byAdding: .day, value: 1, to: gameDate) ?? gameDate
            let partyStart = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: nextDay) ?? nextDay
            let partyEnd = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: nextDay) ?? nextDay

            self.settings = CKREventSettings(
                aperoStartTime: aperoStart,
                aperoEndTime: aperoEnd,
                dinerStartTime: dinerStart,
                dinerEndTime: dinerEnd,
                partyStartTime: partyStart,
                partyEndTime: partyEnd,
                partyAddress: "",
                partyName: "TEUF"
            )
        }

        /// Edit mode — pre-fill with existing settings.
        init(existingSettings: CKREventSettings) {
            self.settings = existingSettings
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
    }
}

struct CKREventSettingsFormView: View {
    @Bindable var store: StoreOf<CKREventSettingsFormFeature>

    var body: some View {
        Form {
            Section("Aperitif") {
                DatePicker(
                    "Start",
                    selection: $store.settings.aperoStartTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                DatePicker(
                    "End",
                    selection: $store.settings.aperoEndTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section("Diner") {
                DatePicker(
                    "Start",
                    selection: $store.settings.dinerStartTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                DatePicker(
                    "End",
                    selection: $store.settings.dinerEndTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section("Party") {
                TextField("Party name", text: $store.settings.partyName)
                TextField("Address", text: $store.settings.partyAddress)
                DatePicker(
                    "Start",
                    selection: $store.settings.partyStartTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                DatePicker(
                    "End",
                    selection: $store.settings.partyEndTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
                TextField(
                    "Note (optional)",
                    text: Binding(
                        get: { store.settings.partyNote ?? "" },
                        set: { store.settings.partyNote = $0.isEmpty ? nil : $0 }
                    )
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        CKREventSettingsFormView(
            store: Store(
                initialState: CKREventSettingsFormFeature.State(gameDate: Date())
            ) {
                CKREventSettingsFormFeature()
            }
        )
        .navigationTitle("Event Settings")
    }
}
