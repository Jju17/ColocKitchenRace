//
//  NoCohousingView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 03/02/2024.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct NoCohouseFeature {

    @ObservableState
    struct State: Equatable {
        var cohouseCode: String = ""
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            }
        }
    }

}

struct NoCohousingView: View {
    @Perception.Bindable var store: StoreOf<NoCohouseFeature>
    @State var cohouseCode: String = ""

    var body: some View {
        WithPerceptionTracking {
            Form {
                Section {
                    HStack(spacing: 50) {
                        Text("Code")
                        TextField(text: $store.cohouseCode) {
                            Text("Code")
                        }
                    }
                    Button("Join existing cohouse") {}
                }

                Section { Button("Create new cohouse") {} }
            }
            .navigationTitle("Cohouse")
        }
    }
}

#Preview {
    NavigationStack {
        NoCohousingView(store: .init(initialState: NoCohouseFeature.State(), reducer: {
            NoCohouseFeature()
        }))
    }
}
