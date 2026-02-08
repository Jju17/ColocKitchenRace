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
    @ObservableState
    struct State {
        var wipCKRGame: CKRGame = CKRGame(nextGameDate: Date())
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

struct CKRGameFormView: View {
    @Bindable var store: StoreOf<CKRGameFormFeature>

    var body: some View {
        Form {
            DatePicker("Next CKR Game", selection: $store.wipCKRGame.nextGameDate)
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
