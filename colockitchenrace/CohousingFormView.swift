//
//  CohousingFormView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 09/10/2023.
//

import ComposableArchitecture
import SwiftUI

struct CohousingFormFeature: Reducer {
    struct State: Equatable {
        var cohousing: Cohousing
    }

    enum Action {

    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            
            }
        }
    }
}

struct CohousingFormView: View {
    let store: StoreOf<CohousingFormFeature>

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    CohousingFormView(
        store: Store(initialState: CohousingFormFeature.State(cohousing: .mock)) {
            CohousingFormFeature()
        })
}
