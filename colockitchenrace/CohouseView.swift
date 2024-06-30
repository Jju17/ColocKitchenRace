//
//  CohouseView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 29/01/2024.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct CohouseFeature {

    @ObservableState
    struct State {
//        case cohouse(CohouseDetailFeature.State)
        var noCohouse = NoCohouseFeature.State()
        @Shared(.cohouse) var cohouse
    }

    enum Action {
        case noCohouse(NoCohouseFeature.Action)
    }

    @Reducer
    struct Path {
        @ObservableState
        enum State {
            case profile(UserProfileDetailFeature.State)
        }
        enum Action {
            case profile(UserProfileDetailFeature.Action)
        }
        var body: some ReducerOf<Self> {
            Scope(state: \.profile, action: \.profile) {
                UserProfileDetailFeature()
            }
        }
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.noCohouse, action: \.noCohouse) {
            NoCohouseFeature()
        }

        Reduce { state, action in
            switch action {
            case .noCohouse:
                return .none
            }
        }
    }
}

struct CohouseView: View {
    @Perception.Bindable var store: StoreOf<CohouseFeature>

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                if let cohouse = store.state.cohouse {
                    CohouseDetailView(store: .init(initialState: CohouseDetailFeature.State(cohouse: Shared(cohouse)), reducer: {
                        CohouseDetailFeature()
                    }))
                } else {
                    NoCohouseView(
                        store: self.store.scope(
                            state: \.noCohouse,
                            action: \.noCohouse
                        )
                    )
                }
            }
        }
    }
}

#Preview {
    CohouseView(
        store: .init(
            initialState: CohouseFeature.State()
        ) {
            CohouseFeature()
        }
    )
}
