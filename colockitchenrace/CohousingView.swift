//
//  CohousingView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 29/01/2024.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct CohousingFeature {

    @ObservableState
    enum State {
        case cohousing(CohousingDetailFeature.State)
        case noCohousing(NoCohouseFeature.State)
    }

    enum Action {
        case cohousing(CohousingDetailFeature.Action)
        case noCohousing(NoCohouseFeature.Action)
    }

    @Reducer
    struct Path {
        @ObservableState
        enum State {
            case profile(UserProfileFeature.State)
        }
        enum Action {
            case profile(UserProfileFeature.Action)
        }
        var body: some ReducerOf<Self> {
            Scope(state: \.profile, action: \.profile) {
                UserProfileFeature()
            }
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .cohousing:
                return .none
            case .noCohousing:
                return .none
            }
        }
    }
}

struct CohousingView: View {
    @Perception.Bindable var store: StoreOf<CohousingFeature>

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                switch store.state {
                case .cohousing:
                    if let cohousingStore = store.scope(state: \.cohousing, action: \.cohousing) {
                        CohousingDetailView(store: cohousingStore)
                    }
                case .noCohousing:
                    if let noCohouseStore = store.scope(state: \.noCohousing, action: \.noCohousing) {
                        NoCohousingView(store: noCohouseStore)
                    }
                }
            }
        }
    }
}

#Preview {
    CohousingView(
        store: .init(
            initialState: CohousingFeature.State.noCohousing(NoCohouseFeature.State())
        ) {
            CohousingFeature()
        }
    )
}
