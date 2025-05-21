//
//  SplashScreenView.swift
//  colockitchenrace
//
//  Created by Julien Rahier on 24/05/2024.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct SplashScreenFeature {
    struct State {}
    enum Action {
        case onAppear
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
            }
        }
    }
}

struct SplashScreenView: View {
    let store: StoreOf<SplashScreenFeature>
    
    var body: some View {
        ZStack(alignment: .center) {
            Color(Color.CKRPurple)
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
