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
    struct State: Equatable {
        var cohouseDetail: CohouseDetailFeature.State?
        var noCohouse = NoCohouseFeature.State()
        @Shared(.cohouse) var cohouse
    }

    enum Action {
        case cohouseDetail(CohouseDetailFeature.Action)
        case cohouseChanged
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
                case .cohouseChanged:
                    if let cohouse = Shared(state.$cohouse) {
                        if state.cohouseDetail == nil {
                            state.cohouseDetail = CohouseDetailFeature.State(cohouse: cohouse)
                        }
                    } else {
                        state.cohouseDetail = nil
                    }
                    return .none
                case .cohouseDetail:
                    return .none
                case .noCohouse:
                    return .none
            }
        }
        .ifLet(\.cohouseDetail, action: \.cohouseDetail) {
            CohouseDetailFeature()
        }
    }
}

struct CohouseView: View {
    @Bindable var store: StoreOf<CohouseFeature>

    var body: some View {
        NavigationStack {
            if let detailStore = store.scope(state: \.cohouseDetail, action: \.cohouseDetail) {
                CohouseDetailView(store: detailStore)
            } else {
                NoCohouseView(
                    store: self.store.scope(
                        state: \.noCohouse,
                        action: \.noCohouse
                    )
                )
            }
        }
        .onAppear {
            store.send(.cohouseChanged)
        }
        .onChange(of: store.cohouse) { _, _ in
            store.send(.cohouseChanged)
        }
    }
}

#Preview {
    CohouseView(
        store: Store(
            initialState: CohouseFeature.State()
        ) {
            CohouseFeature()
        }
    )
}
