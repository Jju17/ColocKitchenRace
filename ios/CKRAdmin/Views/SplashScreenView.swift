//
//  SplashScreenView.swift
//  colocskitchenrace
//
//  Created by Julien Rahier on 24/05/2024.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct SplashScreenFeature {
    struct State: Equatable {}
    enum Action {}

    var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}

struct SplashScreenView: View {
    let store: StoreOf<SplashScreenFeature>
    
    var body: some View {
        ZStack(alignment: .center) {
            Color.ckrLavenderLight
                .ignoresSafeArea()
            VStack {
                Image("AdminLogoNoFill")
                    .resizable()
                    .frame(width: 150, height: 150, alignment: .center)
                ProgressView()
                    .progressViewStyle(.circular)
                    .imageScale(.large)
            }
        }
    }
}

#Preview {
    SplashScreenView(store: Store(initialState: SplashScreenFeature.State()) {
        SplashScreenFeature()
    })
}
